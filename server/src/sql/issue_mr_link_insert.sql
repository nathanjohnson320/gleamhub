INSERT INTO issue_merge_request_links (issue_id, merge_request_id, link_type)
VALUES ($1::uuid, $2::uuid, $3);
