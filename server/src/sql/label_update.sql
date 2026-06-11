UPDATE repository_labels l
SET
  name = $4,
  color = $5
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE l.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND l.id = $3::uuid
RETURNING
  l.id::text,
  l.name,
  l.color;
