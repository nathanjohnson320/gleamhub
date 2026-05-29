INSERT INTO issues (
  repository_id,
  number,
  title,
  description,
  author_user_id,
  state
)
SELECT
  r.id,
  COALESCE(
    (SELECT MAX(i.number) FROM issues i WHERE i.repository_id = r.id),
    0
  ) + 1,
  $3,
  NULLIF($4, ''),
  $5,
  'open'
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
RETURNING
  id::text,
  number,
  title,
  description,
  author_user_id,
  state,
  COALESCE(closed_at::text, '') AS closed_at,
  created_at::text,
  updated_at::text;
