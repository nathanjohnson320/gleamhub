import app/routes/api_routes
import app/routes/clerk
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
    ["orgs", _, "repos", "new"] -> True
    ["keys"] -> True
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
            ["api", "orgs", slug, "repos", repo_ref] -> {
              case req.method {
                http.Delete -> api_routes.delete_repo(req, ctx, slug, repo_ref)
                _ -> wisp.method_not_allowed([http.Delete])
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
