INSERT INTO project_columns (project_id, name, position)
SELECT p.id, $3, $4
FROM projects p
INNER JOIN organizations o ON o.id = p.organization_id
WHERE o.slug = $1 AND p.number = $2
RETURNING
  id::text,
  name,
  position;
