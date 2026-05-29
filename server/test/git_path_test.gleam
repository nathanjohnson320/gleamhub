import app/git_path
import gleam/option
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn normalize_empty_test() {
  let assert Ok("") = git_path.normalize("")
  let assert Ok("") = git_path.normalize("   ")
}

pub fn normalize_trims_and_joins_test() {
  let assert Ok("src/lib") = git_path.normalize("src/lib")
  let assert Ok("a/b/c") = git_path.normalize("a/b/c")
}

pub fn normalize_rejects_empty_segments_test() {
  let assert Error(git_path.InvalidPath) = git_path.normalize("a//b")
}

pub fn normalize_rejects_traversal_test() {
  let assert Error(git_path.InvalidPath) = git_path.normalize("../etc/passwd")
  let assert Error(git_path.InvalidPath) = git_path.normalize("src/../secret")
  let assert Error(git_path.InvalidPath) = git_path.normalize("/absolute")
}

pub fn join_path_test() {
  let assert Ok("src/lib.gleam") = git_path.join_path("src", "lib.gleam")
  let assert Ok("file.txt") = git_path.join_path("", "file.txt")
  let assert Error(git_path.InvalidPath) = git_path.join_path("src", "../escape")
}

pub fn tree_ref_path_test() {
  let assert "main" = git_path.tree_ref_path("main", "")
  let assert "main:README.md" = git_path.tree_ref_path("main", "README.md")
}

pub fn normalize_sha_valid_test() {
  let assert Ok("abc1234") = git_path.normalize_sha("abc1234")
  let assert Ok("deadbeef") = git_path.normalize_sha("DEADBEEF")
}

pub fn normalize_sha_invalid_test() {
  let assert Error(git_path.InvalidPath) = git_path.normalize_sha("abc")
  let assert Error(git_path.InvalidPath) = git_path.normalize_sha("not-hex!")
  let assert Error(git_path.InvalidPath) = git_path.normalize_sha("")
}

pub fn normalize_ref_valid_test() {
  let assert Ok("main") = git_path.normalize_ref("main")
  let assert Ok("feature/foo") = git_path.normalize_ref("feature/foo")
  let assert Ok("abc1234") = git_path.normalize_ref("abc1234")
}

pub fn normalize_ref_invalid_test() {
  let assert Error(git_path.InvalidPath) = git_path.normalize_ref("")
  let assert Error(git_path.InvalidPath) = git_path.normalize_ref("--help")
  let assert Error(git_path.InvalidPath) = git_path.normalize_ref("/main")
}

pub fn validate_disk_path_test() {
  let assert Ok("acme/demo.git") = git_path.validate_disk_path("acme/demo.git")
  let assert Error(git_path.InvalidPath) =
    git_path.validate_disk_path("../escape.git")
  let assert Error(git_path.InvalidPath) =
    git_path.validate_disk_path("/acme/demo.git")
}

pub fn normalize_branch_valid_test() {
  let assert Ok("main") = git_path.normalize_branch("main")
  let assert Ok("feature/foo") = git_path.normalize_branch("feature/foo")
  let assert Ok("release-1") = git_path.normalize_branch("  release-1  ")
}

pub fn normalize_branch_invalid_test() {
  let assert Error(git_path.InvalidPath) = git_path.normalize_branch("")
  let assert Error(git_path.InvalidPath) = git_path.normalize_branch("..")
  let assert Error(git_path.InvalidPath) = git_path.normalize_branch("/main")
  let assert Error(git_path.InvalidPath) = git_path.normalize_branch("a//b")
}

pub fn parent_path_test() {
  let assert option.Some("") = git_path.parent_path("file.txt")
  let assert option.Some("src/lib") = git_path.parent_path("src/lib/foo.gleam")
  let assert option.Some("a") = git_path.parent_path("a/b")
  let assert option.Some("") = git_path.parent_path("")
}
