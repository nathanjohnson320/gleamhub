import app/ref_update_policy
import gleeunit

pub fn main() {
  gleeunit.main()
}

const zero = "0000000000000000000000000000000000000000"

pub fn protected_delete_denied_test() {
  let assert Error("cannot delete a protected branch") =
    ref_update_policy.check_protected_branch("main", "abc", zero, False)
}

pub fn protected_new_branch_denied_test() {
  let assert Error("cannot push directly to protected branch main; open a merge request") =
    ref_update_policy.check_protected_branch("main", zero, "abc", False)
}

pub fn protected_non_ff_denied_test() {
  let assert Error("non-fast-forward push to protected branch denied") =
    ref_update_policy.check_protected_branch("main", "abc", "def", False)
}

pub fn protected_ff_direct_push_denied_test() {
  let assert Error("cannot push directly to protected branch main; open a merge request") =
    ref_update_policy.check_protected_branch("main", "abc", "def", True)
}
