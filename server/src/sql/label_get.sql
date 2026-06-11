SELECT
  l.id::text,
  l.name,
  l.color
FROM repository_labels l
INNER JOIN repositories r ON r.id = l.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND l.id = $3::uuid;
