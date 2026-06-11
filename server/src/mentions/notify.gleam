import gleam/option
import http/web.{type Context}
import notifications/create

pub type MentionContext {
  MrComment(
    org_slug: String,
    repo_name: String,
    mr_number: Int,
    comment_id: String,
  )
  IssueComment(
    org_slug: String,
    repo_name: String,
    issue_number: Int,
    comment_id: String,
  )
}

pub fn comment_mentioned(
  ctx: Context,
  actor_user_id: String,
  mentioned_user_ids: List(String),
  previous_mentioned_user_ids: List(String),
  context: MentionContext,
) -> Nil {
  case context {
    MrComment(org_slug, repo_name, mr_number, comment_id) ->
      create.comment_mentioned(
        ctx,
        actor_user_id,
        mentioned_user_ids,
        previous_mentioned_user_ids,
        org_slug,
        repo_name,
        option.Some(mr_number),
        option.None,
        comment_id,
      )
    IssueComment(org_slug, repo_name, issue_number, comment_id) ->
      create.comment_mentioned(
        ctx,
        actor_user_id,
        mentioned_user_ids,
        previous_mentioned_user_ids,
        org_slug,
        repo_name,
        option.None,
        option.Some(issue_number),
        comment_id,
      )
  }
}
