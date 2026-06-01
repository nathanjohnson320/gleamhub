//// This module contains the code to run the sql queries defined in
//// `./src/app/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/option.{type Option}
import pog
import youid/uuid.{type Uuid}

/// A row you get from running the `issue_close` query
/// defined in `./src/app/sql/issue_close.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
/// defined in `./src/app/sql/issue_close.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_close(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Int,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_comments_insert` query
/// defined in `./src/app/sql/issue_comments_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueCommentsInsertRow {
  IssueCommentsInsertRow(
    id: String,
    author_user_id: String,
    body: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `issue_comments_insert` query
/// defined in `./src/app/sql/issue_comments_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_comments_insert(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Int,
  arg_4: String,
  arg_5: String,
) -> Result(pog.Returned(IssueCommentsInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use author_user_id <- decode.field(1, decode.string)
    use body <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    use updated_at <- decode.field(4, decode.string)
    decode.success(IssueCommentsInsertRow(
      id:,
      author_user_id:,
      body:,
      created_at:,
      updated_at:,
    ))
  }

  "INSERT INTO issue_comments (
  issue_id,
  author_user_id,
  body
)
SELECT i.id, $4, $5
FROM issues i
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND i.number = $3
RETURNING
  id::text,
  author_user_id,
  body,
  created_at::text,
  updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_comments_list` query
/// defined in `./src/app/sql/issue_comments_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type IssueCommentsListRow {
  IssueCommentsListRow(
    id: String,
    author_user_id: String,
    author_name: String,
    body: String,
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `issue_comments_list` query
/// defined in `./src/app/sql/issue_comments_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_comments_list(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Int,
) -> Result(pog.Returned(IssueCommentsListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use author_user_id <- decode.field(1, decode.string)
    use author_name <- decode.field(2, decode.string)
    use body <- decode.field(3, decode.string)
    use created_at <- decode.field(4, decode.string)
    use updated_at <- decode.field(5, decode.string)
    decode.success(IssueCommentsListRow(
      id:,
      author_user_id:,
      author_name:,
      body:,
      created_at:,
      updated_at:,
    ))
  }

  "SELECT
  c.id::text,
  c.author_user_id,
  c.author_user_id AS author_name,
  c.body,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_get` query
/// defined in `./src/app/sql/issue_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
/// defined in `./src/app/sql/issue_get.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_get(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_insert` query
/// defined in `./src/app/sql/issue_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
/// defined in `./src/app/sql/issue_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_insert(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `issue_list` query
/// defined in `./src/app/sql/issue_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
/// defined in `./src/app/sql/issue_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn issue_list(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `keys_authorized_line` query
/// defined in `./src/app/sql/keys_authorized_line.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type KeysAuthorizedLineRow {
  KeysAuthorizedLineRow(user_id: String, public_key: String)
}

/// Runs the `keys_authorized_line` query
/// defined in `./src/app/sql/keys_authorized_line.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn keys_authorized_line(
  db: pog.Connection,
  arg_1: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `keys_delete` query
/// defined in `./src/app/sql/keys_delete.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
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
/// defined in `./src/app/sql/keys_find_user_for_blob.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type KeysFindUserForBlobRow {
  KeysFindUserForBlobRow(user_id: String)
}

/// Runs the `keys_find_user_for_blob` query
/// defined in `./src/app/sql/keys_find_user_for_blob.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn keys_find_user_for_blob(
  db: pog.Connection,
  arg_1: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `keys_insert` query
/// defined in `./src/app/sql/keys_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
/// defined in `./src/app/sql/keys_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
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
/// defined in `./src/app/sql/keys_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
/// defined in `./src/app/sql/keys_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn keys_list(
  db: pog.Connection,
  arg_1: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_close` query
/// defined in `./src/app/sql/mr_close.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
  )
}

/// Runs the `mr_close` query
/// defined in `./src/app/sql/mr_close.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_close(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Int,
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
  mr.updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_comments_insert` query
/// defined in `./src/app/sql/mr_comments_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrCommentsInsertRow {
  MrCommentsInsertRow(
    id: String,
    author_user_id: String,
    body: String,
    file_path: Option(String),
    line: Option(Int),
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `mr_comments_insert` query
/// defined in `./src/app/sql/mr_comments_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_comments_insert(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Int,
  arg_4: String,
  arg_5: String,
  arg_6: String,
  arg_7: Int,
) -> Result(pog.Returned(MrCommentsInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use author_user_id <- decode.field(1, decode.string)
    use body <- decode.field(2, decode.string)
    use file_path <- decode.field(3, decode.optional(decode.string))
    use line <- decode.field(4, decode.optional(decode.int))
    use created_at <- decode.field(5, decode.string)
    use updated_at <- decode.field(6, decode.string)
    decode.success(MrCommentsInsertRow(
      id:,
      author_user_id:,
      body:,
      file_path:,
      line:,
      created_at:,
      updated_at:,
    ))
  }

  "INSERT INTO merge_request_comments (
  merge_request_id,
  author_user_id,
  body,
  file_path,
  line
)
SELECT mr.id, $4, $5, NULLIF($6, ''), CASE WHEN $7 = 0 THEN NULL ELSE $7 END
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
  created_at::text,
  updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.int(arg_7))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_comments_list` query
/// defined in `./src/app/sql/mr_comments_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
    created_at: String,
    updated_at: String,
  )
}

/// Runs the `mr_comments_list` query
/// defined in `./src/app/sql/mr_comments_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_comments_list(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Int,
) -> Result(pog.Returned(MrCommentsListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use author_user_id <- decode.field(1, decode.string)
    use author_name <- decode.field(2, decode.string)
    use body <- decode.field(3, decode.string)
    use file_path <- decode.field(4, decode.optional(decode.string))
    use line <- decode.field(5, decode.optional(decode.int))
    use created_at <- decode.field(6, decode.string)
    use updated_at <- decode.field(7, decode.string)
    decode.success(MrCommentsListRow(
      id:,
      author_user_id:,
      author_name:,
      body:,
      file_path:,
      line:,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_find_open` query
/// defined in `./src/app/sql/mr_find_open.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MrFindOpenRow {
  MrFindOpenRow(number: Int)
}

/// Runs the `mr_find_open` query
/// defined in `./src/app/sql/mr_find_open.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_find_open(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_get` query
/// defined in `./src/app/sql/mr_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
  )
}

/// Runs the `mr_get` query
/// defined in `./src/app/sql/mr_get.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_get(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
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
  mr.updated_at::text
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND mr.number = $3;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_insert` query
/// defined in `./src/app/sql/mr_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
  )
}

/// Runs the `mr_insert` query
/// defined in `./src/app/sql/mr_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_insert(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
  arg_6: String,
  arg_7: String,
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
  state
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
  source_branch,
  target_branch,
  state,
  merge_commit_sha,
  merged_by_user_id,
  COALESCE(merged_at::text, '') AS merged_at,
  COALESCE(closed_at::text, '') AS closed_at,
  created_at::text,
  updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.text(arg_7))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_list` query
/// defined in `./src/app/sql/mr_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
  )
}

/// Runs the `mr_list` query
/// defined in `./src/app/sql/mr_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_list(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
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
  mr.updated_at::text
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
ORDER BY mr.number DESC;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_list_open_by_source` query
/// defined in `./src/app/sql/mr_list_open_by_source.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
  )
}

/// Runs the `mr_list_open_by_source` query
/// defined in `./src/app/sql/mr_list_open_by_source.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_list_open_by_source(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
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
  mr.updated_at::text
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1
  AND r.name = $2
  AND mr.source_branch = $3
  AND mr.state = 'open';
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `mr_merge` query
/// defined in `./src/app/sql/mr_merge.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
  )
}

/// Runs the `mr_merge` query
/// defined in `./src/app/sql/mr_merge.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn mr_merge(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Int,
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
  mr.updated_at::text;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_member_role` query
/// defined in `./src/app/sql/org_member_role.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgMemberRoleRow {
  OrgMemberRoleRow(role: String)
}

/// Runs the `org_member_role` query
/// defined in `./src/app/sql/org_member_role.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_member_role(
  db: pog.Connection,
  arg_1: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `org_members_insert` query
/// defined in `./src/app/sql/org_members_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
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

/// A row you get from running the `orgs_get_by_slug` query
/// defined in `./src/app/sql/orgs_get_by_slug.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgsGetBySlugRow {
  OrgsGetBySlugRow(id: String, slug: String, name: String)
}

/// Runs the `orgs_get_by_slug` query
/// defined in `./src/app/sql/orgs_get_by_slug.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
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
/// defined in `./src/app/sql/orgs_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgsInsertRow {
  OrgsInsertRow(id: String, slug: String, name: String)
}

/// Runs the `orgs_insert` query
/// defined in `./src/app/sql/orgs_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
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
/// defined in `./src/app/sql/orgs_list_for_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgsListForUserRow {
  OrgsListForUserRow(id: String, slug: String, name: String, role: String)
}

/// Runs the `orgs_list_for_user` query
/// defined in `./src/app/sql/orgs_list_for_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn orgs_list_for_user(
  db: pog.Connection,
  arg_1: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `pb_delete_for_repo` query
/// defined in `./src/app/sql/pb_delete_for_repo.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pb_delete_for_repo(
  db: pog.Connection,
  arg_1: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pb_insert` query
/// defined in `./src/app/sql/pb_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PbInsertRow {
  PbInsertRow(branch_name: String)
}

/// Runs the `pb_insert` query
/// defined in `./src/app/sql/pb_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pb_insert(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pb_is_protected` query
/// defined in `./src/app/sql/pb_is_protected.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PbIsProtectedRow {
  PbIsProtectedRow(found: Int)
}

/// Runs the `pb_is_protected` query
/// defined in `./src/app/sql/pb_is_protected.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pb_is_protected(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pb_list` query
/// defined in `./src/app/sql/pb_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PbListRow {
  PbListRow(branch_name: String)
}

/// Runs the `pb_list` query
/// defined in `./src/app/sql/pb_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pb_list(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pipeline_run_claim_next` query
/// defined in `./src/app/sql/pipeline_run_claim_next.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
/// defined in `./src/app/sql/pipeline_run_claim_next.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
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
  pr.merge_request_id::text,
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

/// A row you get from running the `pipeline_run_exists_for_sha` query
/// defined in `./src/app/sql/pipeline_run_exists_for_sha.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PipelineRunExistsForShaRow {
  PipelineRunExistsForShaRow(id: String)
}

/// Runs the `pipeline_run_exists_for_sha` query
/// defined in `./src/app/sql/pipeline_run_exists_for_sha.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pipeline_run_exists_for_sha(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
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
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pipeline_run_get_by_id` query
/// defined in `./src/app/sql/pipeline_run_get_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
/// defined in `./src/app/sql/pipeline_run_get_by_id.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
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
  pr.merge_request_id::text,
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
/// defined in `./src/app/sql/pipeline_run_get_latest.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
/// defined in `./src/app/sql/pipeline_run_get_latest.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
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
  pr.merge_request_id::text,
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

/// A row you get from running the `pipeline_run_insert` query
/// defined in `./src/app/sql/pipeline_run_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PipelineRunInsertRow {
  PipelineRunInsertRow(
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

/// Runs the `pipeline_run_insert` query
/// defined in `./src/app/sql/pipeline_run_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn pipeline_run_insert(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: Uuid,
  arg_3: String,
  arg_4: String,
  arg_5: String,
  arg_6: String,
  arg_7: String,
) -> Result(pog.Returned(PipelineRunInsertRow), pog.QueryError) {
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
    decode.success(PipelineRunInsertRow(
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

  "INSERT INTO pipeline_runs (
  repository_id,
  merge_request_id,
  commit_sha,
  module_path,
  entry_function,
  state,
  trigger
)
VALUES ($1::uuid, $2::uuid, $3, NULLIF($4, ''), $5, $6, $7)
RETURNING
  id::text,
  repository_id::text,
  merge_request_id::text,
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
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.text(arg_7))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `pipeline_run_update` query
/// defined in `./src/app/sql/pipeline_run_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
/// defined in `./src/app/sql/pipeline_run_update.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
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
RETURNING
  id::text,
  repository_id::text,
  merge_request_id::text,
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

/// A row you get from running the `repos_delete` query
/// defined in `./src/app/sql/repos_delete.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReposDeleteRow {
  ReposDeleteRow(disk_path: String)
}

/// Runs the `repos_delete` query
/// defined in `./src/app/sql/repos_delete.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn repos_delete(
  db: pog.Connection,
  arg_1: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `repos_get` query
/// defined in `./src/app/sql/repos_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
/// defined in `./src/app/sql/repos_get.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn repos_get(
  db: pog.Connection,
  arg_1: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `repos_insert` query
/// defined in `./src/app/sql/repos_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
/// defined in `./src/app/sql/repos_insert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn repos_insert(
  db: pog.Connection,
  arg_1: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `repos_list` query
/// defined in `./src/app/sql/repos_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
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
/// defined in `./src/app/sql/repos_list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn repos_list(
  db: pog.Connection,
  arg_1: String,
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
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `users_upsert` query
/// defined in `./src/app/sql/users_upsert.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
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
