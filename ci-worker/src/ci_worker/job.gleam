import gleam/dynamic/decode
import gleam/json
import gleam/result
import gleam/string

pub type Job {
  Job(
    id: String,
    org_slug: String,
    repo_name: String,
    disk_path: String,
    commit_sha: String,
    module_path: String,
    entry_function: String,
    merge_request_id: String,
  )
}

pub fn decode(body: String) -> Result(Job, Nil) {
  let decoder = {
    use id <- decode.field("id", decode.string)
    use org_slug <- decode.field("org_slug", decode.string)
    use repo_name <- decode.field("repo_name", decode.string)
    use disk_path <- decode.field("disk_path", decode.string)
    use commit_sha <- decode.field("commit_sha", decode.string)
    use module_path <- decode.field("module_path", decode.string)
    use entry_function <- decode.field("entry_function", decode.string)
    use merge_request_id <- decode.field("merge_request_id", decode.string)
    decode.success(Job(
      id:,
      org_slug:,
      repo_name:,
      disk_path:,
      commit_sha:,
      module_path:,
      entry_function:,
      merge_request_id:,
    ))
  }

  json.parse(body, decoder)
  |> result.map_error(fn(_) { Nil })
}

pub fn short_sha(commit_sha: String) -> String {
  case string.length(commit_sha) > 7 {
    True -> string.slice(commit_sha, 0, 7)
    False -> commit_sha
  }
}
