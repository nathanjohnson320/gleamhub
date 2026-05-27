import gleeunit
import routes.{
  Blob, Home, OrgRepos, RepoMissingOrg, RepoView, Tree,
  from_pathname, repo_blob_line_path, repo_blob_line_range_path,
}

pub fn main() {
  gleeunit.main()
}

pub fn repo_home_pathname_test() {
  assert from_pathname("/orgs/stord/repos/orders-service")
    == RepoView(Home, "stord", "orders-service", "", "")
}

pub fn missing_org_slug_pathname_test() {
  assert from_pathname("/orgs/repos/orders-service")
    == RepoMissingOrg("orders-service")
}

pub fn org_repos_pathname_test() {
  assert from_pathname("/orgs/stord") == OrgRepos("stord")
}

pub fn tree_pathname_test() {
  assert from_pathname("/orgs/stord/repos/app/tree/main/src")
    == RepoView(Tree, "stord", "app", "main", "src")
}

pub fn blob_pathname_test() {
  assert from_pathname("/orgs/stord/repos/app/blob/main/README.md")
    == RepoView(Blob, "stord", "app", "main", "README.md")
}

pub fn blob_line_path_test() {
  assert
    repo_blob_line_path("stord", "app", "main", "src/lib.gleam", 42)
    == "/orgs/stord/repos/app/blob/main/src/lib.gleam#L42"
  assert
    repo_blob_line_range_path("stord", "app", "main", "src/lib.gleam", 10, 25)
    == "/orgs/stord/repos/app/blob/main/src/lib.gleam#L10-L25"
}
