SELECT
  c.id::text,
  c.author_user_id,
  c.body,
  c.file_path,
  c.line,
  c.created_at::text,
  c.updated_at::text
FROM merge_request_comments c
INNER JOIN merge_requests mr ON mr.id = c.merge_request_id
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND mr.number = $3
ORDER BY c.created_at ASC;
