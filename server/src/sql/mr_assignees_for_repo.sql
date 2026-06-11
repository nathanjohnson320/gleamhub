SELECT
  mra.merge_request_id::text,
  mra.user_id
FROM merge_request_assignees mra
INNER JOIN merge_requests mr ON mr.id = mra.merge_request_id
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2;
