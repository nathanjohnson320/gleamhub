import app/git_exec
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn init_bare_repo_test() {
  let assert Ok(_) = git_exec.init_bare_repo("./data/repos", "test-org/test-repo.git")
}
