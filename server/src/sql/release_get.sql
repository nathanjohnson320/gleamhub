SELECT
  rel.id::text,
  rel.tag_name,
  rel.target_commit_sha,
  rel.title,
  COALESCE(rel.body, '') AS body,
  rel.author_user_id,
  rel.created_at::text
FROM releases rel
INNER JOIN repositories r ON r.id = rel.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND rel.tag_name = $3;
