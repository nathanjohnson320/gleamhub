import database.{type ReleaseError, type ReleaseRow, create_release,
  get_release_by_tag, get_repo, list_releases, member_can_write, update_release,
}
import git/browse_routes as repo_browse_routes
import git/exec as git_exec
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleam/uri
import http/org_access
import http/user_display
import http/web.{type Context}
import json/api as json_api
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

fn json_ok(body: json.Json, status: Int) -> Response {
  json.to_string(body) |> wisp.json_response(status)
}

fn release_error_response(error: ReleaseError) -> Response {
  let message = case error {
    database.DuplicateRelease -> "A release for that tag already exists"
    database.InvalidReleaseTitle -> "Invalid release title"
    database.InvalidTagName -> "Invalid tag name"
    database.TagNotFound -> "Tag not found"
    database.ReleaseNotFound -> "Release not found"
  }
  let status = case error {
    database.ReleaseNotFound -> 404
    _ -> 400
  }
  json.object([#("error", json.string(message))])
  |> json.to_string
  |> wisp.json_response(status)
}

fn with_repo(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  run: fn() -> Response,
) -> Response {
  case org_access.require_member(ctx, user_id(ctx), org_slug) {
    Error(_) -> wisp.response(403)
    Ok(_) ->
      case get_repo(ctx.repo(), org_slug, repo_name) {
        Ok(option.None) -> wisp.not_found()
        Ok(option.Some(_)) -> run()
        Error(_) -> wisp.internal_server_error()
      }
  }
}

fn with_git_repo(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  run: fn(String) -> Response,
) -> Response {
  case org_access.require_member(ctx, user_id(ctx), org_slug) {
    Error(_) -> wisp.response(403)
    Ok(_) ->
      case get_repo(ctx.repo(), org_slug, repo_name) {
        Ok(option.None) -> wisp.not_found()
        Ok(option.Some(repo)) ->
          case git_exec.repo_path(org_access.git_repos_root(ctx), repo.disk_path) {
            Error(_) -> wisp.internal_server_error()
            Ok(git_dir) -> run(git_dir)
          }
        Error(_) -> wisp.internal_server_error()
      }
  }
}

fn require_write(
  ctx: Context,
  org_slug: String,
  run: fn() -> Response,
) -> Response {
  case member_can_write(ctx.repo(), user_id(ctx), org_slug) {
    True -> run()
    False -> wisp.response(403)
  }
}

fn join_tag_segments(segments: List(String)) -> String {
  segments
  |> list.map(decode_tag_segment)
  |> string.join(with: "/")
}

fn decode_tag_segment(segment: String) -> String {
  case uri.percent_decode(segment) {
    Ok(decoded) -> decoded
    Error(_) -> segment
  }
}

fn release_author_name(ctx: Context, release: ReleaseRow) -> String {
  user_display.display_name(ctx, release.author_user_id)
}

pub fn list_repo_releases(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      with_repo(ctx, org_slug, repo_name, fn() {
        case list_releases(ctx.repo(), org_slug, repo_name) {
          Ok(releases) -> {
            let items =
              list.map(releases, fn(r) {
                #(r, release_author_name(ctx, r))
              })
            json_ok(json_api.releases_json(items), 200)
          }
          Error(_) -> wisp.internal_server_error()
        }
      })
  }
}

pub fn get_repo_release(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  tag_segments: List(String),
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      with_repo(ctx, org_slug, repo_name, fn() {
        let tag = join_tag_segments(tag_segments)
        case get_release_by_tag(ctx.repo(), org_slug, repo_name, tag) {
          Ok(option.None) -> wisp.not_found()
          Ok(option.Some(release)) ->
            json_ok(
              json_api.release_json(
                release,
                release_author_name(ctx, release),
              ),
              200,
            )
          Error(_) -> wisp.internal_server_error()
        }
      })
  }
}

pub fn update_repo_release(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  tag_segments: List(String),
) -> Response {
  use <- wisp.require_method(req, http.Patch)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        with_repo(ctx, org_slug, repo_name, fn() {
          let tag = join_tag_segments(tag_segments)
          let decoder = {
            use title <- decode.field("title", decode.string)
            use body <- decode.optional_field("body", "", decode.string)
            decode.success(#(title, body))
          }
          case decode.run(json_body, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON body")
            Ok(#(title, body)) ->
              case
                update_release(
                  ctx.repo(),
                  org_slug,
                  repo_name,
                  tag,
                  title,
                  body,
                )
              {
                Ok(release) ->
                  json_ok(
                    json_api.release_json(
                      release,
                      release_author_name(ctx, release),
                    ),
                    200,
                  )
                Error(e) -> release_error_response(e)
              }
          }
        })
      })
  }
}

pub fn create_repo_release(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        with_repo(ctx, org_slug, repo_name, fn() {
          let decoder = {
            use tag_name <- decode.field("tag_name", decode.string)
            use title <- decode.field("title", decode.string)
            use body <- decode.optional_field("body", "", decode.string)
            decode.success(#(tag_name, title, body))
          }
          case decode.run(json_body, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON body")
            Ok(#(tag_name, title, body)) ->
              with_git_repo(ctx, org_slug, repo_name, fn(git_dir) {
                case git_exec.tag_exists(git_dir, tag_name) {
                  Error(git_exec.NotFound) ->
                    release_error_response(database.TagNotFound)
                  Error(e) -> repo_browse_routes.git_error_response(e)
                  Ok(validated_tag) ->
                    case git_exec.resolve_tag_commit(git_dir, validated_tag) {
                      Error(e) -> repo_browse_routes.git_error_response(e)
                      Ok(sha) ->
                        case
                          create_release(
                            ctx.repo(),
                            org_slug,
                            repo_name,
                            validated_tag,
                            sha,
                            title,
                            body,
                            user_id(ctx),
                          )
                        {
                          Ok(release) ->
                            json_ok(
                              json_api.release_json(
                                release,
                                release_author_name(ctx, release),
                              ),
                              201,
                            )
                          Error(e) -> release_error_response(e)
                        }
                    }
                }
              })
          }
        })
      })
  }
}
