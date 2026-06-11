import gleam/list
import gleam/option.{type Option}
import gleam/string
import http/api.{type Label, type OrgMember}

pub type IssueSearchParts {
  IssueSearchParts(
    label_names: List(String),
    assignee: Option(String),
    author: Option(String),
    text: String,
  )
}

pub type MergeRequestSearchParts {
  MergeRequestSearchParts(
    label_names: List(String),
    author: Option(String),
    source_branch: Option(String),
    target_branch: Option(String),
    text: String,
  )
}

pub fn parse_issue_search(input: String) -> IssueSearchParts {
  parse_issue_tokens(tokenize(input))
}

pub fn parse_merge_request_search(input: String) -> MergeRequestSearchParts {
  parse_mr_tokens(tokenize(input))
}

pub fn resolve_member(
  raw: Option(String),
  members: List(OrgMember),
) -> Option(String) {
  case raw {
    option.None -> option.None
    option.Some(query) -> {
      let needle = string.lowercase(string.trim(query))
      case list.find(members, fn(member) { member_matches(member, needle) }) {
        Ok(member) -> option.Some(member.user_id)
        Error(_) -> option.Some(string.trim(query))
      }
    }
  }
}

pub fn resolve_label_names(
  names: List(String),
  labels: List(Label),
) -> List(String) {
  list.filter_map(names, fn(name) {
    case string.trim(name) {
      "" -> Error(Nil)
      trimmed ->
        Ok(case find_label(labels, trimmed) {
          option.Some(label) -> label.name
          option.None -> trimmed
        })
    }
  })
  |> list.unique
}

fn member_matches(member: OrgMember, needle: String) -> Bool {
  string.lowercase(member.user_id) == needle
  || string.lowercase(member.display_name) == needle
  || case member.username {
    option.Some(username) -> string.lowercase(username) == needle
    option.None -> False
  }
}

fn find_label(labels: List(Label), name: String) -> Option(Label) {
  let needle = string.lowercase(name)
  list.find(labels, fn(label) { string.lowercase(label.name) == needle })
  |> option.from_result
}

fn tokenize(input: String) -> List(String) {
  tokenize_chars(input, 0, string.length(input), "", [], False)
  |> list.reverse
}

fn tokenize_chars(
  input: String,
  index: Int,
  end: Int,
  current: String,
  tokens: List(String),
  quoted: Bool,
) -> List(String) {
  case index >= end {
    True ->
      case string.trim(current) {
        "" -> tokens
        token -> [token, ..tokens]
      }
    False -> {
      let assert Ok(#(grapheme, _rest)) =
        string.pop_grapheme(string.slice(input, index, end))
      let next_index = index + string.length(grapheme)
      case quoted, grapheme {
        True, "\"" ->
          tokenize_chars(input, next_index, end, current <> "\"", tokens, False)
        True, _ ->
          tokenize_chars(
            input,
            next_index,
            end,
            current <> grapheme,
            tokens,
            True,
          )
        False, "\"" ->
          tokenize_chars(input, next_index, end, current <> "\"", tokens, True)
        False, " " | False, "\t" | False, "\n" | False, "\r" ->
          case string.trim(current) {
            "" ->
              tokenize_chars(input, next_index, end, "", tokens, False)
            token ->
              tokenize_chars(input, next_index, end, "", [token, ..tokens], False)
          }
        False, _ ->
          tokenize_chars(
            input,
            next_index,
            end,
            current <> grapheme,
            tokens,
            False,
          )
      }
    }
  }
}

fn parse_issue_tokens(tokens: List(String)) -> IssueSearchParts {
  list.fold(tokens, empty_issue_parts(), fn(parts, token) {
    case split_qualifier(token) {
      option.Some(#("label", value)) | option.Some(#("labels", value)) ->
        IssueSearchParts(
          ..parts,
          label_names: list.append(parts.label_names, split_commas(value)),
        )
      option.Some(#("assignee", value)) ->
        IssueSearchParts(..parts, assignee: option.Some(value))
      option.Some(#("author", value)) ->
        IssueSearchParts(..parts, author: option.Some(value))
      option.Some(_) | option.None ->
        IssueSearchParts(..parts, text: join_text(parts.text, token))
    }
  })
}

fn parse_mr_tokens(tokens: List(String)) -> MergeRequestSearchParts {
  list.fold(tokens, empty_mr_parts(), fn(parts, token) {
    case split_qualifier(token) {
      option.Some(#("label", value)) | option.Some(#("labels", value)) ->
        MergeRequestSearchParts(
          ..parts,
          label_names: list.append(parts.label_names, split_commas(value)),
        )
      option.Some(#("author", value)) ->
        MergeRequestSearchParts(..parts, author: option.Some(value))
      option.Some(#("source", value)) | option.Some(#("head", value)) ->
        MergeRequestSearchParts(..parts, source_branch: option.Some(value))
      option.Some(#("target", value)) | option.Some(#("base", value)) ->
        MergeRequestSearchParts(..parts, target_branch: option.Some(value))
      option.Some(_) | option.None ->
        MergeRequestSearchParts(..parts, text: join_text(parts.text, token))
    }
  })
}

fn empty_issue_parts() -> IssueSearchParts {
  IssueSearchParts(
    label_names: [],
    assignee: option.None,
    author: option.None,
    text: "",
  )
}

fn empty_mr_parts() -> MergeRequestSearchParts {
  MergeRequestSearchParts(
    label_names: [],
    author: option.None,
    source_branch: option.None,
    target_branch: option.None,
    text: "",
  )
}

fn split_qualifier(token: String) -> Option(#(String, String)) {
  case string.split_once(token, ":") {
    Ok(#(key, value)) ->
      case unquote(string.trim(value)) {
        "" -> option.None
        trimmed -> option.Some(#(string.lowercase(string.trim(key)), trimmed))
      }
    Error(_) -> option.None
  }
}

fn unquote(value: String) -> String {
  let trimmed = string.trim(value)
  case string.first(trimmed), string.last(trimmed) {
    Ok("\""), Ok("\"") ->
      trimmed |> string.drop_start(1) |> string.drop_end(1)
    _, _ -> trimmed
  }
}

fn split_commas(value: String) -> List(String) {
  list.filter_map(string.split(value, ","), fn(part) {
    case string.trim(part) {
      "" -> Error(Nil)
      trimmed -> Ok(trimmed)
    }
  })
}

fn join_text(existing: String, token: String) -> String {
  case string.trim(existing) {
    "" -> token
    text -> text <> " " <> token
  }
}
