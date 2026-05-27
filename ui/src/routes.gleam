import gleam/list
import gleam/string
import gleam/uri.{type Uri}

pub type ViewMode {
  Home
  Tree
  Blob
}

pub type Route {
  Orgs
  OrgRepos(String)
  RepoView(ViewMode, String, String, String, String)
  RepoMissingOrg(String)
  Keys
  NotFound
}

pub fn from_uri(uri: Uri) -> Route {
  from_segments(path_segments(uri.path))
}

pub fn from_pathname(pathname: String) -> Route {
  from_segments(path_segments(pathname))
}

fn path_segments(path: String) -> List(String) {
  path
  |> uri.path_segments
  |> list.map(decode_segment)
}

fn decode_segment(segment: String) -> String {
  case uri.percent_decode(segment) {
    Ok(decoded) -> decoded
    Error(_) -> segment
  }
}

fn from_segments(segments: List(String)) -> Route {
  case segments {
    [] | ["orgs"] -> Orgs
    ["keys"] -> Keys
    ["orgs", slug] -> OrgRepos(slug)
    ["orgs", "repos", repo] -> RepoMissingOrg(repo)
    ["orgs", org, "repos", repo] -> RepoView(Home, org, repo, "", "")
    ["orgs", org, "repos", repo, "tree", ref, ..path] ->
      RepoView(Tree, org, repo, ref, join_path(path))
    ["orgs", org, "repos", repo, "blob", ref, ..path] ->
      RepoView(Blob, org, repo, ref, join_path(path))
    _ -> NotFound
  }
}

fn join_path(segments: List(String)) -> String {
  string.join(segments, with: "/")
}

pub fn repo_home_path(org: String, repo: String) -> String {
  "/orgs/" <> org <> "/repos/" <> uri.percent_encode(repo)
}

pub fn repo_tree_path(org: String, repo: String, ref: String, path: String) -> String {
  case path {
    "" ->
      "/orgs/"
      <> org
      <> "/repos/"
      <> uri.percent_encode(repo)
      <> "/tree/"
      <> uri.percent_encode(ref)
    _ ->
      "/orgs/"
      <> org
      <> "/repos/"
      <> uri.percent_encode(repo)
      <> "/tree/"
      <> uri.percent_encode(ref)
      <> "/"
      <> encode_path(path)
  }
}

pub fn repo_blob_path(org: String, repo: String, ref: String, path: String) -> String {
  "/orgs/"
  <> org
  <> "/repos/"
  <> uri.percent_encode(repo)
  <> "/blob/"
  <> uri.percent_encode(ref)
  <> "/"
  <> encode_path(path)
}

fn encode_path(path: String) -> String {
  path
  |> string.split(on: "/")
  |> list.map(uri.percent_encode)
  |> string.join(with: "/")
}

pub fn branch_href(
  mode: ViewMode,
  org: String,
  repo: String,
  ref: String,
  path: String,
) -> String {
  case mode {
    Home -> repo_home_path(org, repo)
    Tree -> repo_tree_path(org, repo, ref, path)
    Blob -> repo_blob_path(org, repo, ref, path)
  }
}

pub fn org_slug_for_repo(route_org: String, repo_org: String) -> String {
  case repo_org {
    "" -> route_org
    _ -> repo_org
  }
}
