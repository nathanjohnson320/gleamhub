UPDATE notifications
SET read_at = now()
WHERE id = $1::uuid
  AND user_id = $2
  AND read_at IS NULL
RETURNING id::text;
