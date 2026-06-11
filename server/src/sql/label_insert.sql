INSERT INTO repository_labels (repository_id, name, color)
SELECT r.id, $3, $4
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
RETURNING
  id::text,
  name,
  color;
