DELETE FROM merge_request_assignees
WHERE merge_request_id = $1::uuid;
