import app/database
import gleam/option
import pog

const ed25519_public_key =
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKL2abstV7VnH5rElnPMPNO1F test@example.com"

const ed25519_key_blob = "AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKL2abstV7VnH5rElnPMPNO1F"

const ed25519_fingerprint = "sha256:AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKL2abstV7VnH5rElnPMPNO1F"

pub fn seed_user(db: pog.Connection, user_id: String) -> Nil {
  let assert Ok(Nil) =
    database.upsert_user(
      db,
      user_id,
      option.Some("Test User"),
      option.Some(user_id <> "@example.com"),
    )
  Nil
}

pub fn seed_org(
  db: pog.Connection,
  slug: String,
  owner_id: String,
) -> database.OrgRow {
  seed_user(db, owner_id)
  let assert Ok(org) = database.create_org(db, slug, "Org " <> slug, owner_id)
  org
}

pub fn seed_repo(
  db: pog.Connection,
  org_slug: String,
  name: String,
  owner_id: String,
) -> database.RepoRow {
  let _ = seed_org(db, org_slug, owner_id)
  let disk = org_slug <> "/" <> name <> ".git"
  let assert Ok(repo) =
    database.insert_repo(db, org_slug, name, option.None, disk)
  repo
}

pub fn test_ssh_key() -> #(String, String, String) {
  #(ed25519_public_key, ed25519_key_blob, ed25519_fingerprint)
}
