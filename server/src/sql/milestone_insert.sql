INSERT INTO milestones (
  repository_id,
  number,
  title,
  description,
  due_on
)
SELECT
  r.id,
  COALESCE(
    (SELECT MAX(m.number) FROM milestones m WHERE m.repository_id = r.id),
    0
  ) + 1,
  $3,
  NULLIF($4, ''),
  NULLIF($5, '')::date
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
RETURNING
  id::text,
  number,
  title,
  description,
  state,
  COALESCE(due_on::text, '') AS due_on,
  COALESCE(closed_at::text, '') AS closed_at,
  created_at::text,
  updated_at::text;
