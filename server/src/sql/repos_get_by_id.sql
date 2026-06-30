SELECT
  r.id::text,
  r.name,
  r.description,
  r.disk_path,
  o.slug AS org_slug
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE r.id = $1::uuid;
