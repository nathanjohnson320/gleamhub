DELETE FROM organization_invitations i
USING organizations o
WHERE i.organization_id = o.id
  AND o.slug = $1
  AND i.id = $2::uuid
RETURNING i.id::text;
