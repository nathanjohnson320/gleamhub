import gleam/dynamic/decode
import gleam/json
import gleam/option

pub type Org {
  Org(id: String, slug: String, name: String, role: option.Option(String))
}

pub type Repo {
  Repo(
    id: String,
    name: String,
    org_slug: String,
    clone_url: String,
    description: option.Option(String),
  )
}

pub type SshKey {
  SshKey(id: String, title: String, public_key: String, fingerprint: String)
}

pub type RepoDetail {
  RepoDetail(
    id: String,
    name: String,
    org_slug: String,
    clone_url: String,
    description: option.Option(String),
    default_branch: option.Option(String),
  )
}

pub type TreeEntry {
  TreeEntry(name: String, entry_type: String, sha: String)
}

pub type TreeListing {
  TreeListing(ref: String, path: String, entries: List(TreeEntry))
}

pub type Readme {
  Readme(ref: String, path: String, content: String)
}

pub type BlobView {
  BlobView(
    ref: String,
    path: String,
    content: String,
    encoding: String,
    size: Int,
    binary: Bool,
  )
}

pub fn org_decoder() -> decode.Decoder(Org) {
  use id <- decode.field("id", decode.string)
  use slug <- decode.field("slug", decode.string)
  use name <- decode.field("name", decode.string)
  use role <- decode.field("role", decode.optional(decode.string))
  decode.success(Org(id:, slug:, name:, role:))
}

pub fn orgs_decoder() -> decode.Decoder(List(Org)) {
  decode.list(org_decoder())
}

pub fn repo_decoder() -> decode.Decoder(Repo) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use org_slug <- decode.field("org_slug", decode.string)
  use clone_url <- decode.field("clone_url", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  decode.success(Repo(id:, name:, org_slug:, clone_url:, description:))
}

pub fn repos_decoder() -> decode.Decoder(List(Repo)) {
  decode.list(repo_decoder())
}

pub fn key_decoder() -> decode.Decoder(SshKey) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use public_key <- decode.field("public_key", decode.string)
  use fingerprint <- decode.field("fingerprint", decode.string)
  decode.success(SshKey(id:, title:, public_key:, fingerprint:))
}

pub fn keys_decoder() -> decode.Decoder(List(SshKey)) {
  decode.list(key_decoder())
}

pub fn create_org_body(slug: String, name: String) -> json.Json {
  json.object([#("slug", json.string(slug)), #("name", json.string(name))])
}

pub fn create_repo_body(name: String, description: option.Option(String)) -> json.Json {
  json.object([
    #("name", json.string(name)),
    #(
      "description",
      case description {
        option.Some(d) -> json.string(d)
        option.None -> json.null()
      },
    ),
  ])
}

pub fn repo_detail_decoder() -> decode.Decoder(RepoDetail) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use org_slug <- decode.field("org_slug", decode.string)
  use clone_url <- decode.field("clone_url", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use default_branch <- decode.field(
    "default_branch",
    decode.optional(decode.string),
  )
  decode.success(RepoDetail(
    id:,
    name:,
    org_slug:,
    clone_url:,
    description:,
    default_branch:,
  ))
}

pub fn branches_decoder() -> decode.Decoder(List(String)) {
  use branches <- decode.field("branches", decode.list(decode.string))
  decode.success(branches)
}

pub fn tree_entry_decoder() -> decode.Decoder(TreeEntry) {
  use name <- decode.field("name", decode.string)
  use entry_type <- decode.field("type", decode.string)
  use sha <- decode.field("sha", decode.string)
  decode.success(TreeEntry(name:, entry_type:, sha:))
}

pub fn tree_decoder() -> decode.Decoder(TreeListing) {
  use ref <- decode.field("ref", decode.string)
  use path <- decode.field("path", decode.string)
  use entries <- decode.field("entries", decode.list(tree_entry_decoder()))
  decode.success(TreeListing(ref:, path:, entries:))
}

pub fn readme_decoder() -> decode.Decoder(Readme) {
  use ref <- decode.field("ref", decode.string)
  use path <- decode.field("path", decode.string)
  use content <- decode.field("content", decode.string)
  decode.success(Readme(ref:, path:, content:))
}

pub fn blob_decoder() -> decode.Decoder(BlobView) {
  use ref <- decode.field("ref", decode.string)
  use path <- decode.field("path", decode.string)
  use content <- decode.field("content", decode.string)
  use encoding <- decode.field("encoding", decode.string)
  use size <- decode.field("size", decode.int)
  use binary <- decode.field("binary", decode.bool)
  decode.success(BlobView(ref:, path:, content:, encoding:, size:, binary:))
}

pub fn create_key_body(title: String, public_key: String) -> json.Json {
  json.object([
    #("title", json.string(title)),
    #("public_key", json.string(public_key)),
  ])
}
