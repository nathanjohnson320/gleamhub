INSERT INTO issue_comments (
  issue_id,
  author_user_id,
  body,
  mentioned_user_ids
)
SELECT i.id, $4, $5, $6::jsonb
FROM issues i
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND i.number = $3
RETURNING
  id::text,
  author_user_id,
  body,
  mentioned_user_ids::text,
  created_at::text,
  updated_at::text;
