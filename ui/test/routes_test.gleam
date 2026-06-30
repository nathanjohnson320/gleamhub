import gleam/option
import gleam/uri
import gleeunit
import routes.{
  Blob, Changes, Checks, Conversation, Home, MrDetail, MrList, MrNew,
  MyNotifications, MyOverview, OrgRepos, ProjectDetail, ProjectList, ProjectNew,
  ReleaseDetail, ReleaseList, ReleaseNew,
  RepoMissingOrg, RepoSettings, RepoView, Tree, from_pathname, from_uri,
  mr_changes_line_path, mr_detail_path, mr_detail_tab_path, mr_list_path,
  mr_new_path, project_detail_path, project_list_path, project_new_path,
  release_detail_path, release_list_path, release_new_path,
  repo_blob_api_suffix, repo_blob_line_path, repo_blob_line_range_path,
  repo_blob_path, repo_raw_browser_path,
}

pub fn main() {
  gleeunit.main()
}

pub fn repo_home_pathname_test() {
  assert from_pathname("/orgs/stord/repos/orders-service")
    == RepoView(
      Home,
      "stord",
      "orders-service",
      "",
      "",
      line_range: option.None,
    )
}

pub fn missing_org_slug_pathname_test() {
  assert from_pathname("/orgs/repos/orders-service")
    == RepoMissingOrg("orders-service")
}

pub fn org_repos_pathname_test() {
  assert from_pathname("/orgs/stord") == OrgRepos("stord")
}

pub fn my_space_pathname_test() {
  assert from_pathname("/me") == routes.MySpace(MyOverview)
  assert from_pathname("/me/notifications") == routes.MySpace(MyNotifications)
}

pub fn account_pathname_test() {
  assert from_pathname("/settings/account") == routes.Account
}

pub fn tree_pathname_test() {
  assert from_pathname("/orgs/stord/repos/app/tree/main/src")
    == RepoView(Tree, "stord", "app", "main", "src", line_range: option.None)
}

pub fn raw_browser_path_test() {
  assert repo_raw_browser_path(
      "stord",
      "app",
      "main",
      "src/main.gleam",
      "jwt-here",
    )
    == "/raw/orgs/stord/repos/app/main/src/main.gleam?token=jwt-here"
}

pub fn blob_pathname_test() {
  assert from_pathname("/orgs/stord/repos/app/blob/main/README.md")
    == RepoView(
      Blob,
      "stord",
      "app",
      "main",
      "README.md",
      line_range: option.None,
    )
}

pub fn blob_line_query_test() {
  let assert Ok(uri) =
    uri.parse("/orgs/stord/repos/app/blob/main/a.gleam?line=42")
  assert from_uri(uri)
    == RepoView(
      Blob,
      "stord",
      "app",
      "main",
      "a.gleam",
      line_range: option.Some(#(42, 42)),
    )
}

pub fn repo_settings_pathname_test() {
  assert from_pathname("/orgs/stord/repos/banana/settings")
    == RepoSettings("stord", "banana")
}

pub fn mr_list_pathname_test() {
  assert from_pathname("/orgs/acme/repos/demo/merge-requests")
    == MrList("acme", "demo")
}

pub fn mr_new_pathname_test() {
  assert from_pathname("/orgs/acme/repos/demo/merge-requests/new")
    == MrNew("acme", "demo")
}

pub fn mr_detail_pathname_test() {
  assert from_pathname("/orgs/acme/repos/demo/merge-requests/12")
    == MrDetail("acme", "demo", 12, Conversation)
}

pub fn mr_checks_tab_pathname_test() {
  assert from_pathname("/orgs/acme/repos/demo/merge-requests/12/checks")
    == MrDetail("acme", "demo", 12, Checks)
}

pub fn mr_changes_line_pathname_test() {
  assert from_pathname(
      "/orgs/acme/repos/demo/merge-requests/3/changes/README.md?line=29",
    )
    == MrDetail(
      "acme",
      "demo",
      3,
      Changes(option.Some("README.md"), option.Some(29)),
    )
}

pub fn mr_path_helpers_test() {
  assert mr_list_path("acme", "demo") == "/orgs/acme/repos/demo/merge-requests"
  assert mr_new_path("acme", "demo")
    == "/orgs/acme/repos/demo/merge-requests/new"
  assert mr_detail_path("acme", "demo", 3)
    == "/orgs/acme/repos/demo/merge-requests/3"
  assert mr_detail_tab_path("acme", "demo", 3, Checks)
    == "/orgs/acme/repos/demo/merge-requests/3/checks"
}

pub fn blob_line_path_test() {
  assert repo_blob_line_path("stord", "app", "main", "src/lib.gleam", 42)
    == "/orgs/stord/repos/app/blob/main/src/lib.gleam?line=42#L42"
  assert repo_blob_line_range_path(
      "stord",
      "app",
      "main",
      "src/lib.gleam",
      10,
      25,
    )
    == "/orgs/stord/repos/app/blob/main/src/lib.gleam?line=10&end=25#L10-L25"
}

pub fn blob_slashy_branch_paths_test() {
  assert repo_blob_path("acme", "demo", "test/merge-conflict", "README.md")
    == "/orgs/acme/repos/demo/blob/test%2Fmerge-conflict/README.md"
  assert repo_blob_api_suffix("test/merge-conflict", "README.md")
    == "/blob/README.md?ref=test%2Fmerge-conflict"
  assert from_pathname(
      "/orgs/acme/repos/demo/blob/test%2Fmerge-conflict/README.md",
    )
    == RepoView(
      Blob,
      "acme",
      "demo",
      "test/merge-conflict",
      "README.md",
      line_range: option.None,
    )
}

pub fn release_pathname_test() {
  assert from_pathname("/orgs/acme/repos/demo/releases") == ReleaseList(
    "acme",
    "demo",
  )
  assert from_pathname("/orgs/acme/repos/demo/releases/new") == ReleaseNew(
    "acme",
    "demo",
  )
  assert from_pathname("/orgs/acme/repos/demo/releases/v1.0.0")
    == ReleaseDetail("acme", "demo", "v1.0.0")
  assert release_list_path("acme", "demo") == "/orgs/acme/repos/demo/releases"
  assert release_new_path("acme", "demo")
    == "/orgs/acme/repos/demo/releases/new"
  assert release_detail_path("acme", "demo", "v1.0.0")
    == "/orgs/acme/repos/demo/releases/v1.0.0"
}

pub fn mr_diff_line_path_test() {
  assert mr_changes_line_path("acme", "demo", 3, "README.md", 29)
    == "/orgs/acme/repos/demo/merge-requests/3/changes/README.md?line=29#diff-line-README.md-L29"
  assert mr_changes_line_path("acme", "demo", 3, "src/foo bar.gleam", 10)
    == "/orgs/acme/repos/demo/merge-requests/3/changes/src/foo%20bar.gleam?line=10#diff-line-src%2Ffoo%20bar.gleam-L10"
}

pub fn project_pathname_test() {
  assert from_pathname("/orgs/acme/projects") == ProjectList("acme")
  assert from_pathname("/orgs/acme/projects/new") == ProjectNew("acme")
  assert from_pathname("/orgs/acme/projects/3") == ProjectDetail("acme", 3)
  assert project_list_path("acme") == "/orgs/acme/projects"
  assert project_new_path("acme") == "/orgs/acme/projects/new"
  assert project_detail_path("acme", 3) == "/orgs/acme/projects/3"
}
