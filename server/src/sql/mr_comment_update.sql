UPDATE merge_request_comments c
SET
  body = $5,
  mentioned_user_ids = $6::jsonb,
  updated_at = now()
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE c.merge_request_id = mr.id
  AND o.slug = $1
  AND r.name = $2
  AND mr.number = $3
  AND c.id = $4::uuid
RETURNING
  c.id::text,
  c.author_user_id,
  c.body,
  c.file_path,
  c.line,
  c.mentioned_user_ids::text,
  c.created_at::text,
  c.updated_at::text;
