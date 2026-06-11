UPDATE repositories r
SET required_approvals = $3
FROM organizations o
WHERE r.organization_id = o.id
  AND o.slug = $1
  AND r.name = $2
RETURNING r.required_approvals;
