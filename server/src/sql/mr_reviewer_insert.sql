INSERT INTO merge_request_reviewers (merge_request_id, user_id, requested_by_user_id)
VALUES ($1::uuid, $2, $3)
ON CONFLICT DO NOTHING;
