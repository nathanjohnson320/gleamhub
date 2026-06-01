import api
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn merge_request_decoder_test() {
  let assert Ok(body) =
    json.parse(
      "{\"id\":\"u1\",\"number\":2,\"title\":\"Fix bug\",\"description\":null,\"author_user_id\":\"a1\",\"source_branch\":\"feature\",\"target_branch\":\"main\",\"state\":\"open\",\"merge_commit_sha\":null,\"merged_at\":null,\"closed_at\":null,\"created_at\":\"2026-01-01T00:00:00Z\"}",
      decode.dynamic,
    )
  let assert Ok(mr) = decode.run(body, api.merge_request_decoder())
  mr.number |> should.equal(2)
  mr.title |> should.equal("Fix bug")
  mr.source_branch |> should.equal("feature")
  mr.description |> should.equal(option.None)
}

pub fn protected_branches_decoder_test() {
  let assert Ok(body) =
    json.parse("{\"branches\":[\"main\",\"release\"]}", decode.dynamic)
  let assert Ok(branches) = decode.run(body, api.protected_branches_decoder())
  branches |> should.equal(["main", "release"])
}

pub fn merge_request_detail_decoder_null_pipeline_test() {
  let assert Ok(body) =
    json.parse(
      "{\"merge_request\":{\"id\":\"u1\",\"number\":1,\"title\":\"T\",\"description\":null,\"author_user_id\":\"a1\",\"source_branch\":\"feature\",\"target_branch\":\"main\",\"state\":\"open\",\"merge_commit_sha\":null,\"merged_at\":null,\"closed_at\":null,\"created_at\":\"2026-01-01T00:00:00Z\"},\"merge_check\":{\"mergeable\":true,\"message\":\"\"},\"pipeline\":null}",
      decode.dynamic,
    )
  let assert Ok(detail) = decode.run(body, api.merge_request_detail_decoder())
  detail.pipeline |> should.equal(option.None)
}

pub fn merge_request_detail_decoder_pipeline_test() {
  let assert Ok(body) =
    json.parse(
      "{\"merge_request\":{\"id\":\"u1\",\"number\":1,\"title\":\"T\",\"description\":null,\"author_user_id\":\"a1\",\"source_branch\":\"feature\",\"target_branch\":\"main\",\"state\":\"open\",\"merge_commit_sha\":null,\"merged_at\":null,\"closed_at\":null,\"created_at\":\"2026-01-01T00:00:00Z\"},\"merge_check\":{\"mergeable\":false,\"message\":\"Checks running\"},\"pipeline\":{\"state\":\"running\",\"commit_sha\":\"abc123\",\"module_path\":\"ci\",\"entry_function\":\"ci\",\"started_at\":\"2026-01-01T00:00:00Z\",\"finished_at\":null,\"log\":null}}",
      decode.dynamic,
    )
  let assert Ok(detail) = decode.run(body, api.merge_request_detail_decoder())
  let assert option.Some(pipeline) = detail.pipeline
  pipeline.state |> should.equal("running")
  pipeline.commit_sha |> should.equal("abc123")
  pipeline.module_path |> should.equal(option.Some("ci"))
}
