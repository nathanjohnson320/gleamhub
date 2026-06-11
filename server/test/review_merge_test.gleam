import git/exec as git_exec
import gleam/string
import gleeunit
import reviews/merge as review_merge

pub fn main() {
  gleeunit.main()
}

fn mergeable_git_check() -> git_exec.MergeCheck {
  git_exec.MergeCheck(
    mergeable: True,
    message: "",
    behind_target: False,
    conflict_paths: [],
    approval_count: 0,
    required_approvals: 0,
  )
}

pub fn no_required_approvals_allows_merge_test() {
  let check = review_merge.combine_merge_check(mergeable_git_check(), 0, 0)
  let assert True = check.mergeable
}

pub fn enough_approvals_allows_merge_test() {
  let check = review_merge.combine_merge_check(mergeable_git_check(), 2, 2)
  let assert True = check.mergeable
  let assert 2 = check.approval_count
}

pub fn missing_approvals_blocks_merge_test() {
  let check = review_merge.combine_merge_check(mergeable_git_check(), 0, 1)
  let assert False = check.mergeable
  let assert True = string.contains(check.message, "1 more approval")
}

pub fn changes_requested_blocks_merge_test() {
  let check =
    review_merge.apply_changes_requested_block(mergeable_git_check(), 1)
  let assert False = check.mergeable
  let assert True = string.contains(check.message, "Changes requested")
}
