SELECT o.id::text, o.slug, o.name, m.role
FROM organizations o
INNER JOIN organization_members m ON m.organization_id = o.id
WHERE m.user_id = $1
ORDER BY o.slug;
