SELECT
  mra.user_id
FROM merge_request_assignees mra
WHERE mra.merge_request_id = $1::uuid;
