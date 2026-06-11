import database
import gleam/list
import gleam/option
import issues/link_parser
import pog

pub fn sync_from_text(
  db: pog.Connection,
  org_slug: String,
  default_repo: String,
  mr_id: String,
  text: option.Option(String),
) -> Result(Nil, pog.QueryError) {
  let body = case text {
    option.None -> ""
    option.Some(t) -> t
  }
  let parsed = link_parser.parse(org_slug, body)
  let resolved =
    list.filter_map(parsed, fn(link) {
      let repo = case link.repo {
        option.None -> default_repo
        option.Some(r) -> r
      }
      case database.get_issue(db, org_slug, repo, link.number) {
        Ok(option.Some(issue)) ->
          Ok(#(issue.id, link_parser.link_type_string(link.link_type)))
        _ -> Error(Nil)
      }
    })
  database.set_issue_mr_links(db, mr_id, resolved)
}
