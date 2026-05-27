import gleam/result
import simplifile

@external(erlang, "git_exec_ffi", "init_bare")
fn init_bare_ffi(path: String) -> Nil

pub fn init_bare_repo(root: String, disk_path: String) -> Result(Nil, String) {
  let path = repo_path(root, disk_path)
  case simplifile.create_directory_all(path) {
    Error(e) -> Error("mkdir failed: " <> simplifile.describe_error(e))
    Ok(_) -> {
      init_bare_ffi(path)
      Ok(Nil)
    }
  }
}

pub fn remove_bare_repo(root: String, disk_path: String) -> Result(Nil, String) {
  simplifile.delete(repo_path(root, disk_path))
  |> result.map_error(fn(e) { "remove repo failed: " <> simplifile.describe_error(e) })
}

fn repo_path(root: String, disk_path: String) -> String {
  root <> "/" <> disk_path
}
