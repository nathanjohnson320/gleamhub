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
FROM issues i
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
ORDER BY i.number DESC;
