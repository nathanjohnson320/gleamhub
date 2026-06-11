SELECT id::text, title, public_key, fingerprint
FROM ssh_public_keys
WHERE user_id = $1
ORDER BY created_at DESC;
