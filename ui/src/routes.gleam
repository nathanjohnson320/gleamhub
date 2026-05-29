import gleam/int
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
  MrList(String, String)
  MrNew(String, String)
  MrDetail(String, String, Int)
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
    ["keys"] | ["settings", "ssh-keys"] -> Keys
    ["orgs", slug] -> OrgRepos(slug)
    ["orgs", "repos", repo] -> RepoMissingOrg(repo)
    ["orgs", org, "repos", repo] -> RepoView(Home, org, repo, "", "")
    ["orgs", org, "repos", repo, "tree", ref, ..path] ->
      RepoView(Tree, org, repo, ref, join_path(path))
    ["orgs", org, "repos", repo, "blob", ref, ..path] ->
      RepoView(Blob, org, repo, ref, join_path(path))
    ["orgs", org, "repos", repo, "merge-requests"] -> MrList(org, repo)
    ["orgs", org, "repos", repo, "merge-requests", "new"] -> MrNew(org, repo)
    ["orgs", org, "repos", repo, "merge-requests", num] ->
      case int.parse(num) {
        Ok(n) -> MrDetail(org, repo, n)
        Error(_) -> NotFound
      }
    _ -> NotFound
  }
}

fn join_path(segments: List(String)) -> String {
  string.join(segments, with: "/")
}

pub fn keys_path() -> String {
  "/settings/ssh-keys"
}

pub fn repo_home_path(org: String, repo: String) -> String {
  "/orgs/" <> org <> "/repos/" <> uri.percent_encode(repo)
}

pub fn mr_list_path(org: String, repo: String) -> String {
  repo_home_path(org, repo) <> "/merge-requests"
}

pub fn mr_new_path(org: String, repo: String) -> String {
  mr_list_path(org, repo) <> "/new"
}

pub fn mr_detail_path(org: String, repo: String, number: Int) -> String {
  mr_list_path(org, repo) <> "/" <> int.to_string(number)
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

/// Permalink to one line (GitHub-style `#L42`).
pub fn repo_blob_line_path(
  org: String,
  repo: String,
  ref: String,
  path: String,
  line: Int,
) -> String {
  repo_blob_path(org, repo, ref, path) <> "#L" <> int.to_string(line)
}

/// Permalink to a line range (`#L10-L25`).
pub fn repo_blob_line_range_path(
  org: String,
  repo: String,
  ref: String,
  path: String,
  start_line: Int,
  end_line: Int,
) -> String {
  repo_blob_path(org, repo, ref, path)
  <> "#L"
  <> int.to_string(start_line)
  <> "-L"
  <> int.to_string(end_line)
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
