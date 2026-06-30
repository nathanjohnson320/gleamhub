UPDATE project_columns pc
SET
  name = $4,
  position = $5
FROM projects p
INNER JOIN organizations o ON o.id = p.organization_id
WHERE pc.project_id = p.id
  AND pc.id = $3::uuid
  AND o.slug = $1
  AND p.number = $2
RETURNING
  pc.id::text,
  pc.name,
  pc.position;
