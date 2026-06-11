SELECT
  mr.id::text,
  mr.number,
  mr.title AS merge_request_title,
  mr.author_user_id,
  o.slug AS org_slug,
  r.name AS repo_name
FROM merge_requests mr
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE mr.id = $1::uuid;
