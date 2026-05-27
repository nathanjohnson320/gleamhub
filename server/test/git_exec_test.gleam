import app/git_exec
import app/git_path
import gleam/list
import gleam/option
import gleam/string
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn normalize_path_test() {
  let assert Ok("") = git_path.normalize("")
  let assert Ok("src/lib") = git_path.normalize("src/lib")
  let assert Error(git_path.InvalidPath) = git_path.normalize("../etc/passwd")
  let assert Error(git_path.InvalidPath) = git_path.normalize("/absolute")
}

pub fn parent_path_test() {
  let assert option.Some("") = git_path.parent_path("file.txt")
  let assert option.Some("src/lib") = git_path.parent_path("src/lib/foo.gleam")
}

@external(erlang, "git_exec_test_ffi", "setup_fixture_repo")
fn setup_fixture_repo() -> String

@external(erlang, "git_exec_test_ffi", "cleanup_fixture_repo")
fn cleanup_fixture_repo(path: String) -> Nil

pub fn browse_fixture_repo_test() {
  let git_dir = setup_fixture_repo()
  let assert Ok(branches) = git_exec.list_branches(git_dir)
  let assert True = list.contains(branches, "main")

  let assert Ok("main") = git_exec.default_branch(git_dir)

  let assert Ok(readme) = git_exec.find_readme(git_dir, "main")
  let assert option.Some(r) = readme
  let assert True = string.contains(r.content, "Gleamhub test")

  let assert Ok(entries) = git_exec.list_tree(git_dir, "main", "")
  let assert True =
    list.any(entries, fn(e) {
      e.name == "README.md" && e.entry_type == git_exec.Blob
    })
  let assert True =
    list.any(entries, fn(e) {
      e.name == "src" && e.entry_type == git_exec.Tree
    })

  let assert Ok(sub) = git_exec.list_tree(git_dir, "main", "src")
  let assert True =
    list.any(sub, fn(e) { e.name == "main.gleam" })

  let assert Ok(blob) = git_exec.read_blob(git_dir, "main", "README.md")
  let assert False = blob.binary
  let assert True = string.contains(blob.content, "Gleamhub test")

  let assert Ok(changelog) = git_exec.read_blob(git_dir, "main", "CHANGELOG.md")
  let assert False = changelog.binary
  let assert True = string.contains(changelog.content, "Initial release")
  let assert True = string.contains(changelog.content, "__GLEAMHUB_EXIT:0")

  cleanup_fixture_repo(git_dir)
}

pub fn merge_request_git_ops_test() {
  let git_dir = setup_fixture_repo()
  let assert Ok(Nil) = git_exec.branch_exists(git_dir, "main")
  let assert Ok(Nil) = git_exec.branch_exists(git_dir, "feature")
  let assert Error(_) = git_exec.branch_exists(git_dir, "nope")

  let assert Ok(base) = git_exec.merge_base(git_dir, "main", "feature")
  let assert True = base != ""

  let assert Ok(commits) = git_exec.commits_between(git_dir, "main", "feature")
  let assert True = list.length(commits) >= 1

  let assert Ok(files) = git_exec.diff_summary(git_dir, "main", "feature")
  let assert True =
    list.any(files, fn(f) { f.path == "feature.txt" })

  let assert Ok(patch) = git_exec.diff_patch(git_dir, "main", "feature", "feature.txt")
  let assert True = string.contains(patch, "feature branch")

  let assert Ok(check) = git_exec.can_merge(git_dir, "main", "feature")
  let assert True = check.mergeable

  let assert Ok(sha) =
    git_exec.merge_branches(git_dir, "main", "feature", git_exec.MergeCommit, "")
  let assert True = sha != ""

  cleanup_fixture_repo(git_dir)
}

pub fn squash_merge_fixture_test() {
  let git_dir = setup_fixture_repo()
  let assert Ok(sha) =
    git_exec.merge_branches(
      git_dir,
      "main",
      "feature",
      git_exec.Squash,
      "Squash feature into main",
    )
  let assert True = sha != ""
  cleanup_fixture_repo(git_dir)
}
