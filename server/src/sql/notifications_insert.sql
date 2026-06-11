INSERT INTO notifications (user_id, type, payload)
VALUES ($1, $2, $3::jsonb)
RETURNING
  id::text,
  type AS notification_type,
  payload::text,
  COALESCE(read_at::text, '') AS read_at,
  created_at::text;
