SELECT k.user_id
FROM ssh_public_keys k
INNER JOIN organization_members om ON om.user_id = k.user_id
INNER JOIN organizations o ON o.id = om.organization_id AND o.slug = $2
INNER JOIN repositories r ON r.organization_id = o.id AND r.name = $3
WHERE k.key_blob = $1
LIMIT 1;
