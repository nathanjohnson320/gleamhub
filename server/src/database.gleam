import database/list_filter
import gleam/dict.{type Dict}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import http/list_query as list_query
import mentions/store as mention_store
import pog
import sql
import youid/uuid

pub type UserRow {
  UserRow(id: String, display_name: Option(String), email: Option(String))
}

pub type OrgRow {
  OrgRow(id: String, slug: String, name: String, role: Option(String))
}

pub type RepoRow {
  RepoRow(
    id: String,
    name: String,
    description: Option(String),
    disk_path: String,
    org_slug: String,
  )
}

pub type KeyRow {
  KeyRow(id: String, title: String, public_key: String, fingerprint: String)
}

pub type LabelRow {
  LabelRow(id: String, name: String, color: String)
}

pub type ReleaseRow {
  ReleaseRow(
    id: String,
    tag_name: String,
    target_commit_sha: String,
    title: String,
    body: String,
    author_user_id: String,
    created_at: String,
  )
}

pub type ReleaseError {
  DuplicateRelease
  InvalidReleaseTitle
  InvalidTagName
  TagNotFound
  ReleaseNotFound
}

pub type IssueAssigneeRow {
  IssueAssigneeRow(user_id: String, display_name: String)
}

pub type IssueMilestoneRow {
  IssueMilestoneRow(id: String, number: Int, title: String)
}

pub type MilestoneRow {
  MilestoneRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    state: String,
    due_on: Option(String),
    closed_at: Option(String),
    created_at: String,
    updated_at: String,
    open_issues: Int,
    closed_issues: Int,
    open_mrs: Int,
  )
}

pub type MilestoneError {
  InvalidMilestoneTitle
  MilestoneNotFound
  InvalidMilestone
}

pub type LabelError {
  InvalidLabelName
  InvalidLabelColor
  DuplicateLabelName
  LabelNotFound
  InvalidLabelIds
  InvalidAssignees
  AuthorCannotReview
}

pub type MergeRequestRow {
  MergeRequestRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    author_user_id: String,
    source_branch: String,
    target_branch: String,
    state: String,
    is_draft: Bool,
    merge_commit_sha: Option(String),
    merged_by_user_id: Option(String),
    merged_at: Option(String),
    closed_at: Option(String),
    created_at: String,
    updated_at: String,
    labels: List(LabelRow),
    assignees: List(IssueAssigneeRow),
    reviewers: List(IssueAssigneeRow),
  )
}

pub type MergeRequestCommentRow {
  MergeRequestCommentRow(
    id: String,
    author_user_id: String,
    author_name: String,
    body: String,
    file_path: Option(String),
    line: Option(Int),
    mentioned_user_ids: List(String),
    created_at: String,
    updated_at: String,
  )
}

pub type MergeRequestReviewRow {
  MergeRequestReviewRow(
    id: String,
    merge_request_id: String,
    user_id: String,
    reviewer_name: String,
    state: String,
    body: Option(String),
    submitted_at: String,
  )
}

pub type ReviewError {
  InvalidReviewState
  AuthorCannotApprove
}

pub type PipelineRunRow {
  PipelineRunRow(
    id: String,
    repository_id: String,
    merge_request_id: String,
    commit_sha: String,
    module_path: String,
    entry_function: String,
    state: String,
    trigger: String,
    log_text: String,
    started_at: Option(String),
    finished_at: Option(String),
    created_at: String,
  )
}

pub type PipelineRunJobRow {
  PipelineRunJobRow(
    id: String,
    repository_id: String,
    merge_request_id: String,
    commit_sha: String,
    module_path: String,
    entry_function: String,
    state: String,
    trigger: String,
    org_slug: String,
    repo_name: String,
    disk_path: String,
  )
}

pub type IssueRow {
  IssueRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    author_user_id: String,
    author_name: String,
    state: String,
    closed_at: Option(String),
    created_at: String,
    updated_at: String,
    labels: List(LabelRow),
    assignees: List(IssueAssigneeRow),
    milestone: Option(IssueMilestoneRow),
  )
}

pub type LinkedIssueRow {
  LinkedIssueRow(number: Int, title: String, state: String, link_type: String)
}

pub type LinkedMergeRequestRow {
  LinkedMergeRequestRow(
    number: Int,
    title: String,
    state: String,
    is_draft: Bool,
    link_type: String,
  )
}

pub type ClosesIssueRef {
  ClosesIssueRef(number: Int, repo_name: String)
}

pub type IssueCommentRow {
  IssueCommentRow(
    id: String,
    author_user_id: String,
    author_name: String,
    body: String,
    mentioned_user_ids: List(String),
    created_at: String,
    updated_at: String,
  )
}

pub type NotificationRow {
  NotificationRow(
    id: String,
    notification_type: String,
    payload: String,
    read_at: Option(String),
    created_at: String,
  )
}

pub type UserStatsRow {
  UserStatsRow(
    open_merge_requests: Int,
    merged_merge_requests: Int,
    open_issues_authored: Int,
    open_issues_assigned: Int,
    reviews_given: Int,
  )
}

pub type MrBriefRow {
  MrBriefRow(
    id: String,
    number: Int,
    title: String,
    author_user_id: String,
    org_slug: String,
    repo_name: String,
  )
}

pub fn display_name_from_email(email: Option(String)) -> Option(String) {
  case email {
    option.None -> option.None
    option.Some(e) ->
      case string.split(e, on: "@") {
        [local, ..] -> option.Some(local)
        _ -> option.Some(e)
      }
  }
}

pub fn upsert_session_user(
  db: pog.Connection,
  user_id: String,
  display_name: Option(String),
  email: Option(String),
) -> Result(Nil, pog.QueryError) {
  let display = case display_name {
    option.Some(_) as from_jwt -> from_jwt
    option.None -> display_name_from_email(email)
  }
  upsert_user(db, user_id, display, email)
}

pub fn upsert_user(
  db: pog.Connection,
  id: String,
  display_name: Option(String),
  email: Option(String),
) -> Result(Nil, pog.QueryError) {
  sql.users_upsert(db, id, nullable_text(display_name), nullable_text(email))
  |> result_map_ok
}

pub fn lookup_user_display_names(
  db: pog.Connection,
  user_ids: List(String),
) -> Result(Dict(String, String), pog.QueryError) {
  let names =
    list.fold(user_ids, dict.new(), fn(acc, user_id) {
      case result_map_optional_row(sql.users_get_display_name(db, user_id)) {
        Ok(option.Some(row)) ->
          case row.display_name {
            option.Some(name) ->
              case string.trim(name) {
                "" -> acc
                trimmed -> dict.insert(acc, user_id, trimmed)
              }
            option.None -> acc
          }
        Ok(option.None) | Error(_) -> acc
      }
    })
  Ok(names)
}

pub fn comment_with_author_name(
  comment: MergeRequestCommentRow,
  author_name: String,
) -> MergeRequestCommentRow {
  MergeRequestCommentRow(..comment, author_name:)
}

pub fn issue_comment_with_author_name(
  comment: IssueCommentRow,
  author_name: String,
) -> IssueCommentRow {
  IssueCommentRow(..comment, author_name:)
}

pub fn issue_with_author_name(
  issue: IssueRow,
  author_name: String,
) -> IssueRow {
  IssueRow(..issue, author_name:)
}

pub fn list_orgs_for_user(
  db: pog.Connection,
  user_id: String,
) -> Result(List(OrgRow), pog.QueryError) {
  sql.orgs_list_for_user(db, user_id)
  |> result_map_rows
  |> result.map(list.map(_, org_from_list_row))
}

pub fn get_org_by_slug(
  db: pog.Connection,
  slug: String,
) -> Result(Option(OrgRow), pog.QueryError) {
  sql.orgs_get_by_slug(db, slug)
  |> result_map_optional_row
  |> result.map(option.map(_, org_from_get_row))
}

pub fn create_org(
  db: pog.Connection,
  slug: String,
  name: String,
  owner_id: String,
) -> Result(OrgRow, pog.QueryError) {
  case
    pog.transaction(db, fn(db) { create_org_queries(db, slug, name, owner_id) })
  {
    Ok(org) -> Ok(org)
    Error(pog.TransactionRolledBack(e)) -> Error(e)
    Error(pog.TransactionQueryError(e)) -> Error(e)
  }
}

fn create_org_queries(
  db: pog.Connection,
  slug: String,
  name: String,
  owner_id: String,
) -> Result(OrgRow, pog.QueryError) {
  case sql.orgs_insert(db, slug, name) {
    Ok(returned) ->
      case returned.rows {
        [row] -> {
          let assert Ok(org_uuid) = uuid.from_string(row.id)
          case sql.org_members_insert(db, org_uuid, owner_id, "owner") {
            Ok(_) ->
              Ok(OrgRow(
                id: row.id,
                slug: row.slug,
                name: row.name,
                role: option.Some("owner"),
              ))
            Error(e) -> Error(e)
          }
        }
        _ -> Error(pog.ConstraintViolated("no org row", "organizations", ""))
      }
    Error(e) -> Error(e)
  }
}

pub fn is_org_member(
  db: pog.Connection,
  user_id: String,
  org_slug: String,
) -> Bool {
  case member_role(db, user_id, org_slug) {
    Ok(option.Some(_)) -> True
    _ -> False
  }
}

pub fn is_org_owner(
  db: pog.Connection,
  user_id: String,
  org_slug: String,
) -> Bool {
  case member_role(db, user_id, org_slug) {
    Ok(option.Some("owner")) -> True
    _ -> False
  }
}

pub fn member_can_write(
  db: pog.Connection,
  user_id: String,
  org_slug: String,
) -> Bool {
  case member_role(db, user_id, org_slug) {
    Ok(option.Some(role)) -> role == "owner" || role == "member"
    _ -> False
  }
}

pub fn member_role(
  db: pog.Connection,
  user_id: String,
  org_slug: String,
) -> Result(Option(String), pog.QueryError) {
  sql.org_member_role(db, user_id, org_slug)
  |> result_map_optional_row
  |> result.map(option.map(_, fn(row) { row.role }))
}

pub type OrgMemberRow {
  OrgMemberRow(user_id: String, role: String, display_name: Option(String))
}

pub type OrgInvitationRow {
  OrgInvitationRow(
    id: String,
    invited_user_id: String,
    role: String,
    invited_by_user_id: String,
    created_at: String,
    org_slug: Option(String),
    org_name: Option(String),
  )
}

pub type MemberError {
  AlreadyMember
  AlreadyInvited
  CannotInviteSelf
  InvitationNotFound
  LastOwner
  NotInvitationTarget
  NotMember
}

fn member_from_list_row(row: sql.OrgMembersListRow) -> OrgMemberRow {
  OrgMemberRow(
    user_id: row.user_id,
    role: row.role,
    display_name: row.display_name,
  )
}

fn invitation_from_list_row(
  row: sql.OrgInvitationsListRow,
) -> OrgInvitationRow {
  OrgInvitationRow(
    id: row.id,
    invited_user_id: row.invited_user_id,
    role: row.role,
    invited_by_user_id: row.invited_by_user_id,
    created_at: row.created_at,
    org_slug: option.None,
    org_name: option.None,
  )
}

fn invitation_from_user_list_row(
  row: sql.OrgInvitationsListForUserRow,
) -> OrgInvitationRow {
  OrgInvitationRow(
    id: row.id,
    invited_user_id: row.invited_user_id,
    role: row.role,
    invited_by_user_id: row.invited_by_user_id,
    created_at: row.created_at,
    org_slug: option.Some(row.slug),
    org_name: option.Some(row.name),
  )
}

fn invitation_from_get_row(row: sql.OrgInvitationsGetRow) -> OrgInvitationRow {
  OrgInvitationRow(
    id: row.id,
    invited_user_id: row.invited_user_id,
    role: row.role,
    invited_by_user_id: row.invited_by_user_id,
    created_at: row.created_at,
    org_slug: option.Some(row.slug),
    org_name: option.Some(row.name),
  )
}

pub fn list_org_members(
  db: pog.Connection,
  org_slug: String,
) -> Result(List(OrgMemberRow), pog.QueryError) {
  sql.org_members_list(db, org_slug)
  |> result_map_rows
  |> result.map(list.map(_, member_from_list_row))
}

pub fn list_org_member_ids(
  db: pog.Connection,
  org_slug: String,
) -> Result(List(String), pog.QueryError) {
  list_org_members(db, org_slug)
  |> result.map(list.map(_, fn(member) { member.user_id }))
}

pub fn count_org_owners(
  db: pog.Connection,
  org_slug: String,
) -> Result(Int, pog.QueryError) {
  sql.org_members_count_owners(db, org_slug)
  |> result_map_first_row
  |> result.map(fn(row) { row.count })
}

pub fn update_member_role(
  db: pog.Connection,
  org_slug: String,
  user_id: String,
  new_role: String,
) -> Result(Nil, MemberError) {
  case member_role(db, user_id, org_slug) {
    Ok(option.None) -> Error(NotMember)
    Error(_) -> Error(NotMember)
    Ok(option.Some(current)) ->
      case current == new_role {
        True -> Ok(Nil)
        False ->
          case current, new_role {
            "owner", "member" ->
              case count_org_owners(db, org_slug) {
                Ok(1) -> Error(LastOwner)
                Ok(_) ->
                  case sql.org_members_update(db, org_slug, user_id, new_role) {
                    Ok(_) -> Ok(Nil)
                    Error(_) -> Error(NotMember)
                  }
                Error(_) -> Error(NotMember)
              }
            _, _ ->
              case sql.org_members_update(db, org_slug, user_id, new_role) {
                Ok(_) -> Ok(Nil)
                Error(_) -> Error(NotMember)
              }
          }
      }
  }
}

pub fn remove_org_member(
  db: pog.Connection,
  org_slug: String,
  user_id: String,
) -> Result(Nil, MemberError) {
  case member_role(db, user_id, org_slug) {
    Ok(option.None) -> Error(NotMember)
    Error(_) -> Error(NotMember)
    Ok(option.Some(role)) ->
      case role {
        "owner" ->
          case count_org_owners(db, org_slug) {
            Ok(1) -> Error(LastOwner)
            Ok(_) ->
              case sql.org_members_delete(db, org_slug, user_id) {
                Ok(_) -> Ok(Nil)
                Error(_) -> Error(NotMember)
              }
            Error(_) -> Error(NotMember)
          }
        _ ->
          case sql.org_members_delete(db, org_slug, user_id) {
            Ok(_) -> Ok(Nil)
            Error(_) -> Error(NotMember)
          }
      }
  }
}

pub fn list_org_invitations(
  db: pog.Connection,
  org_slug: String,
) -> Result(List(OrgInvitationRow), pog.QueryError) {
  sql.org_invitations_list(db, org_slug)
  |> result_map_rows
  |> result.map(list.map(_, invitation_from_list_row))
}

pub fn list_invitations_for_user(
  db: pog.Connection,
  user_id: String,
) -> Result(List(OrgInvitationRow), pog.QueryError) {
  sql.org_invitations_list_for_user(db, user_id)
  |> result_map_rows
  |> result.map(list.map(_, invitation_from_user_list_row))
}

pub fn get_invitation(
  db: pog.Connection,
  invitation_id: String,
) -> Result(Option(OrgInvitationRow), pog.QueryError) {
  case uuid.from_string(invitation_id) {
    Ok(id) ->
      sql.org_invitations_get(db, id)
      |> result_map_optional_row
      |> result.map(option.map(_, invitation_from_get_row))
    Error(_) -> Ok(option.None)
  }
}

pub fn create_org_invitation(
  db: pog.Connection,
  org_slug: String,
  invited_user_id: String,
  invited_by_user_id: String,
  role: String,
) -> Result(OrgInvitationRow, MemberError) {
  case invited_user_id == invited_by_user_id {
    True -> Error(CannotInviteSelf)
    False ->
      case is_org_member(db, invited_user_id, org_slug) {
        True -> Error(AlreadyMember)
        False ->
          case get_org_by_slug(db, org_slug) {
            Ok(option.Some(org)) -> {
              let assert Ok(org_uuid) = uuid.from_string(org.id)
              case
                sql.org_invitations_insert(
                  db,
                  org_uuid,
                  invited_user_id,
                  role,
                  invited_by_user_id,
                )
              {
                Ok(returned) ->
                  case returned.rows {
                    [row] ->
                      Ok(OrgInvitationRow(
                        id: row.id,
                        invited_user_id:,
                        role:,
                        invited_by_user_id:,
                        created_at: "",
                        org_slug: option.Some(org.slug),
                        org_name: option.Some(org.name),
                      ))
                    _ -> Error(AlreadyInvited)
                  }
                Error(pog.ConstraintViolated(..)) -> Error(AlreadyInvited)
                Error(_) -> Error(AlreadyInvited)
              }
            }
            Ok(option.None) -> Error(NotMember)
            Error(_) -> Error(NotMember)
          }
      }
  }
}

pub fn cancel_org_invitation(
  db: pog.Connection,
  org_slug: String,
  invitation_id: String,
) -> Result(Nil, MemberError) {
  case uuid.from_string(invitation_id) {
    Ok(id) ->
      case sql.org_invitations_delete(db, org_slug, id) {
        Ok(returned) ->
          case returned.rows {
            [_] -> Ok(Nil)
            _ -> Error(InvitationNotFound)
          }
        Error(_) -> Error(InvitationNotFound)
      }
    Error(_) -> Error(InvitationNotFound)
  }
}

pub fn decline_invitation(
  db: pog.Connection,
  invitation_id: String,
  user_id: String,
) -> Result(Nil, MemberError) {
  case uuid.from_string(invitation_id) {
    Ok(id) ->
      case sql.org_invitations_delete_by_id(db, id, user_id) {
        Ok(returned) ->
          case returned.rows {
            [_] -> Ok(Nil)
            _ -> Error(NotInvitationTarget)
          }
        Error(_) -> Error(NotInvitationTarget)
      }
    Error(_) -> Error(InvitationNotFound)
  }
}

pub fn accept_invitation(
  db: pog.Connection,
  invitation_id: String,
  user_id: String,
) -> Result(String, MemberError) {
  case uuid.from_string(invitation_id) {
    Error(_) -> Error(InvitationNotFound)
    Ok(id) ->
      case
        pog.transaction(db, fn(db) {
          accept_invitation_queries(db, id, user_id)
        })
      {
        Ok(org_slug) -> Ok(org_slug)
        Error(pog.TransactionRolledBack(e)) -> Error(e)
        Error(pog.TransactionQueryError(_)) -> Error(InvitationNotFound)
      }
  }
}

fn accept_invitation_queries(
  db: pog.Connection,
  invitation_id: uuid.Uuid,
  user_id: String,
) -> Result(String, MemberError) {
  case result_map_optional_row(sql.org_invitations_get(db, invitation_id)) {
    Ok(option.None) -> Error(InvitationNotFound)
    Error(_) -> Error(InvitationNotFound)
    Ok(option.Some(row)) ->
      case row.invited_user_id == user_id {
        False -> Error(NotInvitationTarget)
        True ->
          case is_org_member(db, user_id, row.slug) {
            True -> Error(AlreadyMember)
            False ->
              case get_org_by_slug(db, row.slug) {
                Ok(option.Some(org)) -> {
                  let assert Ok(org_uuid) = uuid.from_string(org.id)
                  case sql.org_members_insert(db, org_uuid, user_id, row.role) {
                    Ok(_) ->
                      case
                        sql.org_invitations_delete_by_id(
                          db,
                          invitation_id,
                          user_id,
                        )
                      {
                        Ok(returned) ->
                          case returned.rows {
                            [_] -> Ok(row.slug)
                            _ -> Error(InvitationNotFound)
                          }
                        Error(_) -> Error(InvitationNotFound)
                      }
                    Error(_) -> Error(AlreadyMember)
                  }
                }
                Ok(option.None) | Error(_) -> Error(InvitationNotFound)
              }
          }
      }
  }
}

pub fn repo_exists_for_org(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
) -> Bool {
  case get_repo(db, org_slug, repo_name) {
    Ok(option.Some(_)) -> True
    _ -> False
  }
}

pub fn list_repos(
  db: pog.Connection,
  org_slug: String,
) -> Result(List(RepoRow), pog.QueryError) {
  sql.repos_list(db, org_slug)
  |> result_map_rows
  |> result.map(list.map(_, repo_from_list_row))
}

pub fn get_repo(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
) -> Result(Option(RepoRow), pog.QueryError) {
  sql.repos_get(db, org_slug, repo_name)
  |> result_map_optional_row
  |> result.map(option.map(_, repo_from_get_row))
}

pub fn delete_repo(
  db: pog.Connection,
  org_slug: String,
  repo_id: String,
) -> Result(String, pog.QueryError) {
  sql.repos_delete(db, org_slug, repo_id)
  |> result_map_first_row
  |> result.map(fn(row) { row.disk_path })
}

pub fn rename_repo(
  db: pog.Connection,
  org_slug: String,
  current_name: String,
  new_name: String,
  new_disk_path: String,
) -> Result(RepoRow, pog.QueryError) {
  sql.repos_update(db, org_slug, current_name, new_name, new_disk_path)
  |> result_map_first_row
  |> result.map(repo_from_update_row)
}

pub fn update_repo_description(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  description: Option(String),
) -> Result(RepoRow, pog.QueryError) {
  sql.repos_update_description(
    db,
    org_slug,
    repo_name,
    nullable_text(description),
  )
  |> result_map_first_row
  |> result.map(repo_from_description_update_row)
}

pub fn insert_repo(
  db: pog.Connection,
  org_slug: String,
  name: String,
  description: Option(String),
  disk_path: String,
) -> Result(RepoRow, pog.QueryError) {
  sql.repos_insert(db, org_slug, name, nullable_text(description), disk_path)
  |> result_map_first_row
  |> result.map(fn(row) {
    RepoRow(
      id: row.id,
      name: row.name,
      description: row.description,
      disk_path: row.disk_path,
      org_slug:,
    )
  })
}

pub fn list_keys(
  db: pog.Connection,
  user_id: String,
) -> Result(List(KeyRow), pog.QueryError) {
  sql.keys_list(db, user_id)
  |> result_map_rows
  |> result.map(list.map(_, key_from_list_row))
}

pub fn insert_key(
  db: pog.Connection,
  user_id: String,
  title: String,
  public_key: String,
  key_blob: String,
  fingerprint: String,
) -> Result(KeyRow, pog.QueryError) {
  sql.keys_insert(db, user_id, title, public_key, key_blob, fingerprint)
  |> result_map_first_row
  |> result.map(key_from_insert_row)
}

pub fn delete_key(
  db: pog.Connection,
  user_id: String,
  key_id: String,
) -> Result(Bool, pog.QueryError) {
  sql.keys_delete(db, key_id, user_id)
  |> result_map_ok
  |> result.map(fn(_) { True })
}

pub fn find_user_for_key_blob(
  db: pog.Connection,
  key_blob: String,
) -> Result(Option(String), pog.QueryError) {
  sql.keys_find_user_for_blob(db, key_blob)
  |> result_map_optional_row
  |> result.map(option.map(_, fn(row) { row.user_id }))
}

pub fn resolve_user_for_key_in_repo(
  db: pog.Connection,
  key_blob: String,
  org_slug: String,
  repo_name: String,
) -> Result(Option(String), pog.QueryError) {
  sql.keys_resolve_user_for_org_repo(db, key_blob, org_slug, repo_name)
  |> result_map_optional_row
  |> result.map(option.map(_, fn(row) { row.user_id }))
}

pub fn authorized_key_line(
  db: pog.Connection,
  key_blob: String,
) -> Result(Option(String), pog.QueryError) {
  sql.keys_authorized_line(db, key_blob)
  |> result_map_optional_row
  |> result.map(
    option.map(_, fn(row) { format_authorized_line(key_blob, row) }),
  )
}

pub fn list_protected_branches(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
) -> Result(List(String), pog.QueryError) {
  sql.pb_list(db, org_slug, repo_name)
  |> result_map_rows
  |> result.map(list.map(_, fn(row) { row.branch_name }))
}

pub fn replace_protected_branches(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  branches: List(String),
) -> Result(List(String), pog.QueryError) {
  use _ <- result.try(sql.pb_delete_for_repo(db, org_slug, repo_name))
  insert_protected_branches(db, org_slug, repo_name, branches, [])
}

fn insert_protected_branches(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  branches: List(String),
  acc: List(String),
) -> Result(List(String), pog.QueryError) {
  case branches {
    [] -> Ok(acc)
    [branch, ..rest] -> {
      use inserted <- result.try(
        sql.pb_insert(db, org_slug, repo_name, branch)
        |> result_map_first_row
        |> result.map(fn(row) { row.branch_name }),
      )
      insert_protected_branches(db, org_slug, repo_name, rest, [inserted, ..acc])
    }
  }
}

pub fn is_branch_protected(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  branch_name: String,
) -> Result(Bool, pog.QueryError) {
  sql.pb_is_protected(db, org_slug, repo_name, branch_name)
  |> result_map_rows
  |> result.map(fn(rows) { rows != [] })
}

pub fn list_merge_requests(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
) -> Result(List(MergeRequestRow), pog.QueryError) {
  list_merge_requests_filtered(
    db,
    org_slug,
    repo_name,
    list_query.MergeRequestListQuery(
      state: "all",
      label_ids: [],
      author: option.None,
      q: option.None,
      source_branch: option.None,
      target_branch: option.None,
      sort: "number",
      order: "desc",
    ),
  )
}

pub fn list_merge_requests_filtered(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  query: list_query.MergeRequestListQuery,
) -> Result(List(MergeRequestRow), pog.QueryError) {
  list_filter.list_merge_requests_filtered(db, org_slug, repo_name, query)
  |> result_map_rows
  |> result.map(list.map(_, mr_from_list_row))
}

pub fn get_merge_request(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
) -> Result(Option(MergeRequestRow), pog.QueryError) {
  sql.mr_get(db, org_slug, repo_name, number)
  |> result_map_optional_row
  |> result.map(option.map(_, mr_from_get_row))
}

pub fn find_open_merge_request(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  source_branch: String,
  target_branch: String,
) -> Result(Option(Int), pog.QueryError) {
  sql.mr_find_open(db, org_slug, repo_name, source_branch, target_branch)
  |> result_map_optional_row
  |> result.map(option.map(_, fn(row) { row.number }))
}

pub fn insert_merge_request(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  title: String,
  description: Option(String),
  author_user_id: String,
  source_branch: String,
  target_branch: String,
  is_draft: Bool,
) -> Result(MergeRequestRow, pog.QueryError) {
  sql.mr_insert(
    db,
    org_slug,
    repo_name,
    title,
    nullable_text(description),
    author_user_id,
    source_branch,
    target_branch,
    is_draft,
  )
  |> result_map_first_row
  |> result.map(mr_from_insert_row)
}

pub fn update_merge_request_is_draft(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
  is_draft: Bool,
) -> Result(MergeRequestRow, pog.QueryError) {
  sql.mr_update_is_draft(db, org_slug, repo_name, number, is_draft)
  |> result_map_first_row
  |> result.map(mr_from_update_is_draft_row)
}

pub fn update_merge_request(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
  title: String,
  description: Option(String),
) -> Result(MergeRequestRow, pog.QueryError) {
  sql.mr_update(db, org_slug, repo_name, number, title, nullable_text(description))
  |> result_map_first_row
  |> result.map(mr_from_update_row)
}

pub fn merge_merge_request(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
  merge_commit_sha: String,
  merged_by_user_id: String,
) -> Result(MergeRequestRow, pog.QueryError) {
  sql.mr_merge(
    db,
    org_slug,
    repo_name,
    number,
    merge_commit_sha,
    merged_by_user_id,
  )
  |> result_map_first_row
  |> result.map(mr_from_merge_row)
}

pub fn close_merge_request(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
) -> Result(MergeRequestRow, pog.QueryError) {
  sql.mr_close(db, org_slug, repo_name, number)
  |> result_map_first_row
  |> result.map(mr_from_close_row)
}

pub fn list_merge_request_comments(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
) -> Result(List(MergeRequestCommentRow), pog.QueryError) {
  sql.mr_comments_list(db, org_slug, repo_name, number)
  |> result_map_rows
  |> result.map(list.map(_, mr_comment_from_list_row))
}

pub fn insert_merge_request_comment(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
  author_user_id: String,
  body: String,
  file_path: Option(String),
  line: Option(Int),
  mentioned_user_ids: List(String),
) -> Result(MergeRequestCommentRow, pog.QueryError) {
  sql.mr_comments_insert(
    db,
    org_slug,
    repo_name,
    number,
    author_user_id,
    body,
    nullable_text(file_path),
    case line {
      option.Some(n) -> n
      option.None -> 0
    },
    mention_store.encode_user_ids(mentioned_user_ids),
  )
  |> result_map_first_row
  |> result.map(mr_comment_from_insert_row)
}

pub fn get_merge_request_comment(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
  comment_id: String,
) -> Result(Option(MergeRequestCommentRow), pog.QueryError) {
  case uuid.from_string(comment_id) {
    Error(_) -> Ok(option.None)
    Ok(comment_uuid) ->
      sql.mr_comment_get(db, org_slug, repo_name, number, comment_uuid)
      |> result_map_optional_row
      |> result.map(option.map(_, mr_comment_from_get_row))
  }
}

pub fn update_merge_request_comment(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
  comment_id: String,
  body: String,
  mentioned_user_ids: List(String),
) -> Result(Option(MergeRequestCommentRow), pog.QueryError) {
  case uuid.from_string(comment_id) {
    Error(_) -> Ok(option.None)
    Ok(comment_uuid) ->
      sql.mr_comment_update(
        db,
        org_slug,
        repo_name,
        number,
        comment_uuid,
        body,
        mention_store.encode_user_ids(mentioned_user_ids),
      )
      |> result_map_optional_row
      |> result.map(option.map(_, mr_comment_from_update_row))
  }
}

pub fn delete_merge_request_comment(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
  comment_id: String,
) -> Result(Bool, pog.QueryError) {
  case uuid.from_string(comment_id) {
    Error(_) -> Ok(False)
    Ok(comment_uuid) ->
      sql.mr_comment_delete(db, org_slug, repo_name, number, comment_uuid)
      |> result_map_optional_row
      |> result.map(option.is_some)
  }
}

pub fn get_required_approvals(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
) -> Result(Int, pog.QueryError) {
  sql.repos_required_approvals_get(db, org_slug, repo_name)
  |> result_map_first_row
  |> result.map(fn(row) { row.required_approvals })
}

pub fn set_required_approvals(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  required_approvals: Int,
) -> Result(Int, pog.QueryError) {
  sql.repos_required_approvals_update(
    db,
    org_slug,
    repo_name,
    required_approvals,
  )
  |> result_map_first_row
  |> result.map(fn(row) { row.required_approvals })
}

pub fn count_merge_request_approvals(
  db: pog.Connection,
  merge_request_id: String,
  author_user_id: String,
) -> Result(Int, pog.QueryError) {
  let assert Ok(mr_uuid) = uuid.from_string(merge_request_id)
  sql.mr_review_approval_count(db, mr_uuid, author_user_id)
  |> result_map_first_row
  |> result.map(fn(row) { row.approval_count })
}

pub fn count_merge_request_changes_requested(
  db: pog.Connection,
  merge_request_id: String,
) -> Result(Int, pog.QueryError) {
  let assert Ok(mr_uuid) = uuid.from_string(merge_request_id)
  sql.mr_review_changes_requested_count(db, mr_uuid)
  |> result_map_first_row
  |> result.map(fn(row) { row.changes_requested_count })
}

pub fn list_merge_request_reviews(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
) -> Result(List(MergeRequestReviewRow), pog.QueryError) {
  sql.mr_reviews_list(db, org_slug, repo_name, number)
  |> result_map_rows
  |> result.map(list.map(_, mr_review_from_list_row))
}

pub fn insert_merge_request_review(
  db: pog.Connection,
  merge_request_id: String,
  user_id: String,
  state: String,
  body: String,
) -> Result(MergeRequestReviewRow, pog.QueryError) {
  let assert Ok(mr_uuid) = uuid.from_string(merge_request_id)
  sql.mr_review_insert(db, mr_uuid, user_id, state, body)
  |> result_map_first_row
  |> result.map(mr_review_from_insert_row)
}

pub fn list_open_merge_requests_by_source(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  source_branch: String,
) -> Result(List(MergeRequestRow), pog.QueryError) {
  sql.mr_list_open_by_source(db, org_slug, repo_name, source_branch)
  |> result_map_rows
  |> result.map(list.map(_, mr_from_open_by_source_row))
}

pub fn pipeline_run_exists_for_sha(
  db: pog.Connection,
  merge_request_id: String,
  commit_sha: String,
) -> Result(Bool, pog.QueryError) {
  let assert Ok(mr_uuid) = uuid.from_string(merge_request_id)
  sql.pipeline_run_exists_for_sha(db, mr_uuid, commit_sha)
  |> result_map_rows
  |> result.map(fn(rows) { rows != [] })
}

pub fn insert_pipeline_run(
  db: pog.Connection,
  repository_id: String,
  merge_request_id: String,
  commit_sha: String,
  module_path: Option(String),
  entry_function: String,
  state: String,
  trigger: String,
) -> Result(PipelineRunRow, pog.QueryError) {
  let assert Ok(repo_uuid) = uuid.from_string(repository_id)
  sql.pipeline_run_insert(
    db,
    repo_uuid,
    merge_request_id,
    "",
    commit_sha,
    nullable_text(module_path),
    entry_function,
    state,
    trigger,
  )
  |> result_map_first_row
  |> result.map(pipeline_run_from_insert_row)
}

pub fn insert_branch_pipeline_run(
  db: pog.Connection,
  repository_id: String,
  branch_name: String,
  commit_sha: String,
  module_path: Option(String),
  entry_function: String,
  state: String,
  trigger: String,
) -> Result(PipelineRunRow, pog.QueryError) {
  let assert Ok(repo_uuid) = uuid.from_string(repository_id)
  sql.pipeline_run_insert(
    db,
    repo_uuid,
    "",
    branch_name,
    commit_sha,
    nullable_text(module_path),
    entry_function,
    state,
    trigger,
  )
  |> result_map_first_row
  |> result.map(pipeline_run_from_insert_row)
}

pub fn pipeline_run_exists_for_branch_sha(
  db: pog.Connection,
  repository_id: String,
  branch_name: String,
  commit_sha: String,
) -> Result(Bool, pog.QueryError) {
  let assert Ok(repo_uuid) = uuid.from_string(repository_id)
  sql.pipeline_run_exists_for_branch_sha(db, repo_uuid, branch_name, commit_sha)
  |> result_map_rows
  |> result.map(fn(rows) { rows != [] })
}

pub fn get_latest_pipeline_run(
  db: pog.Connection,
  merge_request_id: String,
) -> Result(PipelineRunRow, pog.QueryError) {
  let assert Ok(mr_uuid) = uuid.from_string(merge_request_id)
  sql.pipeline_run_get_latest(db, mr_uuid)
  |> result_map_first_row
  |> result.map(pipeline_run_from_latest_row)
}

pub fn get_latest_pipeline_run_optional(
  db: pog.Connection,
  merge_request_id: String,
) -> Result(Option(PipelineRunRow), pog.QueryError) {
  let assert Ok(mr_uuid) = uuid.from_string(merge_request_id)
  sql.pipeline_run_get_latest(db, mr_uuid)
  |> result_map_optional_row
  |> result.map(option.map(_, pipeline_run_from_latest_row))
}

pub fn get_latest_branch_pipeline_run_optional(
  db: pog.Connection,
  repository_id: String,
  branch_name: String,
) -> Result(Option(PipelineRunRow), pog.QueryError) {
  let assert Ok(repo_uuid) = uuid.from_string(repository_id)
  sql.pipeline_run_get_latest_for_branch(db, repo_uuid, branch_name)
  |> result_map_optional_row
  |> result.map(option.map(_, pipeline_run_from_latest_for_branch_row))
}

pub fn list_pipeline_runs_for_mr(
  db: pog.Connection,
  merge_request_id: String,
) -> Result(List(PipelineRunRow), pog.QueryError) {
  let assert Ok(mr_uuid) = uuid.from_string(merge_request_id)
  sql.pipeline_run_list_for_mr(db, mr_uuid)
  |> result_map_rows
  |> result.map(list.map(_, pipeline_run_from_list_for_mr_row))
}

pub fn reclaim_stale_pipeline_runs(db: pog.Connection) -> Nil {
  let _ = sql.pipeline_run_reclaim_stale_running(db)
  let _ = sql.pipeline_run_reclaim_stale_queued(db)
  Nil
}

pub fn claim_next_pipeline_job(
  db: pog.Connection,
) -> Result(Option(PipelineRunJobRow), pog.QueryError) {
  reclaim_stale_pipeline_runs(db)
  sql.pipeline_run_claim_next(db)
  |> result_map_optional_row
  |> result.map(option.map(_, pipeline_run_job_from_claim_row))
}

pub fn get_pipeline_run_job(
  db: pog.Connection,
  run_id: String,
) -> Result(Option(PipelineRunJobRow), pog.QueryError) {
  let assert Ok(run_uuid) = uuid.from_string(run_id)
  sql.pipeline_run_get_by_id(db, run_uuid)
  |> result_map_optional_row
  |> result.map(option.map(_, pipeline_run_job_from_get_by_id_row))
}

pub fn update_pipeline_run(
  db: pog.Connection,
  run_id: String,
  state: String,
  log_text: String,
) -> Result(PipelineRunRow, pog.QueryError) {
  let assert Ok(run_uuid) = uuid.from_string(run_id)
  sql.pipeline_run_update(db, run_uuid, state, log_text)
  |> result_map_first_row
  |> result.map(pipeline_run_from_update_row)
}

pub fn list_issues(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
) -> Result(List(IssueRow), pog.QueryError) {
  list_issues_filtered(
    db,
    org_slug,
    repo_name,
    list_query.IssueListQuery(
      state: "all",
      label_ids: [],
      milestone_id: option.None,
      assignee: option.None,
      author: option.None,
      q: option.None,
      sort: "number",
      order: "desc",
    ),
  )
}

pub fn list_issues_filtered(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  query: list_query.IssueListQuery,
) -> Result(List(IssueRow), pog.QueryError) {
  list_filter.list_issues_filtered(db, org_slug, repo_name, query)
  |> result_map_rows
  |> result.map(list.map(_, issue_from_list_row))
}

pub fn get_issue(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
) -> Result(Option(IssueRow), pog.QueryError) {
  sql.issue_get(db, org_slug, repo_name, number)
  |> result_map_optional_row
  |> result.map(option.map(_, issue_from_get_row))
}

pub fn insert_issue(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  title: String,
  description: Option(String),
  author_user_id: String,
) -> Result(IssueRow, pog.QueryError) {
  sql.issue_insert(
    db,
    org_slug,
    repo_name,
    title,
    nullable_text(description),
    author_user_id,
  )
  |> result_map_first_row
  |> result.map(issue_from_insert_row)
}

pub fn close_issue(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
) -> Result(IssueRow, pog.QueryError) {
  sql.issue_close(db, org_slug, repo_name, number)
  |> result_map_first_row
  |> result.map(issue_from_close_row)
}

pub fn set_issue_mr_links(
  db: pog.Connection,
  merge_request_id: String,
  links: List(#(String, String)),
) -> Result(Nil, pog.QueryError) {
  let assert Ok(mr_uuid) = uuid.from_string(merge_request_id)
  replace_issue_mr_links(db, mr_uuid, links)
}

pub fn list_linked_merge_requests_for_issue(
  db: pog.Connection,
  issue_id: String,
) -> Result(List(LinkedMergeRequestRow), pog.QueryError) {
  let assert Ok(issue_uuid) = uuid.from_string(issue_id)
  sql.issue_mr_links_for_issue(db, issue_uuid)
  |> result_map_rows
  |> result.map(list.map(_, linked_mr_from_row))
}

pub fn list_linked_issues_for_mr(
  db: pog.Connection,
  merge_request_id: String,
) -> Result(List(LinkedIssueRow), pog.QueryError) {
  let assert Ok(mr_uuid) = uuid.from_string(merge_request_id)
  sql.issue_mr_links_for_mr(db, mr_uuid)
  |> result_map_rows
  |> result.map(list.map(_, linked_issue_from_row))
}

pub fn list_closes_issues_for_mr(
  db: pog.Connection,
  merge_request_id: String,
  org_slug: String,
) -> Result(List(ClosesIssueRef), pog.QueryError) {
  let assert Ok(mr_uuid) = uuid.from_string(merge_request_id)
  sql.issue_mr_links_closes_for_mr(db, mr_uuid, org_slug)
  |> result_map_rows
  |> result.map(list.map(_, closes_issue_ref_from_row))
}

pub fn list_issue_comments(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
) -> Result(List(IssueCommentRow), pog.QueryError) {
  sql.issue_comments_list(db, org_slug, repo_name, number)
  |> result_map_rows
  |> result.map(list.map(_, issue_comment_from_list_row))
}

pub fn insert_issue_comment(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
  author_user_id: String,
  body: String,
  mentioned_user_ids: List(String),
) -> Result(IssueCommentRow, pog.QueryError) {
  sql.issue_comments_insert(
    db,
    org_slug,
    repo_name,
    number,
    author_user_id,
    body,
    mention_store.encode_user_ids(mentioned_user_ids),
  )
  |> result_map_first_row
  |> result.map(issue_comment_from_insert_row)
}

pub fn get_issue_comment(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
  comment_id: String,
) -> Result(Option(IssueCommentRow), pog.QueryError) {
  case uuid.from_string(comment_id) {
    Error(_) -> Ok(option.None)
    Ok(comment_uuid) ->
      sql.issue_comment_get(db, org_slug, repo_name, number, comment_uuid)
      |> result_map_optional_row
      |> result.map(option.map(_, issue_comment_from_get_row))
  }
}

pub fn update_issue_comment(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
  comment_id: String,
  body: String,
  mentioned_user_ids: List(String),
) -> Result(Option(IssueCommentRow), pog.QueryError) {
  case uuid.from_string(comment_id) {
    Error(_) -> Ok(option.None)
    Ok(comment_uuid) ->
      sql.issue_comment_update(
        db,
        org_slug,
        repo_name,
        number,
        comment_uuid,
        body,
        mention_store.encode_user_ids(mentioned_user_ids),
      )
      |> result_map_optional_row
      |> result.map(option.map(_, issue_comment_from_update_row))
  }
}

pub fn delete_issue_comment(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
  comment_id: String,
) -> Result(Bool, pog.QueryError) {
  case uuid.from_string(comment_id) {
    Error(_) -> Ok(False)
    Ok(comment_uuid) ->
      sql.issue_comment_delete(db, org_slug, repo_name, number, comment_uuid)
      |> result_map_optional_row
      |> result.map(option.is_some)
  }
}

pub fn list_repo_labels(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
) -> Result(List(LabelRow), pog.QueryError) {
  sql.label_list(db, org_slug, repo_name)
  |> result_map_rows
  |> result.map(list.map(_, label_from_list_row))
}

pub fn insert_repo_label(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  name: String,
  color: String,
) -> Result(LabelRow, LabelError) {
  case normalize_label_name(name) {
    Error(e) -> Error(e)
    Ok(normalized) -> {
      let color = normalize_label_color(color, normalized)
      case
        sql.label_insert(db, org_slug, repo_name, normalized, color)
        |> result_map_first_row
      {
        Ok(row) -> Ok(label_from_insert_row(row))
        Error(pog.ConstraintViolated(..)) -> Error(DuplicateLabelName)
        Error(_) -> Error(InvalidLabelName)
      }
    }
  }
}

pub fn delete_repo_label(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  label_id: String,
) -> Result(Bool, pog.QueryError) {
  case uuid.from_string(label_id) {
    Error(_) -> Ok(False)
    Ok(label_uuid) ->
      sql.label_delete(db, org_slug, repo_name, label_uuid)
      |> result_map_optional_row
      |> result.map(option.is_some)
  }
}

pub fn get_repo_label(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  label_id: String,
) -> Result(Option(LabelRow), pog.QueryError) {
  case uuid.from_string(label_id) {
    Error(_) -> Ok(option.None)
    Ok(label_uuid) ->
      sql.label_get(db, org_slug, repo_name, label_uuid)
      |> result_map_optional_row
      |> result.map(option.map(_, label_from_get_row))
  }
}

pub fn update_repo_label(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  label_id: String,
  name: Option(String),
  color: Option(String),
) -> Result(LabelRow, LabelError) {
  case get_repo_label(db, org_slug, repo_name, label_id) {
    Error(_) -> Error(LabelNotFound)
    Ok(option.None) -> Error(LabelNotFound)
    Ok(option.Some(existing)) -> {
      let next_name = case name {
        option.Some(n) -> n
        option.None -> existing.name
      }
      let next_color = case color {
        option.Some(c) -> c
        option.None -> existing.color
      }
      case normalize_label_name(next_name) {
        Error(e) -> Error(e)
        Ok(normalized) -> {
          let normalized_color = normalize_label_color(next_color, normalized)
          case uuid.from_string(label_id) {
            Error(_) -> Error(LabelNotFound)
            Ok(label_uuid) ->
              case
                sql.label_update(
                  db,
                  org_slug,
                  repo_name,
                  label_uuid,
                  normalized,
                  normalized_color,
                )
                |> result_map_optional_row
              {
                Ok(option.None) -> Error(LabelNotFound)
                Ok(option.Some(row)) -> Ok(label_from_update_row(row))
                Error(pog.ConstraintViolated(..)) -> Error(DuplicateLabelName)
                Error(_) -> Error(InvalidLabelName)
              }
          }
        }
      }
    }
  }
}

pub fn update_issue(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
  title: String,
  description: Option(String),
) -> Result(IssueRow, pog.QueryError) {
  sql.issue_update(
    db,
    org_slug,
    repo_name,
    number,
    title,
    nullable_text(description),
  )
  |> result_map_first_row
  |> result.map(issue_from_update_row)
}

pub fn reopen_issue(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
) -> Result(IssueRow, pog.QueryError) {
  sql.issue_reopen(db, org_slug, repo_name, number)
  |> result_map_first_row
  |> result.map(issue_from_reopen_row)
}

pub fn enrich_issues(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  issues: List(IssueRow),
) -> Result(List(IssueRow), pog.QueryError) {
  case
    sql.issue_labels_for_repo(db, org_slug, repo_name)
    |> result_map_rows
  {
    Error(e) -> Error(e)
    Ok(label_links) ->
      case
        sql.issue_assignees_for_repo(db, org_slug, repo_name)
        |> result_map_rows
      {
        Error(e) -> Error(e)
        Ok(assignee_links) ->
          case
            sql.issue_milestones_for_repo(db, org_slug, repo_name)
            |> result_map_rows
          {
            Error(e) -> Error(e)
            Ok(milestone_links) -> {
              let labels_by_issue = labels_by_parent(label_links)
              let assignees_by_issue =
                assignees_by_parent(assignee_links, fn(row) {
                  #(
                    row.issue_id,
                    IssueAssigneeRow(
                      user_id: row.user_id,
                      display_name: row.user_id,
                    ),
                  )
                })
              let milestones_by_issue = milestones_by_parent(milestone_links)
              Ok(
                list.map(issues, fn(issue) {
                  IssueRow(
                    ..issue,
                    labels: dict_get_list(labels_by_issue, issue.id),
                    assignees: dict_get_assignees(assignees_by_issue, issue.id),
                    milestone: dict_get_milestone(milestones_by_issue, issue.id),
                  )
                }),
              )
            }
          }
      }
  }
}

pub fn enrich_issue(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  issue: IssueRow,
) -> Result(IssueRow, pog.QueryError) {
  case parse_entity_id(issue.id) {
    Error(_) -> Ok(issue)
    Ok(issue_uuid) ->
      case
        sql.issue_labels_for_issue(db, issue_uuid)
        |> result_map_rows
      {
        Error(e) -> Error(e)
        Ok(label_rows) ->
          case
            sql.issue_assignees_for_issue(db, issue_uuid)
            |> result_map_rows
          {
            Error(e) -> Error(e)
            Ok(assignee_rows) -> {
              let labels =
                list.map(label_rows, fn(row) {
                  label_link_row(row.id, row.name, row.color)
                })
              let assignees =
                list.map(assignee_rows, fn(row) {
                  IssueAssigneeRow(
                    user_id: row.user_id,
                    display_name: row.user_id,
                  )
                })
              let milestone =
                case
                  sql.issue_milestones_for_repo(db, org_slug, repo_name)
                  |> result_map_rows
                {
                  Error(_) -> option.None
                  Ok(rows) ->
                    case list.filter(rows, fn(row) { row.issue_id == issue.id }) {
                      [first, ..] ->
                        option.Some(IssueMilestoneRow(
                          id: first.milestone_id,
                          number: first.milestone_number,
                          title: first.milestone_title,
                        ))
                      [] -> option.None
                    }
                }
              Ok(IssueRow(..issue, labels:, assignees:, milestone:))
            }
          }
      }
  }
}

pub fn enrich_merge_requests(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  merge_requests: List(MergeRequestRow),
) -> Result(List(MergeRequestRow), pog.QueryError) {
  case sql.mr_labels_for_repo(db, org_slug, repo_name) |> result_map_rows {
    Error(e) -> Error(e)
    Ok(label_links) ->
      case sql.mr_assignees_for_repo(db, org_slug, repo_name) |> result_map_rows {
        Error(e) -> Error(e)
        Ok(assignee_links) ->
          case
            sql.mr_reviewers_for_repo(db, org_slug, repo_name)
            |> result_map_rows
          {
            Error(e) -> Error(e)
            Ok(reviewer_links) -> {
              let labels_by_mr = mr_labels_by_parent(label_links)
              let assignees_by_mr =
                list.fold(assignee_links, dict.new(), fn(acc, row) {
                  let assignee =
                    IssueAssigneeRow(
                      user_id: row.user_id,
                      display_name: row.user_id,
                    )
                  dict.insert(
                    acc,
                    row.merge_request_id,
                    append_assignee(acc, row.merge_request_id, assignee),
                  )
                })
              let reviewers_by_mr =
                list.fold(reviewer_links, dict.new(), fn(acc, row) {
                  let reviewer =
                    IssueAssigneeRow(
                      user_id: row.user_id,
                      display_name: row.user_id,
                    )
                  dict.insert(
                    acc,
                    row.merge_request_id,
                    append_assignee(acc, row.merge_request_id, reviewer),
                  )
                })
              Ok(
                list.map(merge_requests, fn(mr) {
                  MergeRequestRow(
                    ..mr,
                    labels: dict_get_list(labels_by_mr, mr.id),
                    assignees: dict_get_assignees(assignees_by_mr, mr.id),
                    reviewers:
                      list.filter(
                        dict_get_assignees(reviewers_by_mr, mr.id),
                        fn(reviewer) {
                          reviewer.user_id != mr.author_user_id
                        },
                      ),
                  )
                }),
              )
            }
          }
      }
  }
}

pub fn enrich_merge_request(
  db: pog.Connection,
  _org_slug: String,
  _repo_name: String,
  merge_request: MergeRequestRow,
) -> Result(MergeRequestRow, pog.QueryError) {
  case parse_entity_id(merge_request.id) {
    Error(_) -> Ok(merge_request)
    Ok(mr_uuid) ->
      case sql.mr_labels_for_merge_request(db, mr_uuid) |> result_map_rows {
        Error(e) -> Error(e)
        Ok(label_rows) ->
          case sql.mr_assignees_for_mr(db, mr_uuid) |> result_map_rows {
            Error(e) -> Error(e)
            Ok(assignee_rows) ->
              case sql.mr_reviewers_for_mr(db, mr_uuid) |> result_map_rows {
                Error(e) -> Error(e)
                Ok(reviewer_rows) -> {
                  let labels =
                    list.map(label_rows, fn(row) {
                      label_link_row(row.id, row.name, row.color)
                    })
                  let assignees =
                    list.map(assignee_rows, fn(row) {
                      IssueAssigneeRow(
                        user_id: row.user_id,
                        display_name: row.user_id,
                      )
                    })
                  let reviewers =
                    list.filter(reviewer_rows, fn(row) {
                      row.user_id != merge_request.author_user_id
                    })
                    |> list.map(fn(row) {
                      IssueAssigneeRow(
                        user_id: row.user_id,
                        display_name: row.user_id,
                      )
                    })
                  Ok(MergeRequestRow(
                    ..merge_request,
                    labels:,
                    assignees:,
                    reviewers:,
                  ))
                }
              }
          }
      }
  }
}

pub fn list_same_string_set(a: List(String), b: List(String)) -> Bool {
  list.length(a) == list.length(b)
  && list.all(a, fn(item) { list.contains(b, item) })
}

pub fn issue_label_ids_on_issue(
  db: pog.Connection,
  issue_id: String,
) -> Result(List(String), LabelError) {
  case parse_entity_id(issue_id) {
    Error(e) -> Error(e)
    Ok(issue_uuid) ->
      sql.issue_labels_for_issue(db, issue_uuid)
      |> result_map_rows
      |> result.map(list.map(_, fn(row) { row.id }))
      |> result.map_error(fn(_) { InvalidLabelIds })
  }
}

pub fn issue_assignee_ids_on_issue(
  db: pog.Connection,
  issue_id: String,
) -> Result(List(String), LabelError) {
  case parse_entity_id(issue_id) {
    Error(e) -> Error(e)
    Ok(issue_uuid) ->
      sql.issue_assignees_for_issue(db, issue_uuid)
      |> result_map_rows
      |> result.map(list.map(_, fn(row) { row.user_id }))
      |> result.map_error(fn(_) { InvalidAssignees })
  }
}

pub fn set_issue_labels(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  issue_id: String,
  label_ids: List(String),
) -> Result(Nil, LabelError) {
  case
    parse_entity_id(issue_id),
    validate_repo_label_ids(db, org_slug, repo_name, label_ids)
  {
    Error(e), _ | _, Error(e) -> Error(e)
    Ok(issue_uuid), Ok(valid_ids) ->
      pog.transaction(db, fn(db) {
        set_issue_labels_queries(db, issue_uuid, valid_ids)
      })
      |> map_transaction_label_error
  }
}

pub fn set_issue_assignees(
  db: pog.Connection,
  org_slug: String,
  issue_id: String,
  assignee_user_ids: List(String),
) -> Result(Nil, LabelError) {
  case
    parse_entity_id(issue_id),
    validate_org_assignees(db, org_slug, assignee_user_ids)
  {
    Error(e), _ | _, Error(e) -> Error(e)
    Ok(issue_uuid), Ok(Nil) ->
      pog.transaction(db, fn(db) {
        set_issue_assignees_queries(db, issue_uuid, assignee_user_ids)
      })
      |> map_transaction_label_error
  }
}

pub fn mr_assignee_ids_on_merge_request(
  db: pog.Connection,
  merge_request_id: String,
) -> Result(List(String), LabelError) {
  case parse_entity_id(merge_request_id) {
    Error(e) -> Error(e)
    Ok(mr_uuid) ->
      sql.mr_assignees_for_mr(db, mr_uuid)
      |> result_map_rows
      |> result.map(list.map(_, fn(row) { row.user_id }))
      |> result.map_error(fn(_) { InvalidAssignees })
  }
}

pub fn set_merge_request_assignees(
  db: pog.Connection,
  org_slug: String,
  merge_request_id: String,
  assignee_user_ids: List(String),
) -> Result(Nil, LabelError) {
  case
    parse_entity_id(merge_request_id),
    validate_org_assignees(db, org_slug, assignee_user_ids)
  {
    Error(e), _ | _, Error(e) -> Error(e)
    Ok(mr_uuid), Ok(Nil) ->
      pog.transaction(db, fn(db) {
        set_merge_request_assignees_queries(db, mr_uuid, assignee_user_ids)
      })
      |> map_transaction_label_error
  }
}

pub fn set_merge_request_reviewers(
  db: pog.Connection,
  org_slug: String,
  merge_request_id: String,
  author_user_id: String,
  requested_by_user_id: String,
  reviewer_user_ids: List(String),
) -> Result(Nil, LabelError) {
  case
    parse_entity_id(merge_request_id),
    validate_org_assignees(db, org_slug, reviewer_user_ids),
    validate_mr_reviewers(reviewer_user_ids, author_user_id)
  {
    Error(e), _, _ | _, Error(e), _ | _, _, Error(e) -> Error(e)
    Ok(mr_uuid), Ok(Nil), Ok(Nil) ->
      pog.transaction(db, fn(db) {
        set_merge_request_reviewers_queries(
          db,
          mr_uuid,
          requested_by_user_id,
          reviewer_user_ids,
        )
      })
      |> map_transaction_label_error
  }
}

pub fn set_merge_request_labels(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  merge_request_id: String,
  label_ids: List(String),
) -> Result(Nil, LabelError) {
  case
    parse_entity_id(merge_request_id),
    validate_repo_label_ids(db, org_slug, repo_name, label_ids)
  {
    Error(e), _ | _, Error(e) -> Error(e)
    Ok(mr_uuid), Ok(valid_ids) ->
      pog.transaction(db, fn(db) {
        set_mr_labels_queries(db, mr_uuid, valid_ids)
      })
      |> map_transaction_label_error
  }
}

pub fn issue_assignees_with_names(
  assignees: List(IssueAssigneeRow),
  names: Dict(String, String),
) -> List(IssueAssigneeRow) {
  list.map(assignees, fn(assignee) {
    let display_name = case dict.get(names, assignee.user_id) {
      Ok(name) -> name
      Error(_) -> assignee.user_id
    }
    IssueAssigneeRow(..assignee, display_name:)
  })
}

pub fn issue_with_assignees(
  issue: IssueRow,
  assignees: List(IssueAssigneeRow),
) -> IssueRow {
  IssueRow(..issue, assignees:)
}

pub fn insert_notification(
  db: pog.Connection,
  user_id: String,
  type_: String,
  payload: json.Json,
) -> Result(NotificationRow, pog.QueryError) {
  sql.notifications_insert(db, user_id, type_, payload)
  |> result_map_first_row
  |> result.map(notification_from_insert_row)
}

pub fn list_notifications(
  db: pog.Connection,
  user_id: String,
  limit: Int,
  offset: Int,
) -> Result(List(NotificationRow), pog.QueryError) {
  sql.notifications_list(db, user_id, limit, offset)
  |> result_map_rows
  |> result.map(list.map(_, notification_from_list_row))
}

pub fn count_unread_notifications(
  db: pog.Connection,
  user_id: String,
) -> Result(Int, pog.QueryError) {
  sql.notifications_unread_count(db, user_id)
  |> result_map_first_row
  |> result.map(fn(row) { row.unread_count })
}

pub fn mark_notification_read(
  db: pog.Connection,
  notification_id: String,
  user_id: String,
) -> Result(Bool, pog.QueryError) {
  let assert Ok(id) = uuid.from_string(notification_id)
  sql.notifications_mark_read(db, id, user_id)
  |> result_map_rows
  |> result.map(fn(rows) { rows != [] })
}

pub fn mark_all_notifications_read(
  db: pog.Connection,
  user_id: String,
) -> Result(Nil, pog.QueryError) {
  sql.notifications_mark_all_read(db, user_id)
  |> result_map_ok
}

pub fn get_user_stats(
  db: pog.Connection,
  user_id: String,
) -> Result(UserStatsRow, pog.QueryError) {
  sql.user_stats(db, user_id)
  |> result_map_first_row
  |> result.map(user_stats_from_row)
}

pub fn get_merge_request_brief(
  db: pog.Connection,
  merge_request_id: String,
) -> Result(Option(MrBriefRow), pog.QueryError) {
  case uuid.from_string(merge_request_id) {
    Error(_) -> Ok(option.None)
    Ok(mr_uuid) ->
      sql.mr_get_by_id(db, mr_uuid)
      |> result_map_optional_row
      |> result.map(option.map(_, mr_brief_from_row))
  }
}

fn notification_from_insert_row(row: sql.NotificationsInsertRow) -> NotificationRow {
  notification_row(
    row.id,
    row.notification_type,
    row.payload,
    row.read_at,
    row.created_at,
  )
}

fn notification_from_list_row(row: sql.NotificationsListRow) -> NotificationRow {
  notification_row(
    row.id,
    row.notification_type,
    row.payload,
    row.read_at,
    row.created_at,
  )
}

fn notification_row(
  id: String,
  notification_type: String,
  payload: String,
  read_at: String,
  created_at: String,
) -> NotificationRow {
  NotificationRow(
    id:,
    notification_type:,
    payload:,
    read_at: option_from_text(read_at),
    created_at:,
  )
}

fn user_stats_from_row(row: sql.UserStatsRow) -> UserStatsRow {
  UserStatsRow(
    open_merge_requests: row.open_merge_requests,
    merged_merge_requests: row.merged_merge_requests,
    open_issues_authored: row.open_issues_authored,
    open_issues_assigned: row.open_issues_assigned,
    reviews_given: row.reviews_given,
  )
}

fn mr_brief_from_row(row: sql.MrGetByIdRow) -> MrBriefRow {
  MrBriefRow(
    id: row.id,
    number: row.number,
    title: row.merge_request_title,
    author_user_id: row.author_user_id,
    org_slug: row.org_slug,
    repo_name: row.repo_name,
  )
}

fn option_from_text(value: String) -> Option(String) {
  case string.trim(value) {
    "" -> option.None
    text -> option.Some(text)
  }
}

fn mr_from_list_row(row: sql.MrListRow) -> MergeRequestRow {
  mr_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.source_branch,
    row.target_branch,
    row.state,
    row.is_draft,
    row.merge_commit_sha,
    row.merged_by_user_id,
    row.merged_at,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn mr_from_get_row(row: sql.MrGetRow) -> MergeRequestRow {
  mr_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.source_branch,
    row.target_branch,
    row.state,
    row.is_draft,
    row.merge_commit_sha,
    row.merged_by_user_id,
    row.merged_at,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn mr_from_insert_row(row: sql.MrInsertRow) -> MergeRequestRow {
  mr_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.source_branch,
    row.target_branch,
    row.state,
    row.is_draft,
    row.merge_commit_sha,
    row.merged_by_user_id,
    row.merged_at,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn mr_from_merge_row(row: sql.MrMergeRow) -> MergeRequestRow {
  mr_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.source_branch,
    row.target_branch,
    row.state,
    row.is_draft,
    row.merge_commit_sha,
    row.merged_by_user_id,
    row.merged_at,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn mr_from_close_row(row: sql.MrCloseRow) -> MergeRequestRow {
  mr_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.source_branch,
    row.target_branch,
    row.state,
    row.is_draft,
    row.merge_commit_sha,
    row.merged_by_user_id,
    row.merged_at,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn mr_from_update_is_draft_row(row: sql.MrUpdateIsDraftRow) -> MergeRequestRow {
  mr_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.source_branch,
    row.target_branch,
    row.state,
    row.is_draft,
    row.merge_commit_sha,
    row.merged_by_user_id,
    row.merged_at,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn mr_from_open_by_source_row(
  row: sql.MrListOpenBySourceRow,
) -> MergeRequestRow {
  mr_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.source_branch,
    row.target_branch,
    row.state,
    row.is_draft,
    row.merge_commit_sha,
    row.merged_by_user_id,
    row.merged_at,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn pipeline_run_row(
  id: String,
  repository_id: String,
  merge_request_id: String,
  commit_sha: String,
  module_path: String,
  entry_function: String,
  state: String,
  trigger: String,
  log_text: String,
  started_at: String,
  finished_at: String,
  created_at: String,
) -> PipelineRunRow {
  PipelineRunRow(
    id:,
    repository_id:,
    merge_request_id:,
    commit_sha:,
    module_path:,
    entry_function:,
    state:,
    trigger:,
    log_text:,
    started_at: optional_timestamp(started_at),
    finished_at: optional_timestamp(finished_at),
    created_at:,
  )
}

fn pipeline_run_from_insert_row(
  row: sql.PipelineRunInsertRow,
) -> PipelineRunRow {
  pipeline_run_row(
    row.id,
    row.repository_id,
    row.merge_request_id,
    row.commit_sha,
    row.module_path,
    row.entry_function,
    row.state,
    row.trigger,
    row.log_text,
    row.started_at,
    row.finished_at,
    row.created_at,
  )
}

fn pipeline_run_from_latest_row(
  row: sql.PipelineRunGetLatestRow,
) -> PipelineRunRow {
  pipeline_run_row(
    row.id,
    row.repository_id,
    row.merge_request_id,
    row.commit_sha,
    row.module_path,
    row.entry_function,
    row.state,
    row.trigger,
    row.log_text,
    row.started_at,
    row.finished_at,
    row.created_at,
  )
}

fn pipeline_run_from_latest_for_branch_row(
  row: sql.PipelineRunGetLatestForBranchRow,
) -> PipelineRunRow {
  pipeline_run_row(
    row.id,
    row.repository_id,
    row.merge_request_id,
    row.commit_sha,
    row.module_path,
    row.entry_function,
    row.state,
    row.trigger,
    row.log_text,
    row.started_at,
    row.finished_at,
    row.created_at,
  )
}

fn pipeline_run_from_list_for_mr_row(
  row: sql.PipelineRunListForMrRow,
) -> PipelineRunRow {
  pipeline_run_row(
    row.id,
    row.repository_id,
    row.merge_request_id,
    row.commit_sha,
    row.module_path,
    row.entry_function,
    row.state,
    row.trigger,
    row.log_text,
    row.started_at,
    row.finished_at,
    row.created_at,
  )
}

fn pipeline_run_from_update_row(
  row: sql.PipelineRunUpdateRow,
) -> PipelineRunRow {
  pipeline_run_row(
    row.id,
    row.repository_id,
    row.merge_request_id,
    row.commit_sha,
    row.module_path,
    row.entry_function,
    row.state,
    row.trigger,
    row.log_text,
    row.started_at,
    row.finished_at,
    row.created_at,
  )
}

fn pipeline_run_job_from_claim_row(
  row: sql.PipelineRunClaimNextRow,
) -> PipelineRunJobRow {
  PipelineRunJobRow(
    id: row.id,
    repository_id: row.repository_id,
    merge_request_id: row.merge_request_id,
    commit_sha: row.commit_sha,
    module_path: row.module_path,
    entry_function: row.entry_function,
    state: row.state,
    trigger: row.trigger,
    org_slug: "",
    repo_name: "",
    disk_path: "",
  )
}

fn pipeline_run_job_from_get_by_id_row(
  row: sql.PipelineRunGetByIdRow,
) -> PipelineRunJobRow {
  PipelineRunJobRow(
    id: row.id,
    repository_id: row.repository_id,
    merge_request_id: row.merge_request_id,
    commit_sha: row.commit_sha,
    module_path: row.module_path,
    entry_function: row.entry_function,
    state: row.state,
    trigger: row.trigger,
    org_slug: row.org_slug,
    repo_name: row.repo_name,
    disk_path: row.disk_path,
  )
}

fn mr_row(
  id: String,
  number: Int,
  title: String,
  description: Option(String),
  author_user_id: String,
  source_branch: String,
  target_branch: String,
  state: String,
  is_draft: Bool,
  merge_commit_sha: Option(String),
  merged_by_user_id: Option(String),
  merged_at: String,
  closed_at: String,
  created_at: String,
  updated_at: String,
) -> MergeRequestRow {
  MergeRequestRow(
    id:,
    number:,
    title:,
    description:,
    author_user_id:,
    source_branch:,
    target_branch:,
    state:,
    is_draft:,
    merge_commit_sha:,
    merged_by_user_id:,
    merged_at: optional_timestamp(merged_at),
    closed_at: optional_timestamp(closed_at),
    created_at:,
    updated_at:,
    labels: [],
    assignees: [],
    reviewers: [],
  )
}

fn mr_from_update_row(row: sql.MrUpdateRow) -> MergeRequestRow {
  mr_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.source_branch,
    row.target_branch,
    row.state,
    row.is_draft,
    row.merge_commit_sha,
    row.merged_by_user_id,
    row.merged_at,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn optional_timestamp(value: String) -> Option(String) {
  case string.trim(value) {
    "" -> option.None
    trimmed -> option.Some(trimmed)
  }
}

fn mr_comment_from_list_row(
  row: sql.MrCommentsListRow,
) -> MergeRequestCommentRow {
  mr_comment_row(
    row.id,
    row.author_user_id,
    row.author_name,
    row.body,
    row.file_path,
    row.line,
    mention_store.decode_user_ids(row.mentioned_user_ids),
    row.created_at,
    row.updated_at,
  )
}

fn mr_comment_from_insert_row(
  row: sql.MrCommentsInsertRow,
) -> MergeRequestCommentRow {
  mr_comment_row(
    row.id,
    row.author_user_id,
    "",
    row.body,
    row.file_path,
    row.line,
    mention_store.decode_user_ids(row.mentioned_user_ids),
    row.created_at,
    row.updated_at,
  )
}

fn mr_comment_from_get_row(row: sql.MrCommentGetRow) -> MergeRequestCommentRow {
  mr_comment_row(
    row.id,
    row.author_user_id,
    "",
    row.body,
    row.file_path,
    row.line,
    mention_store.decode_user_ids(row.mentioned_user_ids),
    row.created_at,
    row.updated_at,
  )
}

fn mr_comment_from_update_row(
  row: sql.MrCommentUpdateRow,
) -> MergeRequestCommentRow {
  mr_comment_row(
    row.id,
    row.author_user_id,
    "",
    row.body,
    row.file_path,
    row.line,
    mention_store.decode_user_ids(row.mentioned_user_ids),
    row.created_at,
    row.updated_at,
  )
}

fn mr_review_from_list_row(row: sql.MrReviewsListRow) -> MergeRequestReviewRow {
  mr_review_row(
    row.id,
    row.merge_request_id,
    row.user_id,
    row.reviewer_name,
    row.state,
    row.body,
    row.submitted_at,
  )
}

fn mr_review_from_insert_row(row: sql.MrReviewInsertRow) -> MergeRequestReviewRow {
  mr_review_row(
    row.id,
    row.merge_request_id,
    row.user_id,
    "",
    row.state,
    row.body,
    row.submitted_at,
  )
}

fn mr_review_row(
  id: String,
  merge_request_id: String,
  user_id: String,
  reviewer_name: String,
  state: String,
  body: Option(String),
  submitted_at: String,
) -> MergeRequestReviewRow {
  MergeRequestReviewRow(
    id:,
    merge_request_id:,
    user_id:,
    reviewer_name:,
    state:,
    body:,
    submitted_at:,
  )
}

fn mr_comment_row(
  id: String,
  author_user_id: String,
  author_name: String,
  body: String,
  file_path: Option(String),
  line: Option(Int),
  mentioned_user_ids: List(String),
  created_at: String,
  updated_at: String,
) -> MergeRequestCommentRow {
  MergeRequestCommentRow(
    id:,
    author_user_id:,
    author_name:,
    body:,
    file_path:,
    line:,
    mentioned_user_ids:,
    created_at:,
    updated_at:,
  )
}

fn issue_from_list_row(row: sql.IssueListRow) -> IssueRow {
  issue_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.state,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn issue_from_get_row(row: sql.IssueGetRow) -> IssueRow {
  issue_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.state,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn issue_from_insert_row(row: sql.IssueInsertRow) -> IssueRow {
  issue_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.state,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn issue_from_close_row(row: sql.IssueCloseRow) -> IssueRow {
  issue_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.state,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn issue_row(
  id: String,
  number: Int,
  title: String,
  description: Option(String),
  author_user_id: String,
  state: String,
  closed_at: String,
  created_at: String,
  updated_at: String,
) -> IssueRow {
  IssueRow(
    id:,
    number:,
    title:,
    description:,
    author_user_id:,
    author_name: author_user_id,
    state:,
    closed_at: optional_timestamp(closed_at),
    created_at:,
    updated_at:,
    labels: [],
    assignees: [],
    milestone: option.None,
  )
}

fn issue_from_update_row(row: sql.IssueUpdateRow) -> IssueRow {
  issue_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.state,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn issue_from_reopen_row(row: sql.IssueReopenRow) -> IssueRow {
  issue_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.state,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn issue_comment_from_list_row(
  row: sql.IssueCommentsListRow,
) -> IssueCommentRow {
  issue_comment_row(
    row.id,
    row.author_user_id,
    row.author_name,
    row.body,
    mention_store.decode_user_ids(row.mentioned_user_ids),
    row.created_at,
    row.updated_at,
  )
}

fn issue_comment_from_insert_row(
  row: sql.IssueCommentsInsertRow,
) -> IssueCommentRow {
  issue_comment_row(
    row.id,
    row.author_user_id,
    "",
    row.body,
    mention_store.decode_user_ids(row.mentioned_user_ids),
    row.created_at,
    row.updated_at,
  )
}

fn issue_comment_from_get_row(row: sql.IssueCommentGetRow) -> IssueCommentRow {
  issue_comment_row(
    row.id,
    row.author_user_id,
    "",
    row.body,
    mention_store.decode_user_ids(row.mentioned_user_ids),
    row.created_at,
    row.updated_at,
  )
}

fn issue_comment_from_update_row(
  row: sql.IssueCommentUpdateRow,
) -> IssueCommentRow {
  issue_comment_row(
    row.id,
    row.author_user_id,
    "",
    row.body,
    mention_store.decode_user_ids(row.mentioned_user_ids),
    row.created_at,
    row.updated_at,
  )
}

fn issue_comment_row(
  id: String,
  author_user_id: String,
  author_name: String,
  body: String,
  mentioned_user_ids: List(String),
  created_at: String,
  updated_at: String,
) -> IssueCommentRow {
  IssueCommentRow(
    id:,
    author_user_id:,
    author_name:,
    body:,
    mentioned_user_ids:,
    created_at:,
    updated_at:,
  )
}

fn org_from_list_row(row: sql.OrgsListForUserRow) -> OrgRow {
  OrgRow(
    id: row.id,
    slug: row.slug,
    name: row.name,
    role: option.Some(row.role),
  )
}

fn org_from_get_row(row: sql.OrgsGetBySlugRow) -> OrgRow {
  OrgRow(id: row.id, slug: row.slug, name: row.name, role: option.None)
}

fn repo_from_list_row(row: sql.ReposListRow) -> RepoRow {
  RepoRow(
    id: row.id,
    name: row.name,
    description: row.description,
    disk_path: row.disk_path,
    org_slug: row.slug,
  )
}

fn repo_from_get_row(row: sql.ReposGetRow) -> RepoRow {
  RepoRow(
    id: row.id,
    name: row.name,
    description: row.description,
    disk_path: row.disk_path,
    org_slug: row.slug,
  )
}

fn repo_from_update_row(row: sql.ReposUpdateRow) -> RepoRow {
  RepoRow(
    id: row.id,
    name: row.name,
    description: row.description,
    disk_path: row.disk_path,
    org_slug: row.slug,
  )
}

fn repo_from_description_update_row(
  row: sql.ReposUpdateDescriptionRow,
) -> RepoRow {
  RepoRow(
    id: row.id,
    name: row.name,
    description: row.description,
    disk_path: row.disk_path,
    org_slug: row.slug,
  )
}

fn key_from_insert_row(row: sql.KeysInsertRow) -> KeyRow {
  KeyRow(
    id: row.id,
    title: row.title,
    public_key: row.public_key,
    fingerprint: row.fingerprint,
  )
}

fn key_from_list_row(row: sql.KeysListRow) -> KeyRow {
  KeyRow(
    id: row.id,
    title: row.title,
    public_key: row.public_key,
    fingerprint: row.fingerprint,
  )
}

fn format_authorized_line(
  key_blob: String,
  row: sql.KeysAuthorizedLineRow,
) -> String {
  "restrict,command=\"/usr/local/bin/git-shell.sh\",environment=\"GLEAMHUB_KEY_BLOB="
  <> key_blob
  <> "\",no-port-forwarding,no-pty,no-X11-forwarding "
  <> row.public_key
}

fn nullable_text(value: Option(String)) -> String {
  case value {
    option.Some(text) -> text
    option.None -> ""
  }
}

fn result_map_ok(
  result: Result(pog.Returned(a), pog.QueryError),
) -> Result(Nil, pog.QueryError) {
  case result {
    Ok(_) -> Ok(Nil)
    Error(e) -> Error(e)
  }
}

fn result_map_rows(
  returned: Result(pog.Returned(a), pog.QueryError),
) -> Result(List(a), pog.QueryError) {
  case returned {
    Ok(r) -> Ok(r.rows)
    Error(e) -> Error(e)
  }
}

fn result_map_first_row(
  returned: Result(pog.Returned(a), pog.QueryError),
) -> Result(a, pog.QueryError) {
  case returned {
    Ok(r) ->
      case r.rows {
        [row] -> Ok(row)
        _ -> Error(pog.ConstraintViolated("no row", "query", ""))
      }
    Error(e) -> Error(e)
  }
}

fn result_map_optional_row(
  returned: Result(pog.Returned(a), pog.QueryError),
) -> Result(Option(a), pog.QueryError) {
  case returned {
    Ok(r) ->
      case r.rows {
        [row] -> Ok(option.Some(row))
        _ -> Ok(option.None)
      }
    Error(e) -> Error(e)
  }
}

fn label_from_list_row(row: sql.LabelListRow) -> LabelRow {
  LabelRow(id: row.id, name: row.name, color: row.color)
}

fn label_from_insert_row(row: sql.LabelInsertRow) -> LabelRow {
  LabelRow(id: row.id, name: row.name, color: row.color)
}

fn label_from_get_row(row: sql.LabelGetRow) -> LabelRow {
  LabelRow(id: row.id, name: row.name, color: row.color)
}

fn label_from_update_row(row: sql.LabelUpdateRow) -> LabelRow {
  LabelRow(id: row.id, name: row.name, color: row.color)
}

fn label_link_row(id: String, name: String, color: String) -> LabelRow {
  LabelRow(id:, name:, color:)
}

fn labels_by_parent(
  rows: List(sql.IssueLabelsForRepoRow),
) -> Dict(String, List(LabelRow)) {
  list.fold(rows, dict.new(), fn(acc, row) {
    let label = label_link_row(row.id, row.name, row.color)
    dict.insert(acc, row.issue_id, append_label(acc, row.issue_id, label))
  })
}

fn mr_labels_by_parent(
  rows: List(sql.MrLabelsForRepoRow),
) -> Dict(String, List(LabelRow)) {
  list.fold(rows, dict.new(), fn(acc, row) {
    let label = label_link_row(row.id, row.name, row.color)
    dict.insert(
      acc,
      row.merge_request_id,
      append_label(acc, row.merge_request_id, label),
    )
  })
}

fn assignees_by_parent(
  rows: List(sql.IssueAssigneesForRepoRow),
  build: fn(sql.IssueAssigneesForRepoRow) -> #(String, IssueAssigneeRow),
) -> Dict(String, List(IssueAssigneeRow)) {
  list.fold(rows, dict.new(), fn(acc, row) {
    let #(parent_id, assignee) = build(row)
    dict.insert(acc, parent_id, append_assignee(acc, parent_id, assignee))
  })
}

fn append_label(
  dict_acc: Dict(String, List(LabelRow)),
  key: String,
  label: LabelRow,
) -> List(LabelRow) {
  case dict.get(dict_acc, key) {
    Ok(existing) -> list.append(existing, [label])
    Error(_) -> [label]
  }
}

fn append_assignee(
  dict_acc: Dict(String, List(IssueAssigneeRow)),
  key: String,
  assignee: IssueAssigneeRow,
) -> List(IssueAssigneeRow) {
  case dict.get(dict_acc, key) {
    Ok(existing) -> list.append(existing, [assignee])
    Error(_) -> [assignee]
  }
}

fn dict_get_list(
  labels: Dict(String, List(LabelRow)),
  key: String,
) -> List(LabelRow) {
  case dict.get(labels, key) {
    Ok(items) -> items
    Error(_) -> []
  }
}

fn dict_get_assignees(
  assignees: Dict(String, List(IssueAssigneeRow)),
  key: String,
) -> List(IssueAssigneeRow) {
  case dict.get(assignees, key) {
    Ok(items) -> items
    Error(_) -> []
  }
}

fn milestones_by_parent(
  rows: List(sql.IssueMilestonesForRepoRow),
) -> Dict(String, IssueMilestoneRow) {
  list.fold(rows, dict.new(), fn(acc, row) {
    dict.insert(
      acc,
      row.issue_id,
      IssueMilestoneRow(
        id: row.milestone_id,
        number: row.milestone_number,
        title: row.milestone_title,
      ),
    )
  })
}

fn dict_get_milestone(
  milestones: Dict(String, IssueMilestoneRow),
  key: String,
) -> Option(IssueMilestoneRow) {
  case dict.get(milestones, key) {
    Ok(milestone) -> option.Some(milestone)
    Error(_) -> option.None
  }
}

pub fn normalize_label_name(name: String) -> Result(String, LabelError) {
  let trimmed = string.trim(name)
  case trimmed {
    "" -> Error(InvalidLabelName)
    _ ->
      case string.length(trimmed) > 50 {
        True -> Error(InvalidLabelName)
        False -> Ok(trimmed)
      }
  }
}

const default_label_colors = [
  "#d73a4a", "#0075ca", "#7057ff", "#008672", "#e99695", "#f9d0c4", "#fef2c0",
  "#c2e0c6", "#bfd4f2", "#d4c5f9",
]

fn normalize_label_color(color: String, name: String) -> String {
  let trimmed = string.lowercase(string.trim(color))
  case valid_label_color(trimmed) {
    True -> trimmed
    False -> {
      let len = list.length(default_label_colors)
      case int.remainder(string.length(name), len) {
        Ok(index) ->
          case list.drop(default_label_colors, index) {
            [first, ..] -> first
            _ -> "#6b7280"
          }
        Error(_) -> "#6b7280"
      }
    }
  }
}

fn valid_label_color(color: String) -> Bool {
  case string.length(color) {
    7 ->
      string.starts_with(color, "#")
      && is_hex_string(string.drop_start(color, 1))
    _ -> False
  }
}

fn is_hex_string(value: String) -> Bool {
  value
  |> string.to_graphemes
  |> list.all(fn(char) { string.contains("0123456789abcdef", char) })
}

fn validate_repo_label_ids(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  label_ids: List(String),
) -> Result(List(String), LabelError) {
  case label_ids {
    [] -> Ok([])
    _ ->
      case sql.label_ids_for_repo(db, org_slug, repo_name) |> result_map_rows {
        Ok(rows) -> {
          let allowed = list.map(rows, fn(row) { row.id })
          let invalid =
            list.filter(label_ids, fn(id) { !list.contains(allowed, id) })
          case invalid {
            [_, ..] -> Error(InvalidLabelIds)
            [] -> Ok(list.unique(label_ids))
          }
        }
        Error(_) -> Error(InvalidLabelIds)
      }
  }
}

fn validate_org_assignees(
  db: pog.Connection,
  org_slug: String,
  assignee_user_ids: List(String),
) -> Result(Nil, LabelError) {
  list.fold(assignee_user_ids, Ok(Nil), fn(acc, user_id) {
    case acc {
      Error(e) -> Error(e)
      Ok(Nil) ->
        case is_org_member(db, user_id, org_slug) {
          True -> Ok(Nil)
          False -> Error(InvalidAssignees)
        }
    }
  })
}

fn validate_mr_reviewers(
  reviewer_user_ids: List(String),
  author_user_id: String,
) -> Result(Nil, LabelError) {
  case list.contains(reviewer_user_ids, author_user_id) {
    True -> Error(AuthorCannotReview)
    False -> Ok(Nil)
  }
}

fn parse_entity_id(id: String) -> Result(uuid.Uuid, LabelError) {
  case uuid.from_string(id) {
    Ok(parsed) -> Ok(parsed)
    Error(_) -> Error(InvalidLabelIds)
  }
}

fn replace_issue_labels(
  db: pog.Connection,
  issue_uuid: uuid.Uuid,
  label_ids: List(String),
) -> Result(Nil, LabelError) {
  case sql.issue_labels_delete_all(db, issue_uuid) {
    Error(_) -> Error(InvalidLabelIds)
    Ok(_) -> insert_issue_label_links(db, issue_uuid, label_ids)
  }
}

fn insert_issue_label_links(
  db: pog.Connection,
  issue_uuid: uuid.Uuid,
  label_ids: List(String),
) -> Result(Nil, LabelError) {
  list.fold(label_ids, Ok(Nil), fn(acc, label_id) {
    case acc {
      Error(e) -> Error(e)
      Ok(Nil) ->
        case uuid.from_string(label_id) {
          Error(_) -> Error(InvalidLabelIds)
          Ok(label_uuid) ->
            case sql.issue_label_insert(db, issue_uuid, label_uuid) {
              Error(_) -> Error(InvalidLabelIds)
              Ok(_) -> Ok(Nil)
            }
        }
    }
  })
}

fn replace_issue_assignees(
  db: pog.Connection,
  issue_uuid: uuid.Uuid,
  assignee_user_ids: List(String),
) -> Result(Nil, LabelError) {
  case sql.issue_assignees_delete_all(db, issue_uuid) {
    Error(_) -> Error(InvalidAssignees)
    Ok(_) -> insert_issue_assignee_links(db, issue_uuid, assignee_user_ids)
  }
}

fn insert_issue_assignee_links(
  db: pog.Connection,
  issue_uuid: uuid.Uuid,
  assignee_user_ids: List(String),
) -> Result(Nil, LabelError) {
  list.fold(assignee_user_ids, Ok(Nil), fn(acc, user_id) {
    case acc {
      Error(e) -> Error(e)
      Ok(Nil) ->
        case sql.issue_assignee_insert(db, issue_uuid, user_id) {
          Error(_) -> Error(InvalidAssignees)
          Ok(_) -> Ok(Nil)
        }
    }
  })
}

fn replace_issue_mr_links(
  db: pog.Connection,
  mr_uuid: uuid.Uuid,
  links: List(#(String, String)),
) -> Result(Nil, pog.QueryError) {
  case sql.issue_mr_links_delete_for_mr(db, mr_uuid) {
    Error(e) -> Error(e)
    Ok(_) -> insert_issue_mr_links(db, mr_uuid, links)
  }
}

fn insert_issue_mr_links(
  db: pog.Connection,
  mr_uuid: uuid.Uuid,
  links: List(#(String, String)),
) -> Result(Nil, pog.QueryError) {
  list.fold(links, Ok(Nil), fn(acc, link) {
    case acc {
      Error(e) -> Error(e)
      Ok(Nil) -> {
        let #(issue_id, link_type) = link
        let assert Ok(issue_uuid) = uuid.from_string(issue_id)
        case sql.issue_mr_link_insert(db, issue_uuid, mr_uuid, link_type) {
          Error(e) -> Error(e)
          Ok(_) -> Ok(Nil)
        }
      }
    }
  })
}

fn linked_issue_from_row(row: sql.IssueMrLinksForMrRow) -> LinkedIssueRow {
  let sql.IssueMrLinksForMrRow(number:, title:, state:, link_type:) = row
  LinkedIssueRow(number:, title:, state:, link_type:)
}

fn linked_mr_from_row(row: sql.IssueMrLinksForIssueRow) -> LinkedMergeRequestRow {
  let sql.IssueMrLinksForIssueRow(
    number:,
    title:,
    state:,
    is_draft:,
    link_type:,
  ) = row
  LinkedMergeRequestRow(number:, title:, state:, is_draft:, link_type:)
}

fn closes_issue_ref_from_row(row: sql.IssueMrLinksClosesForMrRow) -> ClosesIssueRef {
  let sql.IssueMrLinksClosesForMrRow(number:, repo_name:) = row
  ClosesIssueRef(number:, repo_name:)
}

fn replace_mr_labels(
  db: pog.Connection,
  mr_uuid: uuid.Uuid,
  label_ids: List(String),
) -> Result(Nil, LabelError) {
  case sql.mr_labels_delete_all(db, mr_uuid) {
    Error(_) -> Error(InvalidLabelIds)
    Ok(_) -> insert_mr_label_links(db, mr_uuid, label_ids)
  }
}

fn insert_mr_label_links(
  db: pog.Connection,
  mr_uuid: uuid.Uuid,
  label_ids: List(String),
) -> Result(Nil, LabelError) {
  list.fold(label_ids, Ok(Nil), fn(acc, label_id) {
    case acc {
      Error(e) -> Error(e)
      Ok(Nil) ->
        case uuid.from_string(label_id) {
          Error(_) -> Error(InvalidLabelIds)
          Ok(label_uuid) ->
            case sql.mr_label_insert(db, mr_uuid, label_uuid) {
              Error(_) -> Error(InvalidLabelIds)
              Ok(_) -> Ok(Nil)
            }
        }
    }
  })
}

fn set_issue_labels_queries(
  db: pog.Connection,
  issue_uuid: uuid.Uuid,
  label_ids: List(String),
) -> Result(Nil, LabelError) {
  replace_issue_labels(db, issue_uuid, label_ids)
}

fn set_issue_assignees_queries(
  db: pog.Connection,
  issue_uuid: uuid.Uuid,
  assignee_user_ids: List(String),
) -> Result(Nil, LabelError) {
  replace_issue_assignees(db, issue_uuid, assignee_user_ids)
}

fn set_mr_labels_queries(
  db: pog.Connection,
  mr_uuid: uuid.Uuid,
  label_ids: List(String),
) -> Result(Nil, LabelError) {
  replace_mr_labels(db, mr_uuid, label_ids)
}

fn replace_mr_assignees(
  db: pog.Connection,
  mr_uuid: uuid.Uuid,
  assignee_user_ids: List(String),
) -> Result(Nil, LabelError) {
  case sql.mr_assignees_delete_all(db, mr_uuid) {
    Error(_) -> Error(InvalidAssignees)
    Ok(_) -> insert_mr_assignee_links(db, mr_uuid, assignee_user_ids)
  }
}

fn insert_mr_assignee_links(
  db: pog.Connection,
  mr_uuid: uuid.Uuid,
  assignee_user_ids: List(String),
) -> Result(Nil, LabelError) {
  list.fold(assignee_user_ids, Ok(Nil), fn(acc, user_id) {
    case acc {
      Error(e) -> Error(e)
      Ok(Nil) ->
        case sql.mr_assignee_insert(db, mr_uuid, user_id) {
          Error(_) -> Error(InvalidAssignees)
          Ok(_) -> Ok(Nil)
        }
    }
  })
}

fn set_merge_request_assignees_queries(
  db: pog.Connection,
  mr_uuid: uuid.Uuid,
  assignee_user_ids: List(String),
) -> Result(Nil, LabelError) {
  replace_mr_assignees(db, mr_uuid, assignee_user_ids)
}

fn set_merge_request_reviewers_queries(
  db: pog.Connection,
  mr_uuid: uuid.Uuid,
  requested_by_user_id: String,
  reviewer_user_ids: List(String),
) -> Result(Nil, LabelError) {
  replace_mr_reviewers(
    db,
    mr_uuid,
    requested_by_user_id,
    reviewer_user_ids,
  )
}

fn replace_mr_reviewers(
  db: pog.Connection,
  mr_uuid: uuid.Uuid,
  requested_by_user_id: String,
  reviewer_user_ids: List(String),
) -> Result(Nil, LabelError) {
  case sql.mr_reviewers_delete_all(db, mr_uuid) {
    Error(_) -> Error(InvalidAssignees)
    Ok(_) ->
      insert_mr_reviewer_links(
        db,
        mr_uuid,
        requested_by_user_id,
        reviewer_user_ids,
      )
  }
}

fn insert_mr_reviewer_links(
  db: pog.Connection,
  mr_uuid: uuid.Uuid,
  requested_by_user_id: String,
  reviewer_user_ids: List(String),
) -> Result(Nil, LabelError) {
  list.fold(reviewer_user_ids, Ok(Nil), fn(acc, user_id) {
    case acc {
      Error(e) -> Error(e)
      Ok(Nil) ->
        case sql.mr_reviewer_insert(db, mr_uuid, user_id, requested_by_user_id) {
          Error(_) -> Error(InvalidAssignees)
          Ok(_) -> Ok(Nil)
        }
    }
  })
}

fn map_transaction_label_error(
  result: Result(Nil, pog.TransactionError(LabelError)),
) -> Result(Nil, LabelError) {
  case result {
    Ok(Nil) -> Ok(Nil)
    Error(pog.TransactionRolledBack(e)) -> Error(e)
    Error(pog.TransactionQueryError(_)) -> Error(InvalidLabelIds)
  }
}

pub fn list_releases(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
) -> Result(List(ReleaseRow), pog.QueryError) {
  sql.release_list(db, org_slug, repo_name)
  |> result_map_rows
  |> result.map(list.map(_, release_from_list_row))
}

pub fn get_release_by_tag(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  tag_name: String,
) -> Result(Option(ReleaseRow), pog.QueryError) {
  case normalize_release_tag_name(tag_name) {
    Error(_) -> Ok(option.None)
    Ok(normalized) ->
      sql.release_get(db, org_slug, repo_name, normalized)
      |> result_map_optional_row
      |> result.map(option.map(_, release_from_get_row))
  }
}

pub fn create_release(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  tag_name: String,
  target_commit_sha: String,
  title: String,
  body: String,
  author_user_id: String,
) -> Result(ReleaseRow, ReleaseError) {
  case normalize_release_tag_name(tag_name) {
    Error(_) -> Error(InvalidTagName)
    Ok(normalized_tag) ->
      case normalize_release_title(title) {
        Error(_) -> Error(InvalidReleaseTitle)
        Ok(normalized_title) ->
          case
            sql.release_insert(
              db,
              org_slug,
              repo_name,
              normalized_tag,
              target_commit_sha,
              normalized_title,
              body,
              author_user_id,
            )
            |> result_map_first_row
          {
            Ok(row) -> Ok(release_from_insert_row(row))
            Error(pog.ConstraintViolated(..)) -> Error(DuplicateRelease)
            Error(_) -> Error(InvalidReleaseTitle)
          }
      }
  }
}

pub fn update_release(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  tag_name: String,
  title: String,
  body: String,
) -> Result(ReleaseRow, ReleaseError) {
  case normalize_release_tag_name(tag_name) {
    Error(_) -> Error(InvalidTagName)
    Ok(normalized_tag) ->
      case normalize_release_title(title) {
        Error(_) -> Error(InvalidReleaseTitle)
        Ok(normalized_title) ->
          case
            sql.release_update(
              db,
              org_slug,
              repo_name,
              normalized_tag,
              normalized_title,
              body,
            )
            |> result_map_first_row
          {
            Ok(row) -> Ok(release_from_update_row(row))
            Error(_) -> Error(ReleaseNotFound)
          }
      }
  }
}

fn normalize_release_tag_name(name: String) -> Result(String, Nil) {
  let trimmed = string.trim(name)
  case trimmed {
    "" -> Error(Nil)
    _ ->
      case string.length(trimmed) > 255 {
        True -> Error(Nil)
        False -> Ok(trimmed)
      }
  }
}

fn normalize_release_title(title: String) -> Result(String, Nil) {
  let trimmed = string.trim(title)
  case trimmed {
    "" -> Error(Nil)
    _ ->
      case string.length(trimmed) > 255 {
        True -> Error(Nil)
        False -> Ok(trimmed)
      }
  }
}

fn release_from_list_row(row: sql.ReleaseListRow) -> ReleaseRow {
  ReleaseRow(
    id: row.id,
    tag_name: row.tag_name,
    target_commit_sha: row.target_commit_sha,
    title: row.title,
    body: row.body,
    author_user_id: row.author_user_id,
    created_at: row.created_at,
  )
}

fn release_from_get_row(row: sql.ReleaseGetRow) -> ReleaseRow {
  ReleaseRow(
    id: row.id,
    tag_name: row.tag_name,
    target_commit_sha: row.target_commit_sha,
    title: row.title,
    body: row.body,
    author_user_id: row.author_user_id,
    created_at: row.created_at,
  )
}

fn release_from_insert_row(row: sql.ReleaseInsertRow) -> ReleaseRow {
  ReleaseRow(
    id: row.id,
    tag_name: row.tag_name,
    target_commit_sha: row.target_commit_sha,
    title: row.title,
    body: row.body,
    author_user_id: row.author_user_id,
    created_at: row.created_at,
  )
}

fn release_from_update_row(row: sql.ReleaseUpdateRow) -> ReleaseRow {
  ReleaseRow(
    id: row.id,
    tag_name: row.tag_name,
    target_commit_sha: row.target_commit_sha,
    title: row.title,
    body: row.body,
    author_user_id: row.author_user_id,
    created_at: row.created_at,
  )
}

pub fn list_milestones(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
) -> Result(List(MilestoneRow), pog.QueryError) {
  sql.milestone_list(db, org_slug, repo_name)
  |> result_map_rows
  |> result.map(list.map(_, milestone_from_list_row))
}

pub fn get_milestone(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
) -> Result(Option(MilestoneRow), pog.QueryError) {
  sql.milestone_get(db, org_slug, repo_name, number)
  |> result_map_optional_row
  |> result.map(option.map(_, milestone_from_get_row))
}

pub fn insert_milestone(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  title: String,
  description: Option(String),
  due_on: Option(String),
) -> Result(MilestoneRow, MilestoneError) {
  case normalize_milestone_title(title) {
    Error(_) -> Error(InvalidMilestoneTitle)
    Ok(normalized_title) ->
      case
        sql.milestone_insert(
          db,
          org_slug,
          repo_name,
          normalized_title,
          nullable_text(description),
          nullable_text(due_on),
        )
        |> result_map_first_row
      {
        Ok(row) ->
          case get_milestone(db, org_slug, repo_name, row.number) {
            Error(_) -> Error(InvalidMilestoneTitle)
            Ok(option.None) -> Error(InvalidMilestoneTitle)
            Ok(option.Some(milestone)) -> Ok(milestone)
          }
        Error(_) -> Error(InvalidMilestoneTitle)
      }
  }
}

pub fn update_milestone(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
  title: String,
  description: Option(String),
  due_on: Option(String),
) -> Result(MilestoneRow, MilestoneError) {
  case normalize_milestone_title(title) {
    Error(_) -> Error(InvalidMilestoneTitle)
    Ok(normalized_title) ->
      case
        sql.milestone_update(
          db,
          org_slug,
          repo_name,
          number,
          normalized_title,
          nullable_text(description),
          nullable_text(due_on),
        )
        |> result_map_first_row
      {
        Ok(_row) ->
          case get_milestone(db, org_slug, repo_name, number) {
            Error(_) -> Error(MilestoneNotFound)
            Ok(option.None) -> Error(MilestoneNotFound)
            Ok(option.Some(milestone)) -> Ok(milestone)
          }
        Error(_) -> Error(MilestoneNotFound)
      }
  }
}

pub fn close_milestone(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
) -> Result(MilestoneRow, MilestoneError) {
  case
    sql.milestone_close(db, org_slug, repo_name, number)
    |> result_map_first_row
  {
    Ok(_row) ->
      case get_milestone(db, org_slug, repo_name, number) {
        Error(_) -> Error(MilestoneNotFound)
        Ok(option.None) -> Error(MilestoneNotFound)
        Ok(option.Some(milestone)) -> Ok(milestone)
      }
    Error(_) -> Error(MilestoneNotFound)
  }
}

pub fn set_issue_milestone(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  number: Int,
  milestone_id: Option(String),
) -> Result(IssueRow, MilestoneError) {
  case
    sql.issue_set_milestone(
      db,
      org_slug,
      repo_name,
      number,
      nullable_text(milestone_id),
    )
    |> result_map_first_row
  {
    Ok(row) -> Ok(issue_from_set_milestone_row(row))
    Error(_) -> Error(InvalidMilestone)
  }
}

pub fn resolve_milestone_id(
  milestones: List(MilestoneRow),
  param: String,
) -> Result(String, MilestoneError) {
  case list.find(milestones, fn(milestone) {
    int.to_string(milestone.number) == param
    || string.lowercase(milestone.title) == string.lowercase(param)
  }) {
    Ok(milestone) -> Ok(milestone.id)
    Error(_) -> Error(InvalidMilestone)
  }
}

fn normalize_milestone_title(title: String) -> Result(String, Nil) {
  let trimmed = string.trim(title)
  case trimmed {
    "" -> Error(Nil)
    _ ->
      case string.length(trimmed) > 255 {
        True -> Error(Nil)
        False -> Ok(trimmed)
      }
  }
}

fn milestone_from_list_row(row: sql.MilestoneListRow) -> MilestoneRow {
  milestone_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.state,
    row.due_on,
    row.closed_at,
    row.created_at,
    row.updated_at,
    row.open_issues,
    row.closed_issues,
    row.open_mrs,
  )
}

fn milestone_from_get_row(row: sql.MilestoneGetRow) -> MilestoneRow {
  milestone_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.state,
    row.due_on,
    row.closed_at,
    row.created_at,
    row.updated_at,
    row.open_issues,
    row.closed_issues,
    row.open_mrs,
  )
}

fn milestone_row(
  id: String,
  number: Int,
  title: String,
  description: Option(String),
  state: String,
  due_on: String,
  closed_at: String,
  created_at: String,
  updated_at: String,
  open_issues: Int,
  closed_issues: Int,
  open_mrs: Int,
) -> MilestoneRow {
  MilestoneRow(
    id:,
    number:,
    title:,
    description:,
    state:,
    due_on: optional_date(due_on),
    closed_at: optional_timestamp(closed_at),
    created_at:,
    updated_at:,
    open_issues:,
    closed_issues:,
    open_mrs:,
  )
}

fn issue_from_set_milestone_row(row: sql.IssueSetMilestoneRow) -> IssueRow {
  issue_row(
    row.id,
    row.number,
    row.title,
    row.description,
    row.author_user_id,
    row.state,
    row.closed_at,
    row.created_at,
    row.updated_at,
  )
}

fn optional_date(value: String) -> Option(String) {
  case value {
    "" -> option.None
    _ -> option.Some(value)
  }
}
