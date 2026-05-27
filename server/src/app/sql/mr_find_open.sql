SELECT mr.number
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1
  AND r.name = $2
  AND mr.source_branch = $3
  AND mr.target_branch = $4
  AND mr.state = 'open'
LIMIT 1;
