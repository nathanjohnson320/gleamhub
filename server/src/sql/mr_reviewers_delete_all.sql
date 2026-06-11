DELETE FROM merge_request_reviewers
WHERE merge_request_id = $1::uuid;
