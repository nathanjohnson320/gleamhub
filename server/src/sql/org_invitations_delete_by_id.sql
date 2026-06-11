DELETE FROM organization_invitations
WHERE id = $1::uuid
  AND invited_user_id = $2
RETURNING id::text;
