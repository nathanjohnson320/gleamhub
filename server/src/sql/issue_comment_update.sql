UPDATE issue_comments c
SET
  body = $5,
  mentioned_user_ids = $6::jsonb,
  updated_at = now()
FROM issues i
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE c.issue_id = i.id
  AND o.slug = $1
  AND r.name = $2
  AND i.number = $3
  AND c.id = $4::uuid
RETURNING
  c.id::text,
  c.author_user_id,
  c.body,
  c.mentioned_user_ids::text,
  c.created_at::text,
  c.updated_at::text;
