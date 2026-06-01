import gleam/option
import gleam/string

/// Search order for hosted-repo Dagger modules (see docs/ci-platform.md).
pub const module_candidates = [
  ".dagger/dagger.json",
  "ci/dagger.json",
  "dagger/dagger.json",
]

pub const default_entry_function = "ci"

@external(erlang, "ci_discovery_ffi", "discover_module")
fn discover_module_ffi(git_dir: String, commit_sha: String) -> String

@external(erlang, "ci_discovery_ffi", "branch_head")
fn branch_head_ffi(git_dir: String, branch: String) -> String

/// Returns the module directory (e.g. `"ci"`, `".dagger"`) at `commit_sha`, if any.
pub fn discover_module(
  git_dir: String,
  commit_sha: String,
) -> option.Option(String) {
  case discover_module_ffi(git_dir, commit_sha) {
    "" -> option.None
    path -> option.Some(path)
  }
}

pub fn branch_head_sha(git_dir: String, branch: String) -> Result(String, Nil) {
  case branch_head_ffi(git_dir, branch) {
    "" -> Error(Nil)
    sha -> Ok(string.trim(sha))
  }
}
