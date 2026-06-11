import database
import gleam/json
import gleam/list
import gleam/option
import http/web.{type Context}

pub const type_mention_mr = "mention.mr_comment"
pub const type_mention_issue = "mention.issue_comment"
pub const type_mr_review = "mr.review"
pub const type_ci_complete = "ci.complete"
pub const type_org_invitation = "org.invitation"

pub fn comment_mentioned(
  ctx: Context,
  actor_user_id: String,
  mentioned_user_ids: List(String),
  previous_mentioned_user_ids: List(String),
  org_slug: String,
  repo_name: String,
  mr_number: option.Option(Int),
  issue_number: option.Option(Int),
  comment_id: String,
) -> Nil {
  let targets =
    new_mention_targets(mentioned_user_ids, previous_mentioned_user_ids)
  let type_ = case mr_number {
    option.Some(_) -> type_mention_mr
    option.None -> type_mention_issue
  }
  let merge_request_title = merge_request_title_for(ctx, org_slug, repo_name, mr_number)
  let issue_title = issue_title_for(ctx, org_slug, repo_name, issue_number)
  let payload =
    json.object([
      #("org_slug", json.string(org_slug)),
      #("repo_name", json.string(repo_name)),
      #("comment_id", json.string(comment_id)),
      #("actor_user_id", json.string(actor_user_id)),
      merge_request_number_field(mr_number),
      merge_request_title_field(merge_request_title),
      issue_number_field(issue_number),
      issue_title_field(issue_title),
    ])
  notify_many(ctx, actor_user_id, targets, type_, payload)
}

pub fn mr_review_submitted(
  ctx: Context,
  actor_user_id: String,
  mr_author_user_id: String,
  org_slug: String,
  repo_name: String,
  mr_number: Int,
  merge_request_title: String,
  review_state: String,
) -> Nil {
  let payload =
    json.object([
      #("org_slug", json.string(org_slug)),
      #("repo_name", json.string(repo_name)),
      #("merge_request_number", json.int(mr_number)),
      #("merge_request_title", json.string(merge_request_title)),
      #("actor_user_id", json.string(actor_user_id)),
      #("review_state", json.string(review_state)),
    ])
  notify_one(ctx, actor_user_id, mr_author_user_id, type_mr_review, payload)
}

pub fn ci_completed(
  ctx: Context,
  mr_author_user_id: String,
  org_slug: String,
  repo_name: String,
  mr_number: Int,
  merge_request_title: String,
  pipeline_run_id: String,
  pipeline_state: String,
  commit_sha: String,
) -> Nil {
  let payload =
    json.object([
      #("org_slug", json.string(org_slug)),
      #("repo_name", json.string(repo_name)),
      #("merge_request_number", json.int(mr_number)),
      #("merge_request_title", json.string(merge_request_title)),
      #("pipeline_run_id", json.string(pipeline_run_id)),
      #("pipeline_state", json.string(pipeline_state)),
      #("commit_sha", json.string(commit_sha)),
    ])
  notify_one(ctx, "", mr_author_user_id, type_ci_complete, payload)
}

pub fn org_invitation_received(
  ctx: Context,
  actor_user_id: String,
  invited_user_id: String,
  org_slug: String,
  org_name: String,
  invitation_id: String,
  role: String,
) -> Nil {
  let payload =
    json.object([
      #("org_slug", json.string(org_slug)),
      #("org_name", json.string(org_name)),
      #("invitation_id", json.string(invitation_id)),
      #("actor_user_id", json.string(actor_user_id)),
      #("role", json.string(role)),
    ])
  notify_one(ctx, actor_user_id, invited_user_id, type_org_invitation, payload)
}

fn merge_request_title_for(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  mr_number: option.Option(Int),
) -> option.Option(String) {
  case mr_number {
    option.None -> option.None
    option.Some(number) ->
      case database.get_merge_request(ctx.repo(), org_slug, repo_name, number) {
        Ok(option.Some(mr)) -> option.Some(mr.title)
        _ -> option.None
      }
  }
}

fn issue_title_for(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  issue_number: option.Option(Int),
) -> option.Option(String) {
  case issue_number {
    option.None -> option.None
    option.Some(number) ->
      case database.get_issue(ctx.repo(), org_slug, repo_name, number) {
        Ok(option.Some(issue)) -> option.Some(issue.title)
        _ -> option.None
      }
  }
}

fn merge_request_number_field(number: option.Option(Int)) -> #(String, json.Json) {
  #(
    "merge_request_number",
    case number {
      option.Some(n) -> json.int(n)
      option.None -> json.null()
    },
  )
}

fn merge_request_title_field(title: option.Option(String)) -> #(
  String,
  json.Json,
) {
  #(
    "merge_request_title",
    case title {
      option.Some(text) -> json.string(text)
      option.None -> json.null()
    },
  )
}

fn issue_number_field(number: option.Option(Int)) -> #(String, json.Json) {
  #(
    "issue_number",
    case number {
      option.Some(n) -> json.int(n)
      option.None -> json.null()
    },
  )
}

fn issue_title_field(title: option.Option(String)) -> #(String, json.Json) {
  #(
    "issue_title",
    case title {
      option.Some(text) -> json.string(text)
      option.None -> json.null()
    },
  )
}

fn new_mention_targets(
  mentioned_user_ids: List(String),
  previous_mentioned_user_ids: List(String),
) -> List(String) {
  mentioned_user_ids
  |> list.filter(fn(id) { !list.contains(previous_mentioned_user_ids, id) })
  |> list.unique
}

fn notify_many(
  ctx: Context,
  actor_user_id: String,
  user_ids: List(String),
  type_: String,
  payload: json.Json,
) -> Nil {
  list.each(user_ids, fn(user_id) {
    notify_one(ctx, actor_user_id, user_id, type_, payload)
  })
  Nil
}

fn notify_one(
  ctx: Context,
  actor_user_id: String,
  user_id: String,
  type_: String,
  payload: json.Json,
) -> Nil {
  case user_id == "" || user_id == actor_user_id {
    True -> Nil
    False -> {
      let _ = database.insert_notification(ctx.repo(), user_id, type_, payload)
      Nil
    }
  }
}
