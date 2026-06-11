SELECT
  mrr.merge_request_id::text,
  mrr.user_id
FROM merge_request_reviewers mrr
INNER JOIN merge_requests mr ON mr.id = mrr.merge_request_id
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2;
