INSERT INTO releases (
  repository_id,
  tag_name,
  target_commit_sha,
  title,
  body,
  author_user_id
)
SELECT r.id, $3, $4, $5, NULLIF($6, ''), $7
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
RETURNING
  id::text,
  tag_name,
  target_commit_sha,
  title,
  COALESCE(body, '') AS body,
  author_user_id,
  created_at::text;
