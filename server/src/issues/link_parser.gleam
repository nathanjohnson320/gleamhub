import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/string

pub type LinkType {
  Closes
  Relates
}

pub type ParsedLink {
  ParsedLink(repo: Option(String), number: Int, link_type: LinkType)
}

const closes_same_repo_pattern =
  "(?i)(?:fix(?:es|ed)?|close(?:s|d)?|resolve(?:s|d)?)\\s+#(\\d+)"

const closes_cross_repo_pattern =
  "(?i)(?:fix(?:es|ed)?|close(?:s|d)?|resolve(?:s|d)?)\\s+([\\w-]+)/([\\w.-]+)#(\\d+)"

const relates_same_repo_pattern =
  "(?i)(?:relate(?:s|d)?|related)\\s+#(\\d+)"

const relates_cross_repo_pattern =
  "(?i)(?:relate(?:s|d)?|related)\\s+([\\w-]+)/([\\w.-]+)#(\\d+)"

pub fn parse(org_slug: String, text: String) -> List(ParsedLink) {
  let closes_same = scan_same_repo(closes_same_repo_pattern, text, Closes)
  let closes_cross = scan_cross_repo(closes_cross_repo_pattern, text, org_slug, Closes)
  let relates_same = scan_same_repo(relates_same_repo_pattern, text, Relates)
  let relates_cross =
    scan_cross_repo(relates_cross_repo_pattern, text, org_slug, Relates)
  dedupe(
    list.append(closes_same, closes_cross)
    |> list.append(relates_same)
    |> list.append(relates_cross),
  )
}

pub fn link_type_string(link_type: LinkType) -> String {
  case link_type {
    Closes -> "closes"
    Relates -> "relates"
  }
}

fn scan_same_repo(
  pattern: String,
  text: String,
  link_type: LinkType,
) -> List(ParsedLink) {
  case regexp.from_string(pattern) {
    Error(_) -> []
    Ok(regex) ->
      regexp.scan(regex, text)
      |> list.filter_map(fn(match) {
        case match.submatches {
          [number_opt] ->
            case number_opt {
              Some(number_str) ->
                result.map(int.parse(number_str), fn(number) {
                  ParsedLink(repo: None, number:, link_type:)
                })
              _ -> Error(Nil)
            }
          _ -> Error(Nil)
        }
      })
  }
}

fn scan_cross_repo(
  pattern: String,
  text: String,
  org_slug: String,
  link_type: LinkType,
) -> List(ParsedLink) {
  case regexp.from_string(pattern) {
    Error(_) -> []
    Ok(regex) ->
      regexp.scan(regex, text)
      |> list.filter_map(fn(match) {
        case match.submatches {
          [org_opt, repo_opt, number_opt] ->
            case org_opt, repo_opt, number_opt {
              Some(parsed_org), Some(repo), Some(number_str) ->
                case string.lowercase(parsed_org) == string.lowercase(org_slug) {
                  False -> Error(Nil)
                  True ->
                    result.map(int.parse(number_str), fn(number) {
                      ParsedLink(repo: Some(repo), number:, link_type:)
                    })
                }
              _, _, _ -> Error(Nil)
            }
          _ -> Error(Nil)
        }
      })
  }
}

fn dedupe(links: List(ParsedLink)) -> List(ParsedLink) {
  list.fold(links, dict.new(), fn(acc, link) {
    let key = link_key(link)
    case dict.get(acc, key) {
      Ok(existing) ->
        dict.insert(acc, key, prefer_closes(existing, link))
      Error(Nil) -> dict.insert(acc, key, link)
    }
  })
  |> dict.values
}

fn link_key(link: ParsedLink) -> String {
  let repo = case link.repo {
    None -> ""
    Some(r) -> r
  }
  repo <> "#" <> int.to_string(link.number)
}

fn prefer_closes(a: ParsedLink, b: ParsedLink) -> ParsedLink {
  case a.link_type, b.link_type {
    Closes, _ -> a
    _, Closes -> b
    _, _ -> a
  }
}
