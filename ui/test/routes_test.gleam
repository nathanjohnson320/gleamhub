import gleeunit
import routes.{
  Blob, Home, NotFound, OrgRepos, RepoMissingOrg, RepoView, Tree,
  from_pathname,
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
