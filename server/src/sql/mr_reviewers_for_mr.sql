SELECT
  mrr.user_id
FROM merge_request_reviewers mrr
WHERE mrr.merge_request_id = $1::uuid;
