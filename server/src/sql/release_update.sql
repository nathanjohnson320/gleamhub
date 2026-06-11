UPDATE releases rel
SET
  title = $4,
  body = NULLIF($5, '')
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE rel.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND rel.tag_name = $3
RETURNING
  rel.id::text,
  rel.tag_name,
  rel.target_commit_sha,
  rel.title,
  COALESCE(rel.body, '') AS body,
  rel.author_user_id,
  rel.created_at::text;
