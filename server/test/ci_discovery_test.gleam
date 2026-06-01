import app/ci_discovery
import db_test_support
import gleam/option
import gleeunit
import route_test_support

pub fn main() {
  db_test_support.require_db()
  gleeunit.main()
}

pub fn discover_module_in_fixture_test() {
  db_test_support.with_db(fn(_db) {
    let root = route_test_support.repos_root()
    let work = route_test_support.clone_git_fixture(root, "acme/demo.git")
    let git_dir = root <> "/acme/demo.git"
    let sha = route_test_support.rev_parse(git_dir, "feature")
    let assert option.Some("ci") = ci_discovery.discover_module(git_dir, sha)
    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn discover_module_missing_on_main_test() {
  db_test_support.with_db(fn(_db) {
    let root = route_test_support.repos_root()
    let work = route_test_support.clone_git_fixture(root, "acme/demo.git")
    let git_dir = root <> "/acme/demo.git"
    let sha = route_test_support.rev_parse(git_dir, "main")
    let assert option.None = ci_discovery.discover_module(git_dir, sha)
    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}
