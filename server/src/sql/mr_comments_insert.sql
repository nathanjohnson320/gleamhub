INSERT INTO merge_request_comments (
  merge_request_id,
  author_user_id,
  body,
  file_path,
  line,
  mentioned_user_ids
)
SELECT
  mr.id,
  $4,
  $5,
  NULLIF($6, ''),
  CASE WHEN $7 = 0 THEN NULL ELSE $7 END,
  $8::jsonb
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND mr.number = $3
RETURNING
  id::text,
  author_user_id,
  body,
  file_path,
  line,
  mentioned_user_ids::text,
  created_at::text,
  updated_at::text;
