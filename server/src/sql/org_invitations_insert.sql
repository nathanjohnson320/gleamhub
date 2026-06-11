INSERT INTO organization_invitations (
  organization_id,
  invited_user_id,
  role,
  invited_by_user_id
)
VALUES ($1::uuid, $2, $3, $4)
RETURNING id::text;
