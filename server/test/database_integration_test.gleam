import app/database
import database_integration_fixtures as fixtures
import db_test_support
import gleam/list
import gleam/option
import gleam/string
import pog

// --- Users ---

pub fn upsert_user_integration_test() {
  db_test_support.with_db(fn(db) {
    let assert Ok(Nil) =
      database.upsert_user(
        db,
        "user_1",
        option.None,
        option.Some("ada@example.com"),
      )
    Nil
  })
}

pub fn upsert_session_user_uses_email_local_part_test() {
  db_test_support.with_db(fn(db) {
    let assert Ok(Nil) =
      database.upsert_session_user(
        db,
        "user_2",
        option.None,
        option.Some("bob@example.com"),
      )
    Nil
  })
}

// --- Organizations ---

pub fn create_org_integration_test() {
  db_test_support.with_db(fn(db) {
    fixtures.seed_user(db, "user_1")
    let assert Ok(org) =
      database.create_org(db, "acme", "Acme Corp", "user_1")
    let assert "acme" = org.slug
    let assert True = database.is_org_owner(db, "user_1", "acme")
    let assert True = database.is_org_member(db, "user_1", "acme")
    let assert True = database.member_can_write(db, "user_1", "acme")
    let assert False = database.is_org_member(db, "user_2", "acme")
    Nil
  })
}

pub fn get_org_by_slug_integration_test() {
  db_test_support.with_db(fn(db) {
    fixtures.seed_user(db, "user_1")
    let assert Ok(org) = database.create_org(db, "acme", "Acme", "user_1")
    let assert Ok(option.Some(found)) = database.get_org_by_slug(db, "acme")
    let assert True = found.id == org.id
    let assert Ok(option.None) = database.get_org_by_slug(db, "missing")
    Nil
  })
}

pub fn list_orgs_for_user_integration_test() {
  db_test_support.with_db(fn(db) {
    fixtures.seed_user(db, "user_1")
    let assert Ok(_) = database.create_org(db, "acme", "Acme", "user_1")
    let assert Ok(orgs) = database.list_orgs_for_user(db, "user_1")
    let assert True = list.any(orgs, fn(o) { o.slug == "acme" })
    let assert Ok([]) = database.list_orgs_for_user(db, "nobody")
    Nil
  })
}

pub fn create_org_duplicate_slug_integration_test() {
  db_test_support.with_db(fn(db) {
    fixtures.seed_user(db, "user_1")
    let assert Ok(_) = database.create_org(db, "acme", "Acme", "user_1")
    let assert Error(pog.ConstraintViolated(..)) =
      database.create_org(db, "acme", "Other", "user_1")
    Nil
  })
}

// --- Repositories ---

pub fn insert_repo_integration_test() {
  db_test_support.with_db(fn(db) {
    fixtures.seed_user(db, "user_1")
    let assert Ok(_) = database.create_org(db, "acme", "Acme", "user_1")
    let assert Ok(repo) =
      database.insert_repo(db, "acme", "demo", option.None, "acme/demo.git")
    let assert True = database.repo_exists_for_org(db, "acme", "demo")
    let assert Ok(option.Some(found)) = database.get_repo(db, "acme", "demo")
    let assert True = found.name == repo.name
    let assert Ok(repos) = database.list_repos(db, "acme")
    let assert True = list.length(repos) == 1
    Nil
  })
}

pub fn delete_repo_integration_test() {
  db_test_support.with_db(fn(db) {
    let repo = fixtures.seed_repo(db, "acme", "demo", "user_1")
    let assert Ok(disk) = database.delete_repo(db, "acme", repo.id)
    let assert True = disk == repo.disk_path
    let assert False = database.repo_exists_for_org(db, "acme", "demo")
    Nil
  })
}

// --- SSH keys ---

pub fn ssh_keys_integration_test() {
  db_test_support.with_db(fn(db) {
    fixtures.seed_user(db, "user_1")
    let #(public_key, blob, fp) = fixtures.test_ssh_key()
    let assert Ok(key) =
      database.insert_key(db, "user_1", "laptop", public_key, blob, fp)
    let assert Ok(keys) = database.list_keys(db, "user_1")
    let assert True = list.any(keys, fn(k) { k.id == key.id })
    let assert Ok(option.Some("user_1")) =
      database.find_user_for_key_blob(db, blob)
    let assert Ok(option.Some(line)) = database.authorized_key_line(db, blob)
    let assert True =
      string.contains(line, "GLEAMHUB_USER_ID=user_1")
    let assert Ok(True) = database.delete_key(db, "user_1", key.id)
    let assert Ok([]) = database.list_keys(db, "user_1")
    Nil
  })
}

// --- Protected branches ---

pub fn protected_branches_integration_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_repo(db, "acme", "demo", "user_1")
    let assert Ok(branches) =
      database.replace_protected_branches(db, "acme", "demo", ["main", "release"])
    let assert True = list.contains(branches, "main")
    let assert Ok(listed) = database.list_protected_branches(db, "acme", "demo")
    let assert True = list.length(listed) == 2
    let assert Ok(True) =
      database.is_branch_protected(db, "acme", "demo", "main")
    let assert Ok(False) =
      database.is_branch_protected(db, "acme", "demo", "feature")
    let assert Ok(_) =
      database.replace_protected_branches(db, "acme", "demo", ["main"])
    let assert Ok(one) = database.list_protected_branches(db, "acme", "demo")
    let assert True = list.length(one) == 1
    Nil
  })
}

// --- Merge requests ---

pub fn merge_request_lifecycle_integration_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_repo(db, "acme", "demo", "user_1")
    let assert Ok(mr) =
      database.insert_merge_request(
        db,
        "acme",
        "demo",
        "Add feature",
        option.Some("Details here"),
        "user_1",
        "feature",
        "main",
      )
    let assert True = mr.state == "open"
    let assert Ok(option.Some(1)) =
      database.find_open_merge_request(db, "acme", "demo", "feature", "main")
    let assert Ok(option.Some(found)) =
      database.get_merge_request(db, "acme", "demo", mr.number)
    let assert True = found.id == mr.id
    let assert Ok(mrs) = database.list_merge_requests(db, "acme", "demo")
    let assert True = list.length(mrs) == 1
    let assert Ok(comment) =
      database.insert_merge_request_comment(
        db,
        "acme",
        "demo",
        mr.number,
        "user_1",
        "Looks good",
        option.None,
        option.None,
      )
    let assert Ok(comments) =
      database.list_merge_request_comments(db, "acme", "demo", mr.number)
    let assert True =
      list.any(comments, fn(c) { c.id == comment.id && c.body == "Looks good" })
    let sha = "abc123def4567890123456789012345678901234"
    let assert Ok(merged) =
      database.merge_merge_request(
        db,
        "acme",
        "demo",
        mr.number,
        sha,
        "user_1",
      )
    let assert True = merged.state == "merged"
    let assert option.Some(merged_sha) = merged.merge_commit_sha
    let assert True = merged_sha == sha
    let assert Ok(option.None) =
      database.find_open_merge_request(db, "acme", "demo", "feature", "main")
    Nil
  })
}

pub fn close_merge_request_integration_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_repo(db, "acme", "demo", "user_1")
    let assert Ok(mr) =
      database.insert_merge_request(
        db,
        "acme",
        "demo",
        "WIP",
        option.None,
        "user_1",
        "feature",
        "main",
      )
    let assert Ok(closed) =
      database.close_merge_request(db, "acme", "demo", mr.number)
    let assert True = closed.state == "closed"
    Nil
  })
}
