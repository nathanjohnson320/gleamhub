SELECT m.role
FROM organization_members m
INNER JOIN organizations o ON o.id = m.organization_id
WHERE m.user_id = $1 AND o.slug = $2;
