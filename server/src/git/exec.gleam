import git/path as git_path
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/string
import simplifile
import wisp
import youid/uuid

pub type GitError {
  GitCommandFailed(String)
  NotFound
  NotATree
  InvalidPath
  InvalidBranch
  BlobTooLarge
  NoBranches
  MergeConflict(String)
  AlreadyUpToDate
}

pub type TreeEntry {
  TreeEntry(
    name: String,
    entry_type: TreeEntryType,
    sha: String,
    last_commit_sha: String,
    last_commit_message: String,
  )
}

pub type TreeEntryType {
  Tree
  Blob
  Submodule
  Symlink
}

pub type BlobContent {
  BlobContent(content: String, size: Int, encoding: String, binary: Bool)
}

pub type ConflictFileSide {
  ConflictFileSide(
    content: String,
    encoding: String,
    binary: Bool,
    missing: Bool,
  )
}

pub type ConflictFile {
  ConflictFile(
    path: String,
    target_branch: String,
    source_branch: String,
    target: ConflictFileSide,
    source: ConflictFileSide,
  )
}

pub type Readme {
  Readme(path: String, content: String)
}

pub type RepoTemplate {
  RepoTemplate(name: String, path: String, content: String)
}

pub type CommitEntry {
  CommitEntry(
    sha: String,
    subject: String,
    author: String,
    committed_at: String,
  )
}

pub type TagInfo {
  TagInfo(
    name: String,
    target_commit_sha: String,
    created_at: String,
    message: String,
  )
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
  MergeCheck(
    mergeable: Bool,
    message: String,
    behind_target: Bool,
    conflict_paths: List(String),
    approval_count: Int,
    required_approvals: Int,
  )
}

pub type MergeMethod {
  MergeCommit
  Squash
  Rebase
}

pub type GitCommitAuthor {
  GitCommitAuthor(name: String, email: String)
}

@external(erlang, "git_merge_ffi", "merge_branches")
fn merge_branches_ffi(
  git_dir: String,
  target_branch: String,
  source_branch: String,
  method: String,
  commit_message: String,
  author_name: String,
  author_email: String,
) -> #(String, String)

const max_blob_bytes = 1_000_000

const max_diff_bytes = 1_000_000

const readme_candidates = [
  "README.md", "README.MD", "readme.md", "Readme.md", "README",
]

const mr_template_file_candidates = [
  ".gleamhub/merge_request_template.md",
  ".gleamhub/pull_request_template.md",
  ".gleamhub/PULL_REQUEST_TEMPLATE.md",
]

const mr_template_dir_candidates = [
  ".gleamhub/merge_request_template",
  ".gleamhub/PULL_REQUEST_TEMPLATE",
  ".gleamhub/pull_request_template",
]

const issue_template_file_candidates = [
  ".gleamhub/issue_template.md",
  ".gleamhub/ISSUE_TEMPLATE.md",
]

const issue_template_dir_candidates = [".gleamhub/issue_template"]

@external(erlang, "git_exec_ffi", "init_bare")
fn init_bare_ffi(path: String) -> String

@external(erlang, "git_exec_ffi", "install_hook")
fn install_hook_ffi(src: String, dest: String) -> String

@external(erlang, "git_exec_ffi", "is_ancestor")
fn is_ancestor_ffi(git_dir: String, oldrev: String, newrev: String) -> String

@external(erlang, "git_exec_ffi", "run_git")
fn run_git_ffi(git_dir: String, args: List(String)) -> #(Int, String, String)

const zero_sha = "0000000000000000000000000000000000000000"

pub fn zero_sha_value() -> String {
  zero_sha
}

pub fn repo_path(root: String, disk_path: String) -> Result(String, GitError) {
  case git_path.validate_disk_path(disk_path) {
    Error(_) -> Error(InvalidPath)
    Ok(safe) -> Ok(root <> "/" <> safe)
  }
}

fn hooks_directory() -> String {
  case simplifile.read("./priv/hooks/pre-receive") {
    Ok(_) -> "./priv/hooks"
    Error(_) -> {
      let assert Ok(priv) = wisp.priv_directory("server")
      priv <> "/hooks"
    }
  }
}

pub fn install_repo_hooks(
  root: String,
  disk_path: String,
) -> Result(Nil, String) {
  case repo_path(root, disk_path) {
    Error(_) -> Error("invalid repository path")
    Ok(git_dir) -> {
      let hooks = hooks_directory()
      let pre_src = hooks <> "/pre-receive"
      let pre_dest = git_dir <> "/hooks/pre-receive"
      let post_src = hooks <> "/post-receive"
      let post_dest = git_dir <> "/hooks/post-receive"
      case install_hook_ffi(pre_src, pre_dest) {
        "ok" ->
          case install_hook_ffi(post_src, post_dest) {
            "ok" -> Ok(Nil)
            _ -> Error("failed to install post-receive hook")
          }
        _ -> Error("failed to install pre-receive hook")
      }
    }
  }
}

pub fn init_bare_repo(root: String, disk_path: String) -> Result(Nil, String) {
  case repo_path(root, disk_path) {
    Error(_) -> Error("invalid repository path")
    Ok(path) ->
      case simplifile.create_directory_all(path) {
        Error(e) -> Error("mkdir failed: " <> simplifile.describe_error(e))
        Ok(_) -> {
          case init_bare_ffi(path) {
            "ok" -> install_repo_hooks(root, disk_path)
            _ -> Error("git init failed")
          }
        }
      }
  }
}

pub fn is_ancestor(
  git_dir: String,
  oldrev: String,
  newrev: String,
) -> Result(Bool, GitError) {
  case is_ancestor_ffi(git_dir, oldrev, newrev) {
    "true" -> Ok(True)
    "false" -> Ok(False)
    "error" -> Error(GitCommandFailed("git merge-base --is-ancestor failed"))
    _ -> Error(GitCommandFailed("git merge-base --is-ancestor failed"))
  }
}

pub fn is_zero_sha(sha: String) -> Bool {
  string.trim(sha) == zero_sha
}

pub fn remove_bare_repo(
  root: String,
  disk_path: String,
) -> Result(Nil, String) {
  case repo_path(root, disk_path) {
    Error(_) -> Error("invalid repository path")
    Ok(path) ->
      simplifile.delete(path)
      |> result.map_error(fn(e) {
        "remove repo failed: " <> simplifile.describe_error(e)
      })
  }
}

pub fn rename_bare_repo(
  root: String,
  from_disk_path: String,
  to_disk_path: String,
) -> Result(Nil, String) {
  case repo_path(root, from_disk_path), repo_path(root, to_disk_path) {
    Error(_), _ | _, Error(_) -> Error("invalid repository path")
    Ok(from_path), Ok(to_path) ->
      simplifile.rename(from_path, to_path)
      |> result.map_error(fn(e) {
        "rename repo failed: " <> simplifile.describe_error(e)
      })
  }
}

fn run_git(git_dir: String, args: List(String)) -> Result(String, GitError) {
  let #(code, stdout, stderr) = run_git_ffi(git_dir, args)
  case code {
    0 -> Ok(stdout)
    _ -> Error(git_error_from_output(stdout, stderr))
  }
}

fn git_error_from_output(stdout: String, stderr: String) -> GitError {
  let msg = case stderr {
    "" -> string.trim(stdout)
    _ -> string.trim(stderr)
  }
  case
    string.contains(msg, "Not a valid object name")
    || string.contains(msg, "Not a valid object")
    || string.contains(msg, "does not exist")
    || string.contains(msg, "exists on disk, but not in")
    || string.contains(msg, "bad revision")
    || string.contains(msg, "unknown revision")
    || string.contains(msg, "not a valid ref")
  {
    True -> NotFound
    False ->
      case string.contains(msg, "Not a tree object") {
        True -> NotATree
        False -> GitCommandFailed(msg)
      }
  }
}

pub fn merge_conflict_message(paths: List(String)) -> String {
  case paths {
    [] -> "Merge conflicts"
    [path] -> "Merge conflict in " <> path
    _ -> "Merge conflicts in " <> int.to_string(list.length(paths)) <> " files"
  }
}

fn parse_merge_tree_conflict_paths(out: String) -> List(String) {
  case string.split(out, on: "\u{0}") {
    [_tree_oid, ..paths] ->
      paths
      |> list.map(string.trim)
      |> list.filter(fn(part) { part != "" })
    _ -> []
  }
}

const tag_ref_format =
  "--format=%(refname:short)\t%(creatordate:iso-strict)\t%(contents:subject)\t%(objecttype)\t%(objectname)"

pub fn list_tags(git_dir: String) -> Result(List(TagInfo), GitError) {
  use out <- result.try(
    run_git(git_dir, [
      "for-each-ref",
      "refs/tags",
      "--sort=-creatordate",
      tag_ref_format,
    ]),
  )
  let lines =
    out
    |> string.split(on: "\n")
    |> list.filter(fn(line) { line != "" })
  list.fold(lines, Ok([]), fn(acc, line) {
    case acc {
      Error(e) -> Error(e)
      Ok(tags) ->
        case string.split(line, on: "\t") {
          [name, created_at, message, objecttype, objectname] -> {
            use sha <- result.try(resolve_tag_commit_for_ref(
              git_dir,
              name,
              objecttype,
              objectname,
            ))
            Ok([
              TagInfo(
                name:,
                target_commit_sha: sha,
                created_at:,
                message:,
              ),
              ..tags
            ])
          }
          _ -> Ok(tags)
        }
    }
  })
  |> result.map(list.reverse)
}

pub fn resolve_tag_name(tag: String) -> Result(String, GitError) {
  case git_path.normalize_branch(tag) {
    Error(_) -> Error(InvalidPath)
    Ok(name) -> Ok(name)
  }
}

pub fn tag_exists(git_dir: String, tag: String) -> Result(String, GitError) {
  use name <- result.try(resolve_tag_name(tag))
  case run_git(git_dir, ["show-ref", "--verify", "refs/tags/" <> name]) {
    Ok(_) -> Ok(name)
    Error(NotFound) -> Error(NotFound)
    Error(e) -> Error(e)
  }
}

pub fn resolve_tag_commit(git_dir: String, tag: String) -> Result(String, GitError) {
  use name <- result.try(tag_exists(git_dir, tag))
  use sha <- result.try(run_git(git_dir, ["rev-list", "-n", "1", name]))
  Ok(string.trim(sha))
}

fn resolve_tag_commit_for_ref(
  git_dir: String,
  name: String,
  objecttype: String,
  objectname: String,
) -> Result(String, GitError) {
  case objecttype {
    "commit" -> Ok(objectname)
    _ -> resolve_tag_commit(git_dir, name)
  }
}

pub fn list_branches(git_dir: String) -> Result(List(String), GitError) {
  use out <- result.try(
    run_git(git_dir, [
      "for-each-ref",
      "refs/heads",
      "--format=%(refname:short)",
    ]),
  )
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

pub fn set_default_branch(
  git_dir: String,
  branch: String,
) -> Result(String, GitError) {
  use name <- result.try(branch_exists(git_dir, branch))
  use _ <- result.try(
    run_git(git_dir, [
      "symbolic-ref",
      "HEAD",
      "refs/heads/" <> name,
    ]),
  )
  Ok(name)
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
      let entries = parse_ls_tree(out)
      Ok(attach_last_commits(git_dir, ref, norm, entries))
    }
  }
}

fn attach_last_commits(
  git_dir: String,
  ref: String,
  path: String,
  entries: List(TreeEntry),
) -> List(TreeEntry) {
  case entries {
    [] -> []
    _ -> {
      let log_path = case path {
        "" -> "."
        _ -> path
      }
      case
        run_git(git_dir, [
          "log",
          "--format=COMMIT:%H%x09%s",
          "--name-only",
          "-n",
          "500",
          ref,
          "--",
          log_path,
        ])
      {
        Ok(out) -> assign_last_commits(path, entries, parse_log_name_only(out))
        Error(_) -> entries
      }
    }
  }
}

fn entry_full_path(base: String, name: String) -> String {
  case base {
    "" -> name
    _ -> base <> "/" <> name
  }
}

fn assign_last_commits(
  base_path: String,
  entries: List(TreeEntry),
  commits: List(#(CommitEntry, List(String))),
) -> List(TreeEntry) {
  let paths = list.map(entries, fn(e) { entry_full_path(base_path, e.name) })
  let assignments: List(#(String, CommitEntry)) =
    list.fold(commits, [], fn(acc: List(#(String, CommitEntry)), commit_files) {
      let #(commit, files) = commit_files
      list.fold(files, acc, fn(inner, file) {
        list.fold(
          paths,
          inner,
          fn(inner2: List(#(String, CommitEntry)), entry_path) {
            case
              list.find(inner2, fn(pair: #(String, CommitEntry)) {
                pair.0 == entry_path
              })
            {
              Ok(_) -> inner2
              Error(_) ->
                case path_matches_entry(file, entry_path) {
                  True -> [#(entry_path, commit), ..inner2]
                  False -> inner2
                }
            }
          },
        )
      })
    })
  list.map(entries, fn(entry) {
    let full = entry_full_path(base_path, entry.name)
    case
      list.find(assignments, fn(pair: #(String, CommitEntry)) { pair.0 == full })
    {
      Ok(#(_, commit)) ->
        TreeEntry(
          ..entry,
          last_commit_sha: commit.sha,
          last_commit_message: commit.subject,
        )
      Error(_) -> entry
    }
  })
}

fn path_matches_entry(changed_file: String, entry_path: String) -> Bool {
  changed_file == entry_path
  || string.starts_with(changed_file, entry_path <> "/")
}

fn parse_log_name_only(output: String) -> List(#(CommitEntry, List(String))) {
  output
  |> string.split(on: "\n")
  |> list.fold([], fn(acc, line) { parse_log_name_only_line(line, acc) })
}

fn parse_log_name_only_line(
  line: String,
  acc: List(#(CommitEntry, List(String))),
) -> List(#(CommitEntry, List(String))) {
  case string.trim(line) {
    "" -> acc
    trimmed ->
      case string.starts_with(trimmed, "COMMIT:") {
        True -> {
          let rest = string.drop_start(trimmed, 7)
          case string.split(rest, on: "\t") {
            [sha, subject] -> [
              #(CommitEntry(sha:, subject:, author: "", committed_at: ""), []),
              ..acc
            ]
            _ -> acc
          }
        }
        False ->
          case acc {
            [#(commit, files), ..rest] -> [
              #(commit, [trimmed, ..files]),
              ..rest
            ]
            [] -> acc
          }
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
          Ok(TreeEntry(
            name:,
            entry_type:,
            sha:,
            last_commit_sha: "",
            last_commit_message: "",
          ))
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
  case read_blob_bytes(git_dir, ref, path) {
    Error(e) -> Error(e)
    Ok(#(content, size)) -> {
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

/// Raw blob bytes for download / raw file routes (includes binary content).
pub fn read_blob_bytes(
  git_dir: String,
  ref: String,
  path: String,
) -> Result(#(String, Int), GitError) {
  case git_path.normalize(path) {
    Error(_) -> Error(InvalidPath)
    Ok(norm) -> {
      let spec = git_path.tree_ref_path(ref, norm)
      use size_str <- result.try(run_git(git_dir, ["cat-file", "-s", spec]))
      let size = parse_int(string.trim(size_str))
      case size > max_blob_bytes {
        True -> Error(BlobTooLarge)
        False -> {
          use content <- result.try(
            run_git(git_dir, ["cat-file", "blob", spec]),
          )
          Ok(#(content, size))
        }
      }
    }
  }
}

/// Zip archive of the tree at `ref`, written to a temp file (caller deletes).
pub fn archive_zip_to_file(
  git_dir: String,
  ref: String,
) -> Result(String, GitError) {
  archive_to_file(git_dir, ref, ArchiveZip)
}

pub type ArchiveFormat {
  ArchiveZip
  ArchiveTarGz
}

/// Source archive at `ref`, written to a temp file (caller deletes).
pub fn archive_to_file(
  git_dir: String,
  ref: String,
  format: ArchiveFormat,
) -> Result(String, GitError) {
  use resolved <- result.try(resolve_archive_ref(git_dir, ref))
  let #(suffix, git_format) = case format {
    ArchiveZip -> #(".zip", "zip")
    ArchiveTarGz -> #(".tar.gz", "tar.gz")
  }
  let path =
    "/tmp/gleamhub_archive_"
    <> string.replace(uuid.to_string(uuid.v7()), each: "-", with: "")
    <> suffix
  case run_git(git_dir, ["archive", "--format=" <> git_format, "-o", path, resolved]) {
    Ok(_) -> Ok(path)
    Error(e) -> Error(e)
  }
}

fn resolve_archive_ref(
  git_dir: String,
  ref: String,
) -> Result(String, GitError) {
  case ref {
    "" -> default_branch(git_dir)
    _ ->
      case git_path.normalize_ref(ref) {
        Ok(validated) -> Ok(validated)
        Error(_) -> Error(InvalidPath)
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

/// Merge request templates from `.gleamhub/` (single file or a directory of `.md` files).
pub fn find_merge_request_templates(
  git_dir: String,
  ref: String,
) -> Result(List(RepoTemplate), GitError) {
  find_repo_templates(
    git_dir,
    ref,
    mr_template_file_candidates,
    mr_template_dir_candidates,
  )
}

/// Issue templates from `.gleamhub/` (single file or a directory of `.md` files).
pub fn find_issue_templates(
  git_dir: String,
  ref: String,
) -> Result(List(RepoTemplate), GitError) {
  find_repo_templates(
    git_dir,
    ref,
    issue_template_file_candidates,
    issue_template_dir_candidates,
  )
}

fn find_repo_templates(
  git_dir: String,
  ref: String,
  file_candidates: List(String),
  dir_candidates: List(String),
) -> Result(List(RepoTemplate), GitError) {
  case find_template_file_loop(git_dir, ref, file_candidates) {
    Ok(option.Some(template)) -> Ok([template])
    Ok(option.None) -> find_templates_in_dirs(git_dir, ref, dir_candidates)
    Error(e) -> Error(e)
  }
}

pub fn resolve_branch_name(branch: String) -> Result(String, GitError) {
  case git_path.normalize_branch(branch) {
    Error(_) -> Error(InvalidBranch)
    Ok(name) -> Ok(name)
  }
}

pub fn branch_exists(
  git_dir: String,
  branch: String,
) -> Result(String, GitError) {
  use name <- result.try(resolve_branch_name(branch))
  case run_git(git_dir, ["show-ref", "--verify", "refs/heads/" <> name]) {
    Ok(_) -> Ok(name)
    Error(NotFound) -> Error(NotFound)
    Error(e) -> Error(e)
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

pub const max_commits_list = 100

pub fn commit_count(git_dir: String, ref: String) -> Result(Int, GitError) {
  use out <- result.try(run_git(git_dir, ["rev-list", "--count", ref]))
  case int.parse(string.trim(out)) {
    Ok(n) -> Ok(n)
    Error(_) -> Error(GitCommandFailed("Invalid commit count"))
  }
}

pub fn show_commit(
  git_dir: String,
  sha: String,
) -> Result(CommitEntry, GitError) {
  case git_path.normalize_sha(sha) {
    Error(_) -> Error(InvalidPath)
    Ok(normalized) -> {
      use out <- result.try(
        run_git(git_dir, [
          "log",
          "-1",
          "--format=%H%x09%s%x09%an%x09%at",
          normalized,
        ]),
      )
      case parse_commits(out) {
        [commit, ..] -> Ok(commit)
        [] -> Error(NotFound)
      }
    }
  }
}

pub fn commits_on_ref(
  git_dir: String,
  ref: String,
) -> Result(List(CommitEntry), GitError) {
  use out <- result.try(
    run_git(git_dir, [
      "log",
      "--format=%H%x09%s%x09%an%x09%at",
      "-n",
      int.to_string(max_commits_list),
      ref,
    ]),
  )
  Ok(parse_commits(out))
}

pub fn commits_between(
  git_dir: String,
  target_branch: String,
  source_branch: String,
) -> Result(List(CommitEntry), GitError) {
  use base <- result.try(merge_base(git_dir, target_branch, source_branch))
  use head <- result.try(branch_ref(git_dir, source_branch))
  use out <- result.try(
    run_git(git_dir, [
      "log",
      "--format=%H%x09%s%x09%an%x09%at",
      base <> ".." <> head,
    ]),
  )
  Ok(parse_commits(out))
}

pub fn diff_summary(
  git_dir: String,
  target_branch: String,
  source_branch: String,
) -> Result(List(DiffFile), GitError) {
  use base <- result.try(merge_base(git_dir, target_branch, source_branch))
  use head <- result.try(branch_ref(git_dir, source_branch))
  use out <- result.try(
    run_git(git_dir, ["diff", "--numstat", base <> "..." <> head]),
  )
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
      use patch <- result.try(
        run_git(git_dir, [
          "diff",
          "-U3",
          base <> "..." <> head,
          "--",
          norm,
        ]),
      )
      case string.length(patch) > max_diff_bytes {
        True -> Error(BlobTooLarge)
        False -> Ok(patch)
      }
    }
  }
}

pub fn conflict_file_content(
  git_dir: String,
  target_branch: String,
  source_branch: String,
  path: String,
) -> Result(ConflictFile, GitError) {
  case git_path.normalize(path) {
    Error(_) -> Error(InvalidPath)
    Ok(norm) -> {
      use target_name <- result.try(branch_exists(git_dir, target_branch))
      use source_name <- result.try(branch_exists(git_dir, source_branch))
      use target <- result.try(read_blob_side(git_dir, target_name, norm))
      use source <- result.try(read_blob_side(git_dir, source_name, norm))
      Ok(ConflictFile(
        path: norm,
        target_branch: target_name,
        source_branch: source_name,
        target:,
        source:,
      ))
    }
  }
}

fn read_blob_side(
  git_dir: String,
  branch: String,
  path: String,
) -> Result(ConflictFileSide, GitError) {
  case read_blob(git_dir, branch, path) {
    Ok(blob) ->
      Ok(ConflictFileSide(
        content: blob.content,
        encoding: blob.encoding,
        binary: blob.binary,
        missing: False,
      ))
    Error(NotFound) ->
      Ok(ConflictFileSide(
        content: "",
        encoding: "text",
        binary: False,
        missing: True,
      ))
    Error(e) -> Error(e)
  }
}

pub fn source_behind_target(
  git_dir: String,
  target_branch: String,
  source_branch: String,
) -> Result(Bool, GitError) {
  use target <- result.try(branch_ref(git_dir, target_branch))
  use source <- result.try(branch_ref(git_dir, source_branch))
  source_behind_target_refs(git_dir, target, source)
}

fn source_behind_target_refs(
  git_dir: String,
  target_sha: String,
  source_sha: String,
) -> Result(Bool, GitError) {
  case is_ancestor(git_dir, target_sha, source_sha) {
    Ok(True) -> Ok(False)
    Ok(False) -> Ok(True)
    Error(e) -> Error(e)
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
  use behind_target <- result.try(source_behind_target_refs(
    git_dir,
    target,
    source,
  ))
  let #(code, stdout, stderr) =
    run_git_ffi(git_dir, [
      "merge-tree",
      "--write-tree",
      "--name-only",
      "-z",
      "--no-messages",
      "--merge-base=" <> base,
      target,
      source,
    ])
  case code {
    0 ->
      Ok(
        MergeCheck(
          mergeable: True,
          message: "",
          behind_target:,
          conflict_paths: [],
          approval_count: 0,
          required_approvals: 0,
        ),
      )
    1 -> {
      let paths = parse_merge_tree_conflict_paths(stdout)
      Ok(MergeCheck(
        mergeable: False,
        message: merge_conflict_message(paths),
        behind_target:,
        conflict_paths: paths,
        approval_count: 0,
        required_approvals: 0,
      ))
    }
    _ -> Error(git_error_from_output(stdout, stderr))
  }
}

pub fn update_source_branch(
  git_dir: String,
  target_branch: String,
  source_branch: String,
  author: GitCommitAuthor,
) -> Result(String, GitError) {
  use behind <- result.try(source_behind_target(
    git_dir,
    target_branch,
    source_branch,
  ))
  case behind {
    False -> Error(AlreadyUpToDate)
    True -> {
      let message =
        "Merge branch '" <> target_branch <> "' into " <> source_branch
      merge_branches(
        git_dir,
        source_branch,
        target_branch,
        MergeCommit,
        message,
        author,
      )
    }
  }
}

fn parent_refs(
  git_dir: String,
  sha: String,
) -> Result(#(String, option.Option(String)), GitError) {
  use p1 <- result.try(run_git(git_dir, ["rev-parse", sha <> "^1"]))
  let p2 = case run_git(git_dir, ["rev-parse", sha <> "^2"]) {
    Ok(out) -> option.Some(string.trim(out))
    Error(_) -> option.None
  }
  Ok(#(string.trim(p1), p2))
}

fn commits_at_merge(
  git_dir: String,
  merge_commit_sha: String,
) -> Result(List(CommitEntry), GitError) {
  use parents <- result.try(parent_refs(git_dir, merge_commit_sha))
  let #(base, source_tip) = parents
  let range = case source_tip {
    option.Some(head) -> base <> ".." <> head
    option.None -> merge_commit_sha <> "^1.." <> merge_commit_sha
  }
  use out <- result.try(
    run_git(git_dir, [
      "log",
      "--format=%H%x09%s%x09%an%x09%at",
      range,
    ]),
  )
  Ok(parse_commits(out))
}

fn diff_summary_at_merge(
  git_dir: String,
  merge_commit_sha: String,
) -> Result(List(DiffFile), GitError) {
  use parents <- result.try(parent_refs(git_dir, merge_commit_sha))
  let #(base, source_tip) = parents
  let range = case source_tip {
    option.Some(head) -> base <> "..." <> head
    option.None -> merge_commit_sha <> "^1..." <> merge_commit_sha
  }
  use out <- result.try(run_git(git_dir, ["diff", "--numstat", range]))
  Ok(parse_numstat(out))
}

fn diff_patch_at_merge(
  git_dir: String,
  merge_commit_sha: String,
  path: String,
) -> Result(String, GitError) {
  case git_path.normalize(path) {
    Error(_) -> Error(InvalidPath)
    Ok(norm) -> {
      use parents <- result.try(parent_refs(git_dir, merge_commit_sha))
      let #(base, source_tip) = parents
      let range = case source_tip {
        option.Some(head) -> base <> "..." <> head
        option.None -> merge_commit_sha <> "^1..." <> merge_commit_sha
      }
      use patch <- result.try(
        run_git(git_dir, [
          "diff",
          "-U3",
          range,
          "--",
          norm,
        ]),
      )
      case string.length(patch) > max_diff_bytes {
        True -> Error(BlobTooLarge)
        False -> Ok(patch)
      }
    }
  }
}

pub fn merge_check_for_request(
  git_dir: String,
  target_branch: String,
  source_branch: String,
  state: String,
) -> Result(MergeCheck, GitError) {
  case state {
    "open" ->
      case can_merge(git_dir, target_branch, source_branch) {
        Ok(check) -> Ok(check)
        Error(NotFound) ->
          Ok(
            MergeCheck(
              mergeable: False,
              message: "Source branch not found",
              behind_target: False,
              conflict_paths: [],
              approval_count: 0,
              required_approvals: 0,
            ),
          )
        Error(e) -> Error(e)
      }
    "merged" ->
      Ok(
        MergeCheck(
          mergeable: False,
          message: "Already merged",
          behind_target: False,
          conflict_paths: [],
          approval_count: 0,
          required_approvals: 0,
        ),
      )
    "closed" ->
      Ok(
        MergeCheck(
          mergeable: False,
          message: "Closed",
          behind_target: False,
          conflict_paths: [],
          approval_count: 0,
          required_approvals: 0,
        ),
      )
    _ ->
      Ok(
        MergeCheck(
          mergeable: False,
          message: "",
          behind_target: False,
          conflict_paths: [],
          approval_count: 0,
          required_approvals: 0,
        ),
      )
  }
}

fn merge_request_snapshot_sha(
  state: String,
  merge_commit_sha: option.Option(String),
) -> option.Option(String) {
  case state, merge_commit_sha {
    "merged", option.Some(sha) -> option.Some(sha)
    _, _ -> option.None
  }
}

pub fn commits_for_merge_request(
  git_dir: String,
  target_branch: String,
  source_branch: String,
  state: String,
  merge_commit_sha: option.Option(String),
) -> Result(List(CommitEntry), GitError) {
  case merge_request_snapshot_sha(state, merge_commit_sha) {
    option.Some(sha) -> commits_at_merge(git_dir, sha)
    option.None ->
      case commits_between(git_dir, target_branch, source_branch) {
        Ok(commits) -> Ok(commits)
        Error(_) ->
          case merge_commit_sha {
            option.Some(sha) -> commits_at_merge(git_dir, sha)
            option.None -> Ok([])
          }
      }
  }
}

pub fn diff_summary_for_merge_request(
  git_dir: String,
  target_branch: String,
  source_branch: String,
  state: String,
  merge_commit_sha: option.Option(String),
) -> Result(List(DiffFile), GitError) {
  case merge_request_snapshot_sha(state, merge_commit_sha) {
    option.Some(sha) -> diff_summary_at_merge(git_dir, sha)
    option.None ->
      case diff_summary(git_dir, target_branch, source_branch) {
        Ok(files) -> Ok(files)
        Error(_) ->
          case merge_commit_sha {
            option.Some(sha) -> diff_summary_at_merge(git_dir, sha)
            option.None -> Ok([])
          }
      }
  }
}

pub fn diff_patch_for_merge_request(
  git_dir: String,
  target_branch: String,
  source_branch: String,
  state: String,
  merge_commit_sha: option.Option(String),
  path: String,
) -> Result(String, GitError) {
  case merge_request_snapshot_sha(state, merge_commit_sha) {
    option.Some(sha) -> diff_patch_at_merge(git_dir, sha, path)
    option.None ->
      case diff_patch(git_dir, target_branch, source_branch, path) {
        Ok(patch) -> Ok(patch)
        Error(_) ->
          case merge_commit_sha {
            option.Some(sha) -> diff_patch_at_merge(git_dir, sha, path)
            option.None -> Ok("")
          }
      }
  }
}

pub fn delete_branch(git_dir: String, branch: String) -> Result(Nil, GitError) {
  case git_path.normalize_branch(branch) {
    Error(_) -> Error(InvalidBranch)
    Ok(name) ->
      case run_git(git_dir, ["update-ref", "-d", "refs/heads/" <> name]) {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error(e)
      }
  }
}

pub fn merge_branches(
  git_dir: String,
  target_branch: String,
  source_branch: String,
  method: MergeMethod,
  commit_message: String,
  author: GitCommitAuthor,
) -> Result(String, GitError) {
  use _ <- result.try(branch_ref(git_dir, target_branch))
  use _ <- result.try(branch_ref(git_dir, source_branch))
  use check <- result.try(can_merge(git_dir, target_branch, source_branch))
  case check.mergeable {
    False -> Error(MergeConflict(check.message))
    True -> {
      let method_str = case method {
        MergeCommit -> "merge"
        Squash -> "squash"
        Rebase -> "rebase"
      }
      let #(tag, detail) =
        merge_branches_ffi(
          git_dir,
          target_branch,
          source_branch,
          method_str,
          commit_message,
          author.name,
          author.email,
        )
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

fn find_template_file_loop(
  git_dir: String,
  ref: String,
  candidates: List(String),
) -> Result(option.Option(RepoTemplate), GitError) {
  case candidates {
    [] -> Ok(option.None)
    [path, ..rest] -> {
      case read_text_blob(git_dir, ref, path) {
        Ok(content) ->
          Ok(
            option.Some(RepoTemplate(
              name: template_name_from_path(path),
              path:,
              content:,
            )),
          )
        Error(NotFound) -> find_template_file_loop(git_dir, ref, rest)
        Error(e) -> Error(e)
      }
    }
  }
}

fn find_templates_in_dirs(
  git_dir: String,
  ref: String,
  dirs: List(String),
) -> Result(List(RepoTemplate), GitError) {
  case dirs {
    [] -> Ok([])
    [dir, ..rest] -> {
      case list_tree(git_dir, ref, dir) {
        Ok(entries) -> {
          let md_files =
            entries
            |> list.filter(fn(e) {
              e.entry_type == Blob && string.ends_with(e.name, ".md")
            })
            |> list.sort(by: fn(a, b) { string.compare(a.name, b.name) })
          case md_files {
            [] -> find_templates_in_dirs(git_dir, ref, rest)
            files -> read_template_entries(git_dir, ref, dir, files)
          }
        }
        Error(NotFound) -> find_templates_in_dirs(git_dir, ref, rest)
        Error(e) -> Error(e)
      }
    }
  }
}

fn read_template_entries(
  git_dir: String,
  ref: String,
  dir: String,
  files: List(TreeEntry),
) -> Result(List(RepoTemplate), GitError) {
  list.fold(files, Ok([]), fn(acc, entry) {
    case acc {
      Error(e) -> Error(e)
      Ok(templates) -> {
        let path = case dir {
          "" -> entry.name
          _ -> dir <> "/" <> entry.name
        }
        case read_text_blob(git_dir, ref, path) {
          Ok(content) ->
            Ok([
              RepoTemplate(
                name: template_name_from_path(entry.name),
                path:,
                content:,
              ),
              ..templates
            ])
          Error(NotFound) | Error(BlobTooLarge) -> Ok(templates)
          Error(e) -> Error(e)
        }
      }
    }
  })
  |> result.map(list.reverse)
}

fn read_text_blob(
  git_dir: String,
  ref: String,
  path: String,
) -> Result(String, GitError) {
  case read_blob(git_dir, ref, path) {
    Ok(blob) ->
      case blob.binary {
        True -> Error(NotFound)
        False -> Ok(blob.content)
      }
    Error(e) -> Error(e)
  }
}

fn template_name_from_path(path: String) -> String {
  let filename = case list.last(string.split(path, on: "/")) {
    Ok(name) -> name
    Error(_) -> path
  }
  case string.ends_with(filename, ".md") {
    True -> string.drop_end(filename, 3)
    False -> filename
  }
}
