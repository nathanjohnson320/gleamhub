SELECT
  rv.id::text,
  rv.merge_request_id::text,
  rv.user_id,
  rv.user_id AS reviewer_name,
  rv.state,
  rv.body,
  rv.submitted_at::text
FROM merge_request_reviews rv
INNER JOIN merge_requests mr ON mr.id = rv.merge_request_id
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND mr.number = $3
ORDER BY rv.submitted_at DESC;
