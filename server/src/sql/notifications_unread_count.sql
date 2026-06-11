SELECT COUNT(*)::int AS unread_count
FROM notifications
WHERE user_id = $1
  AND read_at IS NULL;
