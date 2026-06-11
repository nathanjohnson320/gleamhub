UPDATE notifications
SET read_at = now()
WHERE user_id = $1
  AND read_at IS NULL;
