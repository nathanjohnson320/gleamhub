DELETE FROM organization_members m
USING organizations o
WHERE m.organization_id = o.id
  AND o.slug = $1
  AND m.user_id = $2;
