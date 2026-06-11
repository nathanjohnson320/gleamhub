SELECT pb.branch_name
FROM protected_branches pb
INNER JOIN repositories r ON r.id = pb.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
ORDER BY pb.branch_name;
