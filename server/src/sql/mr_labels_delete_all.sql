DELETE FROM merge_request_labels
WHERE merge_request_id = $1::uuid;
