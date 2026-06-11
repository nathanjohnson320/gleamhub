DELETE FROM repositories r
USING organizations o
WHERE r.organization_id = o.id
  AND o.slug = $1
  AND (r.id::text = $2 OR r.name = $2)
RETURNING r.disk_path;
