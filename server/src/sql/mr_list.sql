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
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
ORDER BY mr.number DESC;
