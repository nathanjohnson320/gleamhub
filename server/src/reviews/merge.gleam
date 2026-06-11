import git/exec as git_exec
import gleam/int

pub fn combine_merge_check(
  check: git_exec.MergeCheck,
  approval_count: Int,
  required_approvals: Int,
) -> git_exec.MergeCheck {
  case check.mergeable, required_approvals {
    False, _ ->
      git_exec.MergeCheck(
        ..check,
        approval_count:,
        required_approvals:,
      )
    True, 0 ->
      git_exec.MergeCheck(
        ..check,
        approval_count:,
        required_approvals:,
      )
    True, required if approval_count >= required ->
      git_exec.MergeCheck(
        ..check,
        approval_count:,
        required_approvals:,
      )
    True, required -> {
      let remaining = required - approval_count
      git_exec.MergeCheck(
        mergeable: False,
        message: "Needs "
          <> int.to_string(remaining)
          <> " more approval"
          <> case remaining {
            1 -> ""
            _ -> "s"
          },
        behind_target: check.behind_target,
        conflict_paths: check.conflict_paths,
        approval_count:,
        required_approvals:,
      )
    }
  }
}

pub fn apply_changes_requested_block(
  check: git_exec.MergeCheck,
  changes_requested_count: Int,
) -> git_exec.MergeCheck {
  case check.mergeable, changes_requested_count {
    False, _ -> check
    True, 0 -> check
    True, _ ->
      git_exec.MergeCheck(
        mergeable: False,
        message: "Changes requested by a reviewer",
        behind_target: check.behind_target,
        conflict_paths: check.conflict_paths,
        approval_count: check.approval_count,
        required_approvals: check.required_approvals,
      )
  }
}
