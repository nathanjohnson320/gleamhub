SELECT
  p.id::text,
  p.number,
  p.title,
  p.description,
  p.state,
  p.created_by_user_id,
  p.created_at::text,
  p.updated_at::text
FROM projects p
INNER JOIN organizations o ON o.id = p.organization_id
WHERE o.slug = $1
ORDER BY p.number DESC;
