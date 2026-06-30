INSERT INTO projects (
  organization_id,
  number,
  title,
  description,
  created_by_user_id
)
SELECT
  o.id,
  COALESCE(
    (SELECT MAX(p.number) FROM projects p WHERE p.organization_id = o.id),
    0
  ) + 1,
  $2,
  NULLIF($3, ''),
  $4
FROM organizations o
WHERE o.slug = $1
RETURNING
  id::text,
  number,
  title,
  description,
  state,
  created_by_user_id,
  created_at::text,
  updated_at::text;
