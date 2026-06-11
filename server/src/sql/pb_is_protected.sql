SELECT 1 AS found
FROM protected_branches pb
INNER JOIN repositories r ON r.id = pb.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1
  AND r.name = $2
  AND pb.branch_name = $3
LIMIT 1;
