UPDATE repositories r
SET name = $3, disk_path = $4
FROM organizations o
WHERE r.organization_id = o.id
  AND o.slug = $1
  AND r.name = $2
RETURNING r.id::text, r.name, r.description, r.disk_path, o.slug;
