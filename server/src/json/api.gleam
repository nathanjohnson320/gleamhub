import database.{
  type IssueAssigneeRow, type IssueCommentRow, type IssueMilestoneRow,
  type IssueRow, type KeyRow, type LabelRow, type LinkedIssueRow,
  type LinkedMergeRequestRow, type MergeRequestCommentRow,
  type MergeRequestReviewRow, type MergeRequestRow, type MilestoneRow,
  type NotificationRow, type OrgInvitationRow, type OrgMemberRow, type OrgRow,
  type PipelineRunRow, type ReleaseRow, type RepoRow, type UserRow,
  type UserStatsRow,
}
import git/exec.{
  type BlobContent, type CommitEntry, type ConflictFile, type ConflictFileSide,
  type DiffFile, type MergeCheck, type RepoTemplate, type TagInfo,
  type TreeEntry, type TreeEntryType, Blob, Submodule, Symlink, Tree,
}
import gleam/dict.{type Dict}
import gleam/json
import gleam/list
import gleam/option

pub fn org_json(org: OrgRow) -> json.Json {
  json.object([
    #("id", json.string(org.id)),
    #("slug", json.string(org.slug)),
    #("name", json.string(org.name)),
    #("role", case org.role {
      option.Some(role) -> json.string(role)
      option.None -> json.null()
    }),
  ])
}

pub fn orgs_json(orgs: List(OrgRow)) -> json.Json {
  json.array(orgs, of: org_json)
}

pub fn user_search_result_json(
  id: String,
  username: option.Option(String),
  display_name: String,
) -> json.Json {
  json.object([
    #("id", json.string(id)),
    #("username", case username {
      option.Some(name) -> json.string(name)
      option.None -> json.null()
    }),
    #("display_name", json.string(display_name)),
  ])
}

pub fn user_search_results_json(
  results: List(#(String, option.Option(String), String)),
) -> json.Json {
  json.array(results, of: fn(result) {
    let #(id, username, display_name) = result
    user_search_result_json(id, username, display_name)
  })
}

pub fn member_json(
  member: OrgMemberRow,
  display_name: String,
  username: option.Option(String),
) -> json.Json {
  json.object([
    #("user_id", json.string(member.user_id)),
    #("role", json.string(member.role)),
    #("display_name", json.string(display_name)),
    #("username", case username {
      option.Some(name) -> json.string(name)
      option.None -> json.null()
    }),
  ])
}

pub fn members_json(
  members: List(OrgMemberRow),
  display_names: Dict(String, String),
  usernames: Dict(String, String),
) -> json.Json {
  json.array(members, of: fn(member) {
    let name = case dict.get(display_names, member.user_id) {
      Ok(value) -> value
      Error(_) ->
        member.display_name
        |> option.unwrap(member.user_id)
    }
    let username = dict_get_option(usernames, member.user_id)
    member_json(member, name, username)
  })
}

pub fn invitation_json(
  invitation: OrgInvitationRow,
  invited_display_name: String,
  invited_username: option.Option(String),
  invited_by_display_name: String,
  invited_by_username: option.Option(String),
) -> json.Json {
  json.object([
    #("id", json.string(invitation.id)),
    #("invited_user_id", json.string(invitation.invited_user_id)),
    #("role", json.string(invitation.role)),
    #("display_name", json.string(invited_display_name)),
    #("username", case invited_username {
      option.Some(name) -> json.string(name)
      option.None -> json.null()
    }),
    #("invited_by", json.string(invitation.invited_by_user_id)),
    #("invited_by_display_name", json.string(invited_by_display_name)),
    #("invited_by_username", case invited_by_username {
      option.Some(name) -> json.string(name)
      option.None -> json.null()
    }),
    #("created_at", json.string(invitation.created_at)),
    #("org_slug", case invitation.org_slug {
      option.Some(slug) -> json.string(slug)
      option.None -> json.null()
    }),
    #("org_name", case invitation.org_name {
      option.Some(name) -> json.string(name)
      option.None -> json.null()
    }),
  ])
}

pub fn invitations_json(
  invitations: List(OrgInvitationRow),
  display_names: Dict(String, String),
  usernames: Dict(String, String),
) -> json.Json {
  json.array(invitations, of: fn(invitation) {
    let invited_name = case
      dict.get(display_names, invitation.invited_user_id)
    {
      Ok(value) -> value
      Error(_) -> invitation.invited_user_id
    }
    let invited_username =
      dict_get_option(usernames, invitation.invited_user_id)
    let invited_by_name = case
      dict.get(display_names, invitation.invited_by_user_id)
    {
      Ok(value) -> value
      Error(_) -> invitation.invited_by_user_id
    }
    let invited_by_username =
      dict_get_option(usernames, invitation.invited_by_user_id)
    invitation_json(
      invitation,
      invited_name,
      invited_username,
      invited_by_name,
      invited_by_username,
    )
  })
}

fn dict_get_option(
  dict: Dict(String, String),
  key: String,
) -> option.Option(String) {
  case dict.get(dict, key) {
    Ok(value) -> option.Some(value)
    Error(_) -> option.None
  }
}

pub fn repo_json(repo: RepoRow, clone_url: String) -> json.Json {
  json.object([
    #("id", json.string(repo.id)),
    #("name", json.string(repo.name)),
    #("org_slug", json.string(repo.org_slug)),
    #("clone_url", json.string(clone_url)),
    #("description", case repo.description {
      option.Some(d) -> json.string(d)
      option.None -> json.null()
    }),
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

pub fn me_json(
  user: UserRow,
  orgs: List(OrgRow),
  stats: UserStatsRow,
  unread_count: Int,
) -> json.Json {
  json.object([
    #("id", json.string(user.id)),
    #("display_name", case user.display_name {
      option.Some(n) -> json.string(n)
      option.None -> json.null()
    }),
    #("email", case user.email {
      option.Some(e) -> json.string(e)
      option.None -> json.null()
    }),
    #("organizations", orgs_json(orgs)),
    #("stats", user_stats_json(stats)),
    #("unread_notifications", json.int(unread_count)),
  ])
}

pub fn user_stats_json(stats: UserStatsRow) -> json.Json {
  json.object([
    #("open_merge_requests", json.int(stats.open_merge_requests)),
    #("merged_merge_requests", json.int(stats.merged_merge_requests)),
    #("open_issues_authored", json.int(stats.open_issues_authored)),
    #("open_issues_assigned", json.int(stats.open_issues_assigned)),
    #("reviews_given", json.int(stats.reviews_given)),
  ])
}

pub fn notification_json(notification: NotificationRow) -> json.Json {
  json.object([
    #("id", json.string(notification.id)),
    #("type", json.string(notification.notification_type)),
    #("payload", json.string(notification.payload)),
    #("read_at", case notification.read_at {
      option.Some(at) -> json.string(at)
      option.None -> json.null()
    }),
    #("created_at", json.string(notification.created_at)),
  ])
}

pub fn notifications_json(notifications: List(NotificationRow)) -> json.Json {
  json.array(notifications, of: notification_json)
}

pub fn access_json(read: Bool, write: Bool, user_id: String) -> json.Json {
  json.object([
    #("read", json.bool(read)),
    #("write", json.bool(write)),
    #("user_id", json.string(user_id)),
  ])
}

pub fn repo_detail_json(
  repo: RepoRow,
  clone_url: String,
  default_branch: option.Option(String),
  default_branch_pipeline: option.Option(PipelineRunRow),
  required_approvals: Int,
) -> json.Json {
  json.object([
    #("id", json.string(repo.id)),
    #("name", json.string(repo.name)),
    #("org_slug", json.string(repo.org_slug)),
    #("clone_url", json.string(clone_url)),
    #("description", case repo.description {
      option.Some(d) -> json.string(d)
      option.None -> json.null()
    }),
    #("default_branch", case default_branch {
      option.Some(ref) -> json.string(ref)
      option.None -> json.null()
    }),
    #(
      "default_branch_pipeline",
      case default_branch_pipeline {
        option.Some(run) -> pipeline_summary_json(run)
        option.None -> json.null()
      },
    ),
    #("required_approvals", json.int(required_approvals)),
  ])
}

pub fn branches_json(branches: List(String)) -> json.Json {
  json.object([#("branches", json.array(branches, of: json.string))])
}

fn tag_json(tag: TagInfo) -> json.Json {
  json.object([
    #("name", json.string(tag.name)),
    #("target_commit_sha", json.string(tag.target_commit_sha)),
    #("created_at", json.string(tag.created_at)),
    #("message", json.string(tag.message)),
  ])
}

pub fn tags_json(tags: List(TagInfo)) -> json.Json {
  json.object([#("tags", json.array(tags, of: tag_json))])
}

pub fn tag_detail_json(tag: TagInfo, commit: CommitEntry) -> json.Json {
  json.object([
    #("name", json.string(tag.name)),
    #("target_commit_sha", json.string(tag.target_commit_sha)),
    #("created_at", json.string(tag.created_at)),
    #("message", json.string(tag.message)),
    #("commit", commit_entry_json(commit)),
  ])
}

fn release_json_fields(
  release: ReleaseRow,
  author_name: String,
) -> List(#(String, json.Json)) {
  [
    #("id", json.string(release.id)),
    #("tag_name", json.string(release.tag_name)),
    #("target_commit_sha", json.string(release.target_commit_sha)),
    #("title", json.string(release.title)),
    #("body", json.string(release.body)),
    #("author_user_id", json.string(release.author_user_id)),
    #("author_name", json.string(author_name)),
    #("created_at", json.string(release.created_at)),
  ]
}

pub fn release_json(release: ReleaseRow, author_name: String) -> json.Json {
  json.object(release_json_fields(release, author_name))
}

pub fn releases_json(items: List(#(ReleaseRow, String))) -> json.Json {
  json.object([
    #(
      "releases",
      json.array(items, of: fn(pair) {
        let #(release, author_name) = pair
        release_json(release, author_name)
      }),
    ),
  ])
}

pub fn readme_json(ref: String, path: String, content: String) -> json.Json {
  json.object([
    #("ref", json.string(ref)),
    #("path", json.string(path)),
    #("content", json.string(content)),
  ])
}

pub fn merge_request_templates_json(
  ref: String,
  templates: List(RepoTemplate),
) -> json.Json {
  json.object([
    #("ref", json.string(ref)),
    #(
      "templates",
      json.array(templates, of: fn(template) {
        json.object([
          #("name", json.string(template.name)),
          #("path", json.string(template.path)),
          #("content", json.string(template.content)),
        ])
      }),
    ),
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

pub fn tree_json(
  ref: String,
  path: String,
  entries: List(TreeEntry),
) -> json.Json {
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

pub fn label_json(label: LabelRow) -> json.Json {
  json.object([
    #("id", json.string(label.id)),
    #("name", json.string(label.name)),
    #("color", json.string(label.color)),
  ])
}

pub fn labels_json(labels: List(LabelRow)) -> json.Json {
  json.object([
    #("labels", json.array(labels, of: label_json)),
  ])
}

pub fn issue_assignee_json(assignee: IssueAssigneeRow) -> json.Json {
  json.object([
    #("user_id", json.string(assignee.user_id)),
    #("display_name", json.string(assignee.display_name)),
  ])
}

pub fn merge_request_json(
  mr: MergeRequestRow,
  author_name: String,
) -> json.Json {
  json.object([
    #("id", json.string(mr.id)),
    #("number", json.int(mr.number)),
    #("title", json.string(mr.title)),
    #("description", optional_string(mr.description)),
    #("author_user_id", json.string(mr.author_user_id)),
    #("author_name", json.string(author_name)),
    #("source_branch", json.string(mr.source_branch)),
    #("target_branch", json.string(mr.target_branch)),
    #("state", json.string(mr.state)),
    #("is_draft", json.bool(mr.is_draft)),
    #("merge_commit_sha", optional_string(mr.merge_commit_sha)),
    #("merged_by_user_id", optional_string(mr.merged_by_user_id)),
    #("merged_at", optional_string(mr.merged_at)),
    #("closed_at", optional_string(mr.closed_at)),
    #("created_at", json.string(mr.created_at)),
    #("updated_at", json.string(mr.updated_at)),
    #("labels", json.array(mr.labels, of: label_json)),
    #("assignees", json.array(mr.assignees, of: issue_assignee_json)),
    #("reviewers", json.array(mr.reviewers, of: issue_assignee_json)),
  ])
}

pub fn pipeline_summary_json(run: PipelineRunRow) -> json.Json {
  json.object([
    #("id", json.string(run.id)),
    #("state", json.string(run.state)),
    #("commit_sha", json.string(run.commit_sha)),
    #("trigger", json.string(run.trigger)),
    #("module_path", case run.module_path {
      "" -> json.null()
      path -> json.string(path)
    }),
    #("entry_function", json.string(run.entry_function)),
    #("started_at", optional_string(run.started_at)),
    #("finished_at", optional_string(run.finished_at)),
    #("created_at", case run.created_at {
      "" -> json.null()
      at -> json.string(at)
    }),
    #("log", json.null()),
  ])
}

pub fn merge_request_list_item_json(
  mr: MergeRequestRow,
  pipeline: option.Option(PipelineRunRow),
) -> json.Json {
  json.object([
    #("id", json.string(mr.id)),
    #("number", json.int(mr.number)),
    #("title", json.string(mr.title)),
    #("description", optional_string(mr.description)),
    #("author_user_id", json.string(mr.author_user_id)),
    #("author_name", json.string(mr.author_user_id)),
    #("source_branch", json.string(mr.source_branch)),
    #("target_branch", json.string(mr.target_branch)),
    #("state", json.string(mr.state)),
    #("is_draft", json.bool(mr.is_draft)),
    #("merge_commit_sha", optional_string(mr.merge_commit_sha)),
    #("merged_by_user_id", optional_string(mr.merged_by_user_id)),
    #("merged_at", optional_string(mr.merged_at)),
    #("closed_at", optional_string(mr.closed_at)),
    #("created_at", json.string(mr.created_at)),
    #("updated_at", json.string(mr.updated_at)),
    #("pipeline", case pipeline {
      option.Some(run) -> pipeline_summary_json(run)
      option.None -> json.null()
    }),
    #("labels", json.array(mr.labels, of: label_json)),
    #("assignees", json.array(mr.assignees, of: issue_assignee_json)),
    #("reviewers", json.array(mr.reviewers, of: issue_assignee_json)),
  ])
}

pub fn merge_requests_json(
  mrs: List(MergeRequestRow),
  author_names: fn(String) -> String,
) -> json.Json {
  json.object([
    #(
      "merge_requests",
      json.array(mrs, of: fn(mr) {
        merge_request_json(mr, author_names(mr.author_user_id))
      }),
    ),
  ])
}

pub fn merge_requests_list_json(
  items: List(#(MergeRequestRow, option.Option(PipelineRunRow))),
) -> json.Json {
  json.object([
    #(
      "merge_requests",
      json.array(items, of: fn(pair) {
        let #(mr, pipeline) = pair
        merge_request_list_item_json(mr, pipeline)
      }),
    ),
  ])
}

pub fn merge_request_comment_json(
  comment: MergeRequestCommentRow,
  mentioned_usernames: List(String),
) -> json.Json {
  json.object([
    #("id", json.string(comment.id)),
    #("author_user_id", json.string(comment.author_user_id)),
    #("author_name", json.string(comment.author_name)),
    #("body", json.string(comment.body)),
    #("file_path", optional_string(comment.file_path)),
    #("line", case comment.line {
      option.Some(n) -> json.int(n)
      option.None -> json.null()
    }),
    #("mentioned_user_ids", json.array(comment.mentioned_user_ids, json.string)),
    #(
      "mentioned_usernames",
      json.array(mentioned_usernames, json.string),
    ),
    #("created_at", json.string(comment.created_at)),
    #("updated_at", json.string(comment.updated_at)),
  ])
}

pub fn merge_request_comments_json(
  comments: List(MergeRequestCommentRow),
  mentioned_usernames: fn(MergeRequestCommentRow) -> List(String),
) -> json.Json {
  json.object([
    #(
      "comments",
      json.array(comments, fn(comment) {
        merge_request_comment_json(comment, mentioned_usernames(comment))
      }),
    ),
  ])
}

pub fn linked_issue_json(issue: LinkedIssueRow) -> json.Json {
  json.object([
    #("number", json.int(issue.number)),
    #("title", json.string(issue.title)),
    #("state", json.string(issue.state)),
    #("link_type", json.string(issue.link_type)),
  ])
}

pub fn linked_merge_request_json(mr: LinkedMergeRequestRow) -> json.Json {
  json.object([
    #("number", json.int(mr.number)),
    #("title", json.string(mr.title)),
    #("state", json.string(mr.state)),
    #("is_draft", json.bool(mr.is_draft)),
    #("link_type", json.string(mr.link_type)),
  ])
}

fn issue_milestone_json(milestone: IssueMilestoneRow) -> json.Json {
  json.object([
    #("id", json.string(milestone.id)),
    #("number", json.int(milestone.number)),
    #("title", json.string(milestone.title)),
  ])
}

pub fn milestone_json(milestone: MilestoneRow) -> json.Json {
  json.object([
    #("id", json.string(milestone.id)),
    #("number", json.int(milestone.number)),
    #("title", json.string(milestone.title)),
    #("description", optional_string(milestone.description)),
    #("state", json.string(milestone.state)),
    #("due_on", optional_string(milestone.due_on)),
    #("closed_at", optional_string(milestone.closed_at)),
    #("created_at", json.string(milestone.created_at)),
    #("updated_at", json.string(milestone.updated_at)),
    #("open_issues", json.int(milestone.open_issues)),
    #("closed_issues", json.int(milestone.closed_issues)),
    #("open_mrs", json.int(milestone.open_mrs)),
  ])
}

pub fn milestones_json(milestones: List(MilestoneRow)) -> json.Json {
  json.object([
    #(
      "milestones",
      json.array(milestones, of: milestone_json),
    ),
  ])
}

pub fn issue_json(issue: IssueRow) -> json.Json {
  let milestone_field = case issue.milestone {
    option.Some(milestone) -> [
      #("milestone", issue_milestone_json(milestone)),
    ]
    option.None -> []
  }
  json.object(list.append(
    [
      #("id", json.string(issue.id)),
      #("number", json.int(issue.number)),
      #("title", json.string(issue.title)),
      #("description", optional_string(issue.description)),
      #("author_user_id", json.string(issue.author_user_id)),
      #("author_name", json.string(issue.author_name)),
      #("state", json.string(issue.state)),
      #("closed_at", optional_string(issue.closed_at)),
      #("created_at", json.string(issue.created_at)),
      #("updated_at", json.string(issue.updated_at)),
      #("labels", json.array(issue.labels, of: label_json)),
      #("assignees", json.array(issue.assignees, of: issue_assignee_json)),
    ],
    milestone_field,
  ))
}

pub fn issues_json(issues: List(IssueRow)) -> json.Json {
  json.object([
    #("issues", json.array(issues, of: issue_json)),
  ])
}

pub fn issue_comment_json(
  comment: IssueCommentRow,
  mentioned_usernames: List(String),
) -> json.Json {
  json.object([
    #("id", json.string(comment.id)),
    #("author_user_id", json.string(comment.author_user_id)),
    #("author_name", json.string(comment.author_name)),
    #("body", json.string(comment.body)),
    #("mentioned_user_ids", json.array(comment.mentioned_user_ids, json.string)),
    #(
      "mentioned_usernames",
      json.array(mentioned_usernames, json.string),
    ),
    #("created_at", json.string(comment.created_at)),
    #("updated_at", json.string(comment.updated_at)),
  ])
}

pub fn issue_comments_json(
  comments: List(IssueCommentRow),
  mentioned_usernames: fn(IssueCommentRow) -> List(String),
) -> json.Json {
  json.object([
    #(
      "comments",
      json.array(comments, fn(comment) {
        issue_comment_json(comment, mentioned_usernames(comment))
      }),
    ),
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

fn conflict_file_side_json(side: ConflictFileSide) -> json.Json {
  json.object([
    #("content", json.string(side.content)),
    #("encoding", json.string(side.encoding)),
    #("binary", json.bool(side.binary)),
    #("missing", json.bool(side.missing)),
  ])
}

pub fn conflict_file_json(file: ConflictFile) -> json.Json {
  json.object([
    #("path", json.string(file.path)),
    #("target_branch", json.string(file.target_branch)),
    #("source_branch", json.string(file.source_branch)),
    #("target", conflict_file_side_json(file.target)),
    #("source", conflict_file_side_json(file.source)),
  ])
}

pub fn merge_check_json(check: MergeCheck) -> json.Json {
  json.object([
    #("mergeable", json.bool(check.mergeable)),
    #("message", json.string(check.message)),
    #("behind_target", json.bool(check.behind_target)),
    #("conflict_paths", json.array(check.conflict_paths, json.string)),
    #("approval_count", json.int(check.approval_count)),
    #("required_approvals", json.int(check.required_approvals)),
  ])
}

pub fn merge_request_review_json(
  review: MergeRequestReviewRow,
) -> json.Json {
  json.object([
    #("id", json.string(review.id)),
    #("user_id", json.string(review.user_id)),
    #("reviewer_name", json.string(review.reviewer_name)),
    #("state", json.string(review.state)),
    #("body", case review.body {
      option.Some(body) -> json.string(body)
      option.None -> json.null()
    }),
    #("submitted_at", json.string(review.submitted_at)),
  ])
}

pub fn merge_request_reviews_json(
  reviews: List(MergeRequestReviewRow),
) -> json.Json {
  json.array(reviews, merge_request_review_json)
}

pub fn merge_request_review_list_json(
  reviews: List(MergeRequestReviewRow),
  reviewers: List(IssueAssigneeRow),
) -> json.Json {
  json.object([
    #("reviews", merge_request_reviews_json(reviews)),
    #("reviewers", json.array(reviewers, of: issue_assignee_json)),
  ])
}

pub fn pipeline_run_json(run: PipelineRunRow) -> json.Json {
  json.object([
    #("id", json.string(run.id)),
    #("state", json.string(run.state)),
    #("commit_sha", json.string(run.commit_sha)),
    #("trigger", json.string(run.trigger)),
    #("module_path", case run.module_path {
      "" -> json.null()
      path -> json.string(path)
    }),
    #("entry_function", json.string(run.entry_function)),
    #("started_at", case run.started_at {
      option.Some(at) -> json.string(at)
      option.None -> json.null()
    }),
    #("finished_at", case run.finished_at {
      option.Some(at) -> json.string(at)
      option.None -> json.null()
    }),
    #("created_at", case run.created_at {
      "" -> json.null()
      at -> json.string(at)
    }),
    #("log", case run.log_text {
      "" -> json.null()
      text -> json.string(text)
    }),
  ])
}

pub fn pipeline_runs_json(runs: List(PipelineRunRow)) -> json.Json {
  json.object([
    #("pipelines", json.array(runs, of: pipeline_run_json)),
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
