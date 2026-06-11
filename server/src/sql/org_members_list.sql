SELECT m.user_id, m.role, u.display_name
FROM organization_members m
INNER JOIN organizations o ON o.id = m.organization_id
LEFT JOIN users u ON u.id = m.user_id
WHERE o.slug = $1
ORDER BY m.role, m.user_id;
