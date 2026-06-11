SELECT
  i.number,
  i.title,
  i.state,
  l.link_type
FROM issue_merge_request_links l
INNER JOIN issues i ON i.id = l.issue_id
WHERE l.merge_request_id = $1::uuid
ORDER BY i.number;
