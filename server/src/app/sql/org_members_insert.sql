INSERT INTO organization_members (organization_id, user_id, role)
VALUES ($1::uuid, $2, $3);
