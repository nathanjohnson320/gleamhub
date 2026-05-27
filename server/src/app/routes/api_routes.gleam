import app/database
import app/git_exec
import app/json_api
import app/org_access
import app/ssh_key_parse
import app/web.{type Context}
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import pog
import wisp.{type Request, type Response}

fn user_id(ctx: Context) -> String {
  let assert option.Some(id) = ctx.user_id
  id
}

fn ensure_user(ctx: Context) -> Result(Nil, Response) {
  case ctx.user_id {
    option.Some(id) -> {
      let _ = database.upsert_user(ctx.repo(), id, option.None, ctx.email)
      Ok(Nil)
    }
    option.None -> Error(wisp.response(401))
  }
}

fn clone_url(ctx: Context, org_slug: String, repo_name: String) -> String {
  "ssh://git@"
  <> org_access.git_host(ctx)
  <> ":2222/"
  <> org_slug
  <> "/"
  <> repo_name
  <> ".git"
}

pub fn get_me(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      let id = user_id(ctx)
      let user = database.UserRow(id:, display_name: option.None, email: ctx.email)
      case database.list_orgs_for_user(ctx.repo(), id) {
        Ok(orgs) ->
          json_api.me_json(user, orgs)
          |> json.to_string
          |> wisp.json_response(200)
        Error(_) -> wisp.internal_server_error()
      }
    }
  }
}

pub fn list_orgs(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      case database.list_orgs_for_user(ctx.repo(), user_id(ctx)) {
        Ok(orgs) ->
          json_api.orgs_json(orgs)
          |> json.to_string
          |> wisp.json_response(200)
        Error(_) -> wisp.internal_server_error()
      }
    }
  }
}

pub fn create_org(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      let decoder = {
        use slug <- decode.field("slug", decode.string)
        use name <- decode.field("name", decode.string)
        decode.success(#(slug, name))
      }
      case decode.run(json, decoder) {
        Ok(#(slug, name)) -> {
          case valid_slug(slug) {
            True -> {
              case
                database.create_org(ctx.repo(), slug, name, user_id(ctx))
              {
                Ok(org) ->
                  json_api.org_json(org)
                  |> json.to_string
                  |> wisp.json_response(201)
                Error(_) -> wisp.unprocessable_content()
              }
            }
            False -> wisp.bad_request("Invalid slug")
          }
        }
        Error(_) -> wisp.bad_request("Invalid JSON")
      }
    }
  }
}

pub fn get_org(req: Request, ctx: Context, slug: String) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      case org_access.require_member(ctx, user_id(ctx), slug) {
        Error(_) -> wisp.response(403)
        Ok(_) -> {
          case database.get_org_by_slug(ctx.repo(), slug) {
            Ok(option.Some(org)) -> {
              let org = database.OrgRow(..org, role: option.Some("member"))
              json_api.org_json(org)
              |> json.to_string
              |> wisp.json_response(200)
            }
            Ok(option.None) -> wisp.not_found()
            Error(_) -> wisp.internal_server_error()
          }
        }
      }
    }
  }
}

pub fn list_repos(req: Request, ctx: Context, slug: String) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      case org_access.require_member(ctx, user_id(ctx), slug) {
        Error(_) -> wisp.response(403)
        Ok(_) -> {
          case database.list_repos(ctx.repo(), slug) {
            Ok(repos) -> {
              let with_urls =
                list.map(repos, fn(r) { #(r, clone_url(ctx, slug, r.name)) })
              json_api.repos_json(with_urls)
              |> json.to_string
              |> wisp.json_response(200)
            }
            Error(_) -> wisp.internal_server_error()
          }
        }
      }
    }
  }
}

pub fn create_repo(req: Request, ctx: Context, slug: String) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      case org_access.require_member(ctx, user_id(ctx), slug) {
        Error(_) -> wisp.response(403)
        Ok(_) -> {
          let decoder = {
            use name <- decode.field("name", decode.string)
            use description <- decode.field(
              "description",
              decode.optional(decode.string),
            )
            decode.success(#(name, description))
          }
          case decode.run(json, decoder) {
            Ok(#(name, description)) -> {
              case valid_slug(name) {
                True -> {
                  let disk_path = slug <> "/" <> name <> ".git"
                  case
                    git_exec.init_bare_repo(
                      org_access.git_repos_root(ctx),
                      disk_path,
                    )
                  {
                    Ok(_) -> {
                      case
                        database.insert_repo(
                          ctx.repo(),
                          slug,
                          name,
                          description,
                          disk_path,
                        )
                      {
                        Ok(repo) -> {
                          let url = clone_url(ctx, slug, name)
                          json_api.repo_json(repo, url)
                          |> json.to_string
                          |> wisp.json_response(201)
                        }
                        Error(_) -> wisp.unprocessable_content()
                      }
                    }
                    Error(_) -> wisp.internal_server_error()
                  }
                }
                False -> wisp.bad_request("Invalid repo name")
              }
            }
            Error(_) -> wisp.bad_request("Invalid JSON")
          }
        }
      }
    }
  }
}

pub fn delete_repo(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Delete)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      case org_access.require_owner(ctx, user_id(ctx), org_slug) {
        Error(_) -> wisp.response(403)
        Ok(_) -> {
          case database.delete_repo(ctx.repo(), org_slug, repo_id) {
            Ok(disk_path) -> {
              case
                git_exec.remove_bare_repo(
                  org_access.git_repos_root(ctx),
                  disk_path,
                )
              {
                Ok(_) -> wisp.no_content()
                Error(_) -> wisp.internal_server_error()
              }
            }
            Error(pog.ConstraintViolated(..)) -> wisp.not_found()
            Error(_) -> wisp.internal_server_error()
          }
        }
      }
    }
  }
}

pub fn list_ssh_keys(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      case database.list_keys(ctx.repo(), user_id(ctx)) {
        Ok(keys) ->
          json_api.keys_json(keys)
          |> json.to_string
          |> wisp.json_response(200)
        Error(_) -> wisp.internal_server_error()
      }
    }
  }
}

pub fn create_ssh_key(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      let decoder = {
        use title <- decode.field("title", decode.string)
        use public_key <- decode.field("public_key", decode.string)
        decode.success(#(title, public_key))
      }
      case decode.run(json, decoder) {
        Ok(#(title, public_key)) -> {
          case ssh_key_parse.parse(public_key) {
            Ok(parsed) -> {
              case
                database.insert_key(
                  ctx.repo(),
                  user_id(ctx),
                  title,
                  parsed.public_key,
                  parsed.key_blob,
                  parsed.fingerprint,
                )
              {
                Ok(key) ->
                  json_api.key_json(key)
                  |> json.to_string
                  |> wisp.json_response(201)
                Error(_) -> wisp.unprocessable_content()
              }
            }
            Error(_) -> wisp.bad_request("Invalid public key")
          }
        }
        Error(_) -> wisp.bad_request("Invalid JSON")
      }
    }
  }
}

pub fn delete_ssh_key(req: Request, ctx: Context, key_id: String) -> Response {
  use <- wisp.require_method(req, http.Delete)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      case database.delete_key(ctx.repo(), user_id(ctx), key_id) {
        Ok(_) -> wisp.no_content()
        Error(_) -> wisp.internal_server_error()
      }
    }
  }
}

fn valid_slug(slug: String) -> Bool {
  string.length(slug) > 0
  && string.length(slug) <= 64
  && list.all(string.to_graphemes(slug), fn(c) {
    case c {
      "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l"
      | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w"
      | "x" | "y" | "z" | "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7"
      | "8" | "9" | "-" -> True
      _ -> False
    }
  })
}
