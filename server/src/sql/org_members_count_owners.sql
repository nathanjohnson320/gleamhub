SELECT COUNT(*)::int AS count
FROM organization_members m
INNER JOIN organizations o ON o.id = m.organization_id
WHERE o.slug = $1 AND m.role = 'owner';
