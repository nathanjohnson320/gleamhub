UPDATE milestones m
SET
  title = $4,
  description = NULLIF($5, ''),
  due_on = NULLIF($6, '')::date,
  updated_at = now()
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE m.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND m.number = $3
RETURNING
  m.id::text,
  m.number,
  m.title,
  m.description,
  m.state,
  COALESCE(m.due_on::text, '') AS due_on,
  COALESCE(m.closed_at::text, '') AS closed_at,
  m.created_at::text,
  m.updated_at::text;
