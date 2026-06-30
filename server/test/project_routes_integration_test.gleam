import database
import database_integration_fixtures as fixtures
import db_test_support
import gleam/json
import gleam/option
import gleam/string
import route_test_support

pub fn project_routes_lifecycle_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let _ = fixtures.seed_org(db, "acme", "owner")
    let assert Ok(_) =
      database.insert_repo(db, "acme", "demo", option.None, "acme/demo.git")

    let empty =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/projects",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(empty)
    let assert True = route_test_support.contains(empty, "\"projects\":[]")

    let created =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/projects",
          token,
          json.object([
            #("title", json.string("Sprint board")),
            #("description", json.string("Q3 planning")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(created)
    let assert True = route_test_support.contains(created, "\"number\":1")
    let project_id = extract_string_field(route_test_support.body(created), "id")

    let detail =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/projects/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(detail)
    let assert True = route_test_support.contains(detail, "Q3 planning")

    let board =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/projects/1/board",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(board)
    let assert True = route_test_support.contains(board, "\"name\":\"Todo\"")
    let assert True = route_test_support.contains(board, "\"name\":\"Done\"")

    let issue =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/issues",
          token,
          json.object([
            #("title", json.string("Ship feature")),
            #("description", json.null()),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(issue)

    let invalid_item =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/projects/1/items",
          token,
          json.object([
            #("item_type", json.string("issue")),
            #("repo_name", json.string("demo")),
            #("number", json.int(99)),
          ]),
        ),
        ctx,
      )
    let assert 400 = route_test_support.status(invalid_item)

    let added_item =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/projects/1/items",
          token,
          json.object([
            #("item_type", json.string("issue")),
            #("repo_name", json.string("demo")),
            #("number", json.int(1)),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(added_item)
    let assert True = route_test_support.contains(added_item, "Ship feature")
    let item_id = extract_string_field(route_test_support.body(added_item), "id")

    let board_with_item =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/projects/1/board",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(board_with_item)
    let assert True = route_test_support.contains(board_with_item, "Ship feature")

    let custom_column =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/projects/1/columns",
          token,
          json.object([
            #("name", json.string("Review")),
            #("position", json.int(3)),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(custom_column)
    let column_id = extract_string_field(route_test_support.body(custom_column), "id")

    let moved =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/projects/1/items/" <> item_id,
          token,
          json.object([
            #("column_id", json.string(column_id)),
            #("position", json.int(0)),
          ]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(moved)
    let assert True = route_test_support.contains(moved, column_id)

    let updated =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/projects/1",
          token,
          json.object([
            #("title", json.string("Sprint Board")),
            #("description", json.string("Updated project")),
          ]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(updated)
    let assert True = route_test_support.contains(updated, "Sprint Board")

    let renamed_column =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/projects/1/columns/" <> column_id,
          token,
          json.object([#("name", json.string("In Review"))]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(renamed_column)
    let assert True = route_test_support.contains(renamed_column, "In Review")

    let deleted_item =
      route_test_support.dispatch(
        route_test_support.delete(
          "/api/orgs/acme/projects/1/items/" <> item_id,
          token,
        ),
        ctx,
      )
    let assert 204 = route_test_support.status(deleted_item)

    let deleted_column =
      route_test_support.dispatch(
        route_test_support.delete(
          "/api/orgs/acme/projects/1/columns/" <> column_id,
          token,
        ),
        ctx,
      )
    let assert 204 = route_test_support.status(deleted_column)

    let assert True = string.length(project_id) > 0

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

fn extract_string_field(body: String, field: String) -> String {
  let pattern = "\"" <> field <> "\":\""
  case string.split(body, on: pattern) {
    [_, rest, ..] ->
      case string.split(rest, on: "\"") {
        [value, ..] -> value
        _ -> ""
      }
    _ -> ""
  }
}
