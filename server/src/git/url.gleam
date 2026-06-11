import gleam/int
import http/org_access
import http/web.{type Context}

/// SSH clone URL shown in the API and UI (`ssh://git@host[:port]/org/repo.git`).
pub fn clone_url(ctx: Context, org_slug: String, repo_name: String) -> String {
  clone_ssh_url(
    org_access.git_host(ctx),
    org_access.git_port(ctx),
    org_slug,
    repo_name,
  )
}

pub fn clone_ssh_url(
  host: String,
  port: Int,
  org_slug: String,
  repo_name: String,
) -> String {
  let authority = case port {
    22 -> host
    _ -> host <> ":" <> int.to_string(port)
  }

  "ssh://git@" <> authority <> "/" <> org_slug <> "/" <> repo_name <> ".git"
}
