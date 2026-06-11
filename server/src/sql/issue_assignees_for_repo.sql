SELECT
  ia.issue_id::text,
  ia.user_id
FROM issue_assignees ia
INNER JOIN issues i ON i.id = ia.issue_id
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2;
