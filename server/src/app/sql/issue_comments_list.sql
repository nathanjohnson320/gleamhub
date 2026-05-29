SELECT
  c.id::text,
  c.author_user_id,
  c.author_user_id AS author_name,
  c.body,
  c.created_at::text,
  c.updated_at::text
FROM issue_comments c
INNER JOIN issues i ON i.id = c.issue_id
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND i.number = $3
ORDER BY c.created_at ASC;
