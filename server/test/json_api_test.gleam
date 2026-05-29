import app/database.{KeyRow, MergeRequestCommentRow, MergeRequestRow, OrgRow, RepoRow, UserRow}
import app/git_exec.{
  BlobContent, CommitEntry, DiffFile, MergeCheck, TreeEntry, Blob, Submodule, Symlink,
  Tree,
}
import app/json_api
import gleam/json
import gleam/option
import gleam/string
import gleeunit

pub fn main() {
  gleeunit.main()
}

fn json_string(j: json.Json) -> String {
  json.to_string(j)
}

pub fn access_json_test() {
  let s = json_api.access_json(True, False) |> json_string
  let assert True = string.contains(s, "\"read\":true")
  let assert True = string.contains(s, "\"write\":false")
}

pub fn ref_update_json_test() {
  let s = json_api.ref_update_json(False, "denied") |> json_string
  let assert True = string.contains(s, "\"allowed\":false")
  let assert True = string.contains(s, "denied")
}

pub fn org_json_test() {
  let org =
    OrgRow(
      id: "org-1",
      slug: "acme",
      name: "Acme",
      role: option.Some("owner"),
    )
  let s = json_api.org_json(org) |> json_string
  let assert True = string.contains(s, "\"slug\":\"acme\"")
  let assert True = string.contains(s, "\"role\":\"owner\"")
}

pub fn repo_json_test() {
  let repo =
    RepoRow(
      id: "r1",
      name: "demo",
      description: option.Some("A demo repo"),
      disk_path: "acme/demo.git",
      org_slug: "acme",
    )
  let s = json_api.repo_json(repo, "git@host:acme/demo.git") |> json_string
  let assert True = string.contains(s, "\"clone_url\":\"git@host:acme/demo.git\"")
  let assert True = string.contains(s, "A demo repo")
}

pub fn key_json_test() {
  let key =
    KeyRow(
      id: "k1",
      title: "laptop",
      public_key: "ssh-ed25519 AAAA",
      fingerprint: "sha256:AAAA",
    )
  let s = json_api.key_json(key) |> json_string
  let assert True = string.contains(s, "\"fingerprint\":\"sha256:AAAA\"")
}

pub fn me_json_test() {
  let user =
    UserRow(
      id: "u1",
      display_name: option.Some("Ada"),
      email: option.Some("ada@example.com"),
    )
  let orgs = [
    OrgRow(id: "o1", slug: "acme", name: "Acme", role: option.None),
  ]
  let s = json_api.me_json(user, orgs) |> json_string
  let assert True = string.contains(s, "\"display_name\":\"Ada\"")
  let assert True = string.contains(s, "\"organizations\"")
}

pub fn branches_json_test() {
  let s = json_api.branches_json(["main", "dev"]) |> json_string
  let assert True = string.contains(s, "\"main\"")
  let assert True = string.contains(s, "\"dev\"")
}

pub fn tree_json_test() {
  let entries = [
    TreeEntry(name: "src", entry_type: Tree, sha: "abc", last_commit_sha: "", last_commit_message: ""),
    TreeEntry(name: "README.md", entry_type: Blob, sha: "def", last_commit_sha: "", last_commit_message: ""),
  ]
  let s = json_api.tree_json("main", "", entries) |> json_string
  let assert True = string.contains(s, "\"type\":\"tree\"")
  let assert True = string.contains(s, "\"type\":\"blob\"")
}

pub fn blob_json_test() {
  let blob =
    BlobContent(content: "hi", size: 2, encoding: "text", binary: False)
  let s = json_api.blob_json("main", "hi.txt", blob) |> json_string
  let assert True = string.contains(s, "\"binary\":false")
  let assert True = string.contains(s, "\"size\":2")
}

pub fn merge_request_json_test() {
  let mr =
    MergeRequestRow(
      id: "mr-1",
      number: 1,
      title: "Add feature",
      description: option.None,
      author_user_id: "u1",
      source_branch: "feature",
      target_branch: "main",
      state: "open",
      merge_commit_sha: option.None,
      merged_by_user_id: option.None,
      merged_at: option.None,
      closed_at: option.None,
      created_at: "2026-01-01",
      updated_at: "2026-01-01",
    )
  let s = json_api.merge_request_json(mr) |> json_string
  let assert True = string.contains(s, "\"number\":1")
  let assert True = string.contains(s, "\"source_branch\":\"feature\"")
}

pub fn merge_check_json_test() {
  let check = MergeCheck(mergeable: False, message: "conflicts")
  let s = json_api.merge_check_json(check) |> json_string
  let assert True = string.contains(s, "\"mergeable\":false")
  let assert True = string.contains(s, "conflicts")
}

pub fn commits_json_test() {
  let commits = [
    CommitEntry(
      sha: "abc",
      subject: "fix",
      author: "Ada",
      committed_at: "1",
    ),
  ]
  let s = json_api.commits_json(commits) |> json_string
  let assert True = string.contains(s, "\"sha\":\"abc\"")
}

pub fn diff_files_json_test() {
  let files = [
    DiffFile(
      path: "a.txt",
      old_path: option.None,
      status: "modified",
      additions: 1,
      deletions: 0,
    ),
  ]
  let s = json_api.diff_files_json(files) |> json_string
  let assert True = string.contains(s, "\"additions\":1")
}

pub fn protected_branches_json_test() {
  let s = json_api.protected_branches_json(["main"]) |> json_string
  let assert True = string.contains(s, "\"branches\":[\"main\"]")
}

pub fn orgs_json_test() {
  let orgs = [
    OrgRow(id: "o1", slug: "a", name: "A", role: option.Some("owner")),
    OrgRow(id: "o2", slug: "b", name: "B", role: option.None),
  ]
  let s = json_api.orgs_json(orgs) |> json_string
  let assert True = string.contains(s, "\"slug\":\"a\"")
  let assert True = string.contains(s, "null")
}

pub fn repos_json_test() {
  let repo =
    RepoRow(
      id: "r1",
      name: "demo",
      description: option.None,
      disk_path: "acme/demo.git",
      org_slug: "acme",
    )
  let s = json_api.repos_json([#(repo, "git@h:acme/demo.git")]) |> json_string
  let assert True = string.contains(s, "\"clone_url\":\"git@h:acme/demo.git\"")
}

pub fn keys_json_test() {
  let key =
    KeyRow(
      id: "k1",
      title: "laptop",
      public_key: "ssh-ed25519 AAAA",
      fingerprint: "sha256:AAAA",
    )
  let s = json_api.keys_json([key]) |> json_string
  let assert True = string.contains(s, "\"title\":\"laptop\"")
}

pub fn repo_detail_json_test() {
  let repo =
    RepoRow(
      id: "r1",
      name: "demo",
      description: option.Some("desc"),
      disk_path: "acme/demo.git",
      org_slug: "acme",
    )
  let s =
    json_api.repo_detail_json(repo, "git@h:acme/demo.git", option.Some("main"))
    |> json_string
  let assert True = string.contains(s, "\"default_branch\":\"main\"")
  let assert True = string.contains(s, "\"description\":\"desc\"")
}

pub fn repo_detail_json_no_branch_test() {
  let repo =
    RepoRow(
      id: "r1",
      name: "demo",
      description: option.None,
      disk_path: "acme/demo.git",
      org_slug: "acme",
    )
  let s =
    json_api.repo_detail_json(repo, "git@h:acme/demo.git", option.None)
    |> json_string
  let assert True = string.contains(s, "\"default_branch\":null")
}

pub fn readme_json_test() {
  let s = json_api.readme_json("main", "README.md", "# Hi") |> json_string
  let assert True = string.contains(s, "\"path\":\"README.md\"")
  let assert True = string.contains(s, "# Hi")
}

pub fn tree_entry_types_json_test() {
  let entries = [
    TreeEntry(name: "sub", entry_type: Submodule, sha: "1", last_commit_sha: "", last_commit_message: ""),
    TreeEntry(name: "link", entry_type: Symlink, sha: "2", last_commit_sha: "", last_commit_message: ""),
  ]
  let s = json_api.tree_json("main", "lib", entries) |> json_string
  let assert True = string.contains(s, "\"type\":\"submodule\"")
  let assert True = string.contains(s, "\"type\":\"symlink\"")
}

pub fn merge_request_json_with_timestamps_test() {
  let mr =
    MergeRequestRow(
      id: "mr-1",
      number: 2,
      title: "Ship it",
      description: option.Some("Details"),
      author_user_id: "u1",
      source_branch: "feature",
      target_branch: "main",
      state: "merged",
      merge_commit_sha: option.Some("sha"),
      merged_by_user_id: option.Some("u2"),
      merged_at: option.Some("2026-01-02"),
      closed_at: option.Some("2026-01-03"),
      created_at: "2026-01-01",
      updated_at: "2026-01-04",
    )
  let s = json_api.merge_request_json(mr) |> json_string
  let assert True = string.contains(s, "\"merged_at\":\"2026-01-02\"")
  let assert True = string.contains(s, "\"description\":\"Details\"")
}

pub fn merge_requests_json_test() {
  let mr =
    MergeRequestRow(
      id: "mr-1",
      number: 1,
      title: "T",
      description: option.None,
      author_user_id: "u1",
      source_branch: "a",
      target_branch: "main",
      state: "open",
      merge_commit_sha: option.None,
      merged_by_user_id: option.None,
      merged_at: option.None,
      closed_at: option.None,
      created_at: "1",
      updated_at: "1",
    )
  let s = json_api.merge_requests_json([mr]) |> json_string
  let assert True = string.contains(s, "\"merge_requests\"")
}

pub fn merge_request_comment_json_test() {
  let comment =
    MergeRequestCommentRow(
      id: "c1",
      author_user_id: "u1",
      author_name: "Ada",
      body: "LGTM",
      file_path: option.Some("a.gleam"),
      line: option.Some(1),
      created_at: "1",
      updated_at: "1",
    )
  let s = json_api.merge_request_comment_json(comment) |> json_string
  let assert True = string.contains(s, "\"line\":1")
}

pub fn merge_request_comments_json_test() {
  let comment =
    MergeRequestCommentRow(
      id: "c1",
      author_user_id: "u1",
      author_name: "",
      body: "ok",
      file_path: option.None,
      line: option.None,
      created_at: "1",
      updated_at: "1",
    )
  let s = json_api.merge_request_comments_json([comment]) |> json_string
  let assert True = string.contains(s, "\"comments\"")
}

pub fn diff_patch_json_test() {
  let s = json_api.diff_patch_json("a.txt", "@@ -0,0 +1 @@") |> json_string
  let assert True = string.contains(s, "\"patch\"")
}

pub fn me_json_null_fields_test() {
  let user = UserRow(id: "u1", display_name: option.None, email: option.None)
  let s = json_api.me_json(user, []) |> json_string
  let assert True = string.contains(s, "\"display_name\":null")
  let assert True = string.contains(s, "\"email\":null")
}

pub fn access_json_write_test() {
  let s = json_api.access_json(False, True) |> json_string
  let assert True = string.contains(s, "\"write\":true")
}
