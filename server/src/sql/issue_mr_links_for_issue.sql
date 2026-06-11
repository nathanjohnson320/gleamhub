SELECT
  mr.number,
  mr.title,
  mr.state,
  mr.is_draft,
  l.link_type
FROM issue_merge_request_links l
INNER JOIN merge_requests mr ON mr.id = l.merge_request_id
WHERE l.issue_id = $1::uuid
ORDER BY mr.number;
