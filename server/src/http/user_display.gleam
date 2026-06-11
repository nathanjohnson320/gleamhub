import database.{
  type IssueCommentRow, type IssueRow, type MergeRequestCommentRow,
  comment_with_author_name, issue_assignees_with_names,
  issue_comment_with_author_name, issue_with_assignees, issue_with_author_name,
  lookup_user_display_names,
}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import http/clerk_api
import http/web.{type Context}

pub fn display_name(ctx: Context, user_id: String) -> String {
  case dict.get(display_names(ctx, [user_id]), user_id) {
    Ok(name) -> name
    Error(_) -> user_id
  }
}

pub fn hydrate_mr_comments(
  ctx: Context,
  comments: List(MergeRequestCommentRow),
) -> List(MergeRequestCommentRow) {
  let ids = list.map(comments, fn(comment) { comment.author_user_id })
  let names = display_names(ctx, ids)
  list.map(comments, fn(comment) {
    let author_name = case dict.get(names, comment.author_user_id) {
      Ok(name) -> name
      Error(_) -> comment.author_name
    }
    comment_with_author_name(comment, author_name)
  })
}

pub fn hydrate_issues(ctx: Context, issues: List(IssueRow)) -> List(IssueRow) {
  let ids = list.map(issues, fn(issue) { issue.author_user_id })
  let names = display_names(ctx, ids)
  list.map(issues, fn(issue) {
    let author_name = case dict.get(names, issue.author_user_id) {
      Ok(name) -> name
      Error(_) -> issue.author_name
    }
    issue_with_author_name(issue, author_name)
  })
}

pub fn hydrate_issue(ctx: Context, issue: IssueRow) -> IssueRow {
  let user_ids =
    list.unique([
      issue.author_user_id,
      ..list.map(issue.assignees, fn(assignee) { assignee.user_id })
    ])
  let names = display_names(ctx, user_ids)
  let author_name = case dict.get(names, issue.author_user_id) {
    Ok(name) -> name
    Error(_) -> issue.author_name
  }
  issue_with_assignees(
    issue_with_author_name(issue, author_name),
    issue_assignees_with_names(issue.assignees, names),
  )
}

pub fn hydrate_issue_assignees(ctx: Context, issue: IssueRow) -> IssueRow {
  let ids = list.map(issue.assignees, fn(assignee) { assignee.user_id })
  let names = display_names(ctx, ids)
  issue_with_assignees(
    issue,
    issue_assignees_with_names(issue.assignees, names),
  )
}

pub fn hydrate_issue_comments(
  ctx: Context,
  comments: List(IssueCommentRow),
) -> List(IssueCommentRow) {
  let ids = list.map(comments, fn(comment) { comment.author_user_id })
  let names = display_names(ctx, ids)
  list.map(comments, fn(comment) {
    let author_name = case dict.get(names, comment.author_user_id) {
      Ok(name) -> name
      Error(_) -> comment.author_name
    }
    issue_comment_with_author_name(comment, author_name)
  })
}

pub fn mention_handles(
  ctx: Context,
  user_ids: List(String),
) -> List(String) {
  let unique_ids = list.unique(user_ids)
  case unique_ids {
    [] -> []
    ids -> {
      let usernames = case ctx.clerk {
        option.Some(client) ->
          case clerk_api.lookup_usernames(client, ids) {
            Ok(map) -> map
            Error(_) -> dict.new()
          }
        option.None -> dict.new()
      }
      list.map(ids, fn(id) {
        case dict.get(usernames, id) {
          Ok(username) -> username
          Error(_) -> id
        }
      })
    }
  }
}

pub fn display_names(
  ctx: Context,
  user_ids: List(String),
) -> Dict(String, String) {
  let unique_ids = list.unique(user_ids)
  let from_db = case lookup_user_display_names(ctx.repo(), unique_ids) {
    Ok(names) -> names
    Error(_) -> dict.new()
  }
  let needs_clerk =
    list.filter(unique_ids, fn(id) {
      case dict.get(from_db, id) {
        Ok(_) -> False
        Error(_) -> True
      }
    })
  let from_clerk = case needs_clerk, ctx.clerk {
    [], _ -> dict.new()
    ids, option.Some(client) -> clerk_api.author_display_names(client, ids)
    _, option.None -> dict.new()
  }
  list.fold(unique_ids, dict.new(), fn(names, id) {
    let resolved = case dict.get(from_db, id) {
      Ok(name) -> name
      Error(_) ->
        case dict.get(from_clerk, id) {
          Ok(name) -> name
          Error(_) -> id
        }
    }
    dict.insert(names, id, resolved)
  })
}
