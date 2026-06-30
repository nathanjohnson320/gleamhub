import diff/mr_line as mr_diff_line
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/uri.{type Uri}

pub type ViewMode {
  Home
  Tree
  Blob
}

pub type MrView {
  Conversation
  Checks
  Commits
  Changes(file: option.Option(String), line: option.Option(Int))
}

pub type MyTab {
  MyOverview
  MyNotifications
}

pub type Route {
  Orgs
  MySpace(MyTab)
  OrgRepos(String)
  OrgMembers(String)
  ProjectList(String)
  ProjectNew(String)
  ProjectDetail(String, Int)
  RepoView(
    ViewMode,
    String,
    String,
    String,
    String,
    line_range: option.Option(#(Int, Int)),
  )
  RepoSettings(String, String)
  MrList(String, String)
  MrNew(String, String)
  MrDetail(String, String, Int, MrView)
  IssueList(String, String)
  IssueNew(String, String)
  IssueDetail(String, String, Int)
  CommitsList(String, String, String)
  ReleaseList(String, String)
  ReleaseNew(String, String)
  ReleaseDetail(String, String, String)
  MilestoneList(String, String)
  MilestoneNew(String, String)
  MilestoneDetail(String, String, Int)
  RepoMissingOrg(String)
  Keys
  Account
  NotFound
}

pub fn from_uri(uri: Uri) -> Route {
  let route = from_segments(path_segments(uri.path), uri.query)
  enrich_repo_blob_line(route, uri.fragment)
}

pub fn from_pathname(pathname: String) -> Route {
  case uri.parse(pathname) {
    Ok(parsed) -> from_uri(parsed)
    Error(_) -> NotFound
  }
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

fn parse_query_line(query: option.Option(String)) -> option.Option(Int) {
  case query {
    option.None -> option.None
    option.Some(q) ->
      case uri.parse_query(q) {
        Ok(params) -> query_param_int(params, "line")
        Error(_) -> option.None
      }
  }
}

fn query_param_int(
  params: List(#(String, String)),
  key: String,
) -> option.Option(Int) {
  list.fold(params, option.None, fn(acc, pair) {
    case acc, pair {
      option.Some(_), _ -> acc
      option.None, #(k, value) if k == key ->
        case int.parse(value) {
          Ok(n) if n > 0 -> option.Some(n)
          _ -> option.None
        }
      option.None, _ -> option.None
    }
  })
}

fn from_segments(
  segments: List(String),
  query: option.Option(String),
) -> Route {
  case segments {
    [] | ["orgs"] -> Orgs
    ["me"] -> MySpace(MyOverview)
    ["me", "notifications"] -> MySpace(MyNotifications)
    ["keys"] | ["settings", "ssh-keys"] -> Keys
    ["settings", "account"] -> Account
    ["orgs", slug] -> OrgRepos(slug)
    ["orgs", slug, "members"] -> OrgMembers(slug)
    ["orgs", slug, "projects"] -> ProjectList(slug)
    ["orgs", slug, "projects", "new"] -> ProjectNew(slug)
    ["orgs", slug, "projects", num] ->
      case int.parse(num) {
        Ok(n) -> ProjectDetail(slug, n)
        Error(_) -> NotFound
      }
    ["orgs", "repos", repo] -> RepoMissingOrg(repo)
    ["orgs", org, "repos", repo] ->
      RepoView(Home, org, repo, "", "", line_range: option.None)
    ["orgs", org, "repos", repo, "commit", sha] ->
      RepoView(Tree, org, repo, sha, "", line_range: option.None)
    ["orgs", org, "repos", repo, "commit", sha, ..path] ->
      RepoView(Tree, org, repo, sha, join_path(path), line_range: option.None)
    ["orgs", org, "repos", repo, "tree", ref, ..path] ->
      RepoView(Tree, org, repo, ref, join_path(path), line_range: option.None)
    ["orgs", org, "repos", repo, "blob", ref, ..path] ->
      RepoView(
        Blob,
        org,
        repo,
        ref,
        join_path(path),
        line_range: parse_query_line_range(query),
      )
    ["orgs", org, "repos", repo, "settings"] -> RepoSettings(org, repo)
    ["orgs", org, "repos", repo, "merge-requests"] -> MrList(org, repo)
    ["orgs", org, "repos", repo, "merge-requests", "new"] -> MrNew(org, repo)
    ["orgs", org, "repos", repo, "merge-requests", num] ->
      case int.parse(num) {
        Ok(n) -> MrDetail(org, repo, n, Conversation)
        Error(_) -> NotFound
      }
    ["orgs", org, "repos", repo, "merge-requests", num, "checks"] ->
      case int.parse(num) {
        Ok(n) -> MrDetail(org, repo, n, Checks)
        Error(_) -> NotFound
      }
    ["orgs", org, "repos", repo, "merge-requests", num, "commits"] ->
      case int.parse(num) {
        Ok(n) -> MrDetail(org, repo, n, Commits)
        Error(_) -> NotFound
      }
    ["orgs", org, "repos", repo, "merge-requests", num, "changes"] ->
      case int.parse(num) {
        Ok(n) ->
          MrDetail(
            org,
            repo,
            n,
            Changes(file: option.None, line: parse_query_line(query)),
          )
        Error(_) -> NotFound
      }
    ["orgs", org, "repos", repo, "merge-requests", num, "changes", ..path] ->
      case int.parse(num) {
        Ok(n) ->
          MrDetail(
            org,
            repo,
            n,
            Changes(
              file: option.Some(join_path(path)),
              line: parse_query_line(query),
            ),
          )
        Error(_) -> NotFound
      }
    ["orgs", org, "repos", repo, "issues"] -> IssueList(org, repo)
    ["orgs", org, "repos", repo, "issues", "new"] -> IssueNew(org, repo)
    ["orgs", org, "repos", repo, "issues", num] ->
      case int.parse(num) {
        Ok(n) -> IssueDetail(org, repo, n)
        Error(_) -> NotFound
      }
    ["orgs", org, "repos", repo, "commits", ref] -> CommitsList(org, repo, ref)
    ["orgs", org, "repos", repo, "commits"] -> CommitsList(org, repo, "")
    ["orgs", org, "repos", repo, "releases"] -> ReleaseList(org, repo)
    ["orgs", org, "repos", repo, "releases", "new"] -> ReleaseNew(org, repo)
    ["orgs", org, "repos", repo, "releases", ..tag] ->
      ReleaseDetail(org, repo, join_path(tag))
    ["orgs", org, "repos", repo, "milestones"] -> MilestoneList(org, repo)
    ["orgs", org, "repos", repo, "milestones", "new"] -> MilestoneNew(org, repo)
    ["orgs", org, "repos", repo, "milestones", num] ->
      case int.parse(num) {
        Ok(n) -> MilestoneDetail(org, repo, n)
        Error(_) -> NotFound
      }
    _ -> NotFound
  }
}

fn parse_query_line_range(
  query: option.Option(String),
) -> option.Option(#(Int, Int)) {
  case query {
    option.None -> option.None
    option.Some(q) ->
      case uri.parse_query(q) {
        Ok(params) -> {
          case query_param_int(params, "line") {
            option.Some(start) -> {
              let end = case query_param_int(params, "end") {
                option.Some(e) -> e
                option.None -> start
              }
              option.Some(#(int.min(start, end), int.max(start, end)))
            }
            option.None -> option.None
          }
        }
        Error(_) -> option.None
      }
  }
}

/// Parse `#L10` or `#L10-L25` from a blob permalink fragment.
pub fn parse_blob_line_fragment(
  fragment: option.Option(String),
) -> option.Option(#(Int, Int)) {
  case fragment {
    option.None -> option.None
    option.Some(raw) -> {
      let hash = case string.starts_with(raw, "#") {
        True -> string.drop_start(raw, 1)
        False -> raw
      }
      parse_line_fragment(hash)
    }
  }
}

fn parse_line_fragment(hash: String) -> option.Option(#(Int, Int)) {
  case string.split(hash, on: "-L") {
    [start_part] ->
      case parse_single_line(start_part) {
        option.Some(n) -> option.Some(#(n, n))
        option.None -> option.None
      }
    [start_part, end_part] -> {
      case parse_single_line(start_part), int.parse(end_part) {
        option.Some(start), Ok(end) ->
          option.Some(#(int.min(start, end), int.max(start, end)))
        _, _ -> option.None
      }
    }
    _ -> option.None
  }
}

fn parse_single_line(part: String) -> option.Option(Int) {
  let stripped = case string.starts_with(part, "L") {
    True -> string.drop_start(part, 1)
    False -> part
  }
  case int.parse(stripped) {
    Ok(n) if n > 0 -> option.Some(n)
    _ -> option.None
  }
}

fn enrich_repo_blob_line(
  route: Route,
  fragment: option.Option(String),
) -> Route {
  case route {
    RepoView(Blob, org, repo, ref, path, line_range: option.None) -> {
      let from_fragment = parse_blob_line_fragment(fragment)
      RepoView(Blob, org, repo, ref, path, line_range: from_fragment)
    }
    _ -> route
  }
}

fn join_path(segments: List(String)) -> String {
  string.join(segments, with: "/")
}

pub fn keys_path() -> String {
  "/settings/ssh-keys"
}

pub fn account_path() -> String {
  "/settings/account"
}

pub fn my_tab_path(tab: MyTab) -> String {
  case tab {
    MyOverview -> "/me"
    MyNotifications -> "/me/notifications"
  }
}

pub fn org_repos_path(slug: String) -> String {
  "/orgs/" <> uri.percent_encode(slug)
}

pub fn org_members_path(slug: String) -> String {
  org_repos_path(slug) <> "/members"
}

pub fn project_list_path(slug: String) -> String {
  org_repos_path(slug) <> "/projects"
}

pub fn project_new_path(slug: String) -> String {
  project_list_path(slug) <> "/new"
}

pub fn project_detail_path(slug: String, num: Int) -> String {
  project_list_path(slug) <> "/" <> int.to_string(num)
}

pub fn repo_home_path(org: String, repo: String) -> String {
  "/orgs/" <> org <> "/repos/" <> uri.percent_encode(repo)
}

pub fn repo_settings_path(org: String, repo: String) -> String {
  repo_home_path(org, repo) <> "/settings"
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

pub fn mr_detail_tab_path(
  org: String,
  repo: String,
  number: Int,
  view: MrView,
) -> String {
  case view {
    Conversation -> mr_detail_path(org, repo, number)
    Checks -> mr_detail_path(org, repo, number) <> "/checks"
    Commits -> mr_detail_path(org, repo, number) <> "/commits"
    Changes(option.None, option.None) ->
      mr_detail_path(org, repo, number) <> "/changes"
    Changes(option.Some(file), option.None) ->
      mr_detail_path(org, repo, number) <> "/changes/" <> encode_path(file)
    Changes(option.Some(file), option.Some(line)) ->
      mr_changes_line_path(org, repo, number, file, line)
    Changes(option.None, option.Some(line)) ->
      mr_detail_path(org, repo, number)
      <> "/changes?line="
      <> int.to_string(line)
  }
}

pub fn mr_changes_line_path(
  org: String,
  repo: String,
  number: Int,
  file: String,
  line: Int,
) -> String {
  mr_detail_path(org, repo, number)
  <> "/changes/"
  <> encode_path(file)
  <> "?line="
  <> int.to_string(line)
  <> "#"
  <> mr_diff_line.diff_line_dom_id(file, line)
}

/// Back-compat name for diff line permalinks.
pub fn mr_diff_line_path(
  org: String,
  repo: String,
  number: Int,
  file: String,
  line: Int,
) -> String {
  mr_changes_line_path(org, repo, number, file, line)
}

pub fn issue_list_path(org: String, repo: String) -> String {
  repo_home_path(org, repo) <> "/issues"
}

pub fn issue_new_path(org: String, repo: String) -> String {
  issue_list_path(org, repo) <> "/new"
}

pub fn issue_detail_path(org: String, repo: String, number: Int) -> String {
  issue_list_path(org, repo) <> "/" <> int.to_string(number)
}

/// True when `ref` looks like a git commit SHA (not a branch name).
pub fn is_commit_ref(ref: String) -> Bool {
  let len = string.length(ref)
  len >= 7 && len <= 40 && is_hex_string(string.lowercase(ref))
}

fn is_hex_string(s: String) -> Bool {
  s
  |> string.to_graphemes
  |> list.all(fn(c) { string.contains("0123456789abcdef", c) })
}

pub fn commit_tree_path(org: String, repo: String, sha: String) -> String {
  repo_home_path(org, repo) <> "/commit/" <> uri.percent_encode(sha)
}

pub fn commits_path(org: String, repo: String, ref: String) -> String {
  case ref {
    "" -> repo_home_path(org, repo) <> "/commits"
    _ -> repo_home_path(org, repo) <> "/commits/" <> uri.percent_encode(ref)
  }
}

pub fn release_list_path(org: String, repo: String) -> String {
  repo_home_path(org, repo) <> "/releases"
}

pub fn milestone_list_path(org: String, repo: String) -> String {
  repo_home_path(org, repo) <> "/milestones"
}

pub fn milestone_new_path(org: String, repo: String) -> String {
  milestone_list_path(org, repo) <> "/new"
}

pub fn milestone_detail_path(org: String, repo: String, number: Int) -> String {
  milestone_list_path(org, repo) <> "/" <> int.to_string(number)
}

pub fn release_new_path(org: String, repo: String) -> String {
  release_list_path(org, repo) <> "/new"
}

pub fn release_detail_path(org: String, repo: String, tag: String) -> String {
  release_list_path(org, repo) <> "/" <> encode_path(tag)
}

pub fn repo_tree_path(
  org: String,
  repo: String,
  ref: String,
  path: String,
) -> String {
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

pub fn repo_blob_path(
  org: String,
  repo: String,
  ref: String,
  path: String,
) -> String {
  "/orgs/"
  <> org
  <> "/repos/"
  <> uri.percent_encode(repo)
  <> "/blob/"
  <> uri.percent_encode(ref)
  <> "/"
  <> encode_path(path)
}

/// Path and query for plain-text raw file view (opens in a new tab; server serves body only).
pub fn repo_raw_browser_path(
  org: String,
  repo: String,
  ref: String,
  path: String,
  token: String,
) -> String {
  let base =
    "/raw/orgs/"
    <> uri.percent_encode(org)
    <> "/repos/"
    <> uri.percent_encode(repo)
    <> "/"
    <> encode_path(ref)
    <> case path {
      "" -> ""
      p -> "/" <> encode_path(p)
    }
  base <> "?token=" <> uri.percent_encode(token)
}

/// API path suffix for blob requests (`/blob/<path>?ref=<branch>`).
pub fn repo_blob_api_suffix(ref: String, path: String) -> String {
  "/blob/" <> encode_path(path) <> "?ref=" <> uri.percent_encode(ref)
}

/// API path suffix for raw file content (`/raw/<ref>/<path>`).
pub fn repo_raw_api_suffix(
  ref: String,
  path: String,
  download: Bool,
) -> String {
  let suffix =
    "/raw/"
    <> encode_path(ref)
    <> case path {
      "" -> ""
      p -> "/" <> encode_path(p)
    }
  case download {
    True -> suffix <> "?download=1"
    False -> suffix
  }
}

/// API path suffix for a zip archive at `ref` (`/archive/<ref>.zip`).
pub type RepoArchiveFormat {
  RepoArchiveZip
  RepoArchiveTarGz
}

pub fn repo_archive_api_suffix(ref: String, format: RepoArchiveFormat) -> String {
  let ext = case format {
    RepoArchiveZip -> ".zip"
    RepoArchiveTarGz -> ".tar.gz"
  }
  "/archive/" <> uri.percent_encode(ref) <> ext
}

/// API path suffix for tree requests (`/tree/<path>?ref=<branch>`).
pub fn repo_tree_api_suffix(ref: String, path: String) -> String {
  case path {
    "" -> "?ref=" <> uri.percent_encode(ref)
    _ -> "/" <> encode_path(path) <> "?ref=" <> uri.percent_encode(ref)
  }
}

pub fn repo_blob_line_path(
  org: String,
  repo: String,
  ref: String,
  path: String,
  line: Int,
) -> String {
  repo_blob_path(org, repo, ref, path)
  <> "?line="
  <> int.to_string(line)
  <> blob_line_fragment(line, line)
}

pub fn repo_blob_line_range_path(
  org: String,
  repo: String,
  ref: String,
  path: String,
  start_line: Int,
  end_line: Int,
) -> String {
  repo_blob_path(org, repo, ref, path)
  <> "?line="
  <> int.to_string(start_line)
  <> "&end="
  <> int.to_string(end_line)
  <> blob_line_fragment(start_line, end_line)
}

fn blob_line_fragment(start: Int, end: Int) -> String {
  case start == end {
    True -> "#L" <> int.to_string(start)
    False -> "#L" <> int.to_string(start) <> "-L" <> int.to_string(end)
  }
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
