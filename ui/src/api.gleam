import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/string

pub type Org {
  Org(id: String, slug: String, name: String, role: option.Option(String))
}

pub type Repo {
  Repo(
    id: String,
    name: String,
    org_slug: String,
    clone_url: String,
    description: option.Option(String),
  )
}

pub type SshKey {
  SshKey(id: String, title: String, public_key: String, fingerprint: String)
}

pub type RepoDetail {
  RepoDetail(
    id: String,
    name: String,
    org_slug: String,
    clone_url: String,
    description: option.Option(String),
    default_branch: option.Option(String),
  )
}

pub type TreeEntry {
  TreeEntry(name: String, entry_type: String, sha: String)
}

pub type TreeListing {
  TreeListing(ref: String, path: String, entries: List(TreeEntry))
}

pub type Readme {
  Readme(ref: String, path: String, content: String)
}

pub type BlobView {
  BlobView(
    ref: String,
    path: String,
    content: String,
    encoding: String,
    size: Int,
    binary: Bool,
  )
}

pub fn org_decoder() -> decode.Decoder(Org) {
  use id <- decode.field("id", decode.string)
  use slug <- decode.field("slug", decode.string)
  use name <- decode.field("name", decode.string)
  use role <- decode.field("role", decode.optional(decode.string))
  decode.success(Org(id:, slug:, name:, role:))
}

pub fn orgs_decoder() -> decode.Decoder(List(Org)) {
  decode.list(org_decoder())
}

pub fn repo_decoder() -> decode.Decoder(Repo) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use org_slug <- decode.field("org_slug", decode.string)
  use clone_url <- decode.field("clone_url", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  decode.success(Repo(id:, name:, org_slug:, clone_url:, description:))
}

pub fn repos_decoder() -> decode.Decoder(List(Repo)) {
  decode.list(repo_decoder())
}

pub fn key_decoder() -> decode.Decoder(SshKey) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use public_key <- decode.field("public_key", decode.string)
  use fingerprint <- decode.field("fingerprint", decode.string)
  decode.success(SshKey(id:, title:, public_key:, fingerprint:))
}

pub fn keys_decoder() -> decode.Decoder(List(SshKey)) {
  decode.list(key_decoder())
}

pub fn create_org_body(slug: String, name: String) -> json.Json {
  json.object([#("slug", json.string(slug)), #("name", json.string(name))])
}

pub fn create_repo_body(name: String, description: option.Option(String)) -> json.Json {
  json.object([
    #("name", json.string(name)),
    #(
      "description",
      case description {
        option.Some(d) -> json.string(d)
        option.None -> json.null()
      },
    ),
  ])
}

pub fn repo_detail_decoder() -> decode.Decoder(RepoDetail) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use org_slug <- decode.field("org_slug", decode.string)
  use clone_url <- decode.field("clone_url", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use default_branch <- decode.field(
    "default_branch",
    decode.optional(decode.string),
  )
  decode.success(RepoDetail(
    id:,
    name:,
    org_slug:,
    clone_url:,
    description:,
    default_branch:,
  ))
}

pub fn branches_decoder() -> decode.Decoder(List(String)) {
  use branches <- decode.field("branches", decode.list(decode.string))
  decode.success(branches)
}

pub fn tree_entry_decoder() -> decode.Decoder(TreeEntry) {
  use name <- decode.field("name", decode.string)
  use entry_type <- decode.field("type", decode.string)
  use sha <- decode.field("sha", decode.string)
  decode.success(TreeEntry(name:, entry_type:, sha:))
}

pub fn tree_decoder() -> decode.Decoder(TreeListing) {
  use ref <- decode.field("ref", decode.string)
  use path <- decode.field("path", decode.string)
  use entries <- decode.field("entries", decode.list(tree_entry_decoder()))
  decode.success(TreeListing(ref:, path:, entries:))
}

pub fn readme_decoder() -> decode.Decoder(Readme) {
  use ref <- decode.field("ref", decode.string)
  use path <- decode.field("path", decode.string)
  use content <- decode.field("content", decode.string)
  decode.success(Readme(ref:, path:, content:))
}

pub fn blob_decoder() -> decode.Decoder(BlobView) {
  use ref <- decode.field("ref", decode.string)
  use path <- decode.field("path", decode.string)
  use content <- decode.field("content", decode.string)
  use encoding <- decode.field("encoding", decode.string)
  use size <- decode.field("size", decode.int)
  use binary <- decode.field("binary", decode.bool)
  decode.success(BlobView(ref:, path:, content:, encoding:, size:, binary:))
}

pub type MergeRequest {
  MergeRequest(
    id: String,
    number: Int,
    title: String,
    description: option.Option(String),
    author_user_id: String,
    source_branch: String,
    target_branch: String,
    state: String,
    merge_commit_sha: option.Option(String),
    merged_at: option.Option(String),
    closed_at: option.Option(String),
    created_at: String,
  )
}

pub type MergeCheck {
  MergeCheck(mergeable: Bool, message: String)
}

pub type MergeRequestDetail {
  MergeRequestDetail(merge_request: MergeRequest, merge_check: MergeCheck)
}

pub type MrComment {
  MrComment(
    id: String,
    author_user_id: String,
    author_name: String,
    body: String,
    file_path: option.Option(String),
    line: option.Option(Int),
    created_at: String,
  )
}

pub type MrCommit {
  MrCommit(sha: String, subject: String, author: String, committed_at: String)
}

pub type DiffFile {
  DiffFile(
    path: String,
    status: String,
    additions: Int,
    deletions: Int,
  )
}

pub fn merge_request_decoder() -> decode.Decoder(MergeRequest) {
  use id <- decode.field("id", decode.string)
  use number <- decode.field("number", decode.int)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use author_user_id <- decode.field("author_user_id", decode.string)
  use source_branch <- decode.field("source_branch", decode.string)
  use target_branch <- decode.field("target_branch", decode.string)
  use state <- decode.field("state", decode.string)
  use merge_commit_sha <- decode.field(
    "merge_commit_sha",
    decode.optional(decode.string),
  )
  use merged_at <- decode.field("merged_at", decode.optional(decode.string))
  use closed_at <- decode.field("closed_at", decode.optional(decode.string))
  use created_at <- decode.field("created_at", decode.string)
  decode.success(MergeRequest(
    id:,
    number:,
    title:,
    description:,
    author_user_id:,
    source_branch:,
    target_branch:,
    state:,
    merge_commit_sha:,
    merged_at:,
    closed_at:,
    created_at:,
  ))
}

pub fn merge_requests_decoder() -> decode.Decoder(List(MergeRequest)) {
  use mrs <- decode.field("merge_requests", decode.list(merge_request_decoder()))
  decode.success(mrs)
}

pub fn merge_request_detail_decoder() -> decode.Decoder(MergeRequestDetail) {
  use merge_request <- decode.field("merge_request", merge_request_decoder())
  use merge_check <- decode.field("merge_check", merge_check_decoder())
  decode.success(MergeRequestDetail(merge_request:, merge_check:))
}

pub fn merge_check_decoder() -> decode.Decoder(MergeCheck) {
  use mergeable <- decode.field("mergeable", decode.bool)
  use message <- decode.field("message", decode.string)
  decode.success(MergeCheck(mergeable:, message:))
}

pub fn mr_comments_decoder() -> decode.Decoder(List(MrComment)) {
  use comments <- decode.field("comments", decode.list(mr_comment_decoder()))
  decode.success(comments)
}

pub fn comment_author_label(comment: MrComment) -> String {
  case string.trim(comment.author_name) {
    "" -> comment.author_user_id
    name -> name
  }
}

pub fn mr_comment_decoder() -> decode.Decoder(MrComment) {
  use id <- decode.field("id", decode.string)
  use author_user_id <- decode.field("author_user_id", decode.string)
  use author_name <- decode.field("author_name", decode.string)
  use body <- decode.field("body", decode.string)
  use file_path <- decode.field("file_path", decode.optional(decode.string))
  use line <- decode.field("line", decode.optional(decode.int))
  use created_at <- decode.field("created_at", decode.string)
  decode.success(MrComment(
    id:,
    author_user_id:,
    author_name:,
    body:,
    file_path:,
    line:,
    created_at:,
  ))
}

pub fn mr_commits_decoder() -> decode.Decoder(List(MrCommit)) {
  use commits <- decode.field("commits", decode.list(mr_commit_decoder()))
  decode.success(commits)
}

pub fn mr_commit_decoder() -> decode.Decoder(MrCommit) {
  use sha <- decode.field("sha", decode.string)
  use subject <- decode.field("subject", decode.string)
  use author <- decode.field("author", decode.string)
  use committed_at <- decode.field("committed_at", decode.string)
  decode.success(MrCommit(sha:, subject:, author:, committed_at:))
}

pub fn diff_files_decoder() -> decode.Decoder(List(DiffFile)) {
  use files <- decode.field("files", decode.list(diff_file_decoder()))
  decode.success(files)
}

pub fn diff_file_decoder() -> decode.Decoder(DiffFile) {
  use path <- decode.field("path", decode.string)
  use status <- decode.field("status", decode.string)
  use additions <- decode.field("additions", decode.int)
  use deletions <- decode.field("deletions", decode.int)
  decode.success(DiffFile(path:, status:, additions:, deletions:))
}

pub fn diff_patch_decoder() -> decode.Decoder(String) {
  use patch <- decode.field("patch", decode.string)
  decode.success(patch)
}

pub fn mr_create_error_decoder() -> decode.Decoder(#(String, option.Option(Int))) {
  use error <- decode.field("error", decode.string)
  use existing_number <- decode.field(
    "existing_number",
    decode.optional(decode.int),
  )
  decode.success(#(error, existing_number))
}

pub fn create_mr_body(
  title: String,
  description: option.Option(String),
  source_branch: String,
  target_branch: String,
) -> json.Json {
  json.object([
    #("title", json.string(title)),
    #(
      "description",
      case description {
        option.Some(d) -> json.string(d)
        option.None -> json.null()
      },
    ),
    #("source_branch", json.string(source_branch)),
    #("target_branch", json.string(target_branch)),
  ])
}

pub fn create_mr_comment_body(
  body: String,
  file_path: option.Option(String),
  line: option.Option(Int),
) -> json.Json {
  json.object([
    #("body", json.string(body)),
    #(
      "file_path",
      case file_path {
        option.Some(p) -> json.string(p)
        option.None -> json.null()
      },
    ),
    #(
      "line",
      case line {
        option.Some(n) -> json.int(n)
        option.None -> json.null()
      },
    ),
  ])
}

pub fn create_key_body(title: String, public_key: String) -> json.Json {
  json.object([
    #("title", json.string(title)),
    #("public_key", json.string(public_key)),
  ])
}

pub fn protected_branches_decoder() -> decode.Decoder(List(String)) {
  use branches <- decode.field("branches", decode.list(decode.string))
  decode.success(branches)
}

pub fn protected_branches_body(branches: List(String)) -> json.Json {
  json.object([#("branches", json.array(branches, json.string))])
}

pub type MergeMethod {
  MergeCommit
  Squash
}

pub fn merge_request_merge_body(method: MergeMethod) -> json.Json {
  let value = case method {
    MergeCommit -> "merge"
    Squash -> "squash"
  }
  json.object([#("merge_method", json.string(value))])
}
