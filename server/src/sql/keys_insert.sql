INSERT INTO ssh_public_keys (user_id, title, public_key, key_blob, fingerprint)
VALUES ($1, $2, $3, $4, $5)
RETURNING id::text, title, public_key, fingerprint;
