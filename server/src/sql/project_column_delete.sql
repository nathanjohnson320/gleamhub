DELETE FROM project_columns pc
USING projects p
INNER JOIN organizations o ON o.id = p.organization_id
WHERE pc.project_id = p.id
  AND pc.id = $3::uuid
  AND o.slug = $1
  AND p.number = $2
RETURNING pc.id::text;
