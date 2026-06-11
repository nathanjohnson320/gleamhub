import ci/discovery as ci_discovery
import ci/merge as ci_merge
import ci/pipeline as ci_pipeline
import database
import git/browse_routes as repo_browse_routes
import git/exec as git_exec
import git/path as git_path
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import http/clerk_api
import http/label_routes
import http/list_query
import http/org_access
import http/user_display
import http/web.{type Context}
import issues/link_sync
import json/api as json_api
import pog
import mentions/notify as mention_notify
import mentions/resolve as mention_resolve
import notifications/create as notify
import reviews/merge as review_merge
import wisp.{type Request, type Response}

fn user_id(ctx: Context) -> String {
  let assert option.Some(id) = ctx.user_id
  id
}

fn git_commit_author(ctx: Context) -> git_exec.GitCommitAuthor {
  let id = user_id(ctx)
  let #(display, email) = case ctx.clerk {
    option.Some(client) ->
      case clerk_api.profile_for_user(client, id) {
        Ok(profile) -> profile
        Error(_) -> #(option.None, option.None)
      }
    option.None -> #(option.None, option.None)
  }
  let name = case display {
    option.Some(n) ->
      case string.trim(n) {
        "" -> id
        trimmed -> trimmed
      }
    option.None -> id
  }
  let email = case email {
    option.Some(e) ->
      case string.trim(e) {
        "" -> id <> "@users.gleamhub.local"
        trimmed -> trimmed
      }
    option.None -> id <> "@users.gleamhub.local"
  }
  git_exec.GitCommitAuthor(name:, email:)
}

fn ensure_user(ctx: Context) -> Result(Nil, Response) {
  case ctx.user_id {
    option.Some(_) -> Ok(Nil)
    option.None -> Error(wisp.response(401))
  }
}

fn hydrate_comments(
  ctx: Context,
  comments: List(database.MergeRequestCommentRow),
) -> List(database.MergeRequestCommentRow) {
  user_display.hydrate_mr_comments(ctx, comments)
}

fn mention_usernames(
  ctx: Context,
  comment: database.MergeRequestCommentRow,
) -> List(String) {
  user_display.mention_handles(ctx, comment.mentioned_user_ids)
}

fn comment_json(
  ctx: Context,
  comment: database.MergeRequestCommentRow,
) -> json.Json {
  json_api.merge_request_comment_json(comment, mention_usernames(ctx, comment))
}

fn insert_mr_comment(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number: Int,
  body: String,
  file_path: option.Option(String),
  line: option.Option(Int),
) -> Result(database.MergeRequestCommentRow, Response) {
  let mentioned_user_ids = mention_resolve.for_org(ctx, org_slug, body)
  case
    database.insert_merge_request_comment(
      ctx.repo(),
      org_slug,
      repo_name,
      number,
      user_id(ctx),
      body,
      file_path,
      line,
      mentioned_user_ids,
    )
  {
    Error(_) -> Error(wisp.internal_server_error())
    Ok(comment) -> {
      let _ =
        mention_notify.comment_mentioned(
        ctx,
        user_id(ctx),
        mentioned_user_ids,
        [],
        mention_notify.MrComment(
          org_slug:,
          repo_name:,
          mr_number: number,
          comment_id: comment.id,
        ),
      )
      Ok(comment)
    }
  }
}

fn update_mr_comment(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number: Int,
  comment_id: String,
  body: String,
) -> Result(database.MergeRequestCommentRow, Response) {
  let previous_mentioned = case
    database.get_merge_request_comment(
      ctx.repo(),
      org_slug,
      repo_name,
      number,
      comment_id,
    )
  {
    Ok(option.Some(comment)) -> comment.mentioned_user_ids
    _ -> []
  }
  let mentioned_user_ids = mention_resolve.for_org(ctx, org_slug, body)
  case
    database.update_merge_request_comment(
      ctx.repo(),
      org_slug,
      repo_name,
      number,
      comment_id,
      body,
      mentioned_user_ids,
    )
  {
    Error(_) -> Error(wisp.internal_server_error())
    Ok(option.None) -> Error(wisp.not_found())
    Ok(option.Some(comment)) -> {
      let _ =
        mention_notify.comment_mentioned(
        ctx,
        user_id(ctx),
        mentioned_user_ids,
        previous_mentioned,
        mention_notify.MrComment(
          org_slug:,
          repo_name:,
          mr_number: number,
          comment_id: comment.id,
        ),
      )
      Ok(comment)
    }
  }
}

fn mr_author_name(ctx: Context, user_id: String) -> String {
  user_display.display_name(ctx, user_id)
}

fn git_dir(
  ctx: Context,
  repo: database.RepoRow,
) -> Result(String, git_exec.GitError) {
  git_exec.repo_path(org_access.git_repos_root(ctx), repo.disk_path)
}

fn with_repo(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  run: fn(database.RepoRow, String) -> Response,
) -> Response {
  case org_access.require_member(ctx, user_id(ctx), org_slug) {
    Error(_) -> wisp.response(403)
    Ok(_) ->
      case database.get_repo(ctx.repo(), org_slug, repo_name) {
        Ok(option.None) -> wisp.not_found()
        Ok(option.Some(repo)) ->
          case git_dir(ctx, repo) {
            Error(_) -> wisp.internal_server_error()
            Ok(git_dir) -> run(repo, git_dir)
          }
        Error(_) -> wisp.internal_server_error()
      }
  }
}

fn with_mr(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number: Int,
  run: fn(database.MergeRequestRow, String) -> Response,
) -> Response {
  with_repo(ctx, org_slug, repo_name, fn(_repo, dir) {
    case database.get_merge_request(ctx.repo(), org_slug, repo_name, number) {
      Ok(option.None) -> wisp.not_found()
      Ok(option.Some(mr)) -> run(mr, dir)
      Error(_) -> wisp.internal_server_error()
    }
  })
}

fn parse_mr_number(num_str: String) -> Result(Int, Response) {
  case int.parse(num_str) {
    Ok(n) -> Ok(n)
    Error(_) -> Error(wisp.bad_request("Invalid merge request number"))
  }
}

fn json_ok(body: json.Json, status: Int) -> Response {
  json.to_string(body) |> wisp.json_response(status)
}

fn pipeline_can_rerun(db: pog.Connection, merge_request_id: String) -> Bool {
  case database.get_latest_pipeline_run_optional(db, merge_request_id) {
    Ok(option.Some(run)) ->
      case run.state {
        "running" | "queued" -> False
        _ -> True
      }
    _ -> True
  }
}

fn draft_merge_check() -> git_exec.MergeCheck {
  git_exec.MergeCheck(
    mergeable: False,
    message: "Mark as ready for review first",
    behind_target: False,
    conflict_paths: [],
    approval_count: 0,
    required_approvals: 0,
  )
}

fn compose_merge_check(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  mr: database.MergeRequestRow,
  git_dir: String,
) -> Result(git_exec.MergeCheck, git_exec.GitError) {
  case mr.is_draft {
    True -> Ok(draft_merge_check())
    False -> compose_git_merge_check(ctx, org_slug, repo_name, mr, git_dir)
  }
}

fn compose_git_merge_check(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  mr: database.MergeRequestRow,
  git_dir: String,
) -> Result(git_exec.MergeCheck, git_exec.GitError) {
  use git_check <- result.try(git_exec.merge_check_for_request(
    git_dir,
    mr.target_branch,
    mr.source_branch,
    mr.state,
  ))
  use with_ci <- result.try(apply_ci_merge_check(ctx, mr, git_dir, git_check))
  Ok(apply_approval_merge_check(ctx, org_slug, repo_name, mr, with_ci))
}

fn apply_ci_merge_check(
  ctx: Context,
  mr: database.MergeRequestRow,
  git_dir: String,
  git_check: git_exec.MergeCheck,
) -> Result(git_exec.MergeCheck, git_exec.GitError) {
  case mr.state {
    "open" -> {
      use head_sha <- result.try(
        ci_discovery.branch_head_sha(git_dir, mr.source_branch)
        |> result.map_error(fn(_) { git_exec.NotFound }),
      )
      database.reclaim_stale_pipeline_runs(ctx.repo())
      let pipeline = case
        database.get_latest_pipeline_run_optional(ctx.repo(), mr.id)
      {
        Ok(run) -> run
        Error(_) -> option.None
      }
      Ok(ci_merge.combine_merge_check(git_check, pipeline, head_sha))
    }
    _ -> Ok(git_check)
  }
}

fn apply_approval_merge_check(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  mr: database.MergeRequestRow,
  check: git_exec.MergeCheck,
) -> git_exec.MergeCheck {
  let with_approvals = case
    database.get_required_approvals(ctx.repo(), org_slug, repo_name)
  {
    Ok(required) ->
      case
        database.count_merge_request_approvals(
          ctx.repo(),
          mr.id,
          mr.author_user_id,
        )
      {
        Ok(count) ->
          review_merge.combine_merge_check(check, count, required)
        Error(_) ->
          git_exec.MergeCheck(
            ..check,
            approval_count: 0,
            required_approvals: required,
          )
      }
    Error(_) ->
      git_exec.MergeCheck(
        ..check,
        approval_count: 0,
        required_approvals: 0,
      )
  }

  case database.count_merge_request_changes_requested(ctx.repo(), mr.id) {
    Ok(count) -> review_merge.apply_changes_requested_block(with_approvals, count)
    Error(_) -> with_approvals
  }
}

fn merge_detail_json(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  mr: database.MergeRequestRow,
  check: git_exec.MergeCheck,
) -> Response {
  database.reclaim_stale_pipeline_runs(ctx.repo())
  case database.enrich_merge_request(ctx.repo(), org_slug, repo_name, mr) {
    Ok(enriched) -> {
      let pipeline = case
        database.get_latest_pipeline_run_optional(ctx.repo(), enriched.id)
      {
        Ok(option.Some(run)) -> json_api.pipeline_run_json(run)
        Ok(option.None) -> json.null()
        Error(_) -> json.null()
      }
      let reviews = case
        database.list_merge_request_reviews(
          ctx.repo(),
          org_slug,
          repo_name,
          enriched.number,
        )
      {
        Ok(rows) -> hydrate_reviews(ctx, rows)
        Error(_) -> []
      }
      let author_name = mr_author_name(ctx, enriched.author_user_id)
      let linked_issues =
        case database.list_linked_issues_for_mr(ctx.repo(), enriched.id) {
          Ok(rows) -> rows
          Error(_) -> []
        }
      json.object([
        #("merge_request", json_api.merge_request_json(enriched, author_name)),
        #("merge_check", json_api.merge_check_json(check)),
        #("pipeline", pipeline),
        #("reviews", json_api.merge_request_reviews_json(reviews)),
        #(
          "linked_issues",
          json.array(linked_issues, json_api.linked_issue_json),
        ),
      ])
      |> json_ok(200)
    }
    Error(_) -> wisp.internal_server_error()
  }
}

fn hydrate_reviews(
  ctx: Context,
  reviews: List(database.MergeRequestReviewRow),
) -> List(database.MergeRequestReviewRow) {
  list.map(reviews, fn(review) {
    database.MergeRequestReviewRow(
      ..review,
      reviewer_name: user_display.display_name(ctx, review.user_id),
    )
  })
}

fn can_edit_merge_request(
  ctx: Context,
  org_slug: String,
  mr: database.MergeRequestRow,
) -> Bool {
  mr.author_user_id == user_id(ctx)
  || database.member_can_write(ctx.repo(), user_id(ctx), org_slug)
}

fn can_edit_comment(
  ctx: Context,
  comment: database.MergeRequestCommentRow,
) -> Bool {
  comment.author_user_id == user_id(ctx)
}

fn can_delete_comment(
  ctx: Context,
  org_slug: String,
  comment: database.MergeRequestCommentRow,
) -> Bool {
  comment.author_user_id == user_id(ctx)
  || database.is_org_owner(ctx.repo(), user_id(ctx), org_slug)
}

fn duplicate_mr_response(existing_number: Int) -> Response {
  json.object([
    #(
      "error",
      json.string("An open merge request already exists for these branches"),
    ),
    #("existing_number", json.int(existing_number)),
  ])
  |> json.to_string
  |> fn(body) { wisp.response(409) |> wisp.json_body(body) }
}

pub fn get_merge_request_template(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      with_repo(ctx, org_slug, repo_name, fn(_repo, git_dir) {
        let ref_param = query_param(req, "ref")
        let resolved = case ref_param {
          "" -> git_exec.default_branch(git_dir)
          ref ->
            case git_path.normalize_ref(ref) {
              Ok(validated) -> Ok(validated)
              Error(_) -> Error(git_exec.InvalidPath)
            }
        }
        case resolved {
          Error(e) -> repo_browse_routes.git_error_response(e)
          Ok(ref) ->
            case git_exec.find_merge_request_templates(git_dir, ref) {
              Ok(templates) ->
                json_ok(
                  json_api.merge_request_templates_json(ref, templates),
                  200,
                )
              Error(e) -> repo_browse_routes.git_error_response(e)
            }
        }
      })
  }
}

fn list_query_error_response(error: list_query.ParseError) -> Response {
  json.object([#("error", json.string(list_query.parse_error_message(error)))])
  |> json.to_string
  |> wisp.json_response(400)
}

fn resolve_merge_request_list_query(
  ctx: Context,
  req: Request,
  org_slug: String,
  repo_name: String,
) -> Result(list_query.MergeRequestListQuery, Response) {
  use base <- result.try(
    list_query.parse_merge_request_list_query(req)
    |> result.map_error(list_query_error_response),
  )
  use label_ids <- result.try(
    resolve_mr_list_label_ids(
      ctx,
      org_slug,
      repo_name,
      list_query.label_params(req),
    ),
  )
  Ok(list_query.MergeRequestListQuery(..base, label_ids:))
}

fn resolve_mr_list_label_ids(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  params: List(String),
) -> Result(List(String), Response) {
  case params {
    [] -> Ok([])
    _ ->
      case database.list_repo_labels(ctx.repo(), org_slug, repo_name) {
        Error(_) -> Error(wisp.internal_server_error())
        Ok(labels) -> {
          let pairs =
            list.map(labels, fn(label) { #(label.id, label.name) })
          list_query.resolve_label_ids(pairs, params)
          |> result.map_error(list_query_error_response)
        }
      }
  }
}

pub fn list_merge_requests(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      with_repo(ctx, org_slug, repo_name, fn(_repo, _dir) {
        database.reclaim_stale_pipeline_runs(ctx.repo())
        case resolve_merge_request_list_query(ctx, req, org_slug, repo_name) {
          Error(response) -> response
          Ok(query) ->
            case
              database.list_merge_requests_filtered(
                ctx.repo(),
                org_slug,
                repo_name,
                query,
              )
            {
              Ok(mrs) ->
                case
                  database.enrich_merge_requests(
                    ctx.repo(),
                    org_slug,
                    repo_name,
                    mrs,
                  )
                {
                  Ok(enriched) -> {
                    let items =
                      list.map(enriched, fn(mr) {
                        let pipeline = case
                          database.get_latest_pipeline_run_optional(
                            ctx.repo(),
                            mr.id,
                          )
                        {
                          Ok(run) -> run
                          Error(_) -> option.None
                        }
                        #(mr, pipeline)
                      })
                    json_ok(json_api.merge_requests_list_json(items), 200)
                  }
                  Error(_) -> wisp.internal_server_error()
                }
              Error(_) -> wisp.internal_server_error()
            }
        }
      })
  }
}

pub fn create_merge_request(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      let decoder = {
        use title <- decode.field("title", decode.string)
        use description <- decode.field(
          "description",
          decode.optional(decode.string),
        )
        use source_branch <- decode.field("source_branch", decode.string)
        use target_branch <- decode.field("target_branch", decode.string)
        use draft <- decode.optional_field("draft", False, decode.bool)
        decode.success(#(
          title,
          description,
          source_branch,
          target_branch,
          draft,
        ))
      }
      case decode.run(json_body, decoder) {
        Error(_) -> wisp.bad_request("Invalid JSON body")
        Ok(#(title, description, source, target, draft)) -> {
          let source = string.trim(source)
          let target = string.trim(target)
          case string.trim(title) {
            "" -> wisp.bad_request("Title is required")
            _ ->
              case source == "" {
                True -> wisp.bad_request("Source branch is required")
                False ->
                  case target == "" {
                    True -> wisp.bad_request("Target branch is required")
                    False ->
                      case source == target {
                        True ->
                          wisp.bad_request(
                            "Source and target branches must differ",
                          )
                        False ->
                          with_repo(ctx, org_slug, repo_name, fn(repo, git_dir) {
                            case
                              git_exec.branch_exists(git_dir, source),
                              git_exec.branch_exists(git_dir, target)
                            {
                              Ok(source_name), Ok(target_name) -> {
                                case
                                  database.find_open_merge_request(
                                    ctx.repo(),
                                    org_slug,
                                    repo_name,
                                    source_name,
                                    target_name,
                                  )
                                {
                                  Ok(option.Some(existing)) ->
                                    duplicate_mr_response(existing)
                                  Ok(option.None) ->
                                    case
                                      database.insert_merge_request(
                                        ctx.repo(),
                                        org_slug,
                                        repo_name,
                                        title,
                                        description,
                                        user_id(ctx),
                                        source_name,
                                        target_name,
                                        draft,
                                      )
                                    {
                                      Ok(mr) -> {
                                        let _ =
                                          link_sync.sync_from_text(
                                            ctx.repo(),
                                            org_slug,
                                            repo_name,
                                            mr.id,
                                            description,
                                          )
                                        let _ =
                                          ci_pipeline.enqueue_for_merge_request(
                                            ctx.pipeline_events_name,
                                            ctx.repo(),
                                            repo.id,
                                            mr.id,
                                            git_dir,
                                            mr.source_branch,
                                            "mr_open",
                                          )
                                        json_ok(
                                          json_api.merge_request_json(
                                            mr,
                                            mr_author_name(
                                              ctx,
                                              mr.author_user_id,
                                            ),
                                          ),
                                          201,
                                        )
                                      }
                                      Error(_) -> wisp.internal_server_error()
                                    }
                                  Error(_) -> wisp.internal_server_error()
                                }
                              }
                              Error(git_exec.InvalidBranch), _ ->
                                wisp.bad_request("Invalid source branch name")
                              _, Error(git_exec.InvalidBranch) ->
                                wisp.bad_request("Invalid target branch name")
                              Error(git_exec.NotFound), _ ->
                                wisp.bad_request("Source branch not found")
                              _, Error(git_exec.NotFound) ->
                                wisp.bad_request("Target branch not found")
                              Error(e), _ | _, Error(e) ->
                                repo_browse_routes.git_error_response(e)
                            }
                          })
                      }
                  }
              }
          }
        }
      }
    }
  }
}

pub fn get_merge_request_detail(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(mr, git_dir) {
            case compose_merge_check(ctx, org_slug, repo_name, mr, git_dir) {
              Ok(check) ->
                merge_detail_json(ctx, org_slug, repo_name, mr, check)
              Error(e) -> repo_browse_routes.git_error_response(e)
            }
          })
      }
  }
}

fn apply_merge_request_patch(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  mr: database.MergeRequestRow,
  title: option.Option(String),
  description: option.Option(String),
  label_ids: option.Option(List(String)),
  draft: option.Option(Bool),
  assignee_user_ids: option.Option(List(String)),
  reviewer_user_ids: option.Option(List(String)),
) -> Result(database.MergeRequestRow, Response) {
  let labels_ok = case label_ids {
    option.Some(ids) ->
      case
        database.set_merge_request_labels(
          ctx.repo(),
          org_slug,
          repo_name,
          mr.id,
          ids,
        )
      {
        Error(e) -> Error(label_routes.label_error_response(e))
        Ok(Nil) -> Ok(Nil)
      }
    option.None -> Ok(Nil)
  }

  let assignees_ok = case assignee_user_ids {
    option.Some(ids) ->
      case database.set_merge_request_assignees(ctx.repo(), org_slug, mr.id, ids)
      {
        Error(e) -> Error(label_routes.label_error_response(e))
        Ok(Nil) -> Ok(Nil)
      }
    option.None -> Ok(Nil)
  }

  let reviewers_ok = case reviewer_user_ids {
    option.Some(ids) ->
      case
        database.set_merge_request_reviewers(
          ctx.repo(),
          org_slug,
          mr.id,
          mr.author_user_id,
          user_id(ctx),
          ids,
        )
      {
        Error(e) -> Error(label_routes.label_error_response(e))
        Ok(Nil) -> Ok(Nil)
      }
    option.None -> Ok(Nil)
  }

  case labels_ok, assignees_ok, reviewers_ok {
    Error(resp), _, _ | _, Error(resp), _ | _, _, Error(resp) -> Error(resp)
    Ok(Nil), Ok(Nil), Ok(Nil) -> {
      let next_title = case title {
        option.Some(t) -> string.trim(t)
        option.None -> mr.title
      }
      let row_result = case next_title {
        "" -> Error(wisp.bad_request("Title is required"))
        _ -> {
          let next_description = case description {
            option.Some(d) -> option.Some(d)
            option.None -> mr.description
          }
          case next_title == mr.title && next_description == mr.description {
            True -> Ok(mr)
            False ->
              database.update_merge_request(
                ctx.repo(),
                org_slug,
                repo_name,
                mr.number,
                next_title,
                next_description,
              )
              |> result.map_error(fn(_) { wisp.internal_server_error() })
          }
        }
      }

      case row_result {
        Error(resp) -> Error(resp)
        Ok(row) -> {
          let draft_result = case draft {
            option.Some(is_draft) ->
              database.update_merge_request_is_draft(
                ctx.repo(),
                org_slug,
                repo_name,
                row.number,
                is_draft,
              )
              |> result.map_error(fn(_) { wisp.internal_server_error() })
            option.None -> Ok(row)
          }

          case draft_result {
            Error(resp) -> Error(resp)
            Ok(updated) -> {
              case description {
                option.Some(next_desc) -> {
                  let _ =
                    link_sync.sync_from_text(
                      ctx.repo(),
                      org_slug,
                      repo_name,
                      updated.id,
                      option.Some(next_desc),
                    )
                  Nil
                }
                option.None -> Nil
              }
              case
                database.enrich_merge_request(
                  ctx.repo(),
                  org_slug,
                  repo_name,
                  updated,
                )
              {
                Ok(enriched) -> Ok(enriched)
                Error(_) -> Error(wisp.internal_server_error())
              }
            }
          }
        }
      }
    }
  }
}

pub fn update_merge_request(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Patch)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(mr, _git_dir) {
            case can_edit_merge_request(ctx, org_slug, mr) {
              False -> wisp.response(403)
              True -> {
                let decoder = {
                  use title <- decode.optional_field(
                    "title",
                    option.None,
                    decode.optional(decode.string),
                  )
                  use description <- decode.optional_field(
                    "description",
                    option.None,
                    decode.optional(decode.string),
                  )
                  use label_ids <- decode.optional_field(
                    "label_ids",
                    option.None,
                    decode.optional(decode.list(decode.string)),
                  )
                  use draft <- decode.optional_field(
                    "draft",
                    option.None,
                    decode.optional(decode.bool),
                  )
                  use assignee_user_ids <- decode.optional_field(
                    "assignee_user_ids",
                    option.None,
                    decode.optional(decode.list(decode.string)),
                  )
                  use reviewer_user_ids <- decode.optional_field(
                    "reviewer_user_ids",
                    option.None,
                    decode.optional(decode.list(decode.string)),
                  )
                  decode.success(#(
                    title,
                    description,
                    label_ids,
                    draft,
                    assignee_user_ids,
                    reviewer_user_ids,
                  ))
                }
                case decode.run(json_body, decoder) {
                  Error(_) -> wisp.bad_request("Invalid JSON body")
                  Ok(#(
                    title,
                    description,
                    label_ids,
                    draft,
                    assignee_user_ids,
                    reviewer_user_ids,
                  )) ->
                    case
                      title,
                      description,
                      label_ids,
                      draft,
                      assignee_user_ids,
                      reviewer_user_ids
                    {
                      option.None,
                      option.None,
                      option.None,
                      option.None,
                      option.None,
                      option.None ->
                        wisp.bad_request("No fields to update")
                      _, _, _, _, _, _ ->
                        case
                          apply_merge_request_patch(
                            ctx,
                            org_slug,
                            repo_name,
                            mr,
                            title,
                            description,
                            label_ids,
                            draft,
                            assignee_user_ids,
                            reviewer_user_ids,
                          )
                        {
                          Ok(enriched) ->
                            json_ok(
                              json_api.merge_request_json(
                                enriched,
                                mr_author_name(ctx, enriched.author_user_id),
                              ),
                              200,
                            )
                          Error(response) -> response
                        }
                    }
                }
              }
            }
          })
      }
  }
}

pub fn list_pipelines(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(mr, _git_dir) {
            database.reclaim_stale_pipeline_runs(ctx.repo())
            case database.list_pipeline_runs_for_mr(ctx.repo(), mr.id) {
              Ok(runs) -> json_ok(json_api.pipeline_runs_json(runs), 200)
              Error(_) -> wisp.internal_server_error()
            }
          })
      }
  }
}

pub fn list_commits(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(mr, git_dir) {
            case
              git_exec.commits_for_merge_request(
                git_dir,
                mr.target_branch,
                mr.source_branch,
                mr.state,
                mr.merge_commit_sha,
              )
            {
              Ok(commits) -> json_ok(json_api.commits_json(commits), 200)
              Error(e) -> repo_browse_routes.git_error_response(e)
            }
          })
      }
  }
}

pub fn get_diff(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(mr, git_dir) {
            let path = query_param(req, "path")
            case path {
              "" ->
                case
                  git_exec.diff_summary_for_merge_request(
                    git_dir,
                    mr.target_branch,
                    mr.source_branch,
                    mr.state,
                    mr.merge_commit_sha,
                  )
                {
                  Ok(files) -> json_ok(json_api.diff_files_json(files), 200)
                  Error(e) -> repo_browse_routes.git_error_response(e)
                }
              file_path ->
                case
                  git_exec.diff_patch_for_merge_request(
                    git_dir,
                    mr.target_branch,
                    mr.source_branch,
                    mr.state,
                    mr.merge_commit_sha,
                    file_path,
                  )
                {
                  Ok(patch) ->
                    json_ok(json_api.diff_patch_json(file_path, patch), 200)
                  Error(e) -> repo_browse_routes.git_error_response(e)
                }
            }
          })
      }
  }
}

pub fn get_conflict_file(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(mr, git_dir) {
            let path = query_param(req, "path")
            case path {
              "" -> wisp.bad_request("path is required")
              file_path ->
                case
                  git_exec.conflict_file_content(
                    git_dir,
                    mr.target_branch,
                    mr.source_branch,
                    file_path,
                  )
                {
                  Ok(file) -> json_ok(json_api.conflict_file_json(file), 200)
                  Error(e) -> repo_browse_routes.git_error_response(e)
                }
            }
          })
      }
  }
}

fn merge_commit_message(mr: database.MergeRequestRow) -> String {
  case mr.description {
    option.Some(d) -> mr.title <> "\n\n" <> d
    option.None -> mr.title
  }
}

type MergeRequestBody {
  MergeRequestBody(method: git_exec.MergeMethod, delete_source_branch: Bool)
}

fn parse_merge_method_string(
  method: option.Option(String),
) -> Result(git_exec.MergeMethod, Response) {
  case method {
    option.None | option.Some("merge") -> Ok(git_exec.MergeCommit)
    option.Some("squash") -> Ok(git_exec.Squash)
    option.Some("rebase") -> Ok(git_exec.Rebase)
    option.Some(_) -> Error(wisp.bad_request("Invalid merge_method"))
  }
}

fn parse_merge_body(json_body) -> Result(MergeRequestBody, Response) {
  let decoder = {
    use merge_method <- decode.field(
      "merge_method",
      decode.optional(decode.string),
    )
    use delete_source_branch <- decode.field(
      "delete_source_branch",
      decode.optional(decode.bool),
    )
    decode.success(#(merge_method, delete_source_branch))
  }
  case decode.run(json_body, decoder) {
    Error(_) ->
      Ok(MergeRequestBody(
        method: git_exec.MergeCommit,
        delete_source_branch: False,
      ))
    Ok(#(method_str, delete_opt)) -> {
      use method <- result.try(parse_merge_method_string(method_str))
      let delete = case delete_opt {
        option.None -> False
        option.Some(v) -> v
      }
      Ok(MergeRequestBody(method:, delete_source_branch: delete))
    }
  }
}

fn close_linked_issues_on_merge(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  mr: database.MergeRequestRow,
) -> Nil {
  let _ =
    link_sync.sync_from_text(
      ctx.repo(),
      org_slug,
      repo_name,
      mr.id,
      option.Some(merge_commit_message(mr)),
    )
  case database.list_closes_issues_for_mr(ctx.repo(), mr.id, org_slug) {
    Ok(issues) ->
      list.each(issues, fn(issue) {
        case
          database.close_issue(
            ctx.repo(),
            org_slug,
            issue.repo_name,
            issue.number,
          )
        {
          Ok(_) -> {
            let _ =
              database.insert_issue_comment(
                ctx.repo(),
                org_slug,
                issue.repo_name,
                issue.number,
                user_id(ctx),
                "Closed by merge request !"
                  <> int.to_string(mr.number),
                [],
              )
            Nil
          }
          Error(_) -> Nil
        }
      })
    Error(_) -> Nil
  }
}

fn maybe_delete_source_branch(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  git_dir: String,
  source_branch: String,
  target_branch: String,
  delete_source_branch: Bool,
) -> Nil {
  case delete_source_branch {
    False -> Nil
    True ->
      case source_branch == target_branch {
        True -> Nil
        False ->
          case
            database.is_branch_protected(
              ctx.repo(),
              org_slug,
              repo_name,
              source_branch,
            )
          {
            Ok(True) -> Nil
            Ok(False) | Error(_) ->
              case git_exec.delete_branch(git_dir, source_branch) {
                Ok(_) -> Nil
                Error(_) -> Nil
              }
          }
      }
  }
}

pub fn merge_merge_request(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case database.member_can_write(ctx.repo(), user_id(ctx), org_slug) {
        False -> wisp.response(403)
        True ->
          case parse_merge_body(json_body) {
            Error(r) -> r
            Ok(body) ->
              case parse_mr_number(number_str) {
                Error(r) -> r
                Ok(number) ->
                  with_mr(ctx, org_slug, repo_name, number, fn(mr, git_dir) {
                    case mr.state {
                      "open" ->
                        case compose_merge_check(ctx, org_slug, repo_name, mr, git_dir) {
                          Ok(check) ->
                            case check.mergeable {
                              False ->
                                json.object([
                                  #("error", json.string(check.message)),
                                ])
                                |> json.to_string
                                |> fn(body) {
                                  wisp.response(422) |> wisp.json_body(body)
                                }
                              True ->
                                case
                                  git_exec.merge_branches(
                                    git_dir,
                                    mr.target_branch,
                                    mr.source_branch,
                                    body.method,
                                    merge_commit_message(mr),
                                    git_commit_author(ctx),
                                  )
                                {
                                  Ok(sha) ->
                                    case
                                      database.merge_merge_request(
                                        ctx.repo(),
                                        org_slug,
                                        repo_name,
                                        number,
                                        sha,
                                        user_id(ctx),
                                      )
                                    {
                                      Ok(updated) -> {
                                        let _ =
                                          close_linked_issues_on_merge(
                                            ctx,
                                            org_slug,
                                            repo_name,
                                            mr,
                                          )
                                        let _ =
                                          maybe_delete_source_branch(
                                            ctx,
                                            org_slug,
                                            repo_name,
                                            git_dir,
                                            mr.source_branch,
                                            mr.target_branch,
                                            body.delete_source_branch,
                                          )
                                        json_ok(
                                          json_api.merge_request_json(
                                            updated,
                                            mr_author_name(
                                              ctx,
                                              updated.author_user_id,
                                            ),
                                          ),
                                          200,
                                        )
                                      }
                                      Error(_) -> wisp.internal_server_error()
                                    }
                                  Error(e) ->
                                    repo_browse_routes.git_error_response(e)
                                }
                            }
                          Error(e) -> repo_browse_routes.git_error_response(e)
                        }
                      _ -> wisp.unprocessable_content()
                    }
                  })
              }
          }
      }
  }
}

pub fn rerun_checks(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case database.member_can_write(ctx.repo(), user_id(ctx), org_slug) {
        False -> wisp.response(403)
        True ->
          case parse_mr_number(number_str) {
            Error(r) -> r
            Ok(number) ->
              with_repo(ctx, org_slug, repo_name, fn(repo, git_dir) {
                case
                  database.get_merge_request(
                    ctx.repo(),
                    org_slug,
                    repo_name,
                    number,
                  )
                {
                  Ok(option.None) -> wisp.not_found()
                  Error(_) -> wisp.internal_server_error()
                  Ok(option.Some(mr)) ->
                    case mr.state {
                      "open" -> {
                        database.reclaim_stale_pipeline_runs(ctx.repo())
                        case pipeline_can_rerun(ctx.repo(), mr.id) {
                          False -> wisp.unprocessable_content()
                          True ->
                            case
                              ci_pipeline.enqueue_for_merge_request(
                                ctx.pipeline_events_name,
                                ctx.repo(),
                                repo.id,
                                mr.id,
                                git_dir,
                                mr.source_branch,
                                "manual",
                              )
                            {
                              Ok(run) ->
                                json_ok(json_api.pipeline_run_json(run), 200)
                              Error(_) -> wisp.internal_server_error()
                            }
                        }
                      }
                      _ -> wisp.unprocessable_content()
                    }
                }
              })
          }
      }
  }
}

pub fn update_merge_request_branch(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case database.member_can_write(ctx.repo(), user_id(ctx), org_slug) {
        False -> wisp.response(403)
        True ->
          case parse_mr_number(number_str) {
            Error(r) -> r
            Ok(number) ->
              with_repo(ctx, org_slug, repo_name, fn(repo, git_dir) {
                case
                  database.get_merge_request(
                    ctx.repo(),
                    org_slug,
                    repo_name,
                    number,
                  )
                {
                  Ok(option.None) -> wisp.not_found()
                  Error(_) -> wisp.internal_server_error()
                  Ok(option.Some(mr)) ->
                    case mr.state {
                      "open" ->
                        case
                          git_exec.update_source_branch(
                            git_dir,
                            mr.target_branch,
                            mr.source_branch,
                            git_commit_author(ctx),
                          )
                        {
                          Ok(_) -> {
                            let _ =
                              ci_pipeline.enqueue_for_merge_request(
                                ctx.pipeline_events_name,
                                ctx.repo(),
                                repo.id,
                                mr.id,
                                git_dir,
                                mr.source_branch,
                                "manual",
                              )
                            case compose_merge_check(ctx, org_slug, repo_name, mr, git_dir) {
                              Ok(check) ->
                                merge_detail_json(
                                  ctx,
                                  org_slug,
                                  repo_name,
                                  mr,
                                  check,
                                )
                              Error(e) ->
                                repo_browse_routes.git_error_response(e)
                            }
                          }
                          Error(e) -> repo_browse_routes.git_error_response(e)
                        }
                      _ -> wisp.unprocessable_content()
                    }
                }
              })
          }
      }
  }
}

pub fn close_merge_request_route(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(mr, _git_dir) {
            let can_close =
              mr.state == "open"
              && {
                mr.author_user_id == user_id(ctx)
                || database.member_can_write(ctx.repo(), user_id(ctx), org_slug)
              }
            case can_close {
              False -> wisp.response(403)
              True ->
                case
                  database.close_merge_request(
                    ctx.repo(),
                    org_slug,
                    repo_name,
                    number,
                  )
                {
                  Ok(updated) ->
                    json_ok(
                      json_api.merge_request_json(
                        updated,
                        mr_author_name(ctx, updated.author_user_id),
                      ),
                      200,
                    )
                  Error(_) -> wisp.internal_server_error()
                }
            }
          })
      }
  }
}

fn valid_review_state(state: String) -> Bool {
  state == "approved" || state == "changes_requested" || state == "commented"
}

fn review_error_response(error: database.ReviewError) -> Response {
  case error {
    database.InvalidReviewState ->
      wisp.bad_request("Invalid review state")
    database.AuthorCannotApprove ->
      wisp.bad_request("Authors cannot approve their own merge requests")
  }
}

pub fn list_reviews(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(mr, _dir) {
            case
              database.list_merge_request_reviews(
                ctx.repo(),
                org_slug,
                repo_name,
                number,
              )
            {
              Ok(reviews) -> {
                let reviews = hydrate_reviews(ctx, reviews)
                case
                  database.enrich_merge_request(
                    ctx.repo(),
                    org_slug,
                    repo_name,
                    mr,
                  )
                {
                  Ok(enriched) ->
                    json_ok(
                      json_api.merge_request_review_list_json(
                        reviews,
                        enriched.reviewers,
                      ),
                      200,
                    )
                  Error(_) -> wisp.internal_server_error()
                }
              }
              Error(_) -> wisp.internal_server_error()
            }
          })
      }
  }
}

pub fn submit_review(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case database.member_can_write(ctx.repo(), user_id(ctx), org_slug) {
        False -> wisp.response(403)
        True ->
          case parse_mr_number(number_str) {
            Error(r) -> r
            Ok(number) ->
              with_mr(ctx, org_slug, repo_name, number, fn(mr, _git_dir) {
                case mr.state {
                  "open" -> {
                    let decoder = {
                      use state <- decode.field("state", decode.string)
                      use body <- decode.optional_field(
                        "body",
                        option.None,
                        decode.optional(decode.string),
                      )
                      decode.success(#(state, body))
                    }
                    case decode.run(json_body, decoder) {
                      Error(_) -> wisp.bad_request("Invalid JSON body")
                      Ok(#(state, body)) -> {
                        let body_text = case body {
                          option.Some(text) -> text
                          option.None -> ""
                        }
                        case valid_review_state(state) {
                          False ->
                            review_error_response(database.InvalidReviewState)
                          True ->
                            case state == "approved"
                              && mr.author_user_id == user_id(ctx) {
                              True ->
                                review_error_response(
                                  database.AuthorCannotApprove,
                                )
                              False ->
                                case
                                  database.insert_merge_request_review(
                                    ctx.repo(),
                                    mr.id,
                                    user_id(ctx),
                                    state,
                                    body_text,
                                  )
                                {
                                  Ok(review) -> {
                                    let review =
                                      database.MergeRequestReviewRow(
                                        ..review,
                                        reviewer_name: user_display.display_name(
                                          ctx,
                                          review.user_id,
                                        ),
                                      )
                                    let _ = notify.mr_review_submitted(
                                      ctx,
                                      user_id(ctx),
                                      mr.author_user_id,
                                      org_slug,
                                      repo_name,
                                      number,
                                      mr.title,
                                      state,
                                    )
                                    json_ok(
                                      json_api.merge_request_review_json(
                                        review,
                                      ),
                                      201,
                                    )
                                  }
                                  Error(_) -> wisp.internal_server_error()
                                }
                            }
                        }
                      }
                    }
                  }
                  _ -> wisp.unprocessable_content()
                }
              })
          }
      }
  }
}

pub fn list_comments(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(_mr, _dir) {
            case
              database.list_merge_request_comments(
                ctx.repo(),
                org_slug,
                repo_name,
                number,
              )
            {
              Ok(comments) -> {
                let comments = hydrate_comments(ctx, comments)
                json_ok(
                  json_api.merge_request_comments_json(
                    comments,
                    fn(comment) { mention_usernames(ctx, comment) },
                  ),
                  200,
                )
              }
              Error(_) -> wisp.internal_server_error()
            }
          })
      }
  }
}

pub fn create_comment(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) -> {
          let decoder = {
            use body <- decode.field("body", decode.string)
            use file_path <- decode.field(
              "file_path",
              decode.optional(decode.string),
            )
            use line <- decode.field("line", decode.optional(decode.int))
            decode.success(#(body, file_path, line))
          }
          case decode.run(json_body, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON body")
            Ok(#(body, file_path, line)) ->
              case string.trim(body) {
                "" -> wisp.bad_request("Comment body is required")
                _ ->
                  case file_path, line {
                    option.Some(_), option.None ->
                      wisp.bad_request("line is required for file comments")
                    option.Some(_), option.Some(n) ->
                      case n > 0 {
                        False -> wisp.bad_request("line must be positive")
                        True ->
                          with_mr(
                            ctx,
                            org_slug,
                            repo_name,
                            number,
                            fn(_mr, _dir) {
                              case
                                insert_mr_comment(
                                  ctx,
                                  org_slug,
                                  repo_name,
                                  number,
                                  body,
                                  file_path,
                                  line,
                                )
                              {
                                Ok(comment) -> {
                                  let comment = case
                                    hydrate_comments(ctx, [comment])
                                  {
                                    [hydrated] -> hydrated
                                    _ -> comment
                                  }
                                  json_ok(comment_json(ctx, comment), 201)
                                }
                                Error(response) -> response
                              }
                            },
                          )
                      }
                    _, _ ->
                      with_mr(ctx, org_slug, repo_name, number, fn(_mr, _dir) {
                        case
                          insert_mr_comment(
                            ctx,
                            org_slug,
                            repo_name,
                            number,
                            body,
                            file_path,
                            line,
                          )
                        {
                          Ok(comment) -> {
                            let comment = case
                              hydrate_comments(ctx, [comment])
                            {
                              [hydrated] -> hydrated
                              _ -> comment
                            }
                            json_ok(comment_json(ctx, comment), 201)
                          }
                          Error(response) -> response
                        }
                      })
                  }
              }
          }
        }
      }
  }
}

pub fn update_comment(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
  comment_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Patch)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) -> {
          let decoder = {
            use body <- decode.field("body", decode.string)
            decode.success(body)
          }
          case decode.run(json_body, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON body")
            Ok(body) ->
              case string.trim(body) {
                "" -> wisp.bad_request("Comment body is required")
                trimmed ->
                  with_mr(ctx, org_slug, repo_name, number, fn(_mr, _git_dir) {
                    case
                      database.get_merge_request_comment(
                        ctx.repo(),
                        org_slug,
                        repo_name,
                        number,
                        comment_id,
                      )
                    {
                      Error(_) -> wisp.internal_server_error()
                      Ok(option.None) -> wisp.not_found()
                      Ok(option.Some(comment)) ->
                        case can_edit_comment(ctx, comment) {
                          False -> wisp.response(403)
                          True ->
                            case
                              update_mr_comment(
                                ctx,
                                org_slug,
                                repo_name,
                                number,
                                comment_id,
                                trimmed,
                              )
                            {
                              Ok(updated) -> {
                                let updated = case
                                  hydrate_comments(ctx, [updated])
                                {
                                  [hydrated] -> hydrated
                                  _ -> updated
                                }
                                json_ok(comment_json(ctx, updated), 200)
                              }
                              Error(response) -> response
                            }
                        }
                    }
                  })
              }
          }
        }
      }
  }
}

pub fn delete_comment(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
  comment_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Delete)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(_mr, _git_dir) {
            case
              database.get_merge_request_comment(
                ctx.repo(),
                org_slug,
                repo_name,
                number,
                comment_id,
              )
            {
              Error(_) -> wisp.internal_server_error()
              Ok(option.None) -> wisp.not_found()
              Ok(option.Some(comment)) ->
                case can_delete_comment(ctx, org_slug, comment) {
                  False -> wisp.response(403)
                  True ->
                    case
                      database.delete_merge_request_comment(
                        ctx.repo(),
                        org_slug,
                        repo_name,
                        number,
                        comment_id,
                      )
                    {
                      Ok(True) -> wisp.response(204)
                      Ok(False) -> wisp.not_found()
                      Error(_) -> wisp.internal_server_error()
                    }
                }
            }
          })
      }
  }
}

fn query_param(req: Request, name: String) -> String {
  case
    list.find(wisp.get_query(req), fn(pair) {
      let #(key, _) = pair
      key == name
    })
  {
    Ok(#(_, value)) -> value
    Error(_) -> ""
  }
}
