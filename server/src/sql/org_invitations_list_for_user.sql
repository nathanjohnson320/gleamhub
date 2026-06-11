SELECT
  i.id::text,
  i.invited_user_id,
  i.role,
  i.invited_by_user_id,
  i.created_at::text,
  o.slug,
  o.name
FROM organization_invitations i
INNER JOIN organizations o ON o.id = i.organization_id
WHERE i.invited_user_id = $1
ORDER BY i.created_at DESC;
