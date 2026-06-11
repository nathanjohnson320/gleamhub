import ci/merge as ci_merge
import database
import git/exec as git_exec
import gleeunit

pub fn main() {
  gleeunit.main()
}

fn sample_run(state: String, sha: String) -> database.PipelineRunRow {
  database.PipelineRunRow(
    id: "run-1",
    repository_id: "repo-1",
    merge_request_id: "mr-1",
    commit_sha: sha,
    module_path: "ci",
    entry_function: "ci",
    state:,
    trigger: "mr_open",
    log_text: "",
    started_at: option.None,
    finished_at: option.None,
    created_at: "2026-01-01T00:00:00Z",
  )
}

import gleam/option

pub fn skipped_pipeline_allows_merge_test() {
  let git =
    git_exec.MergeCheck(
      mergeable: True,
      message: "",
      behind_target: False,
      conflict_paths: [],
      approval_count: 0,
      required_approvals: 0,
    )
  let check =
    ci_merge.combine_merge_check(
      git,
      option.Some(sample_run("skipped", "abc")),
      "abc",
    )
  let assert True = check.mergeable
}

pub fn success_at_head_allows_merge_test() {
  let git =
    git_exec.MergeCheck(
      mergeable: True,
      message: "",
      behind_target: False,
      conflict_paths: [],
      approval_count: 0,
      required_approvals: 0,
    )
  let check =
    ci_merge.combine_merge_check(
      git,
      option.Some(sample_run("success", "abc")),
      "abc",
    )
  let assert True = check.mergeable
}

pub fn running_blocks_merge_test() {
  let git =
    git_exec.MergeCheck(
      mergeable: True,
      message: "",
      behind_target: False,
      conflict_paths: [],
      approval_count: 0,
      required_approvals: 0,
    )
  let check =
    ci_merge.combine_merge_check(
      git,
      option.Some(sample_run("running", "abc")),
      "abc",
    )
  let assert False = check.mergeable
  let assert True = string.contains(check.message, "running")
}

pub fn failure_blocks_merge_test() {
  let git =
    git_exec.MergeCheck(
      mergeable: True,
      message: "",
      behind_target: False,
      conflict_paths: [],
      approval_count: 0,
      required_approvals: 0,
    )
  let check =
    ci_merge.combine_merge_check(
      git,
      option.Some(sample_run("failure", "abc")),
      "abc",
    )
  let assert False = check.mergeable
}

pub fn git_conflict_overrides_pipeline_test() {
  let git =
    git_exec.MergeCheck(
      mergeable: False,
      message: "Merge conflicts",
      behind_target: False,
      conflict_paths: ["conflict.txt"],
      approval_count: 0,
      required_approvals: 0,
    )
  let check =
    ci_merge.combine_merge_check(
      git,
      option.Some(sample_run("success", "abc")),
      "abc",
    )
  let assert False = check.mergeable
  let assert True = string.contains(check.message, "conflicts")
}

import gleam/string
