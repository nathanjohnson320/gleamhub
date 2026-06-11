SELECT
  id::text,
  type AS notification_type,
  payload::text,
  COALESCE(read_at::text, '') AS read_at,
  created_at::text
FROM notifications
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;
