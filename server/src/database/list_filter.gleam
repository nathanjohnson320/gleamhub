import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string
import http/list_query.{
  type IssueListQuery, type MergeRequestListQuery,
}
import pog
import sql

const issue_select = "
SELECT
  i.id::text,
  i.number,
  i.title,
  i.description,
  i.author_user_id,
  i.state,
  COALESCE(i.closed_at::text, '') AS closed_at,
  i.created_at::text,
  i.updated_at::text
"

const issue_from = "
FROM issues i
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
"

const mr_select = "
SELECT
  mr.id::text,
  mr.number,
  mr.title,
  mr.description,
  mr.author_user_id,
  mr.source_branch,
  mr.target_branch,
  mr.state,
  mr.merge_commit_sha,
  mr.merged_by_user_id,
  COALESCE(mr.merged_at::text, '') AS merged_at,
  COALESCE(mr.closed_at::text, '') AS closed_at,
  mr.created_at::text,
  mr.updated_at::text,
  mr.is_draft
"

const mr_from = "
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
"

type FilterPart {
  FilterPart(clause: String, value: pog.Value, closing: String)
}

pub fn list_issues_filtered(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  query: IssueListQuery,
) -> Result(pog.Returned(sql.IssueListRow), pog.QueryError) {
  let #(where_sql, params) =
    build_issue_where(org_slug, repo_name, query)
  let order_sql = order_clause("i", query.sort, query.order)
  let sql_text = issue_select <> issue_from <> where_sql <> order_sql <> ";"
  execute_issue_list(db, sql_text, params)
}

pub fn list_merge_requests_filtered(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  query: MergeRequestListQuery,
) -> Result(pog.Returned(sql.MrListRow), pog.QueryError) {
  let #(where_sql, params) =
    build_mr_where(org_slug, repo_name, query)
  let order_sql = order_clause("mr", query.sort, query.order)
  let sql_text = mr_select <> mr_from <> where_sql <> order_sql <> ";"
  execute_mr_list(db, sql_text, params)
}

fn build_issue_where(
  org_slug: String,
  repo_name: String,
  query: IssueListQuery,
) -> #(String, List(pog.Value)) {
  let #(clauses, params, _index) =
    list.fold(
      issue_filter_parts(query),
      #([], [pog.text(org_slug), pog.text(repo_name)], 3),
      append_filter,
    )
  #(
    "WHERE o.slug = $1 AND r.name = $2" <> string.join(clauses, ""),
    params,
  )
}

fn build_mr_where(
  org_slug: String,
  repo_name: String,
  query: MergeRequestListQuery,
) -> #(String, List(pog.Value)) {
  let #(clauses, params, _index) =
    list.fold(
      mr_filter_parts(query),
      #([], [pog.text(org_slug), pog.text(repo_name)], 3),
      append_filter,
    )
  #(
    "WHERE o.slug = $1 AND r.name = $2" <> string.join(clauses, ""),
    params,
  )
}

fn issue_filter_parts(query: IssueListQuery) -> List(FilterPart) {
  let state = case query.state {
    "all" -> []
    state ->
      [FilterPart(clause: " AND i.state = ", value: pog.text(state), closing: "")]
  }
  let author = option_filter(
    query.author,
    " AND i.author_user_id = ",
    fn(v) { pog.text(v) },
  )
  let assignee = option_filter_with_closing(
    query.assignee,
    " AND EXISTS (
  SELECT 1 FROM issue_assignees ia
  WHERE ia.issue_id = i.id AND ia.user_id = ",
    fn(v) { pog.text(v) },
    ")",
  )
  let title = option_filter(
    query.q,
    " AND i.title ILIKE ",
    fn(v) { pog.text(like_pattern(v)) },
  )
  let labels =
    list.map(query.label_ids, fn(label_id) {
      FilterPart(
        clause: " AND EXISTS (
  SELECT 1 FROM issue_labels il
  WHERE il.issue_id = i.id AND il.label_id = ",
        value: pog.text(label_id),
        closing: "::uuid)",
      )
    })
  let milestone = option_filter_with_closing(
    query.milestone_id,
    " AND i.milestone_id = ",
    fn(v) { pog.text(v) },
    "::uuid",
  )
  list.append(
    state,
    list.append(
      author,
      list.append(
        assignee,
        list.append(title, list.append(labels, milestone)),
      ),
    ),
  )
}

fn mr_filter_parts(query: MergeRequestListQuery) -> List(FilterPart) {
  let state = case query.state {
    "all" -> []
    state ->
      [FilterPart(clause: " AND mr.state = ", value: pog.text(state), closing: "")]
  }
  let author = option_filter(
    query.author,
    " AND mr.author_user_id = ",
    fn(v) { pog.text(v) },
  )
  let title = option_filter(
    query.q,
    " AND mr.title ILIKE ",
    fn(v) { pog.text(like_pattern(v)) },
  )
  let source = option_filter(
    query.source_branch,
    " AND mr.source_branch = ",
    fn(v) { pog.text(v) },
  )
  let target = option_filter(
    query.target_branch,
    " AND mr.target_branch = ",
    fn(v) { pog.text(v) },
  )
  let labels =
    list.map(query.label_ids, fn(label_id) {
      FilterPart(
        clause: " AND EXISTS (
  SELECT 1 FROM merge_request_labels ml
  WHERE ml.merge_request_id = mr.id AND ml.label_id = ",
        value: pog.text(label_id),
        closing: "::uuid)",
      )
    })
  list.append(
    state,
    list.append(
      author,
      list.append(title, list.append(source, list.append(target, labels))),
    ),
  )
}

fn option_filter(
  value: Option(String),
  clause: String,
  to_param: fn(String) -> pog.Value,
) -> List(FilterPart) {
  option_filter_with_closing(value, clause, to_param, "")
}

fn option_filter_with_closing(
  value: Option(String),
  clause: String,
  to_param: fn(String) -> pog.Value,
  closing: String,
) -> List(FilterPart) {
  case value {
    option.None -> []
    option.Some(v) ->
      [FilterPart(clause:, value: to_param(v), closing:)]
  }
}

fn append_filter(
  acc: #(List(String), List(pog.Value), Int),
  part: FilterPart,
) -> #(List(String), List(pog.Value), Int) {
  let #(clauses, params, index) = acc
  let placeholder = "$" <> int.to_string(index)
  #(
    list.append(clauses, [part.clause <> placeholder <> part.closing]),
    list.append(params, [part.value]),
    index + 1,
  )
}

fn order_clause(table_alias: String, sort: String, order: String) -> String {
  let column = case sort {
    "created" -> table_alias <> ".created_at"
    "updated" -> table_alias <> ".updated_at"
    _ -> table_alias <> ".number"
  }
  let direction = case order {
    "asc" -> "ASC"
    _ -> "DESC"
  }
  " ORDER BY " <> column <> " " <> direction
}

fn like_pattern(query: String) -> String {
  "%" <> escape_like(query) <> "%"
}

fn escape_like(query: String) -> String {
  query
  |> string.replace(each: "\\", with: "\\\\")
  |> string.replace(each: "%", with: "\\%")
  |> string.replace(each: "_", with: "\\_")
}

fn execute_issue_list(
  db: pog.Connection,
  sql_text: String,
  params: List(pog.Value),
) -> Result(pog.Returned(sql.IssueListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use state <- decode.field(5, decode.string)
    use closed_at <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use updated_at <- decode.field(8, decode.string)
    decode.success(sql.IssueListRow(
      id:,
      number:,
      title:,
      description:,
      author_user_id:,
      state:,
      closed_at:,
      created_at:,
      updated_at:,
    ))
  }

  list.fold(params, pog.query(sql_text), fn(query, param) {
    pog.parameter(query, param)
  })
  |> pog.returning(decoder)
  |> pog.execute(db)
}

fn execute_mr_list(
  db: pog.Connection,
  sql_text: String,
  params: List(pog.Value),
) -> Result(pog.Returned(sql.MrListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use number <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use author_user_id <- decode.field(4, decode.string)
    use source_branch <- decode.field(5, decode.string)
    use target_branch <- decode.field(6, decode.string)
    use state <- decode.field(7, decode.string)
    use merge_commit_sha <- decode.field(8, decode.optional(decode.string))
    use merged_by_user_id <- decode.field(9, decode.optional(decode.string))
    use merged_at <- decode.field(10, decode.string)
    use closed_at <- decode.field(11, decode.string)
    use created_at <- decode.field(12, decode.string)
    use updated_at <- decode.field(13, decode.string)
    use is_draft <- decode.field(14, decode.bool)
    decode.success(sql.MrListRow(
      id:,
      number:,
      title:,
      description:,
      author_user_id:,
      source_branch:,
      target_branch:,
      state:,
      merge_commit_sha:,
      merged_by_user_id:,
      merged_at:,
      closed_at:,
      created_at:,
      updated_at:,
      is_draft:,
    ))
  }

  list.fold(params, pog.query(sql_text), fn(query, param) {
    pog.parameter(query, param)
  })
  |> pog.returning(decoder)
  |> pog.execute(db)
}
