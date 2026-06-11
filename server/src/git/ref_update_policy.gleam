import git/exec as git_exec

/// Rules for direct git push to refs/heads/* when a branch is protected.
pub fn check_protected_branch(
  branch_name: String,
  oldrev: String,
  newrev: String,
  fast_forward: Bool,
) -> Result(Nil, String) {
  case git_exec.is_zero_sha(newrev) {
    True -> Error("cannot delete a protected branch")
    False ->
      case git_exec.is_zero_sha(oldrev) {
        True ->
          Error(
            "cannot push directly to protected branch "
            <> branch_name
            <> "; open a merge request",
          )
        False ->
          case fast_forward {
            False -> Error("non-fast-forward push to protected branch denied")
            True ->
              Error(
                "cannot push directly to protected branch "
                <> branch_name
                <> "; open a merge request",
              )
          }
      }
  }
}
