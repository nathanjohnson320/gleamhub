SELECT
  i.number,
  r.name AS repo_name
FROM issue_merge_request_links l
INNER JOIN issues i ON i.id = l.issue_id
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE l.merge_request_id = $1::uuid
  AND l.link_type = 'closes'
  AND i.state = 'open'
  AND o.slug = $2
ORDER BY i.number;
