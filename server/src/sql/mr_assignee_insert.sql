INSERT INTO merge_request_assignees (merge_request_id, user_id)
VALUES ($1::uuid, $2)
ON CONFLICT DO NOTHING;
