import app/database.{
  type KeyRow, type OrgRow, type RepoRow, type UserRow,
}
import gleam/json
import gleam/option

pub fn org_json(org: OrgRow) -> json.Json {
  json.object([
    #("id", json.string(org.id)),
    #("slug", json.string(org.slug)),
    #("name", json.string(org.name)),
    #(
      "role",
      case org.role {
        option.Some(role) -> json.string(role)
        option.None -> json.null()
      },
    ),
  ])
}

pub fn orgs_json(orgs: List(OrgRow)) -> json.Json {
  json.array(orgs, of: org_json)
}

pub fn repo_json(repo: RepoRow, clone_url: String) -> json.Json {
  json.object([
    #("id", json.string(repo.id)),
    #("name", json.string(repo.name)),
    #("org_slug", json.string(repo.org_slug)),
    #("disk_path", json.string(repo.disk_path)),
    #("clone_url", json.string(clone_url)),
    #(
      "description",
      case repo.description {
        option.Some(d) -> json.string(d)
        option.None -> json.null()
      },
    ),
  ])
}

pub fn repos_json(repos: List(#(RepoRow, String))) -> json.Json {
  json.array(repos, of: fn(pair) {
    let #(repo, url) = pair
    repo_json(repo, url)
  })
}

pub fn key_json(key: KeyRow) -> json.Json {
  json.object([
    #("id", json.string(key.id)),
    #("title", json.string(key.title)),
    #("public_key", json.string(key.public_key)),
    #("fingerprint", json.string(key.fingerprint)),
  ])
}

pub fn keys_json(keys: List(KeyRow)) -> json.Json {
  json.array(keys, of: key_json)
}

pub fn me_json(user: UserRow, orgs: List(OrgRow)) -> json.Json {
  json.object([
    #("id", json.string(user.id)),
    #(
      "display_name",
      case user.display_name {
        option.Some(n) -> json.string(n)
        option.None -> json.null()
      },
    ),
    #(
      "email",
      case user.email {
        option.Some(e) -> json.string(e)
        option.None -> json.null()
      },
    ),
    #("organizations", orgs_json(orgs)),
  ])
}

pub fn access_json(read: Bool, write: Bool) -> json.Json {
  json.object([#("read", json.bool(read)), #("write", json.bool(write))])
}
