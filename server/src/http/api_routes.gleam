import database
import git/exec as git_exec
import git/ssh_key_parse
import git/url as git_url
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import http/clerk_api
import http/org_access
import http/web.{type Context}
import json/api as json_api
import pog
import wisp.{type Request, type Response}

fn user_id(ctx: Context) -> String {
  let assert option.Some(id) = ctx.user_id
  id
}

fn ensure_user(ctx: Context) -> Result(Nil, Response) {
  case ctx.user_id {
    option.Some(_) -> Ok(Nil)
    option.None -> Error(wisp.response(401))
  }
}

pub fn get_me(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      let id = user_id(ctx)
      let #(display_name, email) = case ctx.clerk {
        option.Some(client) ->
          case clerk_api.profile_for_user(client, id) {
            Ok(profile) -> profile
            Error(_) -> #(option.None, option.None)
          }
        option.None -> #(option.None, option.None)
      }
      let user = database.UserRow(id:, display_name:, email:)
      case database.list_orgs_for_user(ctx.repo(), id) {
        Ok(orgs) ->
          case database.get_user_stats(ctx.repo(), id) {
            Error(_) -> wisp.internal_server_error()
            Ok(stats) ->
              case database.count_unread_notifications(ctx.repo(), id) {
                Error(_) -> wisp.internal_server_error()
                Ok(unread_count) ->
                  json_api.me_json(user, orgs, stats, unread_count)
                  |> json.to_string
                  |> wisp.json_response(200)
              }
          }
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
              case database.create_org(ctx.repo(), slug, name, user_id(ctx)) {
                Ok(org) ->
                  json_api.org_json(org)
                  |> json.to_string
                  |> wisp.json_response(201)
                Error(e) -> create_org_error_response(e)
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

fn create_org_error_response(error: pog.QueryError) -> Response {
  case is_duplicate_slug_error(error) {
    True ->
      json.object([
        #(
          "error",
          json.string(
            "Organization slug already exists. If a previous attempt failed, try another slug or delete the orphan row in the database.",
          ),
        ),
      ])
      |> json.to_string
      |> wisp.json_response(409)
    False -> wisp.unprocessable_content()
  }
}

fn is_duplicate_slug_error(error: pog.QueryError) -> Bool {
  case error {
    pog.ConstraintViolated(_, constraint, _) ->
      string.contains(constraint, "slug")
    pog.PostgresqlError("23505", _, message) ->
      string.contains(message, "organizations_slug")
      || string.contains(message, "(slug)")
    _ -> False
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
              let role =
                database.member_role(ctx.repo(), user_id(ctx), slug)
                |> result.map(option.map(_, fn(r) { r }))
                |> result.unwrap(option.None)
              let org = database.OrgRow(..org, role:)
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
                list.map(repos, fn(r) {
                  #(r, git_url.clone_url(ctx, slug, r.name))
                })
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
                          let url = git_url.clone_url(ctx, slug, name)
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

fn respond_repo(
  ctx: Context,
  org_slug: String,
  repo: database.RepoRow,
) -> Response {
  let url = git_url.clone_url(ctx, org_slug, repo.name)
  json_api.repo_json(repo, url)
  |> json.to_string
  |> wisp.json_response(200)
}

fn valid_description(
  description: option.Option(String),
) -> Result(Nil, Response) {
  case description {
    option.Some(text) ->
      case string.length(text) > 500 {
        True -> Error(wisp.bad_request("Description is too long"))
        False -> Ok(Nil)
      }
    option.None -> Ok(Nil)
  }
}

fn rename_repo_on_disk(
  ctx: Context,
  repo: database.RepoRow,
  org_slug: String,
  new_name: String,
) -> Result(database.RepoRow, Response) {
  let new_disk_path = org_slug <> "/" <> new_name <> ".git"
  case
    git_exec.rename_bare_repo(
      org_access.git_repos_root(ctx),
      repo.disk_path,
      new_disk_path,
    )
  {
    Error(_) -> Error(wisp.internal_server_error())
    Ok(_) ->
      case
        database.rename_repo(
          ctx.repo(),
          org_slug,
          repo.name,
          new_name,
          new_disk_path,
        )
      {
        Ok(updated) ->
          case
            git_exec.install_repo_hooks(
              org_access.git_repos_root(ctx),
              updated.disk_path,
            )
          {
            Error(_) -> {
              let _ =
                git_exec.rename_bare_repo(
                  org_access.git_repos_root(ctx),
                  new_disk_path,
                  repo.disk_path,
                )
              Error(wisp.internal_server_error())
            }
            Ok(_) -> Ok(updated)
          }
        Error(pog.ConstraintViolated(..)) -> {
          let _ =
            git_exec.rename_bare_repo(
              org_access.git_repos_root(ctx),
              new_disk_path,
              repo.disk_path,
            )
          Error(wisp.unprocessable_content())
        }
        Error(_) -> {
          let _ =
            git_exec.rename_bare_repo(
              org_access.git_repos_root(ctx),
              new_disk_path,
              repo.disk_path,
            )
          Error(wisp.internal_server_error())
        }
      }
  }
}

pub fn update_repo(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Patch)
  use json <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case org_access.require_owner(ctx, user_id(ctx), org_slug) {
        Error(_) -> wisp.response(403)
        Ok(_) -> {
          let decoder = {
            use name <- decode.optional_field(
              "name",
              option.None,
              decode.optional(decode.string),
            )
            use description <- decode.optional_field(
              "description",
              option.None,
              decode.optional(decode.string),
            )
            use required_approvals <- decode.optional_field(
              "required_approvals",
              option.None,
              decode.optional(decode.int),
            )
            decode.success(#(name, description, required_approvals))
          }
          case decode.run(json, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON")
            Ok(#(name_opt, description_opt, required_approvals_opt)) ->
              case name_opt, description_opt, required_approvals_opt {
                option.None, option.None, option.None ->
                  wisp.bad_request("At least one field is required")
                _, _, _ ->
                  case database.get_repo(ctx.repo(), org_slug, repo_name) {
                    Ok(option.None) -> wisp.not_found()
                    Error(_) -> wisp.internal_server_error()
                    Ok(option.Some(repo)) ->
                      apply_repo_update(
                        ctx,
                        org_slug,
                        repo,
                        name_opt,
                        description_opt,
                        required_approvals_opt,
                      )
                  }
              }
          }
        }
      }
  }
}

fn valid_required_approvals(count: Int) -> Bool {
  count >= 0 && count <= 10
}

fn apply_repo_update(
  ctx: Context,
  org_slug: String,
  repo: database.RepoRow,
  name_opt: option.Option(String),
  description_opt: option.Option(String),
  required_approvals_opt: option.Option(Int),
) -> Response {
  let after_required_approvals = case required_approvals_opt {
    option.None -> Ok(repo)
    option.Some(count) ->
      case valid_required_approvals(count) {
        False -> Error(wisp.bad_request("Invalid required approvals count"))
        True ->
          database.set_required_approvals(
            ctx.repo(),
            org_slug,
            repo.name,
            count,
          )
          |> result.map(fn(_) { repo })
          |> result.map_error(fn(_) { wisp.internal_server_error() })
      }
  }
  case after_required_approvals {
    Error(r) -> r
    Ok(current) -> {
      let after_description = case description_opt {
        option.None -> Ok(current)
        option.Some(description) -> {
          let cleared = case description {
            "" -> option.None
            _ -> option.Some(description)
          }
          case valid_description(cleared) {
            Error(r) -> Error(r)
            Ok(_) ->
              database.update_repo_description(
                ctx.repo(),
                org_slug,
                current.name,
                cleared,
              )
              |> result.map_error(fn(_) { wisp.internal_server_error() })
          }
        }
      }
      case after_description {
        Error(r) -> r
        Ok(updated) ->
          case name_opt {
            option.None -> respond_repo(ctx, org_slug, updated)
            option.Some(new_name) ->
              case valid_slug(new_name) {
                False -> wisp.bad_request("Invalid repo name")
                True ->
                  case new_name == updated.name {
                    True -> respond_repo(ctx, org_slug, updated)
                    False ->
                      case rename_repo_on_disk(ctx, updated, org_slug, new_name) {
                        Error(r) -> r
                        Ok(renamed) -> respond_repo(ctx, org_slug, renamed)
                      }
                  }
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
      "a"
      | "b"
      | "c"
      | "d"
      | "e"
      | "f"
      | "g"
      | "h"
      | "i"
      | "j"
      | "k"
      | "l"
      | "m"
      | "n"
      | "o"
      | "p"
      | "q"
      | "r"
      | "s"
      | "t"
      | "u"
      | "v"
      | "w"
      | "x"
      | "y"
      | "z"
      | "0"
      | "1"
      | "2"
      | "3"
      | "4"
      | "5"
      | "6"
      | "7"
      | "8"
      | "9"
      | "-"
      | "_" -> True
      _ -> False
    }
  })
}
