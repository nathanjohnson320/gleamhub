import app/database.{
  type KeyRow, type MergeRequestCommentRow, type MergeRequestRow, type OrgRow,
  type RepoRow, type UserRow,
}
import app/git_exec.{
  type BlobContent, type CommitEntry, type DiffFile, type MergeCheck,
  type TreeEntry, type TreeEntryType, Blob, Submodule, Symlink, Tree,
}
import gleam/json
import gleam/option

pub fn org_json(org: OrgRow) -> json.Json {
  json.object([
    #("id", json.string(org.id)),
    #("slug", json.string(org.slug)),
    #("name", json.string(org.name)),
    #(
      "role",
      case org.role {
        option.Some(role) -> json.string(role)
        option.None -> json.null()
      },
    ),
  ])
}

pub fn orgs_json(orgs: List(OrgRow)) -> json.Json {
  json.array(orgs, of: org_json)
}

pub fn repo_json(repo: RepoRow, clone_url: String) -> json.Json {
  json.object([
    #("id", json.string(repo.id)),
    #("name", json.string(repo.name)),
    #("org_slug", json.string(repo.org_slug)),
    #("clone_url", json.string(clone_url)),
    #(
      "description",
      case repo.description {
        option.Some(d) -> json.string(d)
        option.None -> json.null()
      },
    ),
  ])
}

pub fn repos_json(repos: List(#(RepoRow, String))) -> json.Json {
  json.array(repos, of: fn(pair) {
    let #(repo, url) = pair
    repo_json(repo, url)
  })
}

pub fn key_json(key: KeyRow) -> json.Json {
  json.object([
    #("id", json.string(key.id)),
    #("title", json.string(key.title)),
    #("public_key", json.string(key.public_key)),
    #("fingerprint", json.string(key.fingerprint)),
  ])
}

pub fn keys_json(keys: List(KeyRow)) -> json.Json {
  json.array(keys, of: key_json)
}

pub fn me_json(user: UserRow, orgs: List(OrgRow)) -> json.Json {
  json.object([
    #("id", json.string(user.id)),
    #(
      "display_name",
      case user.display_name {
        option.Some(n) -> json.string(n)
        option.None -> json.null()
      },
    ),
    #(
      "email",
      case user.email {
        option.Some(e) -> json.string(e)
        option.None -> json.null()
      },
    ),
    #("organizations", orgs_json(orgs)),
  ])
}

pub fn access_json(read: Bool, write: Bool) -> json.Json {
  json.object([#("read", json.bool(read)), #("write", json.bool(write))])
}

pub fn repo_detail_json(
  repo: RepoRow,
  clone_url: String,
  default_branch: option.Option(String),
) -> json.Json {
  json.object([
    #("id", json.string(repo.id)),
    #("name", json.string(repo.name)),
    #("org_slug", json.string(repo.org_slug)),
    #("clone_url", json.string(clone_url)),
    #(
      "description",
      case repo.description {
        option.Some(d) -> json.string(d)
        option.None -> json.null()
      },
    ),
    #(
      "default_branch",
      case default_branch {
        option.Some(ref) -> json.string(ref)
        option.None -> json.null()
      },
    ),
  ])
}

pub fn branches_json(branches: List(String)) -> json.Json {
  json.object([#("branches", json.array(branches, of: json.string))])
}

pub fn readme_json(ref: String, path: String, content: String) -> json.Json {
  json.object([
    #("ref", json.string(ref)),
    #("path", json.string(path)),
    #("content", json.string(content)),
  ])
}

fn tree_entry_type_json(entry_type: TreeEntryType) -> json.Json {
  case entry_type {
    Tree -> json.string("tree")
    Blob -> json.string("blob")
    Submodule -> json.string("submodule")
    Symlink -> json.string("symlink")
  }
}

pub fn tree_json(ref: String, path: String, entries: List(TreeEntry)) -> json.Json {
  json.object([
    #("ref", json.string(ref)),
    #("path", json.string(path)),
    #(
      "entries",
      json.array(entries, of: fn(entry) {
        json.object([
          #("name", json.string(entry.name)),
          #("type", tree_entry_type_json(entry.entry_type)),
          #("sha", json.string(entry.sha)),
          #("last_commit_sha", json.string(entry.last_commit_sha)),
          #("last_commit_message", json.string(entry.last_commit_message)),
        ])
      }),
    ),
  ])
}

pub fn blob_json(ref: String, path: String, blob: BlobContent) -> json.Json {
  json.object([
    #("ref", json.string(ref)),
    #("path", json.string(path)),
    #("content", json.string(blob.content)),
    #("encoding", json.string(blob.encoding)),
    #("size", json.int(blob.size)),
    #("binary", json.bool(blob.binary)),
  ])
}

fn optional_string(value: option.Option(String)) -> json.Json {
  case value {
    option.Some(text) -> json.string(text)
    option.None -> json.null()
  }
}

pub fn merge_request_json(mr: MergeRequestRow) -> json.Json {
  json.object([
    #("id", json.string(mr.id)),
    #("number", json.int(mr.number)),
    #("title", json.string(mr.title)),
    #("description", optional_string(mr.description)),
    #("author_user_id", json.string(mr.author_user_id)),
    #("source_branch", json.string(mr.source_branch)),
    #("target_branch", json.string(mr.target_branch)),
    #("state", json.string(mr.state)),
    #("merge_commit_sha", optional_string(mr.merge_commit_sha)),
    #("merged_by_user_id", optional_string(mr.merged_by_user_id)),
    #("merged_at", optional_string(mr.merged_at)),
    #("closed_at", optional_string(mr.closed_at)),
    #("created_at", json.string(mr.created_at)),
    #("updated_at", json.string(mr.updated_at)),
  ])
}

pub fn merge_requests_json(mrs: List(MergeRequestRow)) -> json.Json {
  json.object([
    #("merge_requests", json.array(mrs, of: merge_request_json)),
  ])
}

pub fn merge_request_comment_json(comment: MergeRequestCommentRow) -> json.Json {
  json.object([
    #("id", json.string(comment.id)),
    #("author_user_id", json.string(comment.author_user_id)),
    #("author_name", json.string(comment.author_name)),
    #("body", json.string(comment.body)),
    #("file_path", optional_string(comment.file_path)),
    #(
      "line",
      case comment.line {
        option.Some(n) -> json.int(n)
        option.None -> json.null()
      },
    ),
    #("created_at", json.string(comment.created_at)),
    #("updated_at", json.string(comment.updated_at)),
  ])
}

pub fn merge_request_comments_json(
  comments: List(MergeRequestCommentRow),
) -> json.Json {
  json.object([
    #("comments", json.array(comments, of: merge_request_comment_json)),
  ])
}

fn commit_entry_json(c: CommitEntry) -> json.Json {
  json.object([
    #("sha", json.string(c.sha)),
    #("subject", json.string(c.subject)),
    #("author", json.string(c.author)),
    #("committed_at", json.string(c.committed_at)),
  ])
}

pub fn commits_json(commits: List(CommitEntry)) -> json.Json {
  json.object([
    #("commits", json.array(commits, of: commit_entry_json)),
  ])
}

pub fn single_commit_json(commit: CommitEntry) -> json.Json {
  commit_entry_json(commit)
}

pub fn repo_commits_json(total: Int, commits: List(CommitEntry)) -> json.Json {
  json.object([
    #("total", json.int(total)),
    #("commits", json.array(commits, of: commit_entry_json)),
  ])
}

pub fn diff_files_json(files: List(DiffFile)) -> json.Json {
  json.object([
    #(
      "files",
      json.array(files, of: fn(f) {
        json.object([
          #("path", json.string(f.path)),
          #("old_path", optional_string(f.old_path)),
          #("status", json.string(f.status)),
          #("additions", json.int(f.additions)),
          #("deletions", json.int(f.deletions)),
        ])
      }),
    ),
  ])
}

pub fn diff_patch_json(path: String, patch: String) -> json.Json {
  json.object([#("path", json.string(path)), #("patch", json.string(patch))])
}

pub fn merge_check_json(check: MergeCheck) -> json.Json {
  json.object([
    #("mergeable", json.bool(check.mergeable)),
    #("message", json.string(check.message)),
  ])
}

pub fn protected_branches_json(branches: List(String)) -> json.Json {
  json.object([
    #("branches", json.array(branches, of: json.string)),
  ])
}

pub fn ref_update_json(allowed: Bool, message: String) -> json.Json {
  json.object([
    #("allowed", json.bool(allowed)),
    #("message", json.string(message)),
  ])
}
