import app/database
import app/web.{type Context}

pub type Access {
  Access(read: Bool, write: Bool)
}

pub fn git_access(
  ctx: Context,
  user_id: String,
  org_slug: String,
  repo_name: String,
  receive_pack: Bool,
) -> Access {
  let db = ctx.repo()
  let read =
    database.repo_exists_for_org(db, org_slug, repo_name)
    && database.is_org_member(db, user_id, org_slug)

  let write = read && receive_pack && database.member_can_write(db, user_id, org_slug)

  Access(read:, write:)
}

pub fn require_member(
  ctx: Context,
  user_id: String,
  org_slug: String,
) -> Result(Nil, Nil) {
  case database.is_org_member(ctx.repo(), user_id, org_slug) {
    True -> Ok(Nil)
    False -> Error(Nil)
  }
}

pub fn require_owner(
  ctx: Context,
  user_id: String,
  org_slug: String,
) -> Result(Nil, Nil) {
  case database.is_org_owner(ctx.repo(), user_id, org_slug) {
    True -> Ok(Nil)
    False -> Error(Nil)
  }
}

pub fn git_repos_root(ctx: Context) -> String {
  ctx.git_repos_root
}

pub fn git_host(ctx: Context) -> String {
  ctx.git_host
}
