import app/git_path
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/string
import simplifile

pub type GitError {
  GitCommandFailed(String)
  NotFound
  NotATree
  InvalidPath
  InvalidBranch
  BlobTooLarge
  NoBranches
  MergeConflict(String)
}

pub type TreeEntry {
  TreeEntry(name: String, entry_type: TreeEntryType, sha: String)
}

pub type TreeEntryType {
  Tree
  Blob
  Submodule
  Symlink
}

pub type BlobContent {
  BlobContent(
    content: String,
    size: Int,
    encoding: String,
    binary: Bool,
  )
}

pub type Readme {
  Readme(path: String, content: String)
}

pub type CommitEntry {
  CommitEntry(sha: String, subject: String, author: String, committed_at: String)
}

pub type DiffFile {
  DiffFile(
    path: String,
    old_path: option.Option(String),
    status: String,
    additions: Int,
    deletions: Int,
  )
}

pub type MergeCheck {
  MergeCheck(mergeable: Bool, message: String)
}

@external(erlang, "git_merge_ffi", "merge_branches")
fn merge_branches_ffi(
  git_dir: String,
  target_branch: String,
  source_branch: String,
) -> #(String, String)

const max_blob_bytes = 1_000_000

const max_diff_bytes = 1_000_000

const readme_candidates = [
  "README.md", "README.MD", "readme.md", "Readme.md", "README",
]

@external(erlang, "git_exec_ffi", "init_bare")
fn init_bare_ffi(path: String) -> Nil

@external(erlang, "git_exec_ffi", "run_git")
fn run_git_ffi(git_dir: String, args: List(String)) -> #(Int, String, String)

pub fn repo_path(root: String, disk_path: String) -> String {
  root <> "/" <> disk_path
}

pub fn init_bare_repo(root: String, disk_path: String) -> Result(Nil, String) {
  let path = repo_path(root, disk_path)
  case simplifile.create_directory_all(path) {
    Error(e) -> Error("mkdir failed: " <> simplifile.describe_error(e))
    Ok(_) -> {
      init_bare_ffi(path)
      Ok(Nil)
    }
  }
}

pub fn remove_bare_repo(root: String, disk_path: String) -> Result(Nil, String) {
  simplifile.delete(repo_path(root, disk_path))
  |> result.map_error(fn(e) { "remove repo failed: " <> simplifile.describe_error(e) })
}

fn run_git(git_dir: String, args: List(String)) -> Result(String, GitError) {
  let #(code, stdout, stderr) = run_git_ffi(git_dir, args)
  case code {
    0 -> Ok(stdout)
    _ -> {
      let msg = case stderr {
        "" -> string.trim(stdout)
        _ -> string.trim(stderr)
      }
      case string.contains(msg, "Not a valid object name")
        || string.contains(msg, "Not a valid object")
        || string.contains(msg, "does not exist")
        || string.contains(msg, "exists on disk, but not in")
        || string.contains(msg, "bad revision")
      {
        True -> Error(NotFound)
        False ->
          case string.contains(msg, "Not a tree object") {
            True -> Error(NotATree)
            False -> Error(GitCommandFailed(msg))
          }
      }
    }
  }
}

pub fn list_branches(git_dir: String) -> Result(List(String), GitError) {
  use out <- result.try(run_git(git_dir, [
    "for-each-ref",
    "refs/heads",
    "--format=%(refname:short)",
  ]))
  let branches =
    out
    |> string.split(on: "\n")
    |> list.map(string.trim)
    |> list.filter(fn(b) { b != "" })
    |> list.sort(string.compare)
  Ok(branches)
}

pub fn default_branch(git_dir: String) -> Result(String, GitError) {
  case run_git(git_dir, ["symbolic-ref", "--short", "HEAD"]) {
    Ok(ref) -> Ok(string.trim(ref))
    Error(_) ->
      case list_branches(git_dir) {
        Ok([]) -> Error(NoBranches)
        Ok(branches) -> pick_default_branch(branches)
        Error(e) -> Error(e)
      }
  }
}

fn pick_default_branch(branches: List(String)) -> Result(String, GitError) {
  case list.contains(branches, "main") {
    True -> Ok("main")
    False ->
      case list.contains(branches, "master") {
        True -> Ok("master")
        False ->
          case branches {
            [first, ..] -> Ok(first)
            [] -> Error(NoBranches)
          }
      }
  }
}

pub fn list_tree(
  git_dir: String,
  ref: String,
  path: String,
) -> Result(List(TreeEntry), GitError) {
  case git_path.normalize(path) {
    Error(_) -> Error(InvalidPath)
    Ok(norm) -> {
      let tree_path = git_path.tree_ref_path(ref, norm)
      use out <- result.try(run_git(git_dir, ["ls-tree", tree_path]))
      Ok(parse_ls_tree(out))
    }
  }
}

fn parse_ls_tree(output: String) -> List(TreeEntry) {
  output
  |> string.split(on: "\n")
  |> list.filter(fn(line) { line != "" })
  |> list.filter_map(parse_ls_tree_line)
  |> list.sort(by: fn(a, b) {
    case a.entry_type, b.entry_type {
      Tree, Blob -> order.Lt
      Blob, Tree -> order.Gt
      _, _ -> string.compare(a.name, b.name)
    }
  })
}

fn parse_ls_tree_line(line: String) -> Result(TreeEntry, Nil) {
  case string.split(line, on: "\t") {
    [meta, name] -> {
      case string.split(meta, on: " ") {
        [_, type_str, sha] -> {
          let entry_type = case type_str {
            "tree" -> Tree
            "blob" -> Blob
            "commit" -> Submodule
            "link" -> Symlink
            _ -> Blob
          }
          Ok(TreeEntry(name:, entry_type:, sha:))
        }
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

pub fn read_blob(
  git_dir: String,
  ref: String,
  path: String,
) -> Result(BlobContent, GitError) {
  case git_path.normalize(path) {
    Error(_) -> Error(InvalidPath)
    Ok(norm) -> {
      let spec = git_path.tree_ref_path(ref, norm)
      use size_str <- result.try(run_git(git_dir, ["cat-file", "-s", spec]))
      let size = parse_int(string.trim(size_str))
      case size > max_blob_bytes {
        True -> Error(BlobTooLarge)
        False -> {
          use content <- result.try(run_git(git_dir, ["cat-file", "blob", spec]))
          let binary = is_binary_blob(content, size)
          Ok(BlobContent(
            content: case binary {
              True -> ""
              False -> content
            },
            size:,
            encoding: case binary {
              True -> "binary"
              False -> "text"
            },
            binary:,
          ))
        }
      }
    }
  }
}

fn is_binary_blob(content: String, size: Int) -> Bool {
  is_binary_content(content) || { size > 0 && content == "" }
}

fn parse_int(s: String) -> Int {
  case int.parse(s) {
    Ok(n) -> n
    Error(_) -> 0
  }
}

fn is_binary_content(content: String) -> Bool {
  string.contains(content, "\u{0000}")
}

pub fn find_readme(
  git_dir: String,
  ref: String,
) -> Result(option.Option(Readme), GitError) {
  find_readme_loop(git_dir, ref, readme_candidates)
}

pub fn branch_exists(git_dir: String, branch: String) -> Result(Nil, GitError) {
  case git_path.normalize_branch(branch) {
    Error(_) -> Error(InvalidBranch)
    Ok(name) ->
      case run_git(git_dir, ["show-ref", "--verify", "refs/heads/" <> name]) {
        Ok(_) -> Ok(Nil)
        Error(NotFound) -> Error(NotFound)
        Error(e) -> Error(e)
      }
  }
}

pub fn merge_base(
  git_dir: String,
  target_branch: String,
  source_branch: String,
) -> Result(String, GitError) {
  use target <- result.try(branch_ref(git_dir, target_branch))
  use source <- result.try(branch_ref(git_dir, source_branch))
  use base <- result.try(run_git(git_dir, ["merge-base", target, source]))
  Ok(string.trim(base))
}

pub fn commits_between(
  git_dir: String,
  target_branch: String,
  source_branch: String,
) -> Result(List(CommitEntry), GitError) {
  use base <- result.try(merge_base(git_dir, target_branch, source_branch))
  use head <- result.try(branch_ref(git_dir, source_branch))
  use out <- result.try(run_git(git_dir, [
    "log",
    "--format=%H%x09%s%x09%an%x09%at",
    base <> ".." <> head,
  ]))
  Ok(parse_commits(out))
}

pub fn diff_summary(
  git_dir: String,
  target_branch: String,
  source_branch: String,
) -> Result(List(DiffFile), GitError) {
  use base <- result.try(merge_base(git_dir, target_branch, source_branch))
  use head <- result.try(branch_ref(git_dir, source_branch))
  use out <- result.try(run_git(git_dir, ["diff", "--numstat", base <> "..." <> head]))
  Ok(parse_numstat(out))
}

pub fn diff_patch(
  git_dir: String,
  target_branch: String,
  source_branch: String,
  path: String,
) -> Result(String, GitError) {
  case git_path.normalize(path) {
    Error(_) -> Error(InvalidPath)
    Ok(norm) -> {
      use base <- result.try(merge_base(git_dir, target_branch, source_branch))
      use head <- result.try(branch_ref(git_dir, source_branch))
      use patch <- result.try(run_git(git_dir, [
        "diff",
        "-U3",
        base <> "..." <> head,
        "--",
        norm,
      ]))
      case string.length(patch) > max_diff_bytes {
        True -> Error(BlobTooLarge)
        False -> Ok(patch)
      }
    }
  }
}

pub fn can_merge(
  git_dir: String,
  target_branch: String,
  source_branch: String,
) -> Result(MergeCheck, GitError) {
  use base <- result.try(merge_base(git_dir, target_branch, source_branch))
  use target <- result.try(branch_ref(git_dir, target_branch))
  use source <- result.try(branch_ref(git_dir, source_branch))
  use out <- result.try(run_git(git_dir, ["merge-tree", base, target, source]))
  case string.contains(out, "CONFLICT") {
    True -> Ok(MergeCheck(mergeable: False, message: "Merge conflicts"))
    False -> Ok(MergeCheck(mergeable: True, message: ""))
  }
}

pub fn merge_branches(
  git_dir: String,
  target_branch: String,
  source_branch: String,
) -> Result(String, GitError) {
  use _ <- result.try(branch_ref(git_dir, target_branch))
  use _ <- result.try(branch_ref(git_dir, source_branch))
  use check <- result.try(can_merge(git_dir, target_branch, source_branch))
  case check.mergeable {
    False -> Error(MergeConflict(check.message))
    True -> {
      let #(tag, detail) =
        merge_branches_ffi(git_dir, target_branch, source_branch)
      case tag {
        "ok" -> Ok(detail)
        "conflict" -> Error(MergeConflict(detail))
        _ -> Error(GitCommandFailed(detail))
      }
    }
  }
}

fn branch_ref(git_dir: String, branch: String) -> Result(String, GitError) {
  case git_path.normalize_branch(branch) {
    Error(_) -> Error(InvalidBranch)
    Ok(name) ->
      case run_git(git_dir, ["rev-parse", "refs/heads/" <> name]) {
        Ok(sha) -> Ok(string.trim(sha))
        Error(e) -> Error(e)
      }
  }
}

fn parse_commits(output: String) -> List(CommitEntry) {
  output
  |> string.split(on: "\n")
  |> list.filter(fn(line) { line != "" })
  |> list.filter_map(parse_commit_line)
}

fn parse_commit_line(line: String) -> Result(CommitEntry, Nil) {
  case string.split(line, on: "\t") {
    [sha, subject, author, at] ->
      Ok(CommitEntry(sha:, subject:, author:, committed_at: at))
    _ -> Error(Nil)
  }
}

fn parse_numstat(output: String) -> List(DiffFile) {
  output
  |> string.split(on: "\n")
  |> list.filter(fn(line) { line != "" })
  |> list.filter_map(parse_numstat_line)
}

fn parse_numstat_line(line: String) -> Result(DiffFile, Nil) {
  case string.split(line, on: "\t") {
    [add_str, del_str, path] -> {
      let status = case add_str, del_str {
        "-", "-" -> "binary"
        _, _ -> "modified"
      }
      let additions = case add_str {
        "-" -> 0
        _ -> parse_int(add_str)
      }
      let deletions = case del_str {
        "-" -> 0
        _ -> parse_int(del_str)
      }
      Ok(DiffFile(path:, old_path: option.None, status:, additions:, deletions:))
    }
    _ -> Error(Nil)
  }
}

fn find_readme_loop(
  git_dir: String,
  ref: String,
  candidates: List(String),
) -> Result(option.Option(Readme), GitError) {
  case candidates {
    [] -> Ok(option.None)
    [candidate, ..rest] -> {
      let spec = git_path.tree_ref_path(ref, candidate)
      case run_git(git_dir, ["cat-file", "blob", spec]) {
        Ok(content) -> Ok(option.Some(Readme(path: candidate, content:)))
        Error(NotFound) -> find_readme_loop(git_dir, ref, rest)
        Error(e) -> Error(e)
      }
    }
  }
}
