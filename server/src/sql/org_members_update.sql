UPDATE organization_members m
SET role = $3
FROM organizations o
WHERE m.organization_id = o.id
  AND o.slug = $1
  AND m.user_id = $2;
