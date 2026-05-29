import app/git_exec
import gleam/list
import gleam/option
import gleam/string
import gleeunit
import simplifile
import youid/uuid

pub fn main() {
  gleeunit.main()
}

@external(erlang, "git_exec_test_ffi", "setup_fixture_repo")
fn setup_fixture_repo() -> String

@external(erlang, "git_exec_test_ffi", "setup_conflict_fixture_repo")
fn setup_conflict_fixture_repo() -> String

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
      e.name == "README.md" && e.last_commit_message != ""
    })
  let assert True =
    list.any(entries, fn(e) { e.name == "src" && e.entry_type == git_exec.Tree })

  let assert Ok(sub) = git_exec.list_tree(git_dir, "main", "src")
  let assert True = list.any(sub, fn(e) { e.name == "main.gleam" })

  let assert Ok(blob) = git_exec.read_blob(git_dir, "main", "README.md")
  let assert False = blob.binary
  let assert True = string.contains(blob.content, "Gleamhub test")

  let assert Ok(changelog) = git_exec.read_blob(git_dir, "main", "CHANGELOG.md")
  let assert False = changelog.binary
  let assert True = string.contains(changelog.content, "Initial release")
  let assert True = string.contains(changelog.content, "__GLEAMHUB_EXIT:0")

  cleanup_fixture_repo(git_dir)
}

pub fn is_ancestor_test() {
  let git_dir = setup_fixture_repo()
  let assert Ok(main_sha) = git_exec.merge_base(git_dir, "main", "feature")
  let assert Ok(commits) = git_exec.commits_between(git_dir, "main", "feature")
  let assert [git_exec.CommitEntry(sha: feature_sha, ..), ..] = commits

  let assert Ok(True) = git_exec.is_ancestor(git_dir, main_sha, feature_sha)
  let assert Ok(False) = git_exec.is_ancestor(git_dir, feature_sha, main_sha)

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

  let assert Ok(total) = git_exec.commit_count(git_dir, "main")
  let assert True = total >= 1
  let assert Ok(main_commits) = git_exec.commits_on_ref(git_dir, "main")
  let assert True = list.length(main_commits) >= 1
  let assert [git_exec.CommitEntry(sha: main_head, ..), ..] = main_commits
  let assert Ok(head_commit) = git_exec.show_commit(git_dir, main_head)
  let assert True = head_commit.subject != ""

  let assert Ok(files) = git_exec.diff_summary(git_dir, "main", "feature")
  let assert True = list.any(files, fn(f) { f.path == "feature.txt" })

  let assert Ok(patch) =
    git_exec.diff_patch(git_dir, "main", "feature", "feature.txt")
  let assert True = string.contains(patch, "feature branch")

  let assert Ok(check) = git_exec.can_merge(git_dir, "main", "feature")
  let assert True = check.mergeable

  let assert Ok(sha) =
    git_exec.merge_branches(
      git_dir,
      "main",
      "feature",
      git_exec.MergeCommit,
      "",
    )
  let assert True = sha != ""

  cleanup_fixture_repo(git_dir)
}

pub fn merge_conflict_test() {
  let git_dir = setup_conflict_fixture_repo()
  let assert Error(git_exec.MergeConflict(_)) =
    git_exec.merge_branches(
      git_dir,
      "main",
      "feature",
      git_exec.MergeCommit,
      "",
    )
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

pub fn repo_path_test() {
  let assert Ok("/data/repos/acme/demo.git") =
    git_exec.repo_path("/data/repos", "acme/demo.git")
  let assert Error(git_exec.InvalidPath) =
    git_exec.repo_path("/data/repos", "../escape.git")
}

pub fn is_zero_sha_test() {
  let assert True =
    git_exec.is_zero_sha("0000000000000000000000000000000000000000")
  let assert True =
    git_exec.is_zero_sha("  0000000000000000000000000000000000000000  ")
  let assert False = git_exec.is_zero_sha("abc123")
}

pub fn git_invalid_path_test() {
  let git_dir = setup_fixture_repo()
  let assert Error(git_exec.InvalidPath) =
    git_exec.list_tree(git_dir, "main", "../escape")
  let assert Error(git_exec.InvalidPath) =
    git_exec.read_blob(git_dir, "main", "../escape")
  cleanup_fixture_repo(git_dir)
}

pub fn git_invalid_branch_test() {
  let git_dir = setup_fixture_repo()
  let assert Error(git_exec.InvalidBranch) =
    git_exec.branch_exists(git_dir, "../main")
  let assert Error(git_exec.InvalidBranch) =
    git_exec.merge_base(git_dir, "..", "feature")
  cleanup_fixture_repo(git_dir)
}

pub fn git_not_found_test() {
  let git_dir = setup_fixture_repo()
  let assert Error(git_exec.NotFound) =
    git_exec.read_blob(git_dir, "main", "does-not-exist.txt")
  let assert Error(_) = git_exec.branch_exists(git_dir, "no-such-branch")
  cleanup_fixture_repo(git_dir)
}

pub fn git_not_a_tree_test() {
  let git_dir = setup_fixture_repo()
  let assert Error(_) = git_exec.list_tree(git_dir, "main", "README.md")
  cleanup_fixture_repo(git_dir)
}

pub fn init_bare_repo_test() {
  let id = uuid.to_string(uuid.v7())
  let root = "/tmp/gleamhub_bare_" <> id
  let disk = "test-org/test-repo.git"
  let assert Ok(Nil) = git_exec.init_bare_repo(root, disk)
  let assert Ok(git_dir) = git_exec.repo_path(root, disk)
  let assert Ok(branches) = git_exec.list_branches(git_dir)
  let assert [] = branches
  let _ = git_exec.remove_bare_repo(root, disk)
  let _ = simplifile.delete(root)
}

pub fn install_repo_hooks_test() {
  let id = uuid.to_string(uuid.v7())
  let root = "/tmp/gleamhub_hooks_" <> id
  let disk = "test-org/hooked.git"
  let assert Ok(Nil) = git_exec.init_bare_repo(root, disk)
  let assert Ok(git_dir) = git_exec.repo_path(root, disk)
  let assert Ok(Nil) = git_exec.install_repo_hooks(root, disk)
  let hook_path = git_dir <> "/hooks/pre-receive"
  let assert Ok(True) = simplifile.is_file(hook_path)
  let _ = git_exec.remove_bare_repo(root, disk)
  let _ = simplifile.delete(root)
}

pub fn merge_twice_is_idempotent_test() {
  let git_dir = setup_fixture_repo()
  let assert Ok(first_sha) =
    git_exec.merge_branches(
      git_dir,
      "main",
      "feature",
      git_exec.MergeCommit,
      "",
    )
  let assert Ok(second_sha) =
    git_exec.merge_branches(
      git_dir,
      "main",
      "feature",
      git_exec.MergeCommit,
      "",
    )
  let assert True = first_sha == second_sha
  cleanup_fixture_repo(git_dir)
}

pub fn merged_request_with_deleted_source_branch_test() {
  let git_dir = setup_fixture_repo()
  let assert Ok(sha) =
    git_exec.merge_branches(
      git_dir,
      "main",
      "feature",
      git_exec.MergeCommit,
      "",
    )
  let assert Ok(Nil) = git_exec.delete_branch(git_dir, "feature")
  let assert Ok(check) =
    git_exec.merge_check_for_request(git_dir, "main", "feature", "merged")
  let assert False = check.mergeable
  let assert Ok(commits) =
    git_exec.commits_for_merge_request(
      git_dir,
      "main",
      "feature",
      "merged",
      option.Some(sha),
    )
  let assert True = commits != []
  let assert Ok(files) =
    git_exec.diff_summary_for_merge_request(
      git_dir,
      "main",
      "feature",
      "merged",
      option.Some(sha),
    )
  let assert True = files != []
  cleanup_fixture_repo(git_dir)
}

pub fn merged_request_snapshot_used_when_branch_still_exists_test() {
  let git_dir = setup_fixture_repo()
  let assert Ok(sha) =
    git_exec.merge_branches(
      git_dir,
      "main",
      "feature",
      git_exec.MergeCommit,
      "",
    )
  let assert Ok(Nil) = git_exec.branch_exists(git_dir, "feature")
  let assert Ok(commits) =
    git_exec.commits_for_merge_request(
      git_dir,
      "main",
      "feature",
      "merged",
      option.Some(sha),
    )
  let assert True = commits != []
  let assert Ok(files) =
    git_exec.diff_summary_for_merge_request(
      git_dir,
      "main",
      "feature",
      "merged",
      option.Some(sha),
    )
  let assert True = files != []
  cleanup_fixture_repo(git_dir)
}
