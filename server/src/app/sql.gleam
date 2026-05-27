//// This module contains the code to run the sql queries defined in
//// `./src/app/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/option.{type Option}
import pog
import youid/uuid.{type Uuid}

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
    use body <- decode.field(2, decode.string)
    use file_path <- decode.field(3, decode.optional(decode.string))
    use line <- decode.field(4, decode.optional(decode.int))
    use created_at <- decode.field(5, decode.string)
    use updated_at <- decode.field(6, decode.string)
    decode.success(MrCommentsListRow(
      id:,
      author_user_id:,
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
  display_name = COALESCE(EXCLUDED.display_name, users.display_name),
  email = COALESCE(EXCLUDED.email, users.email);
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
