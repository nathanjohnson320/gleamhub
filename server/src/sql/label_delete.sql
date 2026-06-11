DELETE FROM repository_labels l
USING repositories r, organizations o
WHERE l.repository_id = r.id
  AND o.id = r.organization_id
  AND o.slug = $1
  AND r.name = $2
  AND l.id = $3::uuid
RETURNING l.id::text;
