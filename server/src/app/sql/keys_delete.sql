DELETE FROM ssh_public_keys
WHERE id::text = $1 AND user_id = $2;
