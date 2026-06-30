UPDATE project_items pi
SET
  column_id = $4::uuid,
  position = $5
FROM projects p
INNER JOIN organizations o ON o.id = p.organization_id
INNER JOIN project_columns pc ON pc.id = $4::uuid AND pc.project_id = p.id
WHERE pi.id = $3::uuid
  AND pi.project_id = p.id
  AND o.slug = $1
  AND p.number = $2
RETURNING
  pi.id::text,
  pi.column_id::text,
  pi.position,
  pi.item_type,
  pi.repository_id::text,
  pi.item_number,
  pi.created_at::text;
