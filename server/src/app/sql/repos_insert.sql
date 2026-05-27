INSERT INTO repositories (organization_id, name, description, disk_path)
SELECT o.id, $2, $3, $4
FROM organizations o
WHERE o.slug = $1
RETURNING id::text, name, description, disk_path;
