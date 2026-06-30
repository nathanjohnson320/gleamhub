UPDATE projects p
SET
  title = $3,
  description = NULLIF($4, ''),
  state = $5,
  updated_at = now()
FROM organizations o
WHERE p.organization_id = o.id
  AND o.slug = $1
  AND p.number = $2
RETURNING
  p.id::text,
  p.number,
  p.title,
  p.description,
  p.state,
  p.created_by_user_id,
  p.created_at::text,
  p.updated_at::text;
