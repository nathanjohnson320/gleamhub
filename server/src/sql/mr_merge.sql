UPDATE merge_requests mr
SET
  state = 'merged',
  merge_commit_sha = $4,
  merged_by_user_id = $5,
  merged_at = now(),
  updated_at = now()
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE mr.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND mr.number = $3
  AND mr.state = 'open'
RETURNING
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
  mr.is_draft;
