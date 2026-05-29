import app/database
import database_integration_fixtures as fixtures
import db_test_support
import gleam/list
import gleam/option
import pog

pub fn upsert_user_with_display_name_test() {
  db_test_support.with_db(fn(db) {
    let assert Ok(Nil) =
      database.upsert_user(
        db,
        "user_a",
        option.Some("Ada"),
        option.Some("ada@example.com"),
      )
    let assert Ok(Nil) =
      database.upsert_user(
        db,
        "user_a",
        option.Some("Ada Lovelace"),
        option.Some("ada@example.com"),
      )
    Nil
  })
}

pub fn upsert_session_user_prefers_jwt_display_name_test() {
  db_test_support.with_db(fn(db) {
    let assert Ok(Nil) =
      database.upsert_session_user(
        db,
        "user_b",
        option.Some("From JWT"),
        option.Some("ignored@example.com"),
      )
    Nil
  })
}

pub fn org_member_roles_integration_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_org(db, "acme", "owner")
    fixtures.seed_org_member(db, "acme", "member", "member")
    fixtures.seed_org_member(db, "acme", "viewer", "viewer")
    let assert True = database.is_org_owner(db, "owner", "acme")
    let assert False = database.is_org_owner(db, "member", "acme")
    let assert True = database.is_org_member(db, "member", "acme")
    let assert True = database.is_org_member(db, "viewer", "acme")
    let assert True = database.member_can_write(db, "owner", "acme")
    let assert True = database.member_can_write(db, "member", "acme")
    let assert False = database.member_can_write(db, "viewer", "acme")
    let assert False = database.is_org_member(db, "stranger", "acme")
    Nil
  })
}

pub fn create_org_requires_existing_owner_test() {
  db_test_support.with_db(fn(db) {
    let assert Error(pog.ConstraintViolated(..)) =
      database.create_org(db, "ghost", "Ghost Org", "nobody")
    Nil
  })
}

pub fn insert_repo_with_description_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_org(db, "acme", "owner")
    let assert Ok(repo) =
      database.insert_repo(
        db,
        "acme",
        "demo",
        option.Some("A demo repository"),
        "acme/demo.git",
      )
    let assert option.Some("A demo repository") = repo.description
    let assert Ok(option.Some(found)) = database.get_repo(db, "acme", "demo")
    let assert True = found.id == repo.id
    Nil
  })
}

pub fn insert_repo_duplicate_name_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_repo(db, "acme", "demo", "owner")
    let assert Error(pog.ConstraintViolated(..)) =
      database.insert_repo(db, "acme", "demo", option.None, "acme/demo2.git")
    Nil
  })
}

pub fn list_repos_empty_org_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_org(db, "acme", "owner")
    let assert Ok([]) = database.list_repos(db, "acme")
    let assert Ok(option.None) = database.get_repo(db, "acme", "missing")
    let assert False = database.repo_exists_for_org(db, "acme", "missing")
    Nil
  })
}

pub fn ssh_key_lookup_misses_test() {
  db_test_support.with_db(fn(db) {
    let assert Ok(option.None) =
      database.find_user_for_key_blob(db, "no-such-blob")
    let assert Ok(option.None) =
      database.authorized_key_line(db, "no-such-blob")
    Nil
  })
}

pub fn protected_branches_clear_all_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_repo(db, "acme", "demo", "owner")
    let assert Ok(_) =
      database.replace_protected_branches(db, "acme", "demo", ["main"])
    let assert Ok([]) = database.replace_protected_branches(db, "acme", "demo", [])
    let assert Ok(listed) = database.list_protected_branches(db, "acme", "demo")
    let assert True = listed == []
    let assert Ok(False) =
      database.is_branch_protected(db, "acme", "demo", "main")
    Nil
  })
}

pub fn merge_request_comment_with_file_line_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_repo(db, "acme", "demo", "user_1")
    let assert Ok(mr) =
      database.insert_merge_request(
        db,
        "acme",
        "demo",
        "Comment test",
        option.None,
        "user_1",
        "feature",
        "main",
      )
    let assert Ok(comment) =
      database.insert_merge_request_comment(
        db,
        "acme",
        "demo",
        mr.number,
        "user_1",
        "Fix this line",
        option.Some("src/main.gleam"),
        option.Some(10),
      )
    let assert option.Some("src/main.gleam") = comment.file_path
    let assert option.Some(10) = comment.line
    let named = database.comment_with_author_name(comment, "Ada")
    let assert "Ada" = named.author_name
    let assert Ok(comments) =
      database.list_merge_request_comments(db, "acme", "demo", mr.number)
    let assert True = list.length(comments) == 1
    Nil
  })
}

pub fn get_merge_request_missing_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_repo(db, "acme", "demo", "owner")
    let assert Ok(option.None) = database.get_merge_request(db, "acme", "demo", 99)
    let assert Ok(option.None) =
      database.find_open_merge_request(db, "acme", "demo", "nope", "main")
    Nil
  })
}

pub fn merge_request_merge_missing_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_repo(db, "acme", "demo", "owner")
    let sha = "abc123def4567890123456789012345678901234"
    let assert Error(pog.ConstraintViolated(..)) =
      database.merge_merge_request(db, "acme", "demo", 99, sha, "owner")
    Nil
  })
}

pub fn delete_repo_missing_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_org(db, "acme", "owner")
    let assert Error(pog.ConstraintViolated(..)) =
      database.delete_repo(db, "acme", "00000000-0000-0000-0000-000000000000")
    Nil
  })
}
