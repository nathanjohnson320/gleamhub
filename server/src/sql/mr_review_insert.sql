INSERT INTO merge_request_reviews (merge_request_id, user_id, state, body)
VALUES ($1::uuid, $2, $3, NULLIF($4, ''))
RETURNING
  id::text,
  merge_request_id::text,
  user_id,
  state,
  body,
  submitted_at::text;
