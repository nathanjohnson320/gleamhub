import app/routes/api_routes
import app/routes/clerk
import app/routes/merge_request_routes
import app/routes/repo_browse_routes
import app/routes/repo_settings_routes
import app/routes/ssh_internal_routes
import app/web.{type Context}
import gleam/http
import simplifile
import wisp.{type Request, type Response}

fn is_ui_route(segments: List(String)) -> Bool {
  case segments {
    [] -> True
    ["orgs"] -> True
    ["orgs", _] -> True
    ["orgs", _, "repos", _, .._] -> True
    ["keys"] | ["settings", .._] -> True
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
      ssh_internal_routes.authorized_keys(req, ctx)

    ["internal", "ssh", "access"] -> ssh_internal_routes.access_check(req, ctx)

    ["internal", "ssh", "ref-update"] ->
      ssh_internal_routes.ref_update_check(req, ctx)

    _ -> {
      case is_ui_route(path_segments) {
        True -> serve_spa(ctx)
        False -> {
          use ctx <- clerk.middleware(req, ctx)
          case path_segments {
            ["api", "me"] -> api_routes.get_me(req, ctx)
            ["api", "orgs"] -> {
              case req.method {
                http.Get -> api_routes.list_orgs(req, ctx)
                http.Post -> api_routes.create_org(req, ctx)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "orgs", slug] -> api_routes.get_org(req, ctx, slug)
            ["api", "orgs", slug, "repos"] -> {
              case req.method {
                http.Get -> api_routes.list_repos(req, ctx, slug)
                http.Post -> api_routes.create_repo(req, ctx, slug)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "orgs", slug, "repos", name, "merge-requests"] -> {
              case req.method {
                http.Get ->
                  merge_request_routes.list_merge_requests(
                    req,
                    ctx,
                    slug,
                    name,
                  )
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
            ["api", "orgs", slug, "repos", name, "merge-requests", num, "merge"] ->
              merge_request_routes.merge_merge_request(req, ctx, slug, name, num)
            ["api", "orgs", slug, "repos", name, "merge-requests", num, "close"] ->
              merge_request_routes.close_merge_request_route(
                req,
                ctx,
                slug,
                name,
                num,
              )
            ["api", "orgs", slug, "repos", name, "merge-requests", num, "commits"] ->
              merge_request_routes.list_commits(req, ctx, slug, name, num)
            ["api", "orgs", slug, "repos", name, "merge-requests", num, "diff"] ->
              merge_request_routes.get_diff(req, ctx, slug, name, num)
            ["api", "orgs", slug, "repos", name, "merge-requests", num, "comments"] -> {
              case req.method {
                http.Get ->
                  merge_request_routes.list_comments(req, ctx, slug, name, num)
                http.Post ->
                  merge_request_routes.create_comment(req, ctx, slug, name, num)
                _ -> wisp.method_not_allowed([http.Get, http.Post])
              }
            }
            ["api", "orgs", slug, "repos", name, "merge-requests", num] ->
              merge_request_routes.get_merge_request_detail(
                req,
                ctx,
                slug,
                name,
                num,
              )
            ["api", "orgs", slug, "repos", name, "tree"] ->
              repo_browse_routes.get_repo_tree_root(req, ctx, slug, name)
            ["api", "orgs", slug, "repos", name, "tree", ref, ..path] ->
              repo_browse_routes.get_repo_tree(req, ctx, slug, name, ref, path)
            ["api", "orgs", slug, "repos", name, "blob", ref, ..path] ->
              repo_browse_routes.get_repo_blob(req, ctx, slug, name, ref, path)
            ["api", "orgs", slug, "repos", name, "branches"] ->
              repo_browse_routes.list_repo_branches(req, ctx, slug, name)
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
            ["api", "orgs", slug, "repos", name] -> {
              case req.method {
                http.Get ->
                  repo_browse_routes.get_repo_detail(req, ctx, slug, name)
                http.Delete -> api_routes.delete_repo(req, ctx, slug, name)
                _ -> wisp.method_not_allowed([http.Get, http.Delete])
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
