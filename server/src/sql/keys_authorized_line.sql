SELECT user_id, public_key
FROM ssh_public_keys
WHERE key_blob = $1
LIMIT 1;
