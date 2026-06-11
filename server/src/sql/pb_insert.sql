INSERT INTO protected_branches (repository_id, branch_name)
SELECT r.id, $3
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2
RETURNING branch_name;
