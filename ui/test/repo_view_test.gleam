import gleam/option
import gleeunit/should
import pages/repo_view
import routes.{Blob}

pub fn same_view_matches_same_blob_test() {
  let model =
    repo_view.init(
      "nate",
      "gleamhub",
      Blob,
      "main",
      "docker-compose.yml",
      option.None,
    )
  repo_view.same_view(
    model,
    "nate",
    "gleamhub",
    Blob,
    "main",
    "docker-compose.yml",
  )
  |> should.be_true
}

pub fn same_view_rejects_different_path_test() {
  let model =
    repo_view.init(
      "nate",
      "gleamhub",
      Blob,
      "main",
      "docker-compose.yml",
      option.None,
    )
  repo_view.same_view(model, "nate", "gleamhub", Blob, "main", "README.md")
  |> should.be_false
}

pub fn sync_line_range_updates_only_line_range_test() {
  let model =
    repo_view.init(
      "nate",
      "gleamhub",
      Blob,
      "main",
      "docker-compose.yml",
      option.None,
    )
  let synced = repo_view.sync_line_range(model, option.Some(#(18, 18)))
  synced.line_range |> should.equal(option.Some(#(18, 18)))
  synced.blob |> should.equal(model.blob)
  synced.readme |> should.equal(model.readme)
}
