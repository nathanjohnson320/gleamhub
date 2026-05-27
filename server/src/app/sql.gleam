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
