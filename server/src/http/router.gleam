import ci/internal_routes as ci_internal_routes
import git/browse_routes as repo_browse_routes
import git/settings_routes as repo_settings_routes
import git/tag_routes as repo_tag_routes
import git/ssh_internal_routes
import gleam/http
import gleam/list
import http/api_routes
import http/clerk
import http/internal_auth
import http/issue_routes
import http/label_routes
import http/member_routes
import http/merge_request_routes
import http/milestone_routes
import http/notification_routes
import http/project_routes
import http/release_routes
import http/web.{type Context}
import simplifile
import wisp.{type Request, type Response}

fn is_ui_route(segments: List(String)) -> Bool {
  case segments {
    [] -> True
    ["orgs"] -> True
    ["orgs", _] -> True
    ["orgs", _, "members"] -> True
    ["orgs", _, "projects", ..] -> True
    ["orgs", _, "repos", _, ..] -> True
    ["keys"] | ["settings", ..] -> True
    ["me"] -> True
    ["me", ..] -> True
    ["profile"] -> True
    _ -> False
  }
}

fn serve_spa(ctx: Context) -> Response {
  let assert Ok(file) = simplifile.read(ctx.static_directory <> "/index.html")
  wisp.html_response(file, 200)
}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req, ctx)
  let path_segments = wisp.path_segments(req)

  case path_segments {
    ["internal", "ssh", "authorized_keys"] ->
      internal_auth.with_token(req, ctx, fn() {
        ssh_internal_routes.authorized_keys(req, ctx)
      })

    ["internal", "ssh", "access"] ->
      internal_auth.with_token(req, ctx, fn() {
        ssh_internal_routes.access_check(req, ctx)
      })

    ["internal", "ssh", "ref-update"] ->
      internal_auth.with_token(req, ctx, fn() {
        ssh_internal_routes.ref_update_check(req, ctx)
      })

    ["internal", "ci", "enqueue"] ->
      internal_auth.with_token(req, ctx, fn() {
        ci_internal_routes.enqueue(req, ctx)
      })

    ["internal", "ci", "jobs", "next"] ->
      internal_auth.with_token(req, ctx, fn() {
        ci_internal_routes.next_job(req, ctx)
      })

    ["internal", "ci", "jobs", run_id] ->
      internal_auth.with_token(req, ctx, fn() {
        ci_internal_routes.update_job(req, ctx, run_id)
      })

    ["raw", "orgs", org, "repos", repo, ref, ..file_path] ->
      clerk.middleware_allow_query(req, ctx, fn(ctx) {
        repo_browse_routes.get_repo_raw_browser(
          req,
          ctx,
          org,
          repo,
          list.append([ref], file_path),
        )
      })

    _ -> {
      case is_ui_route(path_segments) {
        True -> serve_spa(ctx)
        False -> {
          use ctx <- clerk.middleware(req, ctx)
          case path_segments {
            ["api", "me"] -> api_routes.get_me(req, ctx)
            ["api", "notifications"] -> {
              case req.method {
                http.Get -> notification_routes.list_notifications(req, ctx)
                _ -> wisp.method_not_allowed([http.Get])
              }
            }
            ["api", "notifications", "read-all"] ->
              notification_routes.mark_all_read(req, ctx)
            ["api", "notifications", id, "read"] ->
              notification_routes.mark_read(req, ctx, id)
            ["api", "users", "search"] -> member_routes.search_users(req, ctx)
            ["api", "invitations"] ->
              member_routes.list_my_invitations(req, ctx)
            ["api", "invitations", id, "accept"] ->
              member_routes.accept_invitation(req, ctx, id)
            ["api", "invitations", id, "decline"] ->
              member_routes.decline_invitation(req, ctx, id)
            ["api", "orgs"] -> {
              case req.method {
                http.Get -> api_routes.list_orgs(req, ctx)
                http.Post -> api_routes.create_org(req, ctx)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "orgs", slug] -> api_routes.get_org(req, ctx, slug)
            ["api", "orgs", slug, "members"] -> {
              case req.method {
                http.Get -> member_routes.list_members(req, ctx, slug)
                _ -> wisp.method_not_allowed([http.Get])
              }
            }
            ["api", "orgs", slug, "members", member_id] -> {
              case req.method {
                http.Delete ->
                  member_routes.remove_member(req, ctx, slug, member_id)
                http.Patch ->
                  member_routes.update_member_role(req, ctx, slug, member_id)
                _ -> wisp.method_not_allowed([http.Delete, http.Patch])
              }
            }
            ["api", "orgs", slug, "invitations"] -> {
              case req.method {
                http.Get -> member_routes.list_org_invitations(req, ctx, slug)
                http.Post -> member_routes.create_invitation(req, ctx, slug)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "orgs", slug, "invitations", invitation_id] ->
              member_routes.cancel_invitation(req, ctx, slug, invitation_id)
            ["api", "orgs", slug, "projects"] -> {
              case req.method {
                http.Get -> project_routes.list_org_projects(req, ctx, slug)
                http.Post -> project_routes.create_org_project(req, ctx, slug)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "orgs", slug, "projects", num, "board"] ->
              project_routes.get_org_project_board(req, ctx, slug, num)
            ["api", "orgs", slug, "projects", num, "items"] ->
              project_routes.create_org_project_item(req, ctx, slug, num)
            ["api", "orgs", slug, "projects", num, "items", item_id] ->
              project_routes.project_item_by_id(req, ctx, slug, num, item_id)
            ["api", "orgs", slug, "projects", num, "columns"] ->
              project_routes.create_org_project_column(req, ctx, slug, num)
            ["api", "orgs", slug, "projects", num, "columns", column_id] ->
              project_routes.project_column_by_id(req, ctx, slug, num, column_id)
            ["api", "orgs", slug, "projects", num] ->
              project_routes.project_by_number(req, ctx, slug, num)
            ["api", "orgs", slug, "repos"] -> {
              case req.method {
                http.Get -> api_routes.list_repos(req, ctx, slug)
                http.Post -> api_routes.create_repo(req, ctx, slug)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "orgs", slug, "repos", name, "issues", "template"] ->
              issue_routes.get_issue_template(req, ctx, slug, name)
            ["api", "orgs", slug, "repos", name, "issues"] -> {
              case req.method {
                http.Get -> issue_routes.list_issues(req, ctx, slug, name)
                http.Post -> issue_routes.create_issue(req, ctx, slug, name)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "orgs", _slug, "repos", _name, "issues", "new"] ->
              wisp.not_found()
            ["api", "orgs", slug, "repos", name, "labels"] -> {
              case req.method {
                http.Get -> label_routes.list_labels(req, ctx, slug, name)
                http.Post -> label_routes.create_label(req, ctx, slug, name)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "orgs", slug, "repos", name, "labels", label_id] ->
              label_routes.label_by_id(req, ctx, slug, name, label_id)
            [
              "api",
              "orgs",
              slug,
              "repos",
              name,
              "issues",
              num,
              "comments",
              comment_id,
            ] -> {
              case req.method {
                http.Patch ->
                  issue_routes.update_comment(
                    req,
                    ctx,
                    slug,
                    name,
                    num,
                    comment_id,
                  )
                http.Delete ->
                  issue_routes.delete_comment(
                    req,
                    ctx,
                    slug,
                    name,
                    num,
                    comment_id,
                  )
                _ -> wisp.method_not_allowed([http.Patch, http.Delete])
              }
            }
            ["api", "orgs", slug, "repos", name, "issues", num, "reopen"] ->
              issue_routes.reopen_issue_route(req, ctx, slug, name, num)
            ["api", "orgs", slug, "repos", name, "issues", num, "close"] ->
              issue_routes.close_issue_route(req, ctx, slug, name, num)
            ["api", "orgs", slug, "repos", name, "issues", num, "comments"] -> {
              case req.method {
                http.Get ->
                  issue_routes.list_comments(req, ctx, slug, name, num)
                http.Post ->
                  issue_routes.create_comment(req, ctx, slug, name, num)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "orgs", slug, "repos", name, "issues", num] -> {
              case req.method {
                http.Get ->
                  issue_routes.get_issue_detail(req, ctx, slug, name, num)
                http.Patch ->
                  issue_routes.update_issue(req, ctx, slug, name, num)
                _ -> wisp.method_not_allowed([http.Get, http.Patch])
              }
            }
            ["api", "orgs", slug, "repos", name, "merge-requests"] -> {
              case req.method {
                http.Get ->
                  merge_request_routes.list_merge_requests(req, ctx, slug, name)
                http.Post ->
                  merge_request_routes.create_merge_request(
                    req,
                    ctx,
                    slug,
                    name,
                  )
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "orgs", _slug, "repos", _name, "merge-requests", "new"] ->
              wisp.not_found()
            ["api", "orgs", slug, "repos", name, "merge-requests", "template"] ->
              merge_request_routes.get_merge_request_template(
                req,
                ctx,
                slug,
                name,
              )
            ["api", "orgs", slug, "repos", name, "merge-requests", num, "merge"] ->
              merge_request_routes.merge_merge_request(
                req,
                ctx,
                slug,
                name,
                num,
              )
            ["api", "orgs", slug, "repos", name, "merge-requests", num, "close"] ->
              merge_request_routes.close_merge_request_route(
                req,
                ctx,
                slug,
                name,
                num,
              )
            [
              "api",
              "orgs",
              slug,
              "repos",
              name,
              "merge-requests",
              num,
              "update-branch",
            ] ->
              merge_request_routes.update_merge_request_branch(
                req,
                ctx,
                slug,
                name,
                num,
              )
            [
              "api",
              "orgs",
              slug,
              "repos",
              name,
              "merge-requests",
              num,
              "rerun-checks",
            ] -> merge_request_routes.rerun_checks(req, ctx, slug, name, num)
            [
              "api",
              "orgs",
              slug,
              "repos",
              name,
              "merge-requests",
              num,
              "pipelines",
            ] -> merge_request_routes.list_pipelines(req, ctx, slug, name, num)
            [
              "api",
              "orgs",
              slug,
              "repos",
              name,
              "merge-requests",
              num,
              "commits",
            ] -> merge_request_routes.list_commits(req, ctx, slug, name, num)
            ["api", "orgs", slug, "repos", name, "merge-requests", num, "diff"] ->
              merge_request_routes.get_diff(req, ctx, slug, name, num)
            [
              "api",
              "orgs",
              slug,
              "repos",
              name,
              "merge-requests",
              num,
              "conflict",
            ] ->
              merge_request_routes.get_conflict_file(req, ctx, slug, name, num)
            [
              "api",
              "orgs",
              slug,
              "repos",
              name,
              "merge-requests",
              num,
              "reviews",
            ] -> {
              case req.method {
                http.Get ->
                  merge_request_routes.list_reviews(req, ctx, slug, name, num)
                http.Post ->
                  merge_request_routes.submit_review(req, ctx, slug, name, num)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            [
              "api",
              "orgs",
              slug,
              "repos",
              name,
              "merge-requests",
              num,
              "comments",
              comment_id,
            ] -> {
              case req.method {
                http.Patch ->
                  merge_request_routes.update_comment(
                    req,
                    ctx,
                    slug,
                    name,
                    num,
                    comment_id,
                  )
                http.Delete ->
                  merge_request_routes.delete_comment(
                    req,
                    ctx,
                    slug,
                    name,
                    num,
                    comment_id,
                  )
                _ -> wisp.method_not_allowed([http.Patch, http.Delete])
              }
            }
            [
              "api",
              "orgs",
              slug,
              "repos",
              name,
              "merge-requests",
              num,
              "comments",
            ] -> {
              case req.method {
                http.Get ->
                  merge_request_routes.list_comments(req, ctx, slug, name, num)
                http.Post ->
                  merge_request_routes.create_comment(req, ctx, slug, name, num)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "orgs", slug, "repos", name, "merge-requests", num] -> {
              case req.method {
                http.Get ->
                  merge_request_routes.get_merge_request_detail(
                    req,
                    ctx,
                    slug,
                    name,
                    num,
                  )
                http.Patch ->
                  merge_request_routes.update_merge_request(
                    req,
                    ctx,
                    slug,
                    name,
                    num,
                  )
                _ -> wisp.method_not_allowed([http.Get, http.Patch])
              }
            }
            ["api", "orgs", slug, "repos", name, "tree"] ->
              repo_browse_routes.get_repo_tree_root(req, ctx, slug, name)
            ["api", "orgs", slug, "repos", name, "tree", ..path] ->
              repo_browse_routes.get_repo_tree(req, ctx, slug, name, path)
            ["api", "orgs", slug, "repos", name, "archive", ref_archive] ->
              repo_browse_routes.get_repo_archive(req, ctx, slug, name, ref_archive)
            ["api", "orgs", slug, "repos", name, "raw", ..path] ->
              repo_browse_routes.get_repo_raw(req, ctx, slug, name, path)
            ["api", "orgs", slug, "repos", name, "blob", ..path] ->
              repo_browse_routes.get_repo_blob(req, ctx, slug, name, path)
            ["api", "orgs", slug, "repos", name, "branches"] ->
              repo_browse_routes.list_repo_branches(req, ctx, slug, name)
            ["api", "orgs", slug, "repos", name, "tags"] ->
              repo_tag_routes.list_repo_tags(req, ctx, slug, name)
            ["api", "orgs", slug, "repos", name, "tags", ..tag] ->
              repo_tag_routes.get_repo_tag(req, ctx, slug, name, tag)
            ["api", "orgs", slug, "repos", name, "milestones"] -> {
              case req.method {
                http.Get ->
                  milestone_routes.list_repo_milestones(req, ctx, slug, name)
                http.Post ->
                  milestone_routes.create_repo_milestone(req, ctx, slug, name)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "orgs", slug, "repos", name, "milestones", num, "close"] ->
              milestone_routes.close_repo_milestone(req, ctx, slug, name, num)
            ["api", "orgs", slug, "repos", name, "milestones", num] ->
              milestone_routes.milestone_by_number(req, ctx, slug, name, num)
            ["api", "orgs", slug, "repos", name, "releases"] -> {
              case req.method {
                http.Get ->
                  release_routes.list_repo_releases(req, ctx, slug, name)
                http.Post ->
                  release_routes.create_repo_release(req, ctx, slug, name)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "orgs", slug, "repos", name, "releases", ..tag] -> {
              case req.method {
                http.Get ->
                  release_routes.get_repo_release(req, ctx, slug, name, tag)
                http.Patch ->
                  release_routes.update_repo_release(req, ctx, slug, name, tag)
                _ -> wisp.method_not_allowed([http.Get, http.Patch])
              }
            }
            ["api", "orgs", slug, "repos", name, "readme"] ->
              repo_browse_routes.get_repo_readme(req, ctx, slug, name)
            ["api", "orgs", slug, "repos", name, "commits"] ->
              repo_browse_routes.list_repo_commits(req, ctx, slug, name)
            ["api", "orgs", slug, "repos", name, "commit"] ->
              repo_browse_routes.get_repo_commit(req, ctx, slug, name)
            ["api", "orgs", slug, "repos", name, "protected-branches"] -> {
              case req.method {
                http.Get ->
                  repo_settings_routes.list_protected_branches(
                    req,
                    ctx,
                    slug,
                    name,
                  )
                http.Put ->
                  repo_settings_routes.replace_protected_branches(
                    req,
                    ctx,
                    slug,
                    name,
                  )
                _ -> wisp.method_not_allowed([http.Get, http.Put])
              }
            }
            ["api", "orgs", slug, "repos", name, "default-branch"] -> {
              case req.method {
                http.Put ->
                  repo_settings_routes.set_default_branch(req, ctx, slug, name)
                _ -> wisp.method_not_allowed([http.Put])
              }
            }
            ["api", "orgs", slug, "repos", name] -> {
              case req.method {
                http.Get ->
                  repo_browse_routes.get_repo_detail(req, ctx, slug, name)
                http.Patch -> api_routes.update_repo(req, ctx, slug, name)
                http.Delete -> api_routes.delete_repo(req, ctx, slug, name)
                _ ->
                  wisp.method_not_allowed([http.Get, http.Patch, http.Delete])
              }
            }
            ["api", "ssh-keys"] -> {
              case req.method {
                http.Get -> api_routes.list_ssh_keys(req, ctx)
                http.Post -> api_routes.create_ssh_key(req, ctx)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "ssh-keys", key_id] ->
              api_routes.delete_ssh_key(req, ctx, key_id)

            ["internal-server-error"] -> wisp.internal_server_error()
            ["unprocessable-content"] -> wisp.unprocessable_content()
            ["method-not-allowed"] -> wisp.method_not_allowed([])
            ["entity-too-large"] -> wisp.content_too_large()
            ["bad-request"] -> wisp.bad_request("Bad request")
            _ -> wisp.not_found()
          }
        }
      }
    }
  }
}
