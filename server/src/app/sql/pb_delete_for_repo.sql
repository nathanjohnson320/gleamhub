DELETE FROM protected_branches pb
USING repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE pb.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2;
