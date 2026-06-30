//// This module contains the code to run the sql queries defined in
//// `./src/sql`.
//// > 🐿️ This module was generated automatically using v4.7.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/option.{type Option}
import pog
import youid/uuid.{type Uuid}

/// Runs the `issue_assignee_insert` query
/// defined in `./src/sql/issue_assignee_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_assignee_insert(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO issue_assignees (issue_id, user_id)
VALUES ($1::uuid, $2);
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `issue_assignees_delete_all` query
/// defined in `./src/sql/issue_assignees_delete_all.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_assignees_delete_all(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM issue_assignees
WHERE issue_id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_assignees_for_issue` query
/// defined in `./src/sql/issue_assignees_for_issue.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueAssigneesForIssueRow {
  IssueAssigneesForIssueRow(user_id: String)
}

/// Runs the `issue_assignees_for_issue` query
/// defined in `./src/sql/issue_assignees_for_issue.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_assignees_for_issue(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(IssueAssigneesForIssueRow), pog.QueryError) {
  let decoder = {
    use user_id <- decode.field(0, decode.string)
    decode.success(IssueAssigneesForIssueRow(user_id:))
  }

  "SELECT ia.user_id
FROM issue_assignees ia
WHERE ia.issue_id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_assignees_for_repo` query
/// defined in `./src/sql/issue_assignees_for_repo.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueAssigneesForRepoRow {
  IssueAssigneesForRepoRow(issue_id: String, user_id: String)
}

/// Runs the `issue_assignees_for_repo` query
/// defined in `./src/sql/issue_assignees_for_repo.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_assignees_for_repo(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
) -> Result(pog.Returned(IssueAssigneesForRepoRow), pog.QueryError) {
  let decoder = {
    use issue_id <- decode.field(0, decode.string)
    use user_id <- decode.field(1, decode.string)
    decode.success(IssueAssigneesForRepoRow(issue_id:, user_id:))
  }

  "SELECT
  ia.issue_id::text,
  ia.user_id
FROM issue_assignees ia
INNER JOIN issues i ON i.id = ia.issue_id
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_close` query
/// defined in `./src/sql/issue_close.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueCloseRow {
  IssueCloseRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    author_user_id: String,
    state: String,
    closed_at: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `issue_close` query
/// defined in `./src/sql/issue_close.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_close(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  i_number: Int,
) -> Result(pog.Returned(IssueCloseRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use state <- decode.field(5, decode.string)
    use closed_at <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use updated_at <- decode.field(8, decode.string)
    decode.success(IssueCloseRow(
      id:,
      number:,
      title:,
      description:,
      author_user_id:,
      state:,
      closed_at:,
      created_at:,
      updated_at:,
    ))
  }

  "UPDATE issues i
SET state = 'closed', closed_at = now(), updated_at = now()
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE i.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND i.number = $3
  AND i.state = 'open'
RETURNING
  i.id::text,
  i.number,
  i.title,
  i.description,
  i.author_user_id,
  i.state,
  COALESCE(i.closed_at::text, '') AS closed_at,
  i.created_at::text,
  i.updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(i_number))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_comment_delete` query
/// defined in `./src/sql/issue_comment_delete.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueCommentDeleteRow {
  IssueCommentDeleteRow(id: String)
}

/// Runs the `issue_comment_delete` query
/// defined in `./src/sql/issue_comment_delete.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_comment_delete(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  i_number: Int,
  arg_4: Uuid,
) -> Result(pog.Returned(IssueCommentDeleteRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    decode.success(IssueCommentDeleteRow(id:))
  }

  "DELETE FROM issue_comments c
USING issues i, repositories r, organizations o
WHERE c.issue_id = i.id
  AND i.repository_id = r.id
  AND o.id = r.organization_id
  AND o.slug = $1
  AND r.name = $2
  AND i.number = $3
  AND c.id = $4::uuid
RETURNING c.id::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(i_number))
  |> pog.parameter(pog.text(uuid.to_string(arg_4)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_comment_get` query
/// defined in `./src/sql/issue_comment_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueCommentGetRow {
  IssueCommentGetRow(
    id: String,
    author_user_id: String,
    body: String,
    mentioned_user_ids: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `issue_comment_get` query
/// defined in `./src/sql/issue_comment_get.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_comment_get(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  i_number: Int,
  arg_4: Uuid,
) -> Result(pog.Returned(IssueCommentGetRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use author_user_id <- decode.field(1, decode.string)
    use body <- decode.field(2, decode.string)
    use mentioned_user_ids <- decode.field(3, decode.string)
    use created_at <- decode.field(4, decode.string)
    use updated_at <- decode.field(5, decode.string)
    decode.success(IssueCommentGetRow(
      id:,
      author_user_id:,
      body:,
      mentioned_user_ids:,
      created_at:,
      updated_at:,
    ))
  }

  "SELECT
  c.id::text,
  c.author_user_id,
  c.body,
  c.mentioned_user_ids::text,
  c.created_at::text,
  c.updated_at::text
FROM issue_comments c
INNER JOIN issues i ON i.id = c.issue_id
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND i.number = $3 AND c.id = $4::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(i_number))
  |> pog.parameter(pog.text(uuid.to_string(arg_4)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_comment_update` query
/// defined in `./src/sql/issue_comment_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueCommentUpdateRow {
  IssueCommentUpdateRow(
    id: String,
    author_user_id: String,
    body: String,
    mentioned_user_ids: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `issue_comment_update` query
/// defined in `./src/sql/issue_comment_update.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_comment_update(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  i_number: Int,
  arg_4: Uuid,
  arg_5: String,
  arg_6: Json,
) -> Result(pog.Returned(IssueCommentUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use author_user_id <- decode.field(1, decode.string)
    use body <- decode.field(2, decode.string)
    use mentioned_user_ids <- decode.field(3, decode.string)
    use created_at <- decode.field(4, decode.string)
    use updated_at <- decode.field(5, decode.string)
    decode.success(IssueCommentUpdateRow(
      id:,
      author_user_id:,
      body:,
      mentioned_user_ids:,
      created_at:,
      updated_at:,
    ))
  }

  "UPDATE issue_comments c
SET
  body = $5,
  mentioned_user_ids = $6::jsonb,
  updated_at = now()
FROM issues i
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE c.issue_id = i.id
  AND o.slug = $1
  AND r.name = $2
  AND i.number = $3
  AND c.id = $4::uuid
RETURNING
  c.id::text,
  c.author_user_id,
  c.body,
  c.mentioned_user_ids::text,
  c.created_at::text,
  c.updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(i_number))
  |> pog.parameter(pog.text(uuid.to_string(arg_4)))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(json.to_string(arg_6)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_comments_insert` query
/// defined in `./src/sql/issue_comments_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueCommentsInsertRow {
  IssueCommentsInsertRow(
    id: String,
    author_user_id: String,
    body: String,
    mentioned_user_ids: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `issue_comments_insert` query
/// defined in `./src/sql/issue_comments_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_comments_insert(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  i_number: Int,
  arg_4: String,
  arg_5: String,
  arg_6: Json,
) -> Result(pog.Returned(IssueCommentsInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use author_user_id <- decode.field(1, decode.string)
    use body <- decode.field(2, decode.string)
    use mentioned_user_ids <- decode.field(3, decode.string)
    use created_at <- decode.field(4, decode.string)
    use updated_at <- decode.field(5, decode.string)
    decode.success(IssueCommentsInsertRow(
      id:,
      author_user_id:,
      body:,
      mentioned_user_ids:,
      created_at:,
      updated_at:,
    ))
  }

  "INSERT INTO issue_comments (
  issue_id,
  author_user_id,
  body,
  mentioned_user_ids
)
SELECT i.id, $4, $5, $6::jsonb
FROM issues i
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND i.number = $3
RETURNING
  id::text,
  author_user_id,
  body,
  mentioned_user_ids::text,
  created_at::text,
  updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(i_number))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(json.to_string(arg_6)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_comments_list` query
/// defined in `./src/sql/issue_comments_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueCommentsListRow {
  IssueCommentsListRow(
    id: String,
    author_user_id: String,
    author_name: String,
    body: String,
    mentioned_user_ids: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `issue_comments_list` query
/// defined in `./src/sql/issue_comments_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_comments_list(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  i_number: Int,
) -> Result(pog.Returned(IssueCommentsListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use author_user_id <- decode.field(1, decode.string)
    use author_name <- decode.field(2, decode.string)
    use body <- decode.field(3, decode.string)
    use mentioned_user_ids <- decode.field(4, decode.string)
    use created_at <- decode.field(5, decode.string)
    use updated_at <- decode.field(6, decode.string)
    decode.success(IssueCommentsListRow(
      id:,
      author_user_id:,
      author_name:,
      body:,
      mentioned_user_ids:,
      created_at:,
      updated_at:,
    ))
  }

  "SELECT
  c.id::text,
  c.author_user_id,
  c.author_user_id AS author_name,
  c.body,
  c.mentioned_user_ids::text,
  c.created_at::text,
  c.updated_at::text
FROM issue_comments c
INNER JOIN issues i ON i.id = c.issue_id
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND i.number = $3
ORDER BY c.created_at ASC;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(i_number))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_get` query
/// defined in `./src/sql/issue_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueGetRow {
  IssueGetRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    author_user_id: String,
    state: String,
    closed_at: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `issue_get` query
/// defined in `./src/sql/issue_get.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_get(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: Int,
) -> Result(pog.Returned(IssueGetRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use state <- decode.field(5, decode.string)
    use closed_at <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use updated_at <- decode.field(8, decode.string)
    decode.success(IssueGetRow(
      id:,
      number:,
      title:,
      description:,
      author_user_id:,
      state:,
      closed_at:,
      created_at:,
      updated_at:,
    ))
  }

  "SELECT
  i.id::text,
  i.number,
  i.title,
  i.description,
  i.author_user_id,
  i.state,
  COALESCE(i.closed_at::text, '') AS closed_at,
  i.created_at::text,
  i.updated_at::text
FROM issues i
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND i.number = $3;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_insert` query
/// defined in `./src/sql/issue_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueInsertRow {
  IssueInsertRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    author_user_id: String,
    state: String,
    closed_at: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `issue_insert` query
/// defined in `./src/sql/issue_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_insert(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
) -> Result(pog.Returned(IssueInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use state <- decode.field(5, decode.string)
    use closed_at <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use updated_at <- decode.field(8, decode.string)
    decode.success(IssueInsertRow(
      id:,
      number:,
      title:,
      description:,
      author_user_id:,
      state:,
      closed_at:,
      created_at:,
      updated_at:,
    ))
  }

  "INSERT INTO issues (
  repository_id,
  number,
  title,
  description,
  author_user_id,
  state
)
SELECT
  r.id,
  COALESCE(
    (SELECT MAX(i.number) FROM issues i WHERE i.repository_id = r.id),
    0
  ) + 1,
  $3,
  NULLIF($4, ''),
  $5,
  'open'
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
RETURNING
  id::text,
  number,
  title,
  description,
  author_user_id,
  state,
  COALESCE(closed_at::text, '') AS closed_at,
  created_at::text,
  updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `issue_label_insert` query
/// defined in `./src/sql/issue_label_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_label_insert(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: Uuid,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO issue_labels (issue_id, label_id)
VALUES ($1::uuid, $2::uuid);
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `issue_labels_delete_all` query
/// defined in `./src/sql/issue_labels_delete_all.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_labels_delete_all(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM issue_labels
WHERE issue_id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_labels_for_issue` query
/// defined in `./src/sql/issue_labels_for_issue.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueLabelsForIssueRow {
  IssueLabelsForIssueRow(id: String, name: String, color: String)
}

/// Runs the `issue_labels_for_issue` query
/// defined in `./src/sql/issue_labels_for_issue.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_labels_for_issue(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(IssueLabelsForIssueRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use color <- decode.field(2, decode.string)
    decode.success(IssueLabelsForIssueRow(id:, name:, color:))
  }

  "SELECT
  l.id::text,
  l.name,
  l.color
FROM issue_labels il
INNER JOIN repository_labels l ON l.id = il.label_id
WHERE il.issue_id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_labels_for_repo` query
/// defined in `./src/sql/issue_labels_for_repo.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueLabelsForRepoRow {
  IssueLabelsForRepoRow(
    issue_id: String,
    id: String,
    name: String,
    color: String,
  )
}

/// Runs the `issue_labels_for_repo` query
/// defined in `./src/sql/issue_labels_for_repo.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_labels_for_repo(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
) -> Result(pog.Returned(IssueLabelsForRepoRow), pog.QueryError) {
  let decoder = {
    use issue_id <- decode.field(0, decode.string)
    use id <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    use color <- decode.field(3, decode.string)
    decode.success(IssueLabelsForRepoRow(issue_id:, id:, name:, color:))
  }

  "SELECT
  il.issue_id::text,
  l.id::text,
  l.name,
  l.color
FROM issue_labels il
INNER JOIN repository_labels l ON l.id = il.label_id
INNER JOIN issues i ON i.id = il.issue_id
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_list` query
/// defined in `./src/sql/issue_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueListRow {
  IssueListRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    author_user_id: String,
    state: String,
    closed_at: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `issue_list` query
/// defined in `./src/sql/issue_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_list(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
) -> Result(pog.Returned(IssueListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use state <- decode.field(5, decode.string)
    use closed_at <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use updated_at <- decode.field(8, decode.string)
    decode.success(IssueListRow(
      id:,
      number:,
      title:,
      description:,
      author_user_id:,
      state:,
      closed_at:,
      created_at:,
      updated_at:,
    ))
  }

  "SELECT
  i.id::text,
  i.number,
  i.title,
  i.description,
  i.author_user_id,
  i.state,
  COALESCE(i.closed_at::text, '') AS closed_at,
  i.created_at::text,
  i.updated_at::text
FROM issues i
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
ORDER BY i.number DESC;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_milestones_for_repo` query
/// defined in `./src/sql/issue_milestones_for_repo.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueMilestonesForRepoRow {
  IssueMilestonesForRepoRow(
    issue_id: String,
    milestone_id: String,
    milestone_number: Int,
    milestone_title: String,
  )
}

/// Runs the `issue_milestones_for_repo` query
/// defined in `./src/sql/issue_milestones_for_repo.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_milestones_for_repo(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
) -> Result(pog.Returned(IssueMilestonesForRepoRow), pog.QueryError) {
  let decoder = {
    use issue_id <- decode.field(0, decode.string)
    use milestone_id <- decode.field(1, decode.string)
    use milestone_number <- decode.field(2, decode.int)
    use milestone_title <- decode.field(3, decode.string)
    decode.success(IssueMilestonesForRepoRow(
      issue_id:,
      milestone_id:,
      milestone_number:,
      milestone_title:,
    ))
  }

  "SELECT
  i.id::text AS issue_id,
  m.id::text AS milestone_id,
  m.number AS milestone_number,
  m.title AS milestone_title
FROM issues i
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
INNER JOIN milestones m ON m.id = i.milestone_id
WHERE o.slug = $1 AND r.name = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `issue_mr_link_insert` query
/// defined in `./src/sql/issue_mr_link_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_mr_link_insert(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: Uuid,
  arg_3: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO issue_merge_request_links (issue_id, merge_request_id, link_type)
VALUES ($1::uuid, $2::uuid, $3);
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_mr_links_closes_for_mr` query
/// defined in `./src/sql/issue_mr_links_closes_for_mr.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueMrLinksClosesForMrRow {
  IssueMrLinksClosesForMrRow(number: Int, repo_name: String)
}

/// Runs the `issue_mr_links_closes_for_mr` query
/// defined in `./src/sql/issue_mr_links_closes_for_mr.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_mr_links_closes_for_mr(
  db: pog.Connection,
  arg_1: Uuid,
  o_slug: String,
) -> Result(pog.Returned(IssueMrLinksClosesForMrRow), pog.QueryError) {
  let decoder = {
    use number <- decode.field(0, decode.int)
    use repo_name <- decode.field(1, decode.string)
    decode.success(IssueMrLinksClosesForMrRow(number:, repo_name:))
  }

  "SELECT
  i.number,
  r.name AS repo_name
FROM issue_merge_request_links l
INNER JOIN issues i ON i.id = l.issue_id
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE l.merge_request_id = $1::uuid
  AND l.link_type = 'closes'
  AND i.state = 'open'
  AND o.slug = $2
ORDER BY i.number;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(o_slug))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `issue_mr_links_delete_for_mr` query
/// defined in `./src/sql/issue_mr_links_delete_for_mr.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_mr_links_delete_for_mr(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM issue_merge_request_links
WHERE merge_request_id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_mr_links_for_issue` query
/// defined in `./src/sql/issue_mr_links_for_issue.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueMrLinksForIssueRow {
  IssueMrLinksForIssueRow(
    number: Int,
    title: String,
    state: String,
    is_draft: Bool,
    link_type: String,
  )
}

/// Runs the `issue_mr_links_for_issue` query
/// defined in `./src/sql/issue_mr_links_for_issue.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_mr_links_for_issue(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(IssueMrLinksForIssueRow), pog.QueryError) {
  let decoder = {
    use number <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use state <- decode.field(2, decode.string)
    use is_draft <- decode.field(3, decode.bool)
    use link_type <- decode.field(4, decode.string)
    decode.success(IssueMrLinksForIssueRow(
      number:,
      title:,
      state:,
      is_draft:,
      link_type:,
    ))
  }

  "SELECT
  mr.number,
  mr.title,
  mr.state,
  mr.is_draft,
  l.link_type
FROM issue_merge_request_links l
INNER JOIN merge_requests mr ON mr.id = l.merge_request_id
WHERE l.issue_id = $1::uuid
ORDER BY mr.number;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_mr_links_for_mr` query
/// defined in `./src/sql/issue_mr_links_for_mr.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueMrLinksForMrRow {
  IssueMrLinksForMrRow(
    number: Int,
    title: String,
    state: String,
    link_type: String,
  )
}

/// Runs the `issue_mr_links_for_mr` query
/// defined in `./src/sql/issue_mr_links_for_mr.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_mr_links_for_mr(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(IssueMrLinksForMrRow), pog.QueryError) {
  let decoder = {
    use number <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use state <- decode.field(2, decode.string)
    use link_type <- decode.field(3, decode.string)
    decode.success(IssueMrLinksForMrRow(number:, title:, state:, link_type:))
  }

  "SELECT
  i.number,
  i.title,
  i.state,
  l.link_type
FROM issue_merge_request_links l
INNER JOIN issues i ON i.id = l.issue_id
WHERE l.merge_request_id = $1::uuid
ORDER BY i.number;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_reopen` query
/// defined in `./src/sql/issue_reopen.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueReopenRow {
  IssueReopenRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    author_user_id: String,
    state: String,
    closed_at: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `issue_reopen` query
/// defined in `./src/sql/issue_reopen.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_reopen(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  i_number: Int,
) -> Result(pog.Returned(IssueReopenRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use state <- decode.field(5, decode.string)
    use closed_at <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use updated_at <- decode.field(8, decode.string)
    decode.success(IssueReopenRow(
      id:,
      number:,
      title:,
      description:,
      author_user_id:,
      state:,
      closed_at:,
      created_at:,
      updated_at:,
    ))
  }

  "UPDATE issues i
SET state = 'open', closed_at = NULL, updated_at = now()
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE i.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND i.number = $3
  AND i.state = 'closed'
RETURNING
  i.id::text,
  i.number,
  i.title,
  i.description,
  i.author_user_id,
  i.state,
  COALESCE(i.closed_at::text, '') AS closed_at,
  i.created_at::text,
  i.updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(i_number))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_set_milestone` query
/// defined in `./src/sql/issue_set_milestone.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueSetMilestoneRow {
  IssueSetMilestoneRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    author_user_id: String,
    state: String,
    closed_at: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `issue_set_milestone` query
/// defined in `./src/sql/issue_set_milestone.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_set_milestone(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  i_number: Int,
  arg_4: String,
) -> Result(pog.Returned(IssueSetMilestoneRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use state <- decode.field(5, decode.string)
    use closed_at <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use updated_at <- decode.field(8, decode.string)
    decode.success(IssueSetMilestoneRow(
      id:,
      number:,
      title:,
      description:,
      author_user_id:,
      state:,
      closed_at:,
      created_at:,
      updated_at:,
    ))
  }

  "UPDATE issues i
SET
  milestone_id = NULLIF($4, '')::uuid,
  updated_at = now()
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE i.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND i.number = $3
  AND (
    $4 = ''
    OR EXISTS (
      SELECT 1
      FROM milestones m
      WHERE m.id = NULLIF($4, '')::uuid
        AND m.repository_id = r.id
    )
  )
RETURNING
  i.id::text,
  i.number,
  i.title,
  i.description,
  i.author_user_id,
  i.state,
  COALESCE(i.closed_at::text, '') AS closed_at,
  i.created_at::text,
  i.updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(i_number))
  |> pog.parameter(pog.text(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_update` query
/// defined in `./src/sql/issue_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueUpdateRow {
  IssueUpdateRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    author_user_id: String,
    state: String,
    closed_at: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `issue_update` query
/// defined in `./src/sql/issue_update.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_update(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  i_number: Int,
  arg_4: String,
  arg_5: String,
) -> Result(pog.Returned(IssueUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use state <- decode.field(5, decode.string)
    use closed_at <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use updated_at <- decode.field(8, decode.string)
    decode.success(IssueUpdateRow(
      id:,
      number:,
      title:,
      description:,
      author_user_id:,
      state:,
      closed_at:,
      created_at:,
      updated_at:,
    ))
  }

  "UPDATE issues i
SET
  title = $4,
  description = $5,
  updated_at = now()
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE i.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND i.number = $3
RETURNING
  i.id::text,
  i.number,
  i.title,
  i.description,
  i.author_user_id,
  i.state,
  COALESCE(i.closed_at::text, '') AS closed_at,
  i.created_at::text,
  i.updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(i_number))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `keys_authorized_line` query
/// defined in `./src/sql/keys_authorized_line.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type KeysAuthorizedLineRow {
  KeysAuthorizedLineRow(user_id: String, public_key: String)
}

/// Runs the `keys_authorized_line` query
/// defined in `./src/sql/keys_authorized_line.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn keys_authorized_line(
  db: pog.Connection,
  key_blob: String,
) -> Result(pog.Returned(KeysAuthorizedLineRow), pog.QueryError) {
  let decoder = {
    use user_id <- decode.field(0, decode.string)
    use public_key <- decode.field(1, decode.string)
    decode.success(KeysAuthorizedLineRow(user_id:, public_key:))
  }

  "SELECT user_id, public_key
FROM ssh_public_keys
WHERE key_blob = $1
LIMIT 1;
"
  |> pog.query
  |> pog.parameter(pog.text(key_blob))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `keys_delete` query
/// defined in `./src/sql/keys_delete.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn keys_delete(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM ssh_public_keys
WHERE id::text = $1 AND user_id = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `keys_find_user_for_blob` query
/// defined in `./src/sql/keys_find_user_for_blob.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type KeysFindUserForBlobRow {
  KeysFindUserForBlobRow(user_id: String)
}

/// Runs the `keys_find_user_for_blob` query
/// defined in `./src/sql/keys_find_user_for_blob.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn keys_find_user_for_blob(
  db: pog.Connection,
  key_blob: String,
) -> Result(pog.Returned(KeysFindUserForBlobRow), pog.QueryError) {
  let decoder = {
    use user_id <- decode.field(0, decode.string)
    decode.success(KeysFindUserForBlobRow(user_id:))
  }

  "SELECT user_id
FROM ssh_public_keys
WHERE key_blob = $1
LIMIT 1;
"
  |> pog.query
  |> pog.parameter(pog.text(key_blob))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `keys_insert` query
/// defined in `./src/sql/keys_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type KeysInsertRow {
  KeysInsertRow(
    id: String,
    title: String,
    public_key: String,
    fingerprint: String,
  )
}

/// Runs the `keys_insert` query
/// defined in `./src/sql/keys_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn keys_insert(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
) -> Result(pog.Returned(KeysInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use title <- decode.field(1, decode.string)
    use public_key <- decode.field(2, decode.string)
    use fingerprint <- decode.field(3, decode.string)
    decode.success(KeysInsertRow(id:, title:, public_key:, fingerprint:))
  }

  "INSERT INTO ssh_public_keys (user_id, title, public_key, key_blob, fingerprint)
VALUES ($1, $2, $3, $4, $5)
RETURNING id::text, title, public_key, fingerprint;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `keys_list` query
/// defined in `./src/sql/keys_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type KeysListRow {
  KeysListRow(
    id: String,
    title: String,
    public_key: String,
    fingerprint: String,
  )
}

/// Runs the `keys_list` query
/// defined in `./src/sql/keys_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn keys_list(
  db: pog.Connection,
  user_id: String,
) -> Result(pog.Returned(KeysListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use title <- decode.field(1, decode.string)
    use public_key <- decode.field(2, decode.string)
    use fingerprint <- decode.field(3, decode.string)
    decode.success(KeysListRow(id:, title:, public_key:, fingerprint:))
  }

  "SELECT id::text, title, public_key, fingerprint
FROM ssh_public_keys
WHERE user_id = $1
ORDER BY created_at DESC;
"
  |> pog.query
  |> pog.parameter(pog.text(user_id))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `keys_resolve_user_for_org_repo` query
/// defined in `./src/sql/keys_resolve_user_for_org_repo.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type KeysResolveUserForOrgRepoRow {
  KeysResolveUserForOrgRepoRow(user_id: String)
}

/// Runs the `keys_resolve_user_for_org_repo` query
/// defined in `./src/sql/keys_resolve_user_for_org_repo.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn keys_resolve_user_for_org_repo(
  db: pog.Connection,
  k_ey_blob: String,
  o_slug: String,
  r_name: String,
) -> Result(pog.Returned(KeysResolveUserForOrgRepoRow), pog.QueryError) {
  let decoder = {
    use user_id <- decode.field(0, decode.string)
    decode.success(KeysResolveUserForOrgRepoRow(user_id:))
  }

  "SELECT k.user_id
FROM ssh_public_keys k
INNER JOIN organization_members om ON om.user_id = k.user_id
INNER JOIN organizations o ON o.id = om.organization_id AND o.slug = $2
INNER JOIN repositories r ON r.organization_id = o.id AND r.name = $3
WHERE k.key_blob = $1
LIMIT 1;
"
  |> pog.query
  |> pog.parameter(pog.text(k_ey_blob))
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `label_delete` query
/// defined in `./src/sql/label_delete.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type LabelDeleteRow {
  LabelDeleteRow(id: String)
}

/// Runs the `label_delete` query
/// defined in `./src/sql/label_delete.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn label_delete(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: Uuid,
) -> Result(pog.Returned(LabelDeleteRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    decode.success(LabelDeleteRow(id:))
  }

  "DELETE FROM repository_labels l
USING repositories r, organizations o
WHERE l.repository_id = r.id
  AND o.id = r.organization_id
  AND o.slug = $1
  AND r.name = $2
  AND l.id = $3::uuid
RETURNING l.id::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(uuid.to_string(arg_3)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `label_get` query
/// defined in `./src/sql/label_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type LabelGetRow {
  LabelGetRow(id: String, name: String, color: String)
}

/// Runs the `label_get` query
/// defined in `./src/sql/label_get.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn label_get(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: Uuid,
) -> Result(pog.Returned(LabelGetRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use color <- decode.field(2, decode.string)
    decode.success(LabelGetRow(id:, name:, color:))
  }

  "SELECT
  l.id::text,
  l.name,
  l.color
FROM repository_labels l
INNER JOIN repositories r ON r.id = l.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND l.id = $3::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(uuid.to_string(arg_3)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `label_ids_for_repo` query
/// defined in `./src/sql/label_ids_for_repo.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type LabelIdsForRepoRow {
  LabelIdsForRepoRow(id: String)
}

/// Runs the `label_ids_for_repo` query
/// defined in `./src/sql/label_ids_for_repo.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn label_ids_for_repo(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
) -> Result(pog.Returned(LabelIdsForRepoRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    decode.success(LabelIdsForRepoRow(id:))
  }

  "SELECT l.id::text
FROM repository_labels l
INNER JOIN repositories r ON r.id = l.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `label_insert` query
/// defined in `./src/sql/label_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type LabelInsertRow {
  LabelInsertRow(id: String, name: String, color: String)
}

/// Runs the `label_insert` query
/// defined in `./src/sql/label_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn label_insert(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: String,
  arg_4: String,
) -> Result(pog.Returned(LabelInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use color <- decode.field(2, decode.string)
    decode.success(LabelInsertRow(id:, name:, color:))
  }

  "INSERT INTO repository_labels (repository_id, name, color)
SELECT r.id, $3, $4
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
RETURNING
  id::text,
  name,
  color;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `label_list` query
/// defined in `./src/sql/label_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type LabelListRow {
  LabelListRow(id: String, name: String, color: String)
}

/// Runs the `label_list` query
/// defined in `./src/sql/label_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn label_list(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
) -> Result(pog.Returned(LabelListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use color <- decode.field(2, decode.string)
    decode.success(LabelListRow(id:, name:, color:))
  }

  "SELECT
  l.id::text,
  l.name,
  l.color
FROM repository_labels l
INNER JOIN repositories r ON r.id = l.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
ORDER BY l.name ASC;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `label_update` query
/// defined in `./src/sql/label_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type LabelUpdateRow {
  LabelUpdateRow(id: String, name: String, color: String)
}

/// Runs the `label_update` query
/// defined in `./src/sql/label_update.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn label_update(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: Uuid,
  arg_4: String,
  color: String,
) -> Result(pog.Returned(LabelUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use color <- decode.field(2, decode.string)
    decode.success(LabelUpdateRow(id:, name:, color:))
  }

  "UPDATE repository_labels l
SET
  name = $4,
  color = $5
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE l.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND l.id = $3::uuid
RETURNING
  l.id::text,
  l.name,
  l.color;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(uuid.to_string(arg_3)))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(color))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `milestone_close` query
/// defined in `./src/sql/milestone_close.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MilestoneCloseRow {
  MilestoneCloseRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    state: String,
    due_on: String,
    closed_at: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `milestone_close` query
/// defined in `./src/sql/milestone_close.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn milestone_close(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  m_number: Int,
) -> Result(pog.Returned(MilestoneCloseRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use state <- decode.field(4, decode.string)
    use due_on <- decode.field(5, decode.string)
    use closed_at <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use updated_at <- decode.field(8, decode.string)
    decode.success(MilestoneCloseRow(
      id:,
      number:,
      title:,
      description:,
      state:,
      due_on:,
      closed_at:,
      created_at:,
      updated_at:,
    ))
  }

  "UPDATE milestones m
SET
  state = 'closed',
  closed_at = now(),
  updated_at = now()
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE m.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND m.number = $3
  AND m.state = 'open'
RETURNING
  m.id::text,
  m.number,
  m.title,
  m.description,
  m.state,
  COALESCE(m.due_on::text, '') AS due_on,
  COALESCE(m.closed_at::text, '') AS closed_at,
  m.created_at::text,
  m.updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(m_number))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `milestone_get` query
/// defined in `./src/sql/milestone_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MilestoneGetRow {
  MilestoneGetRow(
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
  )
}

/// Runs the `milestone_get` query
/// defined in `./src/sql/milestone_get.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn milestone_get(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: Int,
) -> Result(pog.Returned(MilestoneGetRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use state <- decode.field(4, decode.string)
    use due_on <- decode.field(5, decode.string)
    use closed_at <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use updated_at <- decode.field(8, decode.string)
    use open_issues <- decode.field(9, decode.int)
    use closed_issues <- decode.field(10, decode.int)
    use open_mrs <- decode.field(11, decode.int)
    decode.success(MilestoneGetRow(
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

  "SELECT
  m.id::text,
  m.number,
  m.title,
  m.description,
  m.state,
  COALESCE(m.due_on::text, '') AS due_on,
  COALESCE(m.closed_at::text, '') AS closed_at,
  m.created_at::text,
  m.updated_at::text,
  (
    SELECT COUNT(*)::int
    FROM issues i
    WHERE i.milestone_id = m.id AND i.state = 'open'
  ) AS open_issues,
  (
    SELECT COUNT(*)::int
    FROM issues i
    WHERE i.milestone_id = m.id AND i.state = 'closed'
  ) AS closed_issues,
  0::int AS open_mrs
FROM milestones m
INNER JOIN repositories r ON r.id = m.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND m.number = $3;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `milestone_insert` query
/// defined in `./src/sql/milestone_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MilestoneInsertRow {
  MilestoneInsertRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    state: String,
    due_on: String,
    closed_at: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `milestone_insert` query
/// defined in `./src/sql/milestone_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn milestone_insert(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
) -> Result(pog.Returned(MilestoneInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use state <- decode.field(4, decode.string)
    use due_on <- decode.field(5, decode.string)
    use closed_at <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use updated_at <- decode.field(8, decode.string)
    decode.success(MilestoneInsertRow(
      id:,
      number:,
      title:,
      description:,
      state:,
      due_on:,
      closed_at:,
      created_at:,
      updated_at:,
    ))
  }

  "INSERT INTO milestones (
  repository_id,
  number,
  title,
  description,
  due_on
)
SELECT
  r.id,
  COALESCE(
    (SELECT MAX(m.number) FROM milestones m WHERE m.repository_id = r.id),
    0
  ) + 1,
  $3,
  NULLIF($4, ''),
  NULLIF($5, '')::date
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
RETURNING
  id::text,
  number,
  title,
  description,
  state,
  COALESCE(due_on::text, '') AS due_on,
  COALESCE(closed_at::text, '') AS closed_at,
  created_at::text,
  updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `milestone_list` query
/// defined in `./src/sql/milestone_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MilestoneListRow {
  MilestoneListRow(
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
  )
}

/// Runs the `milestone_list` query
/// defined in `./src/sql/milestone_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn milestone_list(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
) -> Result(pog.Returned(MilestoneListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use state <- decode.field(4, decode.string)
    use due_on <- decode.field(5, decode.string)
    use closed_at <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use updated_at <- decode.field(8, decode.string)
    use open_issues <- decode.field(9, decode.int)
    use closed_issues <- decode.field(10, decode.int)
    use open_mrs <- decode.field(11, decode.int)
    decode.success(MilestoneListRow(
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

  "SELECT
  m.id::text,
  m.number,
  m.title,
  m.description,
  m.state,
  COALESCE(m.due_on::text, '') AS due_on,
  COALESCE(m.closed_at::text, '') AS closed_at,
  m.created_at::text,
  m.updated_at::text,
  (
    SELECT COUNT(*)::int
    FROM issues i
    WHERE i.milestone_id = m.id AND i.state = 'open'
  ) AS open_issues,
  (
    SELECT COUNT(*)::int
    FROM issues i
    WHERE i.milestone_id = m.id AND i.state = 'closed'
  ) AS closed_issues,
  0::int AS open_mrs
FROM milestones m
INNER JOIN repositories r ON r.id = m.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
ORDER BY m.number DESC;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `milestone_update` query
/// defined in `./src/sql/milestone_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MilestoneUpdateRow {
  MilestoneUpdateRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    state: String,
    due_on: String,
    closed_at: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `milestone_update` query
/// defined in `./src/sql/milestone_update.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn milestone_update(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  m_number: Int,
  arg_4: String,
  arg_5: String,
  arg_6: String,
) -> Result(pog.Returned(MilestoneUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use state <- decode.field(4, decode.string)
    use due_on <- decode.field(5, decode.string)
    use closed_at <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use updated_at <- decode.field(8, decode.string)
    decode.success(MilestoneUpdateRow(
      id:,
      number:,
      title:,
      description:,
      state:,
      due_on:,
      closed_at:,
      created_at:,
      updated_at:,
    ))
  }

  "UPDATE milestones m
SET
  title = $4,
  description = NULLIF($5, ''),
  due_on = NULLIF($6, '')::date,
  updated_at = now()
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE m.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND m.number = $3
RETURNING
  m.id::text,
  m.number,
  m.title,
  m.description,
  m.state,
  COALESCE(m.due_on::text, '') AS due_on,
  COALESCE(m.closed_at::text, '') AS closed_at,
  m.created_at::text,
  m.updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(m_number))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `mr_assignee_insert` query
/// defined in `./src/sql/mr_assignee_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_assignee_insert(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO merge_request_assignees (merge_request_id, user_id)
VALUES ($1::uuid, $2)
ON CONFLICT DO NOTHING;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `mr_assignees_delete_all` query
/// defined in `./src/sql/mr_assignees_delete_all.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_assignees_delete_all(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM merge_request_assignees
WHERE merge_request_id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_assignees_for_mr` query
/// defined in `./src/sql/mr_assignees_for_mr.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrAssigneesForMrRow {
  MrAssigneesForMrRow(user_id: String)
}

/// Runs the `mr_assignees_for_mr` query
/// defined in `./src/sql/mr_assignees_for_mr.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_assignees_for_mr(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(MrAssigneesForMrRow), pog.QueryError) {
  let decoder = {
    use user_id <- decode.field(0, decode.string)
    decode.success(MrAssigneesForMrRow(user_id:))
  }

  "SELECT
  mra.user_id
FROM merge_request_assignees mra
WHERE mra.merge_request_id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_assignees_for_repo` query
/// defined in `./src/sql/mr_assignees_for_repo.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrAssigneesForRepoRow {
  MrAssigneesForRepoRow(merge_request_id: String, user_id: String)
}

/// Runs the `mr_assignees_for_repo` query
/// defined in `./src/sql/mr_assignees_for_repo.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_assignees_for_repo(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
) -> Result(pog.Returned(MrAssigneesForRepoRow), pog.QueryError) {
  let decoder = {
    use merge_request_id <- decode.field(0, decode.string)
    use user_id <- decode.field(1, decode.string)
    decode.success(MrAssigneesForRepoRow(merge_request_id:, user_id:))
  }

  "SELECT
  mra.merge_request_id::text,
  mra.user_id
FROM merge_request_assignees mra
INNER JOIN merge_requests mr ON mr.id = mra.merge_request_id
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_close` query
/// defined in `./src/sql/mr_close.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrCloseRow {
  MrCloseRow(
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
    is_draft: Bool,
  )
}

/// Runs the `mr_close` query
/// defined in `./src/sql/mr_close.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_close(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  mr_number: Int,
) -> Result(pog.Returned(MrCloseRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use source_branch <- decode.field(5, decode.string)
    use target_branch <- decode.field(6, decode.string)
    use state <- decode.field(7, decode.string)
    use merge_commit_sha <- decode.field(8, decode.optional(decode.string))
    use merged_by_user_id <- decode.field(9, decode.optional(decode.string))
    use merged_at <- decode.field(10, decode.string)
    use closed_at <- decode.field(11, decode.string)
    use created_at <- decode.field(12, decode.string)
    use updated_at <- decode.field(13, decode.string)
    use is_draft <- decode.field(14, decode.bool)
    decode.success(MrCloseRow(
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
      merged_at:,
      closed_at:,
      created_at:,
      updated_at:,
      is_draft:,
    ))
  }

  "UPDATE merge_requests mr
SET state = 'closed', closed_at = now(), updated_at = now()
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE mr.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND mr.number = $3
  AND mr.state = 'open'
RETURNING
  mr.id::text,
  mr.number,
  mr.title,
  mr.description,
  mr.author_user_id,
  mr.source_branch,
  mr.target_branch,
  mr.state,
  mr.merge_commit_sha,
  mr.merged_by_user_id,
  COALESCE(mr.merged_at::text, '') AS merged_at,
  COALESCE(mr.closed_at::text, '') AS closed_at,
  mr.created_at::text,
  mr.updated_at::text,
  mr.is_draft;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(mr_number))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_comment_delete` query
/// defined in `./src/sql/mr_comment_delete.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrCommentDeleteRow {
  MrCommentDeleteRow(id: String)
}

/// Runs the `mr_comment_delete` query
/// defined in `./src/sql/mr_comment_delete.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_comment_delete(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  mr_number: Int,
  arg_4: Uuid,
) -> Result(pog.Returned(MrCommentDeleteRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    decode.success(MrCommentDeleteRow(id:))
  }

  "DELETE FROM merge_request_comments c
USING merge_requests mr, repositories r, organizations o
WHERE c.merge_request_id = mr.id
  AND mr.repository_id = r.id
  AND o.id = r.organization_id
  AND o.slug = $1
  AND r.name = $2
  AND mr.number = $3
  AND c.id = $4::uuid
RETURNING c.id::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(mr_number))
  |> pog.parameter(pog.text(uuid.to_string(arg_4)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_comment_get` query
/// defined in `./src/sql/mr_comment_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrCommentGetRow {
  MrCommentGetRow(
    id: String,
    author_user_id: String,
    body: String,
    file_path: Option(String),
    line: Option(Int),
    mentioned_user_ids: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `mr_comment_get` query
/// defined in `./src/sql/mr_comment_get.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_comment_get(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  mr_number: Int,
  arg_4: Uuid,
) -> Result(pog.Returned(MrCommentGetRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use author_user_id <- decode.field(1, decode.string)
    use body <- decode.field(2, decode.string)
    use file_path <- decode.field(3, decode.optional(decode.string))
    use line <- decode.field(4, decode.optional(decode.int))
    use mentioned_user_ids <- decode.field(5, decode.string)
    use created_at <- decode.field(6, decode.string)
    use updated_at <- decode.field(7, decode.string)
    decode.success(MrCommentGetRow(
      id:,
      author_user_id:,
      body:,
      file_path:,
      line:,
      mentioned_user_ids:,
      created_at:,
      updated_at:,
    ))
  }

  "SELECT
  c.id::text,
  c.author_user_id,
  c.body,
  c.file_path,
  c.line,
  c.mentioned_user_ids::text,
  c.created_at::text,
  c.updated_at::text
FROM merge_request_comments c
INNER JOIN merge_requests mr ON mr.id = c.merge_request_id
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND mr.number = $3 AND c.id = $4::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(mr_number))
  |> pog.parameter(pog.text(uuid.to_string(arg_4)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_comment_update` query
/// defined in `./src/sql/mr_comment_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrCommentUpdateRow {
  MrCommentUpdateRow(
    id: String,
    author_user_id: String,
    body: String,
    file_path: Option(String),
    line: Option(Int),
    mentioned_user_ids: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `mr_comment_update` query
/// defined in `./src/sql/mr_comment_update.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_comment_update(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  mr_number: Int,
  arg_4: Uuid,
  arg_5: String,
  arg_6: Json,
) -> Result(pog.Returned(MrCommentUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use author_user_id <- decode.field(1, decode.string)
    use body <- decode.field(2, decode.string)
    use file_path <- decode.field(3, decode.optional(decode.string))
    use line <- decode.field(4, decode.optional(decode.int))
    use mentioned_user_ids <- decode.field(5, decode.string)
    use created_at <- decode.field(6, decode.string)
    use updated_at <- decode.field(7, decode.string)
    decode.success(MrCommentUpdateRow(
      id:,
      author_user_id:,
      body:,
      file_path:,
      line:,
      mentioned_user_ids:,
      created_at:,
      updated_at:,
    ))
  }

  "UPDATE merge_request_comments c
SET
  body = $5,
  mentioned_user_ids = $6::jsonb,
  updated_at = now()
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE c.merge_request_id = mr.id
  AND o.slug = $1
  AND r.name = $2
  AND mr.number = $3
  AND c.id = $4::uuid
RETURNING
  c.id::text,
  c.author_user_id,
  c.body,
  c.file_path,
  c.line,
  c.mentioned_user_ids::text,
  c.created_at::text,
  c.updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(mr_number))
  |> pog.parameter(pog.text(uuid.to_string(arg_4)))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(json.to_string(arg_6)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_comments_insert` query
/// defined in `./src/sql/mr_comments_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrCommentsInsertRow {
  MrCommentsInsertRow(
    id: String,
    author_user_id: String,
    body: String,
    file_path: Option(String),
    line: Option(Int),
    mentioned_user_ids: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `mr_comments_insert` query
/// defined in `./src/sql/mr_comments_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_comments_insert(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  mr_number: Int,
  arg_4: String,
  arg_5: String,
  arg_6: String,
  arg_7: Int,
  arg_8: Json,
) -> Result(pog.Returned(MrCommentsInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use author_user_id <- decode.field(1, decode.string)
    use body <- decode.field(2, decode.string)
    use file_path <- decode.field(3, decode.optional(decode.string))
    use line <- decode.field(4, decode.optional(decode.int))
    use mentioned_user_ids <- decode.field(5, decode.string)
    use created_at <- decode.field(6, decode.string)
    use updated_at <- decode.field(7, decode.string)
    decode.success(MrCommentsInsertRow(
      id:,
      author_user_id:,
      body:,
      file_path:,
      line:,
      mentioned_user_ids:,
      created_at:,
      updated_at:,
    ))
  }

  "INSERT INTO merge_request_comments (
  merge_request_id,
  author_user_id,
  body,
  file_path,
  line,
  mentioned_user_ids
)
SELECT
  mr.id,
  $4,
  $5,
  NULLIF($6, ''),
  CASE WHEN $7 = 0 THEN NULL ELSE $7 END,
  $8::jsonb
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND mr.number = $3
RETURNING
  id::text,
  author_user_id,
  body,
  file_path,
  line,
  mentioned_user_ids::text,
  created_at::text,
  updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(mr_number))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.int(arg_7))
  |> pog.parameter(pog.text(json.to_string(arg_8)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_comments_list` query
/// defined in `./src/sql/mr_comments_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrCommentsListRow {
  MrCommentsListRow(
    id: String,
    author_user_id: String,
    author_name: String,
    body: String,
    file_path: Option(String),
    line: Option(Int),
    mentioned_user_ids: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `mr_comments_list` query
/// defined in `./src/sql/mr_comments_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_comments_list(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  mr_number: Int,
) -> Result(pog.Returned(MrCommentsListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use author_user_id <- decode.field(1, decode.string)
    use author_name <- decode.field(2, decode.string)
    use body <- decode.field(3, decode.string)
    use file_path <- decode.field(4, decode.optional(decode.string))
    use line <- decode.field(5, decode.optional(decode.int))
    use mentioned_user_ids <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use updated_at <- decode.field(8, decode.string)
    decode.success(MrCommentsListRow(
      id:,
      author_user_id:,
      author_name:,
      body:,
      file_path:,
      line:,
      mentioned_user_ids:,
      created_at:,
      updated_at:,
    ))
  }

  "SELECT
  c.id::text,
  c.author_user_id,
  c.author_user_id AS author_name,
  c.body,
  c.file_path,
  c.line,
  c.mentioned_user_ids::text,
  c.created_at::text,
  c.updated_at::text
FROM merge_request_comments c
INNER JOIN merge_requests mr ON mr.id = c.merge_request_id
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND mr.number = $3
ORDER BY c.created_at ASC;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(mr_number))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_find_open` query
/// defined in `./src/sql/mr_find_open.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrFindOpenRow {
  MrFindOpenRow(number: Int)
}

/// Runs the `mr_find_open` query
/// defined in `./src/sql/mr_find_open.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_find_open(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  mr_source_branch: String,
  mr_target_branch: String,
) -> Result(pog.Returned(MrFindOpenRow), pog.QueryError) {
  let decoder = {
    use number <- decode.field(0, decode.int)
    decode.success(MrFindOpenRow(number:))
  }

  "SELECT mr.number
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1
  AND r.name = $2
  AND mr.source_branch = $3
  AND mr.target_branch = $4
  AND mr.state = 'open'
LIMIT 1;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(mr_source_branch))
  |> pog.parameter(pog.text(mr_target_branch))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_get` query
/// defined in `./src/sql/mr_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrGetRow {
  MrGetRow(
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
    is_draft: Bool,
  )
}

/// Runs the `mr_get` query
/// defined in `./src/sql/mr_get.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_get(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: Int,
) -> Result(pog.Returned(MrGetRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use source_branch <- decode.field(5, decode.string)
    use target_branch <- decode.field(6, decode.string)
    use state <- decode.field(7, decode.string)
    use merge_commit_sha <- decode.field(8, decode.optional(decode.string))
    use merged_by_user_id <- decode.field(9, decode.optional(decode.string))
    use merged_at <- decode.field(10, decode.string)
    use closed_at <- decode.field(11, decode.string)
    use created_at <- decode.field(12, decode.string)
    use updated_at <- decode.field(13, decode.string)
    use is_draft <- decode.field(14, decode.bool)
    decode.success(MrGetRow(
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
      merged_at:,
      closed_at:,
      created_at:,
      updated_at:,
      is_draft:,
    ))
  }

  "SELECT
  mr.id::text,
  mr.number,
  mr.title,
  mr.description,
  mr.author_user_id,
  mr.source_branch,
  mr.target_branch,
  mr.state,
  mr.merge_commit_sha,
  mr.merged_by_user_id,
  COALESCE(mr.merged_at::text, '') AS merged_at,
  COALESCE(mr.closed_at::text, '') AS closed_at,
  mr.created_at::text,
  mr.updated_at::text,
  mr.is_draft
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND mr.number = $3;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_get_by_id` query
/// defined in `./src/sql/mr_get_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrGetByIdRow {
  MrGetByIdRow(
    id: String,
    number: Int,
    merge_request_title: String,
    author_user_id: String,
    org_slug: String,
    repo_name: String,
  )
}

/// Runs the `mr_get_by_id` query
/// defined in `./src/sql/mr_get_by_id.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_get_by_id(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(MrGetByIdRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use merge_request_title <- decode.field(2, decode.string)
    use author_user_id <- decode.field(3, decode.string)
    use org_slug <- decode.field(4, decode.string)
    use repo_name <- decode.field(5, decode.string)
    decode.success(MrGetByIdRow(
      id:,
      number:,
      merge_request_title:,
      author_user_id:,
      org_slug:,
      repo_name:,
    ))
  }

  "SELECT
  mr.id::text,
  mr.number,
  mr.title AS merge_request_title,
  mr.author_user_id,
  o.slug AS org_slug,
  r.name AS repo_name
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE mr.id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_insert` query
/// defined in `./src/sql/mr_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrInsertRow {
  MrInsertRow(
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
    is_draft: Bool,
  )
}

/// Runs the `mr_insert` query
/// defined in `./src/sql/mr_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_insert(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
  arg_6: String,
  arg_7: String,
  arg_8: Bool,
) -> Result(pog.Returned(MrInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use source_branch <- decode.field(5, decode.string)
    use target_branch <- decode.field(6, decode.string)
    use state <- decode.field(7, decode.string)
    use merge_commit_sha <- decode.field(8, decode.optional(decode.string))
    use merged_by_user_id <- decode.field(9, decode.optional(decode.string))
    use merged_at <- decode.field(10, decode.string)
    use closed_at <- decode.field(11, decode.string)
    use created_at <- decode.field(12, decode.string)
    use updated_at <- decode.field(13, decode.string)
    use is_draft <- decode.field(14, decode.bool)
    decode.success(MrInsertRow(
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
      merged_at:,
      closed_at:,
      created_at:,
      updated_at:,
      is_draft:,
    ))
  }

  "INSERT INTO merge_requests (
  repository_id,
  number,
  title,
  description,
  author_user_id,
  source_branch,
  target_branch,
  state,
  is_draft
)
SELECT
  r.id,
  COALESCE(
    (SELECT MAX(m.number) FROM merge_requests m WHERE m.repository_id = r.id),
    0
  ) + 1,
  $3,
  NULLIF($4, ''),
  $5,
  $6,
  $7,
  'open',
  $8
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
RETURNING
  id::text,
  number,
  title,
  description,
  author_user_id,
  source_branch,
  target_branch,
  state,
  merge_commit_sha,
  merged_by_user_id,
  COALESCE(merged_at::text, '') AS merged_at,
  COALESCE(closed_at::text, '') AS closed_at,
  created_at::text,
  updated_at::text,
  is_draft;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.text(arg_7))
  |> pog.parameter(pog.bool(arg_8))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `mr_label_insert` query
/// defined in `./src/sql/mr_label_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_label_insert(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: Uuid,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO merge_request_labels (merge_request_id, label_id)
VALUES ($1::uuid, $2::uuid);
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `mr_labels_delete_all` query
/// defined in `./src/sql/mr_labels_delete_all.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_labels_delete_all(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM merge_request_labels
WHERE merge_request_id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_labels_for_merge_request` query
/// defined in `./src/sql/mr_labels_for_merge_request.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrLabelsForMergeRequestRow {
  MrLabelsForMergeRequestRow(id: String, name: String, color: String)
}

/// Runs the `mr_labels_for_merge_request` query
/// defined in `./src/sql/mr_labels_for_merge_request.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_labels_for_merge_request(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(MrLabelsForMergeRequestRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use color <- decode.field(2, decode.string)
    decode.success(MrLabelsForMergeRequestRow(id:, name:, color:))
  }

  "SELECT
  l.id::text,
  l.name,
  l.color
FROM merge_request_labels ml
INNER JOIN repository_labels l ON l.id = ml.label_id
WHERE ml.merge_request_id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_labels_for_repo` query
/// defined in `./src/sql/mr_labels_for_repo.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrLabelsForRepoRow {
  MrLabelsForRepoRow(
    merge_request_id: String,
    id: String,
    name: String,
    color: String,
  )
}

/// Runs the `mr_labels_for_repo` query
/// defined in `./src/sql/mr_labels_for_repo.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_labels_for_repo(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
) -> Result(pog.Returned(MrLabelsForRepoRow), pog.QueryError) {
  let decoder = {
    use merge_request_id <- decode.field(0, decode.string)
    use id <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    use color <- decode.field(3, decode.string)
    decode.success(MrLabelsForRepoRow(merge_request_id:, id:, name:, color:))
  }

  "SELECT
  mrl.merge_request_id::text,
  l.id::text,
  l.name,
  l.color
FROM merge_request_labels mrl
INNER JOIN repository_labels l ON l.id = mrl.label_id
INNER JOIN merge_requests mr ON mr.id = mrl.merge_request_id
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_list` query
/// defined in `./src/sql/mr_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrListRow {
  MrListRow(
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
    is_draft: Bool,
  )
}

/// Runs the `mr_list` query
/// defined in `./src/sql/mr_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_list(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
) -> Result(pog.Returned(MrListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use source_branch <- decode.field(5, decode.string)
    use target_branch <- decode.field(6, decode.string)
    use state <- decode.field(7, decode.string)
    use merge_commit_sha <- decode.field(8, decode.optional(decode.string))
    use merged_by_user_id <- decode.field(9, decode.optional(decode.string))
    use merged_at <- decode.field(10, decode.string)
    use closed_at <- decode.field(11, decode.string)
    use created_at <- decode.field(12, decode.string)
    use updated_at <- decode.field(13, decode.string)
    use is_draft <- decode.field(14, decode.bool)
    decode.success(MrListRow(
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
      merged_at:,
      closed_at:,
      created_at:,
      updated_at:,
      is_draft:,
    ))
  }

  "SELECT
  mr.id::text,
  mr.number,
  mr.title,
  mr.description,
  mr.author_user_id,
  mr.source_branch,
  mr.target_branch,
  mr.state,
  mr.merge_commit_sha,
  mr.merged_by_user_id,
  COALESCE(mr.merged_at::text, '') AS merged_at,
  COALESCE(mr.closed_at::text, '') AS closed_at,
  mr.created_at::text,
  mr.updated_at::text,
  mr.is_draft
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
ORDER BY mr.number DESC;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_list_open_by_source` query
/// defined in `./src/sql/mr_list_open_by_source.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrListOpenBySourceRow {
  MrListOpenBySourceRow(
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
    is_draft: Bool,
  )
}

/// Runs the `mr_list_open_by_source` query
/// defined in `./src/sql/mr_list_open_by_source.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_list_open_by_source(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  mr_source_branch: String,
) -> Result(pog.Returned(MrListOpenBySourceRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use source_branch <- decode.field(5, decode.string)
    use target_branch <- decode.field(6, decode.string)
    use state <- decode.field(7, decode.string)
    use merge_commit_sha <- decode.field(8, decode.optional(decode.string))
    use merged_by_user_id <- decode.field(9, decode.optional(decode.string))
    use merged_at <- decode.field(10, decode.string)
    use closed_at <- decode.field(11, decode.string)
    use created_at <- decode.field(12, decode.string)
    use updated_at <- decode.field(13, decode.string)
    use is_draft <- decode.field(14, decode.bool)
    decode.success(MrListOpenBySourceRow(
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
      merged_at:,
      closed_at:,
      created_at:,
      updated_at:,
      is_draft:,
    ))
  }

  "SELECT
  mr.id::text,
  mr.number,
  mr.title,
  mr.description,
  mr.author_user_id,
  mr.source_branch,
  mr.target_branch,
  mr.state,
  mr.merge_commit_sha,
  mr.merged_by_user_id,
  COALESCE(mr.merged_at::text, '') AS merged_at,
  COALESCE(mr.closed_at::text, '') AS closed_at,
  mr.created_at::text,
  mr.updated_at::text,
  mr.is_draft
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1
  AND r.name = $2
  AND mr.source_branch = $3
  AND mr.state = 'open';
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(mr_source_branch))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_merge` query
/// defined in `./src/sql/mr_merge.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrMergeRow {
  MrMergeRow(
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
    is_draft: Bool,
  )
}

/// Runs the `mr_merge` query
/// defined in `./src/sql/mr_merge.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_merge(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  mr_number: Int,
  arg_4: String,
  arg_5: String,
) -> Result(pog.Returned(MrMergeRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use source_branch <- decode.field(5, decode.string)
    use target_branch <- decode.field(6, decode.string)
    use state <- decode.field(7, decode.string)
    use merge_commit_sha <- decode.field(8, decode.optional(decode.string))
    use merged_by_user_id <- decode.field(9, decode.optional(decode.string))
    use merged_at <- decode.field(10, decode.string)
    use closed_at <- decode.field(11, decode.string)
    use created_at <- decode.field(12, decode.string)
    use updated_at <- decode.field(13, decode.string)
    use is_draft <- decode.field(14, decode.bool)
    decode.success(MrMergeRow(
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
      merged_at:,
      closed_at:,
      created_at:,
      updated_at:,
      is_draft:,
    ))
  }

  "UPDATE merge_requests mr
SET
  state = 'merged',
  merge_commit_sha = $4,
  merged_by_user_id = $5,
  merged_at = now(),
  updated_at = now()
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE mr.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND mr.number = $3
  AND mr.state = 'open'
RETURNING
  mr.id::text,
  mr.number,
  mr.title,
  mr.description,
  mr.author_user_id,
  mr.source_branch,
  mr.target_branch,
  mr.state,
  mr.merge_commit_sha,
  mr.merged_by_user_id,
  COALESCE(mr.merged_at::text, '') AS merged_at,
  COALESCE(mr.closed_at::text, '') AS closed_at,
  mr.created_at::text,
  mr.updated_at::text,
  mr.is_draft;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(mr_number))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_review_approval_count` query
/// defined in `./src/sql/mr_review_approval_count.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrReviewApprovalCountRow {
  MrReviewApprovalCountRow(approval_count: Int)
}

/// Runs the `mr_review_approval_count` query
/// defined in `./src/sql/mr_review_approval_count.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_review_approval_count(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
) -> Result(pog.Returned(MrReviewApprovalCountRow), pog.QueryError) {
  let decoder = {
    use approval_count <- decode.field(0, decode.int)
    decode.success(MrReviewApprovalCountRow(approval_count:))
  }

  "SELECT COUNT(*)::int AS approval_count
FROM (
  SELECT DISTINCT ON (r.user_id) r.user_id, r.state
  FROM merge_request_reviews r
  WHERE r.merge_request_id = $1::uuid
    AND r.user_id != $2
  ORDER BY r.user_id, r.submitted_at DESC
) latest
WHERE latest.state = 'approved';
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_review_changes_requested_count` query
/// defined in `./src/sql/mr_review_changes_requested_count.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrReviewChangesRequestedCountRow {
  MrReviewChangesRequestedCountRow(changes_requested_count: Int)
}

/// Runs the `mr_review_changes_requested_count` query
/// defined in `./src/sql/mr_review_changes_requested_count.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_review_changes_requested_count(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(MrReviewChangesRequestedCountRow), pog.QueryError) {
  let decoder = {
    use changes_requested_count <- decode.field(0, decode.int)
    decode.success(MrReviewChangesRequestedCountRow(changes_requested_count:))
  }

  "SELECT COUNT(*)::int AS changes_requested_count
FROM (
  SELECT DISTINCT ON (rr.user_id) rr.user_id, rv.state
  FROM merge_request_reviewers rr
  LEFT JOIN LATERAL (
    SELECT r.state
    FROM merge_request_reviews r
    WHERE r.merge_request_id = rr.merge_request_id
      AND r.user_id = rr.user_id
    ORDER BY r.submitted_at DESC
    LIMIT 1
  ) rv ON TRUE
  WHERE rr.merge_request_id = $1::uuid
) latest
WHERE latest.state = 'changes_requested';
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_review_insert` query
/// defined in `./src/sql/mr_review_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrReviewInsertRow {
  MrReviewInsertRow(
    id: String,
    merge_request_id: String,
    user_id: String,
    state: String,
    body: Option(String),
    submitted_at: String,
  )
}

/// Runs the `mr_review_insert` query
/// defined in `./src/sql/mr_review_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_review_insert(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
  arg_3: String,
  arg_4: String,
) -> Result(pog.Returned(MrReviewInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use merge_request_id <- decode.field(1, decode.string)
    use user_id <- decode.field(2, decode.string)
    use state <- decode.field(3, decode.string)
    use body <- decode.field(4, decode.optional(decode.string))
    use submitted_at <- decode.field(5, decode.string)
    decode.success(MrReviewInsertRow(
      id:,
      merge_request_id:,
      user_id:,
      state:,
      body:,
      submitted_at:,
    ))
  }

  "INSERT INTO merge_request_reviews (merge_request_id, user_id, state, body)
VALUES ($1::uuid, $2, $3, NULLIF($4, ''))
RETURNING
  id::text,
  merge_request_id::text,
  user_id,
  state,
  body,
  submitted_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `mr_reviewer_insert` query
/// defined in `./src/sql/mr_reviewer_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_reviewer_insert(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
  arg_3: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO merge_request_reviewers (merge_request_id, user_id, requested_by_user_id)
VALUES ($1::uuid, $2, $3)
ON CONFLICT DO NOTHING;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `mr_reviewers_delete_all` query
/// defined in `./src/sql/mr_reviewers_delete_all.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_reviewers_delete_all(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM merge_request_reviewers
WHERE merge_request_id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_reviewers_for_mr` query
/// defined in `./src/sql/mr_reviewers_for_mr.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrReviewersForMrRow {
  MrReviewersForMrRow(user_id: String)
}

/// Runs the `mr_reviewers_for_mr` query
/// defined in `./src/sql/mr_reviewers_for_mr.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_reviewers_for_mr(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(MrReviewersForMrRow), pog.QueryError) {
  let decoder = {
    use user_id <- decode.field(0, decode.string)
    decode.success(MrReviewersForMrRow(user_id:))
  }

  "SELECT
  mrr.user_id
FROM merge_request_reviewers mrr
WHERE mrr.merge_request_id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_reviewers_for_repo` query
/// defined in `./src/sql/mr_reviewers_for_repo.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrReviewersForRepoRow {
  MrReviewersForRepoRow(merge_request_id: String, user_id: String)
}

/// Runs the `mr_reviewers_for_repo` query
/// defined in `./src/sql/mr_reviewers_for_repo.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_reviewers_for_repo(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
) -> Result(pog.Returned(MrReviewersForRepoRow), pog.QueryError) {
  let decoder = {
    use merge_request_id <- decode.field(0, decode.string)
    use user_id <- decode.field(1, decode.string)
    decode.success(MrReviewersForRepoRow(merge_request_id:, user_id:))
  }

  "SELECT
  mrr.merge_request_id::text,
  mrr.user_id
FROM merge_request_reviewers mrr
INNER JOIN merge_requests mr ON mr.id = mrr.merge_request_id
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_reviews_list` query
/// defined in `./src/sql/mr_reviews_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrReviewsListRow {
  MrReviewsListRow(
    id: String,
    merge_request_id: String,
    user_id: String,
    reviewer_name: String,
    state: String,
    body: Option(String),
    submitted_at: String,
  )
}

/// Runs the `mr_reviews_list` query
/// defined in `./src/sql/mr_reviews_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_reviews_list(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  mr_number: Int,
) -> Result(pog.Returned(MrReviewsListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use merge_request_id <- decode.field(1, decode.string)
    use user_id <- decode.field(2, decode.string)
    use reviewer_name <- decode.field(3, decode.string)
    use state <- decode.field(4, decode.string)
    use body <- decode.field(5, decode.optional(decode.string))
    use submitted_at <- decode.field(6, decode.string)
    decode.success(MrReviewsListRow(
      id:,
      merge_request_id:,
      user_id:,
      reviewer_name:,
      state:,
      body:,
      submitted_at:,
    ))
  }

  "SELECT
  rv.id::text,
  rv.merge_request_id::text,
  rv.user_id,
  rv.user_id AS reviewer_name,
  rv.state,
  rv.body,
  rv.submitted_at::text
FROM merge_request_reviews rv
INNER JOIN merge_requests mr ON mr.id = rv.merge_request_id
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND mr.number = $3
ORDER BY rv.submitted_at DESC;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(mr_number))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_update` query
/// defined in `./src/sql/mr_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrUpdateRow {
  MrUpdateRow(
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
    is_draft: Bool,
  )
}

/// Runs the `mr_update` query
/// defined in `./src/sql/mr_update.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_update(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  mr_number: Int,
  arg_4: String,
  arg_5: String,
) -> Result(pog.Returned(MrUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use source_branch <- decode.field(5, decode.string)
    use target_branch <- decode.field(6, decode.string)
    use state <- decode.field(7, decode.string)
    use merge_commit_sha <- decode.field(8, decode.optional(decode.string))
    use merged_by_user_id <- decode.field(9, decode.optional(decode.string))
    use merged_at <- decode.field(10, decode.string)
    use closed_at <- decode.field(11, decode.string)
    use created_at <- decode.field(12, decode.string)
    use updated_at <- decode.field(13, decode.string)
    use is_draft <- decode.field(14, decode.bool)
    decode.success(MrUpdateRow(
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
      merged_at:,
      closed_at:,
      created_at:,
      updated_at:,
      is_draft:,
    ))
  }

  "UPDATE merge_requests mr
SET
  title = $4,
  description = $5,
  updated_at = now()
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE mr.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND mr.number = $3
RETURNING
  mr.id::text,
  mr.number,
  mr.title,
  mr.description,
  mr.author_user_id,
  mr.source_branch,
  mr.target_branch,
  mr.state,
  mr.merge_commit_sha,
  mr.merged_by_user_id,
  COALESCE(mr.merged_at::text, '') AS merged_at,
  COALESCE(mr.closed_at::text, '') AS closed_at,
  mr.created_at::text,
  mr.updated_at::text,
  mr.is_draft;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(mr_number))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_update_is_draft` query
/// defined in `./src/sql/mr_update_is_draft.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrUpdateIsDraftRow {
  MrUpdateIsDraftRow(
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
    is_draft: Bool,
  )
}

/// Runs the `mr_update_is_draft` query
/// defined in `./src/sql/mr_update_is_draft.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_update_is_draft(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  mr_number: Int,
  arg_4: Bool,
) -> Result(pog.Returned(MrUpdateIsDraftRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use source_branch <- decode.field(5, decode.string)
    use target_branch <- decode.field(6, decode.string)
    use state <- decode.field(7, decode.string)
    use merge_commit_sha <- decode.field(8, decode.optional(decode.string))
    use merged_by_user_id <- decode.field(9, decode.optional(decode.string))
    use merged_at <- decode.field(10, decode.string)
    use closed_at <- decode.field(11, decode.string)
    use created_at <- decode.field(12, decode.string)
    use updated_at <- decode.field(13, decode.string)
    use is_draft <- decode.field(14, decode.bool)
    decode.success(MrUpdateIsDraftRow(
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
      merged_at:,
      closed_at:,
      created_at:,
      updated_at:,
      is_draft:,
    ))
  }

  "UPDATE merge_requests mr
SET is_draft = $4, updated_at = now()
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE mr.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND mr.number = $3
  AND mr.state = 'open'
RETURNING
  mr.id::text,
  mr.number,
  mr.title,
  mr.description,
  mr.author_user_id,
  mr.source_branch,
  mr.target_branch,
  mr.state,
  mr.merge_commit_sha,
  mr.merged_by_user_id,
  COALESCE(mr.merged_at::text, '') AS merged_at,
  COALESCE(mr.closed_at::text, '') AS closed_at,
  mr.created_at::text,
  mr.updated_at::text,
  mr.is_draft;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(mr_number))
  |> pog.parameter(pog.bool(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `notifications_insert` query
/// defined in `./src/sql/notifications_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type NotificationsInsertRow {
  NotificationsInsertRow(
    id: String,
    notification_type: String,
    payload: String,
    read_at: String,
    created_at: String,
  )
}

/// Runs the `notifications_insert` query
/// defined in `./src/sql/notifications_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn notifications_insert(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Json,
) -> Result(pog.Returned(NotificationsInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use notification_type <- decode.field(1, decode.string)
    use payload <- decode.field(2, decode.string)
    use read_at <- decode.field(3, decode.string)
    use created_at <- decode.field(4, decode.string)
    decode.success(NotificationsInsertRow(
      id:,
      notification_type:,
      payload:,
      read_at:,
      created_at:,
    ))
  }

  "INSERT INTO notifications (user_id, type, payload)
VALUES ($1, $2, $3::jsonb)
RETURNING
  id::text,
  type AS notification_type,
  payload::text,
  COALESCE(read_at::text, '') AS read_at,
  created_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(json.to_string(arg_3)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `notifications_list` query
/// defined in `./src/sql/notifications_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type NotificationsListRow {
  NotificationsListRow(
    id: String,
    notification_type: String,
    payload: String,
    read_at: String,
    created_at: String,
  )
}

/// Runs the `notifications_list` query
/// defined in `./src/sql/notifications_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn notifications_list(
  db: pog.Connection,
  user_id: String,
  arg_2: Int,
  arg_3: Int,
) -> Result(pog.Returned(NotificationsListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use notification_type <- decode.field(1, decode.string)
    use payload <- decode.field(2, decode.string)
    use read_at <- decode.field(3, decode.string)
    use created_at <- decode.field(4, decode.string)
    decode.success(NotificationsListRow(
      id:,
      notification_type:,
      payload:,
      read_at:,
      created_at:,
    ))
  }

  "SELECT
  id::text,
  type AS notification_type,
  payload::text,
  COALESCE(read_at::text, '') AS read_at,
  created_at::text
FROM notifications
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;
"
  |> pog.query
  |> pog.parameter(pog.text(user_id))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `notifications_mark_all_read` query
/// defined in `./src/sql/notifications_mark_all_read.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn notifications_mark_all_read(
  db: pog.Connection,
  user_id: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "UPDATE notifications
SET read_at = now()
WHERE user_id = $1
  AND read_at IS NULL;
"
  |> pog.query
  |> pog.parameter(pog.text(user_id))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `notifications_mark_read` query
/// defined in `./src/sql/notifications_mark_read.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type NotificationsMarkReadRow {
  NotificationsMarkReadRow(id: String)
}

/// Runs the `notifications_mark_read` query
/// defined in `./src/sql/notifications_mark_read.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn notifications_mark_read(
  db: pog.Connection,
  arg_1: Uuid,
  user_id: String,
) -> Result(pog.Returned(NotificationsMarkReadRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    decode.success(NotificationsMarkReadRow(id:))
  }

  "UPDATE notifications
SET read_at = now()
WHERE id = $1::uuid
  AND user_id = $2
  AND read_at IS NULL
RETURNING id::text;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(user_id))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `notifications_unread_count` query
/// defined in `./src/sql/notifications_unread_count.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type NotificationsUnreadCountRow {
  NotificationsUnreadCountRow(unread_count: Int)
}

/// Runs the `notifications_unread_count` query
/// defined in `./src/sql/notifications_unread_count.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn notifications_unread_count(
  db: pog.Connection,
  user_id: String,
) -> Result(pog.Returned(NotificationsUnreadCountRow), pog.QueryError) {
  let decoder = {
    use unread_count <- decode.field(0, decode.int)
    decode.success(NotificationsUnreadCountRow(unread_count:))
  }

  "SELECT COUNT(*)::int AS unread_count
FROM notifications
WHERE user_id = $1
  AND read_at IS NULL;
"
  |> pog.query
  |> pog.parameter(pog.text(user_id))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_invitations_delete` query
/// defined in `./src/sql/org_invitations_delete.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgInvitationsDeleteRow {
  OrgInvitationsDeleteRow(id: String)
}

/// Runs the `org_invitations_delete` query
/// defined in `./src/sql/org_invitations_delete.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_invitations_delete(
  db: pog.Connection,
  o_slug: String,
  arg_2: Uuid,
) -> Result(pog.Returned(OrgInvitationsDeleteRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    decode.success(OrgInvitationsDeleteRow(id:))
  }

  "DELETE FROM organization_invitations i
USING organizations o
WHERE i.organization_id = o.id
  AND o.slug = $1
  AND i.id = $2::uuid
RETURNING i.id::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_invitations_delete_by_id` query
/// defined in `./src/sql/org_invitations_delete_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgInvitationsDeleteByIdRow {
  OrgInvitationsDeleteByIdRow(id: String)
}

/// Runs the `org_invitations_delete_by_id` query
/// defined in `./src/sql/org_invitations_delete_by_id.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_invitations_delete_by_id(
  db: pog.Connection,
  arg_1: Uuid,
  invited_user_id: String,
) -> Result(pog.Returned(OrgInvitationsDeleteByIdRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    decode.success(OrgInvitationsDeleteByIdRow(id:))
  }

  "DELETE FROM organization_invitations
WHERE id = $1::uuid
  AND invited_user_id = $2
RETURNING id::text;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(invited_user_id))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_invitations_get` query
/// defined in `./src/sql/org_invitations_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgInvitationsGetRow {
  OrgInvitationsGetRow(
    id: String,
    invited_user_id: String,
    role: String,
    invited_by_user_id: String,
    created_at: String,
    slug: String,
    name: String,
  )
}

/// Runs the `org_invitations_get` query
/// defined in `./src/sql/org_invitations_get.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_invitations_get(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(OrgInvitationsGetRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use invited_user_id <- decode.field(1, decode.string)
    use role <- decode.field(2, decode.string)
    use invited_by_user_id <- decode.field(3, decode.string)
    use created_at <- decode.field(4, decode.string)
    use slug <- decode.field(5, decode.string)
    use name <- decode.field(6, decode.string)
    decode.success(OrgInvitationsGetRow(
      id:,
      invited_user_id:,
      role:,
      invited_by_user_id:,
      created_at:,
      slug:,
      name:,
    ))
  }

  "SELECT
  i.id::text,
  i.invited_user_id,
  i.role,
  i.invited_by_user_id,
  i.created_at::text,
  o.slug,
  o.name
FROM organization_invitations i
INNER JOIN organizations o ON o.id = i.organization_id
WHERE i.id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_invitations_insert` query
/// defined in `./src/sql/org_invitations_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgInvitationsInsertRow {
  OrgInvitationsInsertRow(id: String)
}

/// Runs the `org_invitations_insert` query
/// defined in `./src/sql/org_invitations_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_invitations_insert(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
  arg_3: String,
  arg_4: String,
) -> Result(pog.Returned(OrgInvitationsInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    decode.success(OrgInvitationsInsertRow(id:))
  }

  "INSERT INTO organization_invitations (
  organization_id,
  invited_user_id,
  role,
  invited_by_user_id
)
VALUES ($1::uuid, $2, $3, $4)
RETURNING id::text;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_invitations_list` query
/// defined in `./src/sql/org_invitations_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgInvitationsListRow {
  OrgInvitationsListRow(
    id: String,
    invited_user_id: String,
    role: String,
    invited_by_user_id: String,
    created_at: String,
  )
}

/// Runs the `org_invitations_list` query
/// defined in `./src/sql/org_invitations_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_invitations_list(
  db: pog.Connection,
  o_slug: String,
) -> Result(pog.Returned(OrgInvitationsListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use invited_user_id <- decode.field(1, decode.string)
    use role <- decode.field(2, decode.string)
    use invited_by_user_id <- decode.field(3, decode.string)
    use created_at <- decode.field(4, decode.string)
    decode.success(OrgInvitationsListRow(
      id:,
      invited_user_id:,
      role:,
      invited_by_user_id:,
      created_at:,
    ))
  }

  "SELECT
  i.id::text,
  i.invited_user_id,
  i.role,
  i.invited_by_user_id,
  i.created_at::text
FROM organization_invitations i
INNER JOIN organizations o ON o.id = i.organization_id
WHERE o.slug = $1
ORDER BY i.created_at DESC;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_invitations_list_for_user` query
/// defined in `./src/sql/org_invitations_list_for_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgInvitationsListForUserRow {
  OrgInvitationsListForUserRow(
    id: String,
    invited_user_id: String,
    role: String,
    invited_by_user_id: String,
    created_at: String,
    slug: String,
    name: String,
  )
}

/// Runs the `org_invitations_list_for_user` query
/// defined in `./src/sql/org_invitations_list_for_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_invitations_list_for_user(
  db: pog.Connection,
  i_nvited_user_id: String,
) -> Result(pog.Returned(OrgInvitationsListForUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use invited_user_id <- decode.field(1, decode.string)
    use role <- decode.field(2, decode.string)
    use invited_by_user_id <- decode.field(3, decode.string)
    use created_at <- decode.field(4, decode.string)
    use slug <- decode.field(5, decode.string)
    use name <- decode.field(6, decode.string)
    decode.success(OrgInvitationsListForUserRow(
      id:,
      invited_user_id:,
      role:,
      invited_by_user_id:,
      created_at:,
      slug:,
      name:,
    ))
  }

  "SELECT
  i.id::text,
  i.invited_user_id,
  i.role,
  i.invited_by_user_id,
  i.created_at::text,
  o.slug,
  o.name
FROM organization_invitations i
INNER JOIN organizations o ON o.id = i.organization_id
WHERE i.invited_user_id = $1
ORDER BY i.created_at DESC;
"
  |> pog.query
  |> pog.parameter(pog.text(i_nvited_user_id))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_member_role` query
/// defined in `./src/sql/org_member_role.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgMemberRoleRow {
  OrgMemberRoleRow(role: String)
}

/// Runs the `org_member_role` query
/// defined in `./src/sql/org_member_role.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_member_role(
  db: pog.Connection,
  m_user_id: String,
  arg_2: String,
) -> Result(pog.Returned(OrgMemberRoleRow), pog.QueryError) {
  let decoder = {
    use role <- decode.field(0, decode.string)
    decode.success(OrgMemberRoleRow(role:))
  }

  "SELECT m.role
FROM organization_members m
INNER JOIN organizations o ON o.id = m.organization_id
WHERE m.user_id = $1 AND o.slug = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(m_user_id))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_members_count_owners` query
/// defined in `./src/sql/org_members_count_owners.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgMembersCountOwnersRow {
  OrgMembersCountOwnersRow(count: Int)
}

/// Runs the `org_members_count_owners` query
/// defined in `./src/sql/org_members_count_owners.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_members_count_owners(
  db: pog.Connection,
  o_slug: String,
) -> Result(pog.Returned(OrgMembersCountOwnersRow), pog.QueryError) {
  let decoder = {
    use count <- decode.field(0, decode.int)
    decode.success(OrgMembersCountOwnersRow(count:))
  }

  "SELECT COUNT(*)::int AS count
FROM organization_members m
INNER JOIN organizations o ON o.id = m.organization_id
WHERE o.slug = $1 AND m.role = 'owner';
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `org_members_delete` query
/// defined in `./src/sql/org_members_delete.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_members_delete(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM organization_members m
USING organizations o
WHERE m.organization_id = o.id
  AND o.slug = $1
  AND m.user_id = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `org_members_insert` query
/// defined in `./src/sql/org_members_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_members_insert(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
  arg_3: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO organization_members (organization_id, user_id, role)
VALUES ($1::uuid, $2, $3);
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_members_list` query
/// defined in `./src/sql/org_members_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgMembersListRow {
  OrgMembersListRow(user_id: String, role: String, display_name: Option(String))
}

/// Runs the `org_members_list` query
/// defined in `./src/sql/org_members_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_members_list(
  db: pog.Connection,
  o_slug: String,
) -> Result(pog.Returned(OrgMembersListRow), pog.QueryError) {
  let decoder = {
    use user_id <- decode.field(0, decode.string)
    use role <- decode.field(1, decode.string)
    use display_name <- decode.field(2, decode.optional(decode.string))
    decode.success(OrgMembersListRow(user_id:, role:, display_name:))
  }

  "SELECT m.user_id, m.role, u.display_name
FROM organization_members m
INNER JOIN organizations o ON o.id = m.organization_id
LEFT JOIN users u ON u.id = m.user_id
WHERE o.slug = $1
ORDER BY m.role, m.user_id;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `org_members_update` query
/// defined in `./src/sql/org_members_update.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_members_update(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
  role: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "UPDATE organization_members m
SET role = $3
FROM organizations o
WHERE m.organization_id = o.id
  AND o.slug = $1
  AND m.user_id = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(role))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `orgs_get_by_slug` query
/// defined in `./src/sql/orgs_get_by_slug.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgsGetBySlugRow {
  OrgsGetBySlugRow(id: String, slug: String, name: String)
}

/// Runs the `orgs_get_by_slug` query
/// defined in `./src/sql/orgs_get_by_slug.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn orgs_get_by_slug(
  db: pog.Connection,
  arg_1: String,
) -> Result(pog.Returned(OrgsGetBySlugRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use slug <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    decode.success(OrgsGetBySlugRow(id:, slug:, name:))
  }

  "SELECT id::text, slug, name
FROM organizations
WHERE slug = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `orgs_insert` query
/// defined in `./src/sql/orgs_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgsInsertRow {
  OrgsInsertRow(id: String, slug: String, name: String)
}

/// Runs the `orgs_insert` query
/// defined in `./src/sql/orgs_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn orgs_insert(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
) -> Result(pog.Returned(OrgsInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use slug <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    decode.success(OrgsInsertRow(id:, slug:, name:))
  }

  "INSERT INTO organizations (slug, name)
VALUES ($1, $2)
RETURNING id::text, slug, name;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `orgs_list_for_user` query
/// defined in `./src/sql/orgs_list_for_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgsListForUserRow {
  OrgsListForUserRow(id: String, slug: String, name: String, role: String)
}

/// Runs the `orgs_list_for_user` query
/// defined in `./src/sql/orgs_list_for_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn orgs_list_for_user(
  db: pog.Connection,
  m_user_id: String,
) -> Result(pog.Returned(OrgsListForUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use slug <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    use role <- decode.field(3, decode.string)
    decode.success(OrgsListForUserRow(id:, slug:, name:, role:))
  }

  "SELECT o.id::text, o.slug, o.name, m.role
FROM organizations o
INNER JOIN organization_members m ON m.organization_id = o.id
WHERE m.user_id = $1
ORDER BY o.slug;
"
  |> pog.query
  |> pog.parameter(pog.text(m_user_id))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `pb_delete_for_repo` query
/// defined in `./src/sql/pb_delete_for_repo.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pb_delete_for_repo(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM protected_branches pb
USING repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE pb.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pb_insert` query
/// defined in `./src/sql/pb_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PbInsertRow {
  PbInsertRow(branch_name: String)
}

/// Runs the `pb_insert` query
/// defined in `./src/sql/pb_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pb_insert(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: String,
) -> Result(pog.Returned(PbInsertRow), pog.QueryError) {
  let decoder = {
    use branch_name <- decode.field(0, decode.string)
    decode.success(PbInsertRow(branch_name:))
  }

  "INSERT INTO protected_branches (repository_id, branch_name)
SELECT r.id, $3
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
RETURNING branch_name;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pb_is_protected` query
/// defined in `./src/sql/pb_is_protected.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PbIsProtectedRow {
  PbIsProtectedRow(found: Int)
}

/// Runs the `pb_is_protected` query
/// defined in `./src/sql/pb_is_protected.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pb_is_protected(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  pb_branch_name: String,
) -> Result(pog.Returned(PbIsProtectedRow), pog.QueryError) {
  let decoder = {
    use found <- decode.field(0, decode.int)
    decode.success(PbIsProtectedRow(found:))
  }

  "SELECT 1 AS found
FROM protected_branches pb
INNER JOIN repositories r ON r.id = pb.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1
  AND r.name = $2
  AND pb.branch_name = $3
LIMIT 1;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(pb_branch_name))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pb_list` query
/// defined in `./src/sql/pb_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PbListRow {
  PbListRow(branch_name: String)
}

/// Runs the `pb_list` query
/// defined in `./src/sql/pb_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pb_list(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
) -> Result(pog.Returned(PbListRow), pog.QueryError) {
  let decoder = {
    use branch_name <- decode.field(0, decode.string)
    decode.success(PbListRow(branch_name:))
  }

  "SELECT pb.branch_name
FROM protected_branches pb
INNER JOIN repositories r ON r.id = pb.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
ORDER BY pb.branch_name;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pipeline_run_claim_next` query
/// defined in `./src/sql/pipeline_run_claim_next.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PipelineRunClaimNextRow {
  PipelineRunClaimNextRow(
    id: String,
    repository_id: String,
    merge_request_id: String,
    commit_sha: String,
    module_path: String,
    entry_function: String,
    state: String,
    trigger: String,
  )
}

/// Runs the `pipeline_run_claim_next` query
/// defined in `./src/sql/pipeline_run_claim_next.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pipeline_run_claim_next(
  db: pog.Connection,
) -> Result(pog.Returned(PipelineRunClaimNextRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use repository_id <- decode.field(1, decode.string)
    use merge_request_id <- decode.field(2, decode.string)
    use commit_sha <- decode.field(3, decode.string)
    use module_path <- decode.field(4, decode.string)
    use entry_function <- decode.field(5, decode.string)
    use state <- decode.field(6, decode.string)
    use trigger <- decode.field(7, decode.string)
    decode.success(PipelineRunClaimNextRow(
      id:,
      repository_id:,
      merge_request_id:,
      commit_sha:,
      module_path:,
      entry_function:,
      state:,
      trigger:,
    ))
  }

  "UPDATE pipeline_runs pr
SET
  state = 'running',
  started_at = now()
FROM (
  SELECT id
  FROM pipeline_runs
  WHERE state = 'queued'
  ORDER BY created_at
  FOR UPDATE SKIP LOCKED
  LIMIT 1
) picked
WHERE pr.id = picked.id
RETURNING
  pr.id::text,
  pr.repository_id::text,
  COALESCE(pr.merge_request_id::text, '') AS merge_request_id,
  pr.commit_sha,
  COALESCE(pr.module_path, '') AS module_path,
  pr.entry_function,
  pr.state,
  pr.trigger;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pipeline_run_exists_for_branch_sha` query
/// defined in `./src/sql/pipeline_run_exists_for_branch_sha.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PipelineRunExistsForBranchShaRow {
  PipelineRunExistsForBranchShaRow(found: Int)
}

/// Runs the `pipeline_run_exists_for_branch_sha` query
/// defined in `./src/sql/pipeline_run_exists_for_branch_sha.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pipeline_run_exists_for_branch_sha(
  db: pog.Connection,
  arg_1: Uuid,
  branch_name: String,
  commit_sha: String,
) -> Result(pog.Returned(PipelineRunExistsForBranchShaRow), pog.QueryError) {
  let decoder = {
    use found <- decode.field(0, decode.int)
    decode.success(PipelineRunExistsForBranchShaRow(found:))
  }

  "SELECT 1 AS found
FROM pipeline_runs
WHERE repository_id = $1::uuid
  AND branch_name = $2
  AND commit_sha = $3
LIMIT 1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(branch_name))
  |> pog.parameter(pog.text(commit_sha))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pipeline_run_exists_for_sha` query
/// defined in `./src/sql/pipeline_run_exists_for_sha.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PipelineRunExistsForShaRow {
  PipelineRunExistsForShaRow(id: String)
}

/// Runs the `pipeline_run_exists_for_sha` query
/// defined in `./src/sql/pipeline_run_exists_for_sha.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pipeline_run_exists_for_sha(
  db: pog.Connection,
  arg_1: Uuid,
  pr_commit_sha: String,
) -> Result(pog.Returned(PipelineRunExistsForShaRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    decode.success(PipelineRunExistsForShaRow(id:))
  }

  "SELECT pr.id::text
FROM pipeline_runs pr
WHERE pr.merge_request_id = $1::uuid
  AND pr.commit_sha = $2
LIMIT 1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(pr_commit_sha))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pipeline_run_get_by_id` query
/// defined in `./src/sql/pipeline_run_get_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PipelineRunGetByIdRow {
  PipelineRunGetByIdRow(
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
    org_slug: String,
    repo_name: String,
    disk_path: String,
  )
}

/// Runs the `pipeline_run_get_by_id` query
/// defined in `./src/sql/pipeline_run_get_by_id.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pipeline_run_get_by_id(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(PipelineRunGetByIdRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use repository_id <- decode.field(1, decode.string)
    use merge_request_id <- decode.field(2, decode.string)
    use commit_sha <- decode.field(3, decode.string)
    use module_path <- decode.field(4, decode.string)
    use entry_function <- decode.field(5, decode.string)
    use state <- decode.field(6, decode.string)
    use trigger <- decode.field(7, decode.string)
    use log_text <- decode.field(8, decode.string)
    use started_at <- decode.field(9, decode.string)
    use finished_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    use org_slug <- decode.field(12, decode.string)
    use repo_name <- decode.field(13, decode.string)
    use disk_path <- decode.field(14, decode.string)
    decode.success(PipelineRunGetByIdRow(
      id:,
      repository_id:,
      merge_request_id:,
      commit_sha:,
      module_path:,
      entry_function:,
      state:,
      trigger:,
      log_text:,
      started_at:,
      finished_at:,
      created_at:,
      org_slug:,
      repo_name:,
      disk_path:,
    ))
  }

  "SELECT
  pr.id::text,
  pr.repository_id::text,
  COALESCE(pr.merge_request_id::text, '') AS merge_request_id,
  pr.commit_sha,
  COALESCE(pr.module_path, '') AS module_path,
  pr.entry_function,
  pr.state,
  pr.trigger,
  COALESCE(pr.log_text, '') AS log_text,
  COALESCE(pr.started_at::text, '') AS started_at,
  COALESCE(pr.finished_at::text, '') AS finished_at,
  pr.created_at::text,
  o.slug AS org_slug,
  r.name AS repo_name,
  r.disk_path
FROM pipeline_runs pr
INNER JOIN repositories r ON r.id = pr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE pr.id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pipeline_run_get_latest` query
/// defined in `./src/sql/pipeline_run_get_latest.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PipelineRunGetLatestRow {
  PipelineRunGetLatestRow(
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
  )
}

/// Runs the `pipeline_run_get_latest` query
/// defined in `./src/sql/pipeline_run_get_latest.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pipeline_run_get_latest(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(PipelineRunGetLatestRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use repository_id <- decode.field(1, decode.string)
    use merge_request_id <- decode.field(2, decode.string)
    use commit_sha <- decode.field(3, decode.string)
    use module_path <- decode.field(4, decode.string)
    use entry_function <- decode.field(5, decode.string)
    use state <- decode.field(6, decode.string)
    use trigger <- decode.field(7, decode.string)
    use log_text <- decode.field(8, decode.string)
    use started_at <- decode.field(9, decode.string)
    use finished_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    decode.success(PipelineRunGetLatestRow(
      id:,
      repository_id:,
      merge_request_id:,
      commit_sha:,
      module_path:,
      entry_function:,
      state:,
      trigger:,
      log_text:,
      started_at:,
      finished_at:,
      created_at:,
    ))
  }

  "SELECT
  pr.id::text,
  pr.repository_id::text,
  COALESCE(pr.merge_request_id::text, '') AS merge_request_id,
  pr.commit_sha,
  COALESCE(pr.module_path, '') AS module_path,
  pr.entry_function,
  pr.state,
  pr.trigger,
  COALESCE(pr.log_text, '') AS log_text,
  COALESCE(pr.started_at::text, '') AS started_at,
  COALESCE(pr.finished_at::text, '') AS finished_at,
  pr.created_at::text
FROM pipeline_runs pr
WHERE pr.merge_request_id = $1::uuid
ORDER BY pr.created_at DESC
LIMIT 1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pipeline_run_get_latest_for_branch` query
/// defined in `./src/sql/pipeline_run_get_latest_for_branch.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PipelineRunGetLatestForBranchRow {
  PipelineRunGetLatestForBranchRow(
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
  )
}

/// Runs the `pipeline_run_get_latest_for_branch` query
/// defined in `./src/sql/pipeline_run_get_latest_for_branch.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pipeline_run_get_latest_for_branch(
  db: pog.Connection,
  arg_1: Uuid,
  pr_branch_name: String,
) -> Result(pog.Returned(PipelineRunGetLatestForBranchRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use repository_id <- decode.field(1, decode.string)
    use merge_request_id <- decode.field(2, decode.string)
    use commit_sha <- decode.field(3, decode.string)
    use module_path <- decode.field(4, decode.string)
    use entry_function <- decode.field(5, decode.string)
    use state <- decode.field(6, decode.string)
    use trigger <- decode.field(7, decode.string)
    use log_text <- decode.field(8, decode.string)
    use started_at <- decode.field(9, decode.string)
    use finished_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    decode.success(PipelineRunGetLatestForBranchRow(
      id:,
      repository_id:,
      merge_request_id:,
      commit_sha:,
      module_path:,
      entry_function:,
      state:,
      trigger:,
      log_text:,
      started_at:,
      finished_at:,
      created_at:,
    ))
  }

  "SELECT
  pr.id::text,
  pr.repository_id::text,
  COALESCE(pr.merge_request_id::text, '') AS merge_request_id,
  pr.commit_sha,
  COALESCE(pr.module_path, '') AS module_path,
  pr.entry_function,
  pr.state,
  pr.trigger,
  COALESCE(pr.log_text, '') AS log_text,
  COALESCE(pr.started_at::text, '') AS started_at,
  COALESCE(pr.finished_at::text, '') AS finished_at,
  pr.created_at::text
FROM pipeline_runs pr
WHERE pr.repository_id = $1::uuid
  AND pr.branch_name = $2
ORDER BY pr.created_at DESC
LIMIT 1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(pr_branch_name))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pipeline_run_insert` query
/// defined in `./src/sql/pipeline_run_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PipelineRunInsertRow {
  PipelineRunInsertRow(
    id: String,
    repository_id: String,
    merge_request_id: String,
    branch_name: String,
    commit_sha: String,
    module_path: String,
    entry_function: String,
    state: String,
    trigger: String,
    log_text: String,
    started_at: String,
    finished_at: String,
    created_at: String,
  )
}

/// Runs the `pipeline_run_insert` query
/// defined in `./src/sql/pipeline_run_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pipeline_run_insert(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
  arg_6: String,
  arg_7: String,
  arg_8: String,
) -> Result(pog.Returned(PipelineRunInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use repository_id <- decode.field(1, decode.string)
    use merge_request_id <- decode.field(2, decode.string)
    use branch_name <- decode.field(3, decode.string)
    use commit_sha <- decode.field(4, decode.string)
    use module_path <- decode.field(5, decode.string)
    use entry_function <- decode.field(6, decode.string)
    use state <- decode.field(7, decode.string)
    use trigger <- decode.field(8, decode.string)
    use log_text <- decode.field(9, decode.string)
    use started_at <- decode.field(10, decode.string)
    use finished_at <- decode.field(11, decode.string)
    use created_at <- decode.field(12, decode.string)
    decode.success(PipelineRunInsertRow(
      id:,
      repository_id:,
      merge_request_id:,
      branch_name:,
      commit_sha:,
      module_path:,
      entry_function:,
      state:,
      trigger:,
      log_text:,
      started_at:,
      finished_at:,
      created_at:,
    ))
  }

  "INSERT INTO pipeline_runs (
  repository_id,
  merge_request_id,
  branch_name,
  commit_sha,
  module_path,
  entry_function,
  state,
  trigger
)
VALUES (
  $1::uuid,
  NULLIF($2, '')::uuid,
  NULLIF($3, ''),
  $4,
  NULLIF($5, ''),
  $6,
  $7,
  $8
)
RETURNING
  id::text,
  repository_id::text,
  COALESCE(merge_request_id::text, '') AS merge_request_id,
  COALESCE(branch_name, '') AS branch_name,
  commit_sha,
  COALESCE(module_path, '') AS module_path,
  entry_function,
  state,
  trigger,
  COALESCE(log_text, '') AS log_text,
  COALESCE(started_at::text, '') AS started_at,
  COALESCE(finished_at::text, '') AS finished_at,
  created_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.text(arg_7))
  |> pog.parameter(pog.text(arg_8))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pipeline_run_list_for_mr` query
/// defined in `./src/sql/pipeline_run_list_for_mr.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PipelineRunListForMrRow {
  PipelineRunListForMrRow(
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
  )
}

/// Runs the `pipeline_run_list_for_mr` query
/// defined in `./src/sql/pipeline_run_list_for_mr.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pipeline_run_list_for_mr(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(PipelineRunListForMrRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use repository_id <- decode.field(1, decode.string)
    use merge_request_id <- decode.field(2, decode.string)
    use commit_sha <- decode.field(3, decode.string)
    use module_path <- decode.field(4, decode.string)
    use entry_function <- decode.field(5, decode.string)
    use state <- decode.field(6, decode.string)
    use trigger <- decode.field(7, decode.string)
    use log_text <- decode.field(8, decode.string)
    use started_at <- decode.field(9, decode.string)
    use finished_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    decode.success(PipelineRunListForMrRow(
      id:,
      repository_id:,
      merge_request_id:,
      commit_sha:,
      module_path:,
      entry_function:,
      state:,
      trigger:,
      log_text:,
      started_at:,
      finished_at:,
      created_at:,
    ))
  }

  "SELECT
  pr.id::text,
  pr.repository_id::text,
  COALESCE(pr.merge_request_id::text, '') AS merge_request_id,
  pr.commit_sha,
  COALESCE(pr.module_path, '') AS module_path,
  pr.entry_function,
  pr.state,
  pr.trigger,
  COALESCE(pr.log_text, '') AS log_text,
  COALESCE(pr.started_at::text, '') AS started_at,
  COALESCE(pr.finished_at::text, '') AS finished_at,
  pr.created_at::text
FROM pipeline_runs pr
WHERE pr.merge_request_id = $1::uuid
ORDER BY pr.created_at DESC
LIMIT 50;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `pipeline_run_reclaim_stale_queued` query
/// defined in `./src/sql/pipeline_run_reclaim_stale_queued.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pipeline_run_reclaim_stale_queued(
  db: pog.Connection,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "UPDATE pipeline_runs
SET
  state = 'failure',
  finished_at = now(),
  log_text = 'No CI worker claimed this job'
WHERE state = 'queued'
  AND created_at < now() - interval '10 minutes';
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `pipeline_run_reclaim_stale_running` query
/// defined in `./src/sql/pipeline_run_reclaim_stale_running.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pipeline_run_reclaim_stale_running(
  db: pog.Connection,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "UPDATE pipeline_runs
SET
  state = 'failure',
  finished_at = now(),
  log_text = CASE
    WHEN COALESCE(log_text, '') = '' THEN 'CI job timed out or worker stopped'
    ELSE
      log_text
      || E'\\n\\n[Job stopped: no completion within 5 minutes. If checks still show running, restart the CI worker and re-run checks.]'
  END
WHERE state = 'running'
  AND started_at < now() - interval '5 minutes';
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pipeline_run_update` query
/// defined in `./src/sql/pipeline_run_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PipelineRunUpdateRow {
  PipelineRunUpdateRow(
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
  )
}

/// Runs the `pipeline_run_update` query
/// defined in `./src/sql/pipeline_run_update.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pipeline_run_update(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
  arg_3: String,
) -> Result(pog.Returned(PipelineRunUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use repository_id <- decode.field(1, decode.string)
    use merge_request_id <- decode.field(2, decode.string)
    use commit_sha <- decode.field(3, decode.string)
    use module_path <- decode.field(4, decode.string)
    use entry_function <- decode.field(5, decode.string)
    use state <- decode.field(6, decode.string)
    use trigger <- decode.field(7, decode.string)
    use log_text <- decode.field(8, decode.string)
    use started_at <- decode.field(9, decode.string)
    use finished_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    decode.success(PipelineRunUpdateRow(
      id:,
      repository_id:,
      merge_request_id:,
      commit_sha:,
      module_path:,
      entry_function:,
      state:,
      trigger:,
      log_text:,
      started_at:,
      finished_at:,
      created_at:,
    ))
  }

  "UPDATE pipeline_runs
SET
  state = $2::varchar,
  log_text = NULLIF($3, ''),
  finished_at = CASE
    WHEN $2::varchar IN ('success', 'failure', 'cancelled', 'skipped') THEN now()
    ELSE finished_at
  END
WHERE id = $1::uuid
  AND state = 'running'
RETURNING
  id::text,
  repository_id::text,
  COALESCE(merge_request_id::text, '') AS merge_request_id,
  commit_sha,
  COALESCE(module_path, '') AS module_path,
  entry_function,
  state,
  trigger,
  COALESCE(log_text, '') AS log_text,
  COALESCE(started_at::text, '') AS started_at,
  COALESCE(finished_at::text, '') AS finished_at,
  created_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_board` query
/// defined in `./src/sql/project_board.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectBoardRow {
  ProjectBoardRow(
    column_id: String,
    column_name: String,
    column_position: Int,
    item_id: String,
    item_position: Option(Int),
    item_type: Option(String),
    item_number: Option(Int),
    repo_name: Option(String),
    org_slug: String,
    item_title: String,
    item_state: String,
    item_created_at: String,
  )
}

/// Runs the `project_board` query
/// defined in `./src/sql/project_board.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_board(
  db: pog.Connection,
  o_slug: String,
  p_number: Int,
) -> Result(pog.Returned(ProjectBoardRow), pog.QueryError) {
  let decoder = {
    use column_id <- decode.field(0, decode.string)
    use column_name <- decode.field(1, decode.string)
    use column_position <- decode.field(2, decode.int)
    use item_id <- decode.field(3, decode.string)
    use item_position <- decode.field(4, decode.optional(decode.int))
    use item_type <- decode.field(5, decode.optional(decode.string))
    use item_number <- decode.field(6, decode.optional(decode.int))
    use repo_name <- decode.field(7, decode.optional(decode.string))
    use org_slug <- decode.field(8, decode.string)
    use item_title <- decode.field(9, decode.string)
    use item_state <- decode.field(10, decode.string)
    use item_created_at <- decode.field(11, decode.string)
    decode.success(ProjectBoardRow(
      column_id:,
      column_name:,
      column_position:,
      item_id:,
      item_position:,
      item_type:,
      item_number:,
      repo_name:,
      org_slug:,
      item_title:,
      item_state:,
      item_created_at:,
    ))
  }

  "SELECT
  pc.id::text AS column_id,
  pc.name AS column_name,
  pc.position AS column_position,
  COALESCE(pi.id::text, '') AS item_id,
  pi.position AS item_position,
  pi.item_type,
  pi.item_number,
  r.name AS repo_name,
  o.slug AS org_slug,
  COALESCE(i.title, mr.title, '') AS item_title,
  COALESCE(i.state, mr.state, '') AS item_state,
  COALESCE(pi.created_at::text, '') AS item_created_at
FROM projects p
INNER JOIN organizations o ON o.id = p.organization_id
INNER JOIN project_columns pc ON pc.project_id = p.id
LEFT JOIN project_items pi ON pi.column_id = pc.id
LEFT JOIN repositories r ON r.id = pi.repository_id
LEFT JOIN issues i
  ON pi.item_type = 'issue'
  AND i.repository_id = r.id
  AND i.number = pi.item_number
LEFT JOIN merge_requests mr
  ON pi.item_type = 'merge_request'
  AND mr.repository_id = r.id
  AND mr.number = pi.item_number
WHERE o.slug = $1 AND p.number = $2
ORDER BY pc.position, pi.position;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.int(p_number))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_column_delete` query
/// defined in `./src/sql/project_column_delete.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectColumnDeleteRow {
  ProjectColumnDeleteRow(id: String)
}

/// Runs the `project_column_delete` query
/// defined in `./src/sql/project_column_delete.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_column_delete(
  db: pog.Connection,
  o_slug: String,
  p_number: Int,
  arg_3: Uuid,
) -> Result(pog.Returned(ProjectColumnDeleteRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    decode.success(ProjectColumnDeleteRow(id:))
  }

  "DELETE FROM project_columns pc
USING projects p
INNER JOIN organizations o ON o.id = p.organization_id
WHERE pc.project_id = p.id
  AND pc.id = $3::uuid
  AND o.slug = $1
  AND p.number = $2
RETURNING pc.id::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.int(p_number))
  |> pog.parameter(pog.text(uuid.to_string(arg_3)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_column_insert` query
/// defined in `./src/sql/project_column_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectColumnInsertRow {
  ProjectColumnInsertRow(id: String, name: String, position: Int)
}

/// Runs the `project_column_insert` query
/// defined in `./src/sql/project_column_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_column_insert(
  db: pog.Connection,
  o_slug: String,
  p_number: Int,
  arg_3: String,
  arg_4: Int,
) -> Result(pog.Returned(ProjectColumnInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use position <- decode.field(2, decode.int)
    decode.success(ProjectColumnInsertRow(id:, name:, position:))
  }

  "INSERT INTO project_columns (project_id, name, position)
SELECT p.id, $3, $4
FROM projects p
INNER JOIN organizations o ON o.id = p.organization_id
WHERE o.slug = $1 AND p.number = $2
RETURNING
  id::text,
  name,
  position;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.int(p_number))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_column_update` query
/// defined in `./src/sql/project_column_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectColumnUpdateRow {
  ProjectColumnUpdateRow(id: String, name: String, position: Int)
}

/// Runs the `project_column_update` query
/// defined in `./src/sql/project_column_update.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_column_update(
  db: pog.Connection,
  o_slug: String,
  p_number: Int,
  arg_3: Uuid,
  arg_4: String,
  position: Int,
) -> Result(pog.Returned(ProjectColumnUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use position <- decode.field(2, decode.int)
    decode.success(ProjectColumnUpdateRow(id:, name:, position:))
  }

  "UPDATE project_columns pc
SET
  name = $4,
  position = $5
FROM projects p
INNER JOIN organizations o ON o.id = p.organization_id
WHERE pc.project_id = p.id
  AND pc.id = $3::uuid
  AND o.slug = $1
  AND p.number = $2
RETURNING
  pc.id::text,
  pc.name,
  pc.position;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.int(p_number))
  |> pog.parameter(pog.text(uuid.to_string(arg_3)))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.int(position))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_get` query
/// defined in `./src/sql/project_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectGetRow {
  ProjectGetRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    state: String,
    created_by_user_id: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `project_get` query
/// defined in `./src/sql/project_get.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_get(
  db: pog.Connection,
  o_slug: String,
  arg_2: Int,
) -> Result(pog.Returned(ProjectGetRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use state <- decode.field(4, decode.string)
    use created_by_user_id <- decode.field(5, decode.string)
    use created_at <- decode.field(6, decode.string)
    use updated_at <- decode.field(7, decode.string)
    decode.success(ProjectGetRow(
      id:,
      number:,
      title:,
      description:,
      state:,
      created_by_user_id:,
      created_at:,
      updated_at:,
    ))
  }

  "SELECT
  p.id::text,
  p.number,
  p.title,
  p.description,
  p.state,
  p.created_by_user_id,
  p.created_at::text,
  p.updated_at::text
FROM projects p
INNER JOIN organizations o ON o.id = p.organization_id
WHERE o.slug = $1 AND p.number = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_insert` query
/// defined in `./src/sql/project_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectInsertRow {
  ProjectInsertRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    state: String,
    created_by_user_id: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `project_insert` query
/// defined in `./src/sql/project_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_insert(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
) -> Result(pog.Returned(ProjectInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use state <- decode.field(4, decode.string)
    use created_by_user_id <- decode.field(5, decode.string)
    use created_at <- decode.field(6, decode.string)
    use updated_at <- decode.field(7, decode.string)
    decode.success(ProjectInsertRow(
      id:,
      number:,
      title:,
      description:,
      state:,
      created_by_user_id:,
      created_at:,
      updated_at:,
    ))
  }

  "INSERT INTO projects (
  organization_id,
  number,
  title,
  description,
  created_by_user_id
)
SELECT
  o.id,
  COALESCE(
    (SELECT MAX(p.number) FROM projects p WHERE p.organization_id = o.id),
    0
  ) + 1,
  $2,
  NULLIF($3, ''),
  $4
FROM organizations o
WHERE o.slug = $1
RETURNING
  id::text,
  number,
  title,
  description,
  state,
  created_by_user_id,
  created_at::text,
  updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_item_delete` query
/// defined in `./src/sql/project_item_delete.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectItemDeleteRow {
  ProjectItemDeleteRow(id: String)
}

/// Runs the `project_item_delete` query
/// defined in `./src/sql/project_item_delete.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_item_delete(
  db: pog.Connection,
  o_slug: String,
  p_number: Int,
  arg_3: Uuid,
) -> Result(pog.Returned(ProjectItemDeleteRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    decode.success(ProjectItemDeleteRow(id:))
  }

  "DELETE FROM project_items pi
USING projects p
INNER JOIN organizations o ON o.id = p.organization_id
WHERE pi.project_id = p.id
  AND pi.id = $3::uuid
  AND o.slug = $1
  AND p.number = $2
RETURNING pi.id::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.int(p_number))
  |> pog.parameter(pog.text(uuid.to_string(arg_3)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_item_insert` query
/// defined in `./src/sql/project_item_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectItemInsertRow {
  ProjectItemInsertRow(
    id: String,
    column_id: String,
    position: Int,
    item_type: String,
    repository_id: String,
    item_number: Int,
    created_at: String,
  )
}

/// Runs the `project_item_insert` query
/// defined in `./src/sql/project_item_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_item_insert(
  db: pog.Connection,
  o_slug: String,
  p_number: Int,
  r_name: String,
  arg_4: String,
  i_number: Int,
) -> Result(pog.Returned(ProjectItemInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use column_id <- decode.field(1, decode.string)
    use position <- decode.field(2, decode.int)
    use item_type <- decode.field(3, decode.string)
    use repository_id <- decode.field(4, decode.string)
    use item_number <- decode.field(5, decode.int)
    use created_at <- decode.field(6, decode.string)
    decode.success(ProjectItemInsertRow(
      id:,
      column_id:,
      position:,
      item_type:,
      repository_id:,
      item_number:,
      created_at:,
    ))
  }

  "INSERT INTO project_items (
  project_id,
  column_id,
  position,
  item_type,
  repository_id,
  item_number
)
SELECT
  p.id,
  (
    SELECT pc.id
    FROM project_columns pc
    WHERE pc.project_id = p.id
    ORDER BY pc.position
    LIMIT 1
  ),
  COALESCE(
    (
      SELECT MAX(pi.position)
      FROM project_items pi
      WHERE pi.column_id = (
        SELECT pc2.id
        FROM project_columns pc2
        WHERE pc2.project_id = p.id
        ORDER BY pc2.position
        LIMIT 1
      )
    ),
    -1
  ) + 1,
  $4::varchar,
  r.id,
  $5
FROM projects p
INNER JOIN organizations o ON o.id = p.organization_id
INNER JOIN repositories r ON r.organization_id = o.id AND r.name = $3
WHERE o.slug = $1
  AND p.number = $2
  AND EXISTS (
    SELECT 1 FROM project_columns pc WHERE pc.project_id = p.id
  )
  AND (
    ($4 = 'issue' AND EXISTS (
      SELECT 1 FROM issues i WHERE i.repository_id = r.id AND i.number = $5
    ))
    OR ($4 = 'merge_request' AND EXISTS (
      SELECT 1 FROM merge_requests mr
      WHERE mr.repository_id = r.id AND mr.number = $5
    ))
  )
RETURNING
  id::text,
  column_id::text,
  position,
  item_type,
  repository_id::text,
  item_number,
  created_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.int(p_number))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.int(i_number))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_item_move` query
/// defined in `./src/sql/project_item_move.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectItemMoveRow {
  ProjectItemMoveRow(
    id: String,
    column_id: String,
    position: Int,
    item_type: String,
    repository_id: String,
    item_number: Int,
    created_at: String,
  )
}

/// Runs the `project_item_move` query
/// defined in `./src/sql/project_item_move.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_item_move(
  db: pog.Connection,
  o_slug: String,
  p_number: Int,
  arg_3: Uuid,
  arg_4: Uuid,
  position: Int,
) -> Result(pog.Returned(ProjectItemMoveRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use column_id <- decode.field(1, decode.string)
    use position <- decode.field(2, decode.int)
    use item_type <- decode.field(3, decode.string)
    use repository_id <- decode.field(4, decode.string)
    use item_number <- decode.field(5, decode.int)
    use created_at <- decode.field(6, decode.string)
    decode.success(ProjectItemMoveRow(
      id:,
      column_id:,
      position:,
      item_type:,
      repository_id:,
      item_number:,
      created_at:,
    ))
  }

  "UPDATE project_items pi
SET
  column_id = $4::uuid,
  position = $5
FROM projects p
INNER JOIN organizations o ON o.id = p.organization_id
INNER JOIN project_columns pc ON pc.id = $4::uuid AND pc.project_id = p.id
WHERE pi.id = $3::uuid
  AND pi.project_id = p.id
  AND o.slug = $1
  AND p.number = $2
RETURNING
  pi.id::text,
  pi.column_id::text,
  pi.position,
  pi.item_type,
  pi.repository_id::text,
  pi.item_number,
  pi.created_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.int(p_number))
  |> pog.parameter(pog.text(uuid.to_string(arg_3)))
  |> pog.parameter(pog.text(uuid.to_string(arg_4)))
  |> pog.parameter(pog.int(position))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_list` query
/// defined in `./src/sql/project_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectListRow {
  ProjectListRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    state: String,
    created_by_user_id: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `project_list` query
/// defined in `./src/sql/project_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_list(
  db: pog.Connection,
  o_slug: String,
) -> Result(pog.Returned(ProjectListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use state <- decode.field(4, decode.string)
    use created_by_user_id <- decode.field(5, decode.string)
    use created_at <- decode.field(6, decode.string)
    use updated_at <- decode.field(7, decode.string)
    decode.success(ProjectListRow(
      id:,
      number:,
      title:,
      description:,
      state:,
      created_by_user_id:,
      created_at:,
      updated_at:,
    ))
  }

  "SELECT
  p.id::text,
  p.number,
  p.title,
  p.description,
  p.state,
  p.created_by_user_id,
  p.created_at::text,
  p.updated_at::text
FROM projects p
INNER JOIN organizations o ON o.id = p.organization_id
WHERE o.slug = $1
ORDER BY p.number DESC;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_update` query
/// defined in `./src/sql/project_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectUpdateRow {
  ProjectUpdateRow(
    id: String,
    number: Int,
    title: String,
    description: Option(String),
    state: String,
    created_by_user_id: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `project_update` query
/// defined in `./src/sql/project_update.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_update(
  db: pog.Connection,
  o_slug: String,
  p_number: Int,
  arg_3: String,
  arg_4: String,
  arg_5: String,
) -> Result(pog.Returned(ProjectUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use state <- decode.field(4, decode.string)
    use created_by_user_id <- decode.field(5, decode.string)
    use created_at <- decode.field(6, decode.string)
    use updated_at <- decode.field(7, decode.string)
    decode.success(ProjectUpdateRow(
      id:,
      number:,
      title:,
      description:,
      state:,
      created_by_user_id:,
      created_at:,
      updated_at:,
    ))
  }

  "UPDATE projects p
SET
  title = $3,
  description = NULLIF($4, ''),
  state = $5,
  updated_at = now()
FROM organizations o
WHERE p.organization_id = o.id
  AND o.slug = $1
  AND p.number = $2
RETURNING
  p.id::text,
  p.number,
  p.title,
  p.description,
  p.state,
  p.created_by_user_id,
  p.created_at::text,
  p.updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.int(p_number))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `release_get` query
/// defined in `./src/sql/release_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReleaseGetRow {
  ReleaseGetRow(
    id: String,
    tag_name: String,
    target_commit_sha: String,
    title: String,
    body: String,
    author_user_id: String,
    created_at: String,
  )
}

/// Runs the `release_get` query
/// defined in `./src/sql/release_get.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn release_get(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: String,
) -> Result(pog.Returned(ReleaseGetRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use tag_name <- decode.field(1, decode.string)
    use target_commit_sha <- decode.field(2, decode.string)
    use title <- decode.field(3, decode.string)
    use body <- decode.field(4, decode.string)
    use author_user_id <- decode.field(5, decode.string)
    use created_at <- decode.field(6, decode.string)
    decode.success(ReleaseGetRow(
      id:,
      tag_name:,
      target_commit_sha:,
      title:,
      body:,
      author_user_id:,
      created_at:,
    ))
  }

  "SELECT
  rel.id::text,
  rel.tag_name,
  rel.target_commit_sha,
  rel.title,
  COALESCE(rel.body, '') AS body,
  rel.author_user_id,
  rel.created_at::text
FROM releases rel
INNER JOIN repositories r ON r.id = rel.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND rel.tag_name = $3;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `release_insert` query
/// defined in `./src/sql/release_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReleaseInsertRow {
  ReleaseInsertRow(
    id: String,
    tag_name: String,
    target_commit_sha: String,
    title: String,
    body: String,
    author_user_id: String,
    created_at: String,
  )
}

/// Runs the `release_insert` query
/// defined in `./src/sql/release_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn release_insert(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
  arg_6: String,
  arg_7: String,
) -> Result(pog.Returned(ReleaseInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use tag_name <- decode.field(1, decode.string)
    use target_commit_sha <- decode.field(2, decode.string)
    use title <- decode.field(3, decode.string)
    use body <- decode.field(4, decode.string)
    use author_user_id <- decode.field(5, decode.string)
    use created_at <- decode.field(6, decode.string)
    decode.success(ReleaseInsertRow(
      id:,
      tag_name:,
      target_commit_sha:,
      title:,
      body:,
      author_user_id:,
      created_at:,
    ))
  }

  "INSERT INTO releases (
  repository_id,
  tag_name,
  target_commit_sha,
  title,
  body,
  author_user_id
)
SELECT r.id, $3, $4, $5, NULLIF($6, ''), $7
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
RETURNING
  id::text,
  tag_name,
  target_commit_sha,
  title,
  COALESCE(body, '') AS body,
  author_user_id,
  created_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.text(arg_7))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `release_list` query
/// defined in `./src/sql/release_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReleaseListRow {
  ReleaseListRow(
    id: String,
    tag_name: String,
    target_commit_sha: String,
    title: String,
    body: String,
    author_user_id: String,
    created_at: String,
  )
}

/// Runs the `release_list` query
/// defined in `./src/sql/release_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn release_list(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
) -> Result(pog.Returned(ReleaseListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use tag_name <- decode.field(1, decode.string)
    use target_commit_sha <- decode.field(2, decode.string)
    use title <- decode.field(3, decode.string)
    use body <- decode.field(4, decode.string)
    use author_user_id <- decode.field(5, decode.string)
    use created_at <- decode.field(6, decode.string)
    decode.success(ReleaseListRow(
      id:,
      tag_name:,
      target_commit_sha:,
      title:,
      body:,
      author_user_id:,
      created_at:,
    ))
  }

  "SELECT
  rel.id::text,
  rel.tag_name,
  rel.target_commit_sha,
  rel.title,
  COALESCE(rel.body, '') AS body,
  rel.author_user_id,
  rel.created_at::text
FROM releases rel
INNER JOIN repositories r ON r.id = rel.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
ORDER BY rel.created_at DESC;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `release_update` query
/// defined in `./src/sql/release_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReleaseUpdateRow {
  ReleaseUpdateRow(
    id: String,
    tag_name: String,
    target_commit_sha: String,
    title: String,
    body: String,
    author_user_id: String,
    created_at: String,
  )
}

/// Runs the `release_update` query
/// defined in `./src/sql/release_update.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn release_update(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  rel_tag_name: String,
  arg_4: String,
  arg_5: String,
) -> Result(pog.Returned(ReleaseUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use tag_name <- decode.field(1, decode.string)
    use target_commit_sha <- decode.field(2, decode.string)
    use title <- decode.field(3, decode.string)
    use body <- decode.field(4, decode.string)
    use author_user_id <- decode.field(5, decode.string)
    use created_at <- decode.field(6, decode.string)
    decode.success(ReleaseUpdateRow(
      id:,
      tag_name:,
      target_commit_sha:,
      title:,
      body:,
      author_user_id:,
      created_at:,
    ))
  }

  "UPDATE releases rel
SET
  title = $4,
  body = NULLIF($5, '')
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE rel.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND rel.tag_name = $3
RETURNING
  rel.id::text,
  rel.tag_name,
  rel.target_commit_sha,
  rel.title,
  COALESCE(rel.body, '') AS body,
  rel.author_user_id,
  rel.created_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(rel_tag_name))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `repos_delete` query
/// defined in `./src/sql/repos_delete.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReposDeleteRow {
  ReposDeleteRow(disk_path: String)
}

/// Runs the `repos_delete` query
/// defined in `./src/sql/repos_delete.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn repos_delete(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
) -> Result(pog.Returned(ReposDeleteRow), pog.QueryError) {
  let decoder = {
    use disk_path <- decode.field(0, decode.string)
    decode.success(ReposDeleteRow(disk_path:))
  }

  "DELETE FROM repositories r
USING organizations o
WHERE r.organization_id = o.id
  AND o.slug = $1
  AND (r.id::text = $2 OR r.name = $2)
RETURNING r.disk_path;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `repos_get` query
/// defined in `./src/sql/repos_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReposGetRow {
  ReposGetRow(
    id: String,
    name: String,
    description: Option(String),
    disk_path: String,
    slug: String,
  )
}

/// Runs the `repos_get` query
/// defined in `./src/sql/repos_get.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn repos_get(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
) -> Result(pog.Returned(ReposGetRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use disk_path <- decode.field(3, decode.string)
    use slug <- decode.field(4, decode.string)
    decode.success(ReposGetRow(id:, name:, description:, disk_path:, slug:))
  }

  "SELECT r.id::text, r.name, r.description, r.disk_path, o.slug
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `repos_get_by_id` query
/// defined in `./src/sql/repos_get_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReposGetByIdRow {
  ReposGetByIdRow(
    id: String,
    name: String,
    description: Option(String),
    disk_path: String,
    org_slug: String,
  )
}

/// Runs the `repos_get_by_id` query
/// defined in `./src/sql/repos_get_by_id.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn repos_get_by_id(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(ReposGetByIdRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use disk_path <- decode.field(3, decode.string)
    use org_slug <- decode.field(4, decode.string)
    decode.success(ReposGetByIdRow(
      id:,
      name:,
      description:,
      disk_path:,
      org_slug:,
    ))
  }

  "SELECT
  r.id::text,
  r.name,
  r.description,
  r.disk_path,
  o.slug AS org_slug
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE r.id = $1::uuid;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `repos_insert` query
/// defined in `./src/sql/repos_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReposInsertRow {
  ReposInsertRow(
    id: String,
    name: String,
    description: Option(String),
    disk_path: String,
  )
}

/// Runs the `repos_insert` query
/// defined in `./src/sql/repos_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn repos_insert(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
) -> Result(pog.Returned(ReposInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use disk_path <- decode.field(3, decode.string)
    decode.success(ReposInsertRow(id:, name:, description:, disk_path:))
  }

  "INSERT INTO repositories (organization_id, name, description, disk_path)
SELECT o.id, $2, $3, $4
FROM organizations o
WHERE o.slug = $1
RETURNING id::text, name, description, disk_path;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `repos_list` query
/// defined in `./src/sql/repos_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReposListRow {
  ReposListRow(
    id: String,
    name: String,
    description: Option(String),
    disk_path: String,
    slug: String,
  )
}

/// Runs the `repos_list` query
/// defined in `./src/sql/repos_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn repos_list(
  db: pog.Connection,
  o_slug: String,
) -> Result(pog.Returned(ReposListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use disk_path <- decode.field(3, decode.string)
    use slug <- decode.field(4, decode.string)
    decode.success(ReposListRow(id:, name:, description:, disk_path:, slug:))
  }

  "SELECT r.id::text, r.name, r.description, r.disk_path, o.slug
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1
ORDER BY r.name;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `repos_required_approvals_get` query
/// defined in `./src/sql/repos_required_approvals_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReposRequiredApprovalsGetRow {
  ReposRequiredApprovalsGetRow(required_approvals: Int)
}

/// Runs the `repos_required_approvals_get` query
/// defined in `./src/sql/repos_required_approvals_get.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn repos_required_approvals_get(
  db: pog.Connection,
  o_slug: String,
  arg_2: String,
) -> Result(pog.Returned(ReposRequiredApprovalsGetRow), pog.QueryError) {
  let decoder = {
    use required_approvals <- decode.field(0, decode.int)
    decode.success(ReposRequiredApprovalsGetRow(required_approvals:))
  }

  "SELECT r.required_approvals
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `repos_required_approvals_update` query
/// defined in `./src/sql/repos_required_approvals_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReposRequiredApprovalsUpdateRow {
  ReposRequiredApprovalsUpdateRow(required_approvals: Int)
}

/// Runs the `repos_required_approvals_update` query
/// defined in `./src/sql/repos_required_approvals_update.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn repos_required_approvals_update(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  required_approvals: Int,
) -> Result(pog.Returned(ReposRequiredApprovalsUpdateRow), pog.QueryError) {
  let decoder = {
    use required_approvals <- decode.field(0, decode.int)
    decode.success(ReposRequiredApprovalsUpdateRow(required_approvals:))
  }

  "UPDATE repositories r
SET required_approvals = $3
FROM organizations o
WHERE r.organization_id = o.id
  AND o.slug = $1
  AND r.name = $2
RETURNING r.required_approvals;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.int(required_approvals))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `repos_update` query
/// defined in `./src/sql/repos_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReposUpdateRow {
  ReposUpdateRow(
    id: String,
    name: String,
    description: Option(String),
    disk_path: String,
    slug: String,
  )
}

/// Runs the `repos_update` query
/// defined in `./src/sql/repos_update.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn repos_update(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: String,
  disk_path: String,
) -> Result(pog.Returned(ReposUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use disk_path <- decode.field(3, decode.string)
    use slug <- decode.field(4, decode.string)
    decode.success(ReposUpdateRow(id:, name:, description:, disk_path:, slug:))
  }

  "UPDATE repositories r
SET name = $3, disk_path = $4
FROM organizations o
WHERE r.organization_id = o.id
  AND o.slug = $1
  AND r.name = $2
RETURNING r.id::text, r.name, r.description, r.disk_path, o.slug;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(disk_path))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `repos_update_description` query
/// defined in `./src/sql/repos_update_description.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReposUpdateDescriptionRow {
  ReposUpdateDescriptionRow(
    id: String,
    name: String,
    description: Option(String),
    disk_path: String,
    slug: String,
  )
}

/// Runs the `repos_update_description` query
/// defined in `./src/sql/repos_update_description.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn repos_update_description(
  db: pog.Connection,
  o_slug: String,
  r_name: String,
  arg_3: String,
) -> Result(pog.Returned(ReposUpdateDescriptionRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use disk_path <- decode.field(3, decode.string)
    use slug <- decode.field(4, decode.string)
    decode.success(ReposUpdateDescriptionRow(
      id:,
      name:,
      description:,
      disk_path:,
      slug:,
    ))
  }

  "UPDATE repositories r
SET description = NULLIF($3, '')
FROM organizations o
WHERE r.organization_id = o.id
  AND o.slug = $1
  AND r.name = $2
RETURNING
  r.id::text,
  r.name,
  r.description,
  r.disk_path,
  o.slug;
"
  |> pog.query
  |> pog.parameter(pog.text(o_slug))
  |> pog.parameter(pog.text(r_name))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `user_stats` query
/// defined in `./src/sql/user_stats.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UserStatsRow {
  UserStatsRow(
    open_merge_requests: Int,
    merged_merge_requests: Int,
    open_issues_authored: Int,
    open_issues_assigned: Int,
    reviews_given: Int,
  )
}

/// Runs the `user_stats` query
/// defined in `./src/sql/user_stats.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn user_stats(
  db: pog.Connection,
  mr_author_user_id: String,
) -> Result(pog.Returned(UserStatsRow), pog.QueryError) {
  let decoder = {
    use open_merge_requests <- decode.field(0, decode.int)
    use merged_merge_requests <- decode.field(1, decode.int)
    use open_issues_authored <- decode.field(2, decode.int)
    use open_issues_assigned <- decode.field(3, decode.int)
    use reviews_given <- decode.field(4, decode.int)
    decode.success(UserStatsRow(
      open_merge_requests:,
      merged_merge_requests:,
      open_issues_authored:,
      open_issues_assigned:,
      reviews_given:,
    ))
  }

  "SELECT
  (
    SELECT COUNT(*)::int
    FROM merge_requests mr
    WHERE mr.author_user_id = $1
      AND mr.state = 'open'
  ) AS open_merge_requests,
  (
    SELECT COUNT(*)::int
    FROM merge_requests mr
    WHERE mr.author_user_id = $1
      AND mr.state = 'merged'
  ) AS merged_merge_requests,
  (
    SELECT COUNT(*)::int
    FROM issues i
    WHERE i.author_user_id = $1
      AND i.state = 'open'
  ) AS open_issues_authored,
  (
    SELECT COUNT(*)::int
    FROM issue_assignees ia
    INNER JOIN issues i ON i.id = ia.issue_id
    WHERE ia.user_id = $1
      AND i.state = 'open'
  ) AS open_issues_assigned,
  (
    SELECT COUNT(*)::int
    FROM merge_request_reviews r
    WHERE r.user_id = $1
  ) AS reviews_given;
"
  |> pog.query
  |> pog.parameter(pog.text(mr_author_user_id))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `users_get_display_name` query
/// defined in `./src/sql/users_get_display_name.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UsersGetDisplayNameRow {
  UsersGetDisplayNameRow(display_name: Option(String))
}

/// Runs the `users_get_display_name` query
/// defined in `./src/sql/users_get_display_name.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn users_get_display_name(
  db: pog.Connection,
  arg_1: String,
) -> Result(pog.Returned(UsersGetDisplayNameRow), pog.QueryError) {
  let decoder = {
    use display_name <- decode.field(0, decode.optional(decode.string))
    decode.success(UsersGetDisplayNameRow(display_name:))
  }

  "SELECT display_name
FROM users
WHERE id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `users_upsert` query
/// defined in `./src/sql/users_upsert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn users_upsert(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO users (id, display_name, email)
VALUES ($1, $2, $3)
ON CONFLICT (id) DO UPDATE SET
  display_name = COALESCE(
    NULLIF(TRIM(EXCLUDED.display_name), ''),
    NULLIF(TRIM(users.display_name), '')
  ),
  email = COALESCE(
    NULLIF(TRIM(EXCLUDED.email), ''),
    NULLIF(TRIM(users.email), '')
  );
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
