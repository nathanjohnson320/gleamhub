SELECT r.id::text, r.name, r.description, r.disk_path, o.slug
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2;
