DELETE FROM issue_merge_request_links
WHERE merge_request_id = $1::uuid;
