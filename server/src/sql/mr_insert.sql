INSERT INTO merge_requests (
  repository_id,
  number,
  title,
  description,
  author_user_id,
  source_branch,
  target_branch,
  state,
  is_draft
)
SELECT
  r.id,
  COALESCE(
    (SELECT MAX(m.number) FROM merge_requests m WHERE m.repository_id = r.id),
    0
  ) + 1,
  $3,
  NULLIF($4, ''),
  $5,
  $6,
  $7,
  'open',
  $8
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
RETURNING
  id::text,
  number,
  title,
  description,
  author_user_id,
  source_branch,
  target_branch,
  state,
  merge_commit_sha,
  merged_by_user_id,
  COALESCE(merged_at::text, '') AS merged_at,
  COALESCE(closed_at::text, '') AS closed_at,
  created_at::text,
  updated_at::text,
  is_draft;
