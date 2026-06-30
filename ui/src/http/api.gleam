import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/string

pub type Org {
  Org(id: String, slug: String, name: String, role: option.Option(String))
}

pub type UserStats {
  UserStats(
    open_merge_requests: Int,
    merged_merge_requests: Int,
    open_issues_authored: Int,
    open_issues_assigned: Int,
    reviews_given: Int,
  )
}

pub type Me {
  Me(
    id: String,
    display_name: option.Option(String),
    email: option.Option(String),
    organizations: List(Org),
    stats: UserStats,
    unread_notifications: Int,
  )
}

pub type Notification {
  Notification(
    id: String,
    type_: String,
    payload: String,
    read_at: option.Option(String),
    created_at: String,
  )
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
    default_branch_pipeline: option.Option(Pipeline),
    required_approvals: Int,
  )
}

pub type TreeEntry {
  TreeEntry(
    name: String,
    entry_type: String,
    sha: String,
    last_commit_sha: String,
    last_commit_message: String,
  )
}

pub type TreeListing {
  TreeListing(ref: String, path: String, entries: List(TreeEntry))
}

pub type Readme {
  Readme(ref: String, path: String, content: String)
}

pub type MergeRequestTemplate {
  MergeRequestTemplate(name: String, path: String, content: String)
}

pub type MergeRequestTemplates {
  MergeRequestTemplates(ref: String, templates: List(MergeRequestTemplate))
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

pub type UserSearchResult {
  UserSearchResult(
    id: String,
    username: option.Option(String),
    display_name: String,
  )
}

pub type OrgMember {
  OrgMember(
    user_id: String,
    role: String,
    display_name: String,
    username: option.Option(String),
  )
}

pub type OrgInvitation {
  OrgInvitation(
    id: String,
    invited_user_id: String,
    role: String,
    display_name: String,
    username: option.Option(String),
    invited_by: String,
    invited_by_display_name: String,
    invited_by_username: option.Option(String),
    created_at: String,
    org_slug: option.Option(String),
    org_name: option.Option(String),
  )
}

pub type AcceptInvitation {
  AcceptInvitation(org_slug: String)
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

pub fn user_stats_decoder() -> decode.Decoder(UserStats) {
  use open_merge_requests <- decode.field(
    "open_merge_requests",
    decode.int,
  )
  use merged_merge_requests <- decode.field(
    "merged_merge_requests",
    decode.int,
  )
  use open_issues_authored <- decode.field("open_issues_authored", decode.int)
  use open_issues_assigned <- decode.field("open_issues_assigned", decode.int)
  use reviews_given <- decode.field("reviews_given", decode.int)
  decode.success(UserStats(
    open_merge_requests:,
    merged_merge_requests:,
    open_issues_authored:,
    open_issues_assigned:,
    reviews_given:,
  ))
}

pub fn me_decoder() -> decode.Decoder(Me) {
  use id <- decode.field("id", decode.string)
  use display_name <- decode.optional_field(
    "display_name",
    option.None,
    decode.optional(decode.string),
  )
  use email <- decode.optional_field(
    "email",
    option.None,
    decode.optional(decode.string),
  )
  use organizations <- decode.field("organizations", orgs_decoder())
  use stats <- decode.field("stats", user_stats_decoder())
  use unread_notifications <- decode.optional_field(
    "unread_notifications",
    0,
    decode.int,
  )
  decode.success(Me(
    id:,
    display_name:,
    email:,
    organizations:,
    stats:,
    unread_notifications:,
  ))
}

pub fn notification_decoder() -> decode.Decoder(Notification) {
  use id <- decode.field("id", decode.string)
  use type_ <- decode.field("type", decode.string)
  use payload <- decode.field("payload", decode.string)
  use read_at <- decode.optional_field(
    "read_at",
    option.None,
    decode.optional(decode.string),
  )
  use created_at <- decode.field("created_at", decode.string)
  decode.success(Notification(
    id:,
    type_:,
    payload:,
    read_at:,
    created_at:,
  ))
}

pub fn notifications_decoder() -> decode.Decoder(List(Notification)) {
  decode.list(notification_decoder())
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

pub fn create_repo_body(
  name: String,
  description: option.Option(String),
) -> json.Json {
  json.object([
    #("name", json.string(name)),
    #("description", case description {
      option.Some(d) -> json.string(d)
      option.None -> json.null()
    }),
  ])
}

pub fn create_invitation_body(user_id: String, role: String) -> json.Json {
  json.object([
    #("user_id", json.string(user_id)),
    #("role", json.string(role)),
  ])
}

pub fn update_member_role_body(role: String) -> json.Json {
  json.object([#("role", json.string(role))])
}

pub fn user_search_decoder() -> decode.Decoder(UserSearchResult) {
  use id <- decode.field("id", decode.string)
  use username <- decode.field("username", decode.optional(decode.string))
  use display_name <- decode.field("display_name", decode.string)
  decode.success(UserSearchResult(id:, username:, display_name:))
}

pub fn user_search_results_decoder() -> decode.Decoder(List(UserSearchResult)) {
  decode.list(user_search_decoder())
}

pub fn member_decoder() -> decode.Decoder(OrgMember) {
  use user_id <- decode.field("user_id", decode.string)
  use role <- decode.field("role", decode.string)
  use display_name <- decode.field("display_name", decode.string)
  use username <- decode.field("username", decode.optional(decode.string))
  decode.success(OrgMember(user_id:, role:, display_name:, username:))
}

pub fn members_decoder() -> decode.Decoder(List(OrgMember)) {
  decode.list(member_decoder())
}

pub fn invitation_decoder() -> decode.Decoder(OrgInvitation) {
  use id <- decode.field("id", decode.string)
  use invited_user_id <- decode.field("invited_user_id", decode.string)
  use role <- decode.field("role", decode.string)
  use display_name <- decode.field("display_name", decode.string)
  use username <- decode.field("username", decode.optional(decode.string))
  use invited_by <- decode.field("invited_by", decode.string)
  use invited_by_display_name <- decode.field(
    "invited_by_display_name",
    decode.string,
  )
  use invited_by_username <- decode.field(
    "invited_by_username",
    decode.optional(decode.string),
  )
  use created_at <- decode.field("created_at", decode.string)
  use org_slug <- decode.field("org_slug", decode.optional(decode.string))
  use org_name <- decode.field("org_name", decode.optional(decode.string))
  decode.success(OrgInvitation(
    id:,
    invited_user_id:,
    role:,
    display_name:,
    username:,
    invited_by:,
    invited_by_display_name:,
    invited_by_username:,
    created_at:,
    org_slug:,
    org_name:,
  ))
}

pub fn invitations_decoder() -> decode.Decoder(List(OrgInvitation)) {
  decode.list(invitation_decoder())
}

pub fn accept_invitation_decoder() -> decode.Decoder(AcceptInvitation) {
  use org_slug <- decode.field("org_slug", decode.string)
  decode.success(AcceptInvitation(org_slug:))
}

pub fn rename_repo_body(name: String) -> json.Json {
  json.object([#("name", json.string(name))])
}

pub fn update_repo_body(name: String, description: String) -> json.Json {
  json.object([
    #("name", json.string(name)),
    #("description", json.string(description)),
  ])
}

pub fn required_approvals_body(required_approvals: Int) -> json.Json {
  json.object([#("required_approvals", json.int(required_approvals))])
}

pub fn default_branch_body(branch: String) -> json.Json {
  json.object([#("branch", json.string(branch))])
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
  use default_branch_pipeline <- decode.optional_field(
    "default_branch_pipeline",
    option.None,
    decode.optional(pipeline_decoder()),
  )
  use required_approvals <- decode.field("required_approvals", decode.int)
  decode.success(RepoDetail(
    id:,
    name:,
    org_slug:,
    clone_url:,
    description:,
    default_branch:,
    default_branch_pipeline:,
    required_approvals:,
  ))
}

pub fn branches_decoder() -> decode.Decoder(List(String)) {
  use branches <- decode.field("branches", decode.list(decode.string))
  decode.success(branches)
}

pub type Tag {
  Tag(
    name: String,
    target_commit_sha: String,
    created_at: String,
    message: String,
  )
}

pub fn tag_decoder() -> decode.Decoder(Tag) {
  use name <- decode.field("name", decode.string)
  use target_commit_sha <- decode.field("target_commit_sha", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use message <- decode.field("message", decode.string)
  decode.success(Tag(
    name:,
    target_commit_sha:,
    created_at:,
    message:,
  ))
}

pub fn tags_decoder() -> decode.Decoder(List(Tag)) {
  use tags <- decode.field("tags", decode.list(tag_decoder()))
  decode.success(tags)
}

pub type Release {
  Release(
    id: String,
    tag_name: String,
    target_commit_sha: String,
    title: String,
    body: String,
    author_user_id: String,
    author_name: String,
    created_at: String,
  )
}

pub fn release_decoder() -> decode.Decoder(Release) {
  use id <- decode.field("id", decode.string)
  use tag_name <- decode.field("tag_name", decode.string)
  use target_commit_sha <- decode.field("target_commit_sha", decode.string)
  use title <- decode.field("title", decode.string)
  use body <- decode.field("body", decode.string)
  use author_user_id <- decode.field("author_user_id", decode.string)
  use author_name <- decode.field("author_name", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(Release(
    id:,
    tag_name:,
    target_commit_sha:,
    title:,
    body:,
    author_user_id:,
    author_name:,
    created_at:,
  ))
}

pub fn releases_decoder() -> decode.Decoder(List(Release)) {
  use releases <- decode.field("releases", decode.list(release_decoder()))
  decode.success(releases)
}

pub fn create_release_body(
  tag_name: String,
  title: String,
  body: option.Option(String),
) -> json.Json {
  json.object([
    #("tag_name", json.string(tag_name)),
    #("title", json.string(title)),
    #("body", case body {
      option.Some(text) -> json.string(text)
      option.None -> json.null()
    }),
  ])
}

pub fn update_release_body(title: String, body: option.Option(String)) -> json.Json {
  json.object([
    #("title", json.string(title)),
    #("body", case body {
      option.Some(text) -> json.string(text)
      option.None -> json.null()
    }),
  ])
}

pub fn tree_entry_decoder() -> decode.Decoder(TreeEntry) {
  use name <- decode.field("name", decode.string)
  use entry_type <- decode.field("type", decode.string)
  use sha <- decode.field("sha", decode.string)
  use last_commit_sha <- decode.field(
    "last_commit_sha",
    decode.optional(decode.string),
  )
  use last_commit_message <- decode.field(
    "last_commit_message",
    decode.optional(decode.string),
  )
  decode.success(TreeEntry(
    name:,
    entry_type:,
    sha:,
    last_commit_sha: option.unwrap(last_commit_sha, ""),
    last_commit_message: option.unwrap(last_commit_message, ""),
  ))
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

pub fn merge_request_template_decoder() -> decode.Decoder(MergeRequestTemplate) {
  use name <- decode.field("name", decode.string)
  use path <- decode.field("path", decode.string)
  use content <- decode.field("content", decode.string)
  decode.success(MergeRequestTemplate(name:, path:, content:))
}

pub fn merge_request_templates_decoder() -> decode.Decoder(
  MergeRequestTemplates,
) {
  use ref <- decode.field("ref", decode.string)
  use templates <- decode.field(
    "templates",
    decode.list(merge_request_template_decoder()),
  )
  decode.success(MergeRequestTemplates(ref:, templates:))
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

pub type Label {
  Label(id: String, name: String, color: String)
}

pub type IssueAssignee {
  IssueAssignee(user_id: String, display_name: String)
}

pub type MergeRequest {
  MergeRequest(
    id: String,
    number: Int,
    title: String,
    description: option.Option(String),
    author_user_id: String,
    author_name: String,
    source_branch: String,
    target_branch: String,
    state: String,
    is_draft: Bool,
    merge_commit_sha: option.Option(String),
    merged_at: option.Option(String),
    closed_at: option.Option(String),
    created_at: String,
    pipeline: option.Option(Pipeline),
    labels: List(Label),
    assignees: List(IssueAssignee),
    reviewers: List(IssueAssignee),
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

pub type MrReview {
  MrReview(
    id: String,
    user_id: String,
    reviewer_name: String,
    state: String,
    body: option.Option(String),
    submitted_at: String,
  )
}

pub type Pipeline {
  Pipeline(
    id: String,
    state: String,
    commit_sha: String,
    trigger: String,
    module_path: option.Option(String),
    entry_function: String,
    started_at: option.Option(String),
    finished_at: option.Option(String),
    created_at: option.Option(String),
    log: option.Option(String),
  )
}

pub type MergeRequestDetail {
  MergeRequestDetail(
    merge_request: MergeRequest,
    merge_check: MergeCheck,
    pipeline: option.Option(Pipeline),
    reviews: List(MrReview),
    linked_issues: List(LinkedIssue),
  )
}

pub type MrComment {
  MrComment(
    id: String,
    author_user_id: String,
    author_name: String,
    body: String,
    file_path: option.Option(String),
    line: option.Option(Int),
    mentioned_user_ids: List(String),
    mentioned_usernames: List(String),
    created_at: String,
    updated_at: String,
  )
}

pub type IssueMilestone {
  IssueMilestone(id: String, number: Int, title: String)
}

pub type Milestone {
  Milestone(
    id: String,
    number: Int,
    title: String,
    description: option.Option(String),
    state: String,
    due_on: option.Option(String),
    closed_at: option.Option(String),
    created_at: String,
    updated_at: String,
    open_issues: Int,
    closed_issues: Int,
    open_mrs: Int,
  )
}

pub type Project {
  Project(
    id: String,
    number: Int,
    title: String,
    description: option.Option(String),
    state: String,
    created_at: String,
    updated_at: String,
  )
}

pub type ProjectItem {
  ProjectItem(
    id: String,
    item_type: String,
    repo_name: String,
    org_slug: String,
    number: Int,
    title: String,
    state: String,
  )
}

pub type ProjectColumn {
  ProjectColumn(
    id: String,
    name: String,
    position: Int,
    items: List(ProjectItem),
  )
}

pub type ProjectBoard {
  ProjectBoard(project: Project, columns: List(ProjectColumn))
}

pub type Issue {
  Issue(
    id: String,
    number: Int,
    title: String,
    description: option.Option(String),
    author_user_id: String,
    author_name: String,
    state: String,
    closed_at: option.Option(String),
    created_at: String,
    labels: List(Label),
    assignees: List(IssueAssignee),
    milestone: option.Option(IssueMilestone),
  )
}

pub type LinkedIssue {
  LinkedIssue(number: Int, title: String, state: String, link_type: String)
}

pub type LinkedMergeRequest {
  LinkedMergeRequest(
    number: Int,
    title: String,
    state: String,
    is_draft: Bool,
    link_type: String,
  )
}

pub type IssueDetail {
  IssueDetail(issue: Issue, linked_merge_requests: List(LinkedMergeRequest))
}

pub type IssueComment {
  IssueComment(
    id: String,
    author_user_id: String,
    author_name: String,
    body: String,
    mentioned_user_ids: List(String),
    mentioned_usernames: List(String),
    created_at: String,
    updated_at: String,
  )
}

pub type MrCommit {
  MrCommit(sha: String, subject: String, author: String, committed_at: String)
}

pub type DiffFile {
  DiffFile(path: String, status: String, additions: Int, deletions: Int)
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

pub fn label_decoder() -> decode.Decoder(Label) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use color <- decode.field("color", decode.string)
  decode.success(Label(id:, name:, color:))
}

pub fn labels_decoder() -> decode.Decoder(List(Label)) {
  use labels <- decode.field("labels", decode.list(label_decoder()))
  decode.success(labels)
}

pub fn issue_assignee_decoder() -> decode.Decoder(IssueAssignee) {
  use user_id <- decode.field("user_id", decode.string)
  use display_name <- decode.field("display_name", decode.string)
  decode.success(IssueAssignee(user_id:, display_name:))
}

pub fn merge_request_decoder() -> decode.Decoder(MergeRequest) {
  use id <- decode.field("id", decode.string)
  use number <- decode.field("number", decode.int)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use author_user_id <- decode.field("author_user_id", decode.string)
  use author_name <- decode.field("author_name", decode.string)
  use source_branch <- decode.field("source_branch", decode.string)
  use target_branch <- decode.field("target_branch", decode.string)
  use state <- decode.field("state", decode.string)
  use is_draft <- decode.optional_field("is_draft", False, decode.bool)
  use merge_commit_sha <- decode.field(
    "merge_commit_sha",
    decode.optional(decode.string),
  )
  use merged_at <- decode.field("merged_at", decode.optional(decode.string))
  use closed_at <- decode.field("closed_at", decode.optional(decode.string))
  use created_at <- decode.field("created_at", decode.string)
  use pipeline <- decode.optional_field(
    "pipeline",
    option.None,
    decode.optional(pipeline_decoder()),
  )
  use labels <- decode.optional_field(
    "labels",
    [],
    decode.list(label_decoder()),
  )
  use assignees <- decode.optional_field(
    "assignees",
    [],
    decode.list(issue_assignee_decoder()),
  )
  use reviewers <- decode.optional_field(
    "reviewers",
    [],
    decode.list(issue_assignee_decoder()),
  )
  decode.success(MergeRequest(
    id:,
    number:,
    title:,
    description:,
    author_user_id:,
    author_name:,
    source_branch:,
    target_branch:,
    state:,
    is_draft:,
    merge_commit_sha:,
    merged_at:,
    closed_at:,
    created_at:,
    pipeline:,
    labels:,
    assignees:,
    reviewers:,
  ))
}

pub fn merge_requests_decoder() -> decode.Decoder(List(MergeRequest)) {
  use mrs <- decode.field(
    "merge_requests",
    decode.list(merge_request_decoder()),
  )
  decode.success(mrs)
}

pub fn merge_request_detail_decoder() -> decode.Decoder(MergeRequestDetail) {
  use merge_request <- decode.field("merge_request", merge_request_decoder())
  use merge_check <- decode.field("merge_check", merge_check_decoder())
  use pipeline <- decode.field("pipeline", decode.optional(pipeline_decoder()))
  use reviews <- decode.optional_field("reviews", [], decode.list(mr_review_decoder()))
  use linked_issues <- decode.optional_field(
    "linked_issues",
    [],
    decode.list(linked_issue_decoder()),
  )
  decode.success(MergeRequestDetail(
    merge_request:,
    merge_check:,
    pipeline:,
    reviews:,
    linked_issues:,
  ))
}

pub fn pipeline_decoder() -> decode.Decoder(Pipeline) {
  use id <- decode.field("id", decode.string)
  use state <- decode.field("state", decode.string)
  use commit_sha <- decode.field("commit_sha", decode.string)
  use trigger <- decode.field("trigger", decode.string)
  use module_path <- decode.field("module_path", decode.optional(decode.string))
  use entry_function <- decode.field("entry_function", decode.string)
  use started_at <- decode.field("started_at", decode.optional(decode.string))
  use finished_at <- decode.field("finished_at", decode.optional(decode.string))
  use created_at <- decode.field("created_at", decode.optional(decode.string))
  use log <- decode.field("log", decode.optional(decode.string))
  decode.success(Pipeline(
    id:,
    state:,
    commit_sha:,
    trigger:,
    module_path:,
    entry_function:,
    started_at:,
    finished_at:,
    created_at:,
    log:,
  ))
}

pub fn pipelines_decoder() -> decode.Decoder(List(Pipeline)) {
  use pipelines <- decode.field("pipelines", decode.list(pipeline_decoder()))
  decode.success(pipelines)
}

pub fn merge_check_decoder() -> decode.Decoder(MergeCheck) {
  use mergeable <- decode.field("mergeable", decode.bool)
  use message <- decode.field("message", decode.string)
  use behind_target <- decode.optional_field(
    "behind_target",
    False,
    decode.bool,
  )
  use conflict_paths <- decode.optional_field(
    "conflict_paths",
    [],
    decode.list(decode.string),
  )
  use approval_count <- decode.optional_field("approval_count", 0, decode.int)
  use required_approvals <- decode.optional_field(
    "required_approvals",
    0,
    decode.int,
  )
  decode.success(MergeCheck(
    mergeable:,
    message:,
    behind_target:,
    conflict_paths:,
    approval_count:,
    required_approvals:,
  ))
}

pub fn mr_review_decoder() -> decode.Decoder(MrReview) {
  use id <- decode.field("id", decode.string)
  use user_id <- decode.field("user_id", decode.string)
  use reviewer_name <- decode.field("reviewer_name", decode.string)
  use state <- decode.field("state", decode.string)
  use body <- decode.optional_field("body", option.None, decode.optional(decode.string))
  use submitted_at <- decode.field("submitted_at", decode.string)
  decode.success(MrReview(
    id:,
    user_id:,
    reviewer_name:,
    state:,
    body:,
    submitted_at:,
  ))
}

pub fn submit_mr_review_body(state: String, body: option.Option(String)) -> json.Json {
  let fields = [
    #("state", json.string(state)),
    ..case body {
      option.Some(text) -> [#("body", json.string(text))]
      option.None -> []
    },
  ]
  json.object(fields)
}

pub fn mr_comments_decoder() -> decode.Decoder(List(MrComment)) {
  use comments <- decode.field("comments", decode.list(mr_comment_decoder()))
  decode.success(comments)
}

pub fn comment_author_label(comment: MrComment) -> String {
  author_label(comment.author_name, comment.author_user_id)
}

pub fn mr_author_label(mr: MergeRequest) -> String {
  author_label(mr.author_name, mr.author_user_id)
}

fn author_label(name: String, user_id: String) -> String {
  case string.trim(name) {
    "" -> user_id
    label -> label
  }
}

pub fn issue_comment_author_label(comment: IssueComment) -> String {
  author_label(comment.author_name, comment.author_user_id)
}

pub fn issue_author_label(issue: Issue) -> String {
  author_label(issue.author_name, issue.author_user_id)
}

pub fn mr_comment_decoder() -> decode.Decoder(MrComment) {
  use id <- decode.field("id", decode.string)
  use author_user_id <- decode.field("author_user_id", decode.string)
  use author_name <- decode.field("author_name", decode.string)
  use body <- decode.field("body", decode.string)
  use file_path <- decode.field("file_path", decode.optional(decode.string))
  use line <- decode.field("line", decode.optional(decode.int))
  use mentioned_user_ids <- decode.optional_field(
    "mentioned_user_ids",
    [],
    decode.list(decode.string),
  )
  use mentioned_usernames <- decode.optional_field(
    "mentioned_usernames",
    [],
    decode.list(decode.string),
  )
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.optional_field(
    "updated_at",
    created_at,
    decode.string,
  )
  decode.success(MrComment(
    id:,
    author_user_id:,
    author_name:,
    body:,
    file_path:,
    line:,
    mentioned_user_ids:,
    mentioned_usernames:,
    created_at:,
    updated_at:,
  ))
}

pub type RepoCommits {
  RepoCommits(total: Int, commits: List(MrCommit))
}

pub fn mr_commits_decoder() -> decode.Decoder(List(MrCommit)) {
  use commits <- decode.field("commits", decode.list(mr_commit_decoder()))
  decode.success(commits)
}

pub fn commit_decoder() -> decode.Decoder(MrCommit) {
  mr_commit_decoder()
}

pub fn repo_commits_decoder() -> decode.Decoder(RepoCommits) {
  use total <- decode.field("total", decode.int)
  use commits <- decode.field("commits", decode.list(mr_commit_decoder()))
  decode.success(RepoCommits(total:, commits:))
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

fn conflict_file_side_decoder() -> decode.Decoder(ConflictFileSide) {
  use content <- decode.field("content", decode.string)
  use encoding <- decode.field("encoding", decode.string)
  use binary <- decode.field("binary", decode.bool)
  use missing <- decode.field("missing", decode.bool)
  decode.success(ConflictFileSide(content:, encoding:, binary:, missing:))
}

pub fn conflict_file_decoder() -> decode.Decoder(ConflictFile) {
  use path <- decode.field("path", decode.string)
  use target_branch <- decode.field("target_branch", decode.string)
  use source_branch <- decode.field("source_branch", decode.string)
  use target <- decode.field("target", conflict_file_side_decoder())
  use source <- decode.field("source", conflict_file_side_decoder())
  decode.success(ConflictFile(
    path:,
    target_branch:,
    source_branch:,
    target:,
    source:,
  ))
}

pub fn mr_create_error_decoder() -> decode.Decoder(
  #(String, option.Option(Int)),
) {
  use error <- decode.field("error", decode.string)
  use existing_number <- decode.field(
    "existing_number",
    decode.optional(decode.int),
  )
  decode.success(#(error, existing_number))
}

pub fn error_message_from_json(json_str: String, fallback: String) -> String {
  case json.parse(json_str, decode.at(["error"], decode.string)) {
    Ok(message) ->
      case string.trim(message) {
        "" -> fallback
        trimmed -> trimmed
      }
    Error(_) -> fallback
  }
}

pub fn issue_milestone_decoder() -> decode.Decoder(IssueMilestone) {
  use id <- decode.field("id", decode.string)
  use number <- decode.field("number", decode.int)
  use title <- decode.field("title", decode.string)
  decode.success(IssueMilestone(id:, number:, title:))
}

pub fn milestone_decoder() -> decode.Decoder(Milestone) {
  use id <- decode.field("id", decode.string)
  use number <- decode.field("number", decode.int)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use state <- decode.field("state", decode.string)
  use due_on <- decode.field("due_on", decode.optional(decode.string))
  use closed_at <- decode.field("closed_at", decode.optional(decode.string))
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  use open_issues <- decode.field("open_issues", decode.int)
  use closed_issues <- decode.field("closed_issues", decode.int)
  use open_mrs <- decode.field("open_mrs", decode.int)
  decode.success(Milestone(
    id:,
    number:,
    title:,
    description:,
    state:,
    due_on:,
    closed_at:,
    created_at:,
    updated_at:,
    open_issues:,
    closed_issues:,
    open_mrs:,
  ))
}

pub fn milestones_decoder() -> decode.Decoder(List(Milestone)) {
  use milestones <- decode.field("milestones", decode.list(milestone_decoder()))
  decode.success(milestones)
}

pub fn project_decoder() -> decode.Decoder(Project) {
  use id <- decode.field("id", decode.string)
  use number <- decode.field("number", decode.int)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use state <- decode.field("state", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  decode.success(Project(
    id:,
    number:,
    title:,
    description:,
    state:,
    created_at:,
    updated_at:,
  ))
}

pub fn projects_decoder() -> decode.Decoder(List(Project)) {
  use projects <- decode.field("projects", decode.list(project_decoder()))
  decode.success(projects)
}

pub fn project_item_decoder() -> decode.Decoder(ProjectItem) {
  use id <- decode.field("id", decode.string)
  use item_type <- decode.field("item_type", decode.string)
  use repo_name <- decode.field("repo_name", decode.string)
  use org_slug <- decode.field("org_slug", decode.string)
  use number <- decode.field("number", decode.int)
  use title <- decode.field("title", decode.string)
  use state <- decode.field("state", decode.string)
  decode.success(ProjectItem(
    id:,
    item_type:,
    repo_name:,
    org_slug:,
    number:,
    title:,
    state:,
  ))
}

pub fn project_column_decoder() -> decode.Decoder(ProjectColumn) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use position <- decode.field("position", decode.int)
  use items <- decode.optional_field(
    "items",
    [],
    decode.list(project_item_decoder()),
  )
  decode.success(ProjectColumn(id:, name:, position:, items:))
}

pub fn project_board_decoder() -> decode.Decoder(ProjectBoard) {
  use project <- decode.field("project", project_decoder())
  use columns <- decode.field("columns", decode.list(project_column_decoder()))
  decode.success(ProjectBoard(project:, columns:))
}

pub fn issue_decoder() -> decode.Decoder(Issue) {
  use id <- decode.field("id", decode.string)
  use number <- decode.field("number", decode.int)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use author_user_id <- decode.field("author_user_id", decode.string)
  use author_name <- decode.field("author_name", decode.string)
  use state <- decode.field("state", decode.string)
  use closed_at <- decode.field("closed_at", decode.optional(decode.string))
  use created_at <- decode.field("created_at", decode.string)
  use labels <- decode.optional_field(
    "labels",
    [],
    decode.list(label_decoder()),
  )
  use assignees <- decode.optional_field(
    "assignees",
    [],
    decode.list(issue_assignee_decoder()),
  )
  use milestone <- decode.optional_field(
    "milestone",
    option.None,
    decode.optional(issue_milestone_decoder()),
  )
  decode.success(Issue(
    id:,
    number:,
    title:,
    description:,
    author_user_id:,
    author_name:,
    state:,
    closed_at:,
    created_at:,
    labels:,
    assignees:,
    milestone:,
  ))
}

pub fn issues_decoder() -> decode.Decoder(List(Issue)) {
  use issues <- decode.field("issues", decode.list(issue_decoder()))
  decode.success(issues)
}

pub fn linked_issue_decoder() -> decode.Decoder(LinkedIssue) {
  use number <- decode.field("number", decode.int)
  use title <- decode.field("title", decode.string)
  use state <- decode.field("state", decode.string)
  use link_type <- decode.field("link_type", decode.string)
  decode.success(LinkedIssue(number:, title:, state:, link_type:))
}

pub fn linked_merge_request_decoder() -> decode.Decoder(LinkedMergeRequest) {
  use number <- decode.field("number", decode.int)
  use title <- decode.field("title", decode.string)
  use state <- decode.field("state", decode.string)
  use is_draft <- decode.field("is_draft", decode.bool)
  use link_type <- decode.field("link_type", decode.string)
  decode.success(LinkedMergeRequest(
    number:,
    title:,
    state:,
    is_draft:,
    link_type:,
  ))
}

pub fn issue_detail_decoder() -> decode.Decoder(IssueDetail) {
  use issue <- decode.field("issue", issue_decoder())
  use linked_merge_requests <- decode.optional_field(
    "linked_merge_requests",
    [],
    decode.list(linked_merge_request_decoder()),
  )
  decode.success(IssueDetail(issue:, linked_merge_requests:))
}

pub fn issue_comments_decoder() -> decode.Decoder(List(IssueComment)) {
  use comments <- decode.field("comments", decode.list(issue_comment_decoder()))
  decode.success(comments)
}

pub fn issue_comment_decoder() -> decode.Decoder(IssueComment) {
  use id <- decode.field("id", decode.string)
  use author_user_id <- decode.field("author_user_id", decode.string)
  use author_name <- decode.field("author_name", decode.string)
  use body <- decode.field("body", decode.string)
  use mentioned_user_ids <- decode.optional_field(
    "mentioned_user_ids",
    [],
    decode.list(decode.string),
  )
  use mentioned_usernames <- decode.optional_field(
    "mentioned_usernames",
    [],
    decode.list(decode.string),
  )
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.optional_field(
    "updated_at",
    created_at,
    decode.string,
  )
  decode.success(IssueComment(
    id:,
    author_user_id:,
    author_name:,
    body:,
    mentioned_user_ids:,
    mentioned_usernames:,
    created_at:,
    updated_at:,
  ))
}

pub fn create_issue_body(
  title: String,
  description: option.Option(String),
) -> json.Json {
  json.object([
    #("title", json.string(title)),
    #("description", case description {
      option.Some(d) -> json.string(d)
      option.None -> json.null()
    }),
  ])
}

pub fn create_issue_comment_body(body: String) -> json.Json {
  json.object([#("body", json.string(body))])
}

pub fn update_comment_body(body: String) -> json.Json {
  json.object([#("body", json.string(body))])
}

pub fn update_label_body(
  name: option.Option(String),
  color: option.Option(String),
) -> json.Json {
  let name_field = case name {
    option.Some(n) -> [#("name", json.string(n))]
    option.None -> []
  }
  let color_field = case color {
    option.Some(c) -> [#("color", json.string(c))]
    option.None -> []
  }
  json.object(list.append(name_field, color_field))
}

pub fn comment_is_edited(created_at: String, updated_at: String) -> Bool {
  updated_at != "" && updated_at != created_at
}

pub fn create_milestone_body(
  title: String,
  description: option.Option(String),
  due_on: option.Option(String),
) -> json.Json {
  json.object([
    #("title", json.string(title)),
    #("description", case description {
      option.Some(d) -> json.string(d)
      option.None -> json.null()
    }),
    #("due_on", case due_on {
      option.Some(d) -> json.string(d)
      option.None -> json.null()
    }),
  ])
}

pub fn update_milestone_body(
  title: String,
  description: option.Option(String),
  due_on: option.Option(String),
) -> json.Json {
  json.object([
    #("title", json.string(title)),
    #("description", case description {
      option.Some(d) -> json.string(d)
      option.None -> json.null()
    }),
    #("due_on", case due_on {
      option.Some(d) -> json.string(d)
      option.None -> json.null()
    }),
  ])
}

pub fn create_project_body(
  title: String,
  description: option.Option(String),
) -> json.Json {
  json.object([
    #("title", json.string(title)),
    #("description", case description {
      option.Some(d) -> json.string(d)
      option.None -> json.null()
    }),
  ])
}

pub fn update_project_body(
  title: option.Option(String),
  description: option.Option(String),
  state: option.Option(String),
) -> json.Json {
  let title_field = case title {
    option.Some(t) -> [#("title", json.string(t))]
    option.None -> []
  }
  let description_field = case description {
    option.Some(d) -> [#("description", json.string(d))]
    option.None -> []
  }
  let state_field = case state {
    option.Some(s) -> [#("state", json.string(s))]
    option.None -> []
  }
  json.object(list.append(list.append(title_field, description_field), state_field))
}

pub fn add_project_item_body(
  item_type: String,
  repo_name: String,
  number: Int,
) -> json.Json {
  json.object([
    #("item_type", json.string(item_type)),
    #("repo_name", json.string(repo_name)),
    #("number", json.int(number)),
  ])
}

pub fn move_project_item_body(column_id: String, position: Int) -> json.Json {
  json.object([
    #("column_id", json.string(column_id)),
    #("position", json.int(position)),
  ])
}

pub fn update_project_column_body(
  name: option.Option(String),
  position: option.Option(Int),
) -> json.Json {
  let name_field = case name {
    option.Some(n) -> [#("name", json.string(n))]
    option.None -> []
  }
  let position_field = case position {
    option.Some(p) -> [#("position", json.int(p))]
    option.None -> []
  }
  json.object(list.append(name_field, position_field))
}

pub fn update_issue_milestone_body(milestone_id: option.Option(String)) -> json.Json {
  json.object([
    #(
      "milestone_id",
      case milestone_id {
        option.Some(id) -> json.string(id)
        option.None -> json.null()
      },
    ),
  ])
}

pub fn update_issue_body(
  title: String,
  description: option.Option(String),
  label_ids: List(String),
  assignee_user_ids: List(String),
  milestone_id: option.Option(option.Option(String)),
) -> json.Json {
  let milestone_field = case milestone_id {
    option.None -> []
    option.Some(id) -> [
      #(
        "milestone_id",
        case id {
          option.Some(value) -> json.string(value)
          option.None -> json.null()
        },
      ),
    ]
  }
  json.object(list.append(
    [
      #("title", json.string(title)),
      #("description", case description {
        option.Some(d) -> json.string(d)
        option.None -> json.null()
      }),
      #("label_ids", json.array(label_ids, of: json.string)),
      #("assignee_user_ids", json.array(assignee_user_ids, of: json.string)),
    ],
    milestone_field,
  ))
}

pub fn update_merge_request_labels_body(label_ids: List(String)) -> json.Json {
  update_merge_request_patch(
    option.None,
    option.None,
    option.Some(label_ids),
    option.None,
    option.None,
    option.None,
  )
}

pub fn update_merge_request_body(
  label_ids: option.Option(List(String)),
  draft: option.Option(Bool),
) -> json.Json {
  update_merge_request_patch(
    option.None,
    option.None,
    label_ids,
    draft,
    option.None,
    option.None,
  )
}

pub fn update_merge_request_patch(
  title: option.Option(String),
  description: option.Option(option.Option(String)),
  label_ids: option.Option(List(String)),
  draft: option.Option(Bool),
  assignee_user_ids: option.Option(List(String)),
  reviewer_user_ids: option.Option(List(String)),
) -> json.Json {
  let fields =
    []
    |> prepend_title_field(title)
    |> prepend_description_field(description)
    |> prepend_label_ids_field(label_ids)
    |> prepend_draft_field(draft)
    |> prepend_assignee_ids_field(assignee_user_ids)
    |> prepend_reviewer_ids_field(reviewer_user_ids)
  json.object(fields)
}

fn prepend_title_field(
  fields: List(#(String, json.Json)),
  title: option.Option(String),
) -> List(#(String, json.Json)) {
  case title {
    option.Some(value) -> [#("title", json.string(value)), ..fields]
    option.None -> fields
  }
}

fn prepend_description_field(
  fields: List(#(String, json.Json)),
  description: option.Option(option.Option(String)),
) -> List(#(String, json.Json)) {
  case description {
    option.Some(value) -> [
      #(
        "description",
        case value {
          option.Some(d) -> json.string(d)
          option.None -> json.null()
        },
      ),
      ..fields
    ]
    option.None -> fields
  }
}

fn prepend_assignee_ids_field(
  fields: List(#(String, json.Json)),
  assignee_user_ids: option.Option(List(String)),
) -> List(#(String, json.Json)) {
  case assignee_user_ids {
    option.Some(ids) -> [
      #("assignee_user_ids", json.array(ids, of: json.string)),
      ..fields
    ]
    option.None -> fields
  }
}

fn prepend_reviewer_ids_field(
  fields: List(#(String, json.Json)),
  reviewer_user_ids: option.Option(List(String)),
) -> List(#(String, json.Json)) {
  case reviewer_user_ids {
    option.Some(ids) -> [
      #("reviewer_user_ids", json.array(ids, of: json.string)),
      ..fields
    ]
    option.None -> fields
  }
}

fn prepend_label_ids_field(
  fields: List(#(String, json.Json)),
  label_ids: option.Option(List(String)),
) -> List(#(String, json.Json)) {
  case label_ids {
    option.Some(ids) -> [
      #("label_ids", json.array(ids, of: json.string)),
      ..fields
    ]
    option.None -> fields
  }
}

fn prepend_draft_field(
  fields: List(#(String, json.Json)),
  draft: option.Option(Bool),
) -> List(#(String, json.Json)) {
  case draft {
    option.Some(value) -> [#("draft", json.bool(value)), ..fields]
    option.None -> fields
  }
}

pub fn create_label_body(name: String, color: String) -> json.Json {
  json.object([
    #("name", json.string(name)),
    #("color", json.string(color)),
  ])
}

pub fn create_mr_body(
  title: String,
  description: option.Option(String),
  source_branch: String,
  target_branch: String,
  draft: Bool,
) -> json.Json {
  json.object([
    #("title", json.string(title)),
    #("description", case description {
      option.Some(d) -> json.string(d)
      option.None -> json.null()
    }),
    #("source_branch", json.string(source_branch)),
    #("target_branch", json.string(target_branch)),
    #("draft", json.bool(draft)),
  ])
}

pub fn create_mr_comment_body(
  body: String,
  file_path: option.Option(String),
  line: option.Option(Int),
) -> json.Json {
  json.object([
    #("body", json.string(body)),
    #("file_path", case file_path {
      option.Some(p) -> json.string(p)
      option.None -> json.null()
    }),
    #("line", case line {
      option.Some(n) -> json.int(n)
      option.None -> json.null()
    }),
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
  Rebase
}

pub fn merge_request_merge_body(
  method: MergeMethod,
  delete_source_branch: Bool,
) -> json.Json {
  let value = case method {
    MergeCommit -> "merge"
    Squash -> "squash"
    Rebase -> "rebase"
  }
  json.object([
    #("merge_method", json.string(value)),
    #("delete_source_branch", json.bool(delete_source_branch)),
  ])
}
