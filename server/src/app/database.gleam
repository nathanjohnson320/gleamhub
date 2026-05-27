import app/sql
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import pog
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
    merge_commit_sha: Option(String),
    merged_by_user_id: Option(String),
    merged_at: Option(String),
    closed_at: Option(String),
    created_at: String,
    updated_at: String,
  )
}

pub type MergeRequestCommentRow {
  MergeRequestCommentRow(
    id: String,
    author_user_id: String,
    body: String,
    file_path: Option(String),
    line: Option(Int),
    created_at: String,
    updated_at: String,
  )
}

pub fn upsert_user(
  db: pog.Connection,
  id: String,
  display_name: Option(String),
  email: Option(String),
) -> Result(Nil, pog.QueryError) {
  sql.users_upsert(
    db,
    id,
    nullable_text(display_name),
    nullable_text(email),
  )
  |> result_map_ok
}

pub fn list_orgs_for_user(db: pog.Connection, user_id: String) -> Result(
  List(OrgRow),
  pog.QueryError,
) {
  sql.orgs_list_for_user(db, user_id)
  |> result_map_rows
  |> result.map(list.map(_, org_from_list_row))
}

pub fn get_org_by_slug(db: pog.Connection, slug: String) -> Result(
  Option(OrgRow),
  pog.QueryError,
) {
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
        _ ->
          Error(pog.ConstraintViolated("no org row", "organizations", ""))
      }
    Error(e) -> Error(e)
  }
}

pub fn is_org_member(db: pog.Connection, user_id: String, org_slug: String) -> Bool {
  case member_role(db, user_id, org_slug) {
    Ok(option.Some(_)) -> True
    _ -> False
  }
}

pub fn is_org_owner(db: pog.Connection, user_id: String, org_slug: String) -> Bool {
  case member_role(db, user_id, org_slug) {
    Ok(option.Some("owner")) -> True
    _ -> False
  }
}

pub fn member_can_write(db: pog.Connection, user_id: String, org_slug: String) -> Bool {
  case member_role(db, user_id, org_slug) {
    Ok(option.Some(role)) -> role == "owner" || role == "member"
    _ -> False
  }
}

fn member_role(
  db: pog.Connection,
  user_id: String,
  org_slug: String,
) -> Result(Option(String), pog.QueryError) {
  sql.org_member_role(db, user_id, org_slug)
  |> result_map_optional_row
  |> result.map(option.map(_, fn(row) { row.role }))
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

pub fn list_repos(db: pog.Connection, org_slug: String) -> Result(
  List(RepoRow),
  pog.QueryError,
) {
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

pub fn insert_repo(
  db: pog.Connection,
  org_slug: String,
  name: String,
  description: Option(String),
  disk_path: String,
) -> Result(RepoRow, pog.QueryError) {
  sql.repos_insert(
    db,
    org_slug,
    name,
    nullable_text(description),
    disk_path,
  )
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

pub fn list_keys(db: pog.Connection, user_id: String) -> Result(
  List(KeyRow),
  pog.QueryError,
) {
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

pub fn delete_key(db: pog.Connection, user_id: String, key_id: String) -> Result(
  Bool,
  pog.QueryError,
) {
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

pub fn authorized_key_line(db: pog.Connection, key_blob: String) -> Result(
  Option(String),
  pog.QueryError,
) {
  sql.keys_authorized_line(db, key_blob)
  |> result_map_optional_row
  |> result.map(option.map(_, format_authorized_line))
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
      insert_protected_branches(db, org_slug, repo_name, rest, [
        inserted,
        ..acc
      ])
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
  sql.mr_list(db, org_slug, repo_name)
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
  )
  |> result_map_first_row
  |> result.map(mr_from_insert_row)
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
  )
  |> result_map_first_row
  |> result.map(mr_comment_from_insert_row)
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
    row.merge_commit_sha,
    row.merged_by_user_id,
    row.merged_at,
    row.closed_at,
    row.created_at,
    row.updated_at,
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
    merge_commit_sha:,
    merged_by_user_id:,
    merged_at: optional_timestamp(merged_at),
    closed_at: optional_timestamp(closed_at),
    created_at:,
    updated_at:,
  )
}

fn optional_timestamp(value: String) -> Option(String) {
  case string.trim(value) {
    "" -> option.None
    trimmed -> option.Some(trimmed)
  }
}

fn mr_comment_from_list_row(row: sql.MrCommentsListRow) -> MergeRequestCommentRow {
  mr_comment_row(
    row.id,
    row.author_user_id,
    row.body,
    row.file_path,
    row.line,
    row.created_at,
    row.updated_at,
  )
}

fn mr_comment_from_insert_row(row: sql.MrCommentsInsertRow) -> MergeRequestCommentRow {
  mr_comment_row(
    row.id,
    row.author_user_id,
    row.body,
    row.file_path,
    row.line,
    row.created_at,
    row.updated_at,
  )
}

fn mr_comment_row(
  id: String,
  author_user_id: String,
  body: String,
  file_path: Option(String),
  line: Option(Int),
  created_at: String,
  updated_at: String,
) -> MergeRequestCommentRow {
  MergeRequestCommentRow(
    id:,
    author_user_id:,
    body:,
    file_path:,
    line:,
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

fn format_authorized_line(row: sql.KeysAuthorizedLineRow) -> String {
  "restrict,command=\"/usr/local/bin/git-shell.sh\",environment=\"GLEAMHUB_USER_ID="
  <> row.user_id
  <> "\",no-port-forwarding,no-pty,no-X11-forwarding "
  <> row.public_key
}

fn nullable_text(value: Option(String)) -> String {
  case value {
    option.Some(text) -> text
    option.None -> ""
  }
}

fn result_map_ok(result: Result(pog.Returned(a), pog.QueryError)) -> Result(
  Nil,
  pog.QueryError,
) {
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
        _ ->
          Error(pog.ConstraintViolated("no row", "query", ""))
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
