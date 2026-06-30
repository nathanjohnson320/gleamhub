DELETE FROM project_items pi
USING projects p
INNER JOIN organizations o ON o.id = p.organization_id
WHERE pi.project_id = p.id
  AND pi.id = $3::uuid
  AND o.slug = $1
  AND p.number = $2
RETURNING pi.id::text;
