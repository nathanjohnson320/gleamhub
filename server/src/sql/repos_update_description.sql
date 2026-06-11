UPDATE repositories r
SET description = NULLIF($3, '')
FROM organizations o
WHERE r.organization_id = o.id
  AND o.slug = $1
  AND r.name = $2
RETURNING
  r.id::text,
  r.name,
  r.description,
  r.disk_path,
  o.slug;
