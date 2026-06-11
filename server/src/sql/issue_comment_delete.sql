DELETE FROM issue_comments c
USING issues i, repositories r, organizations o
WHERE c.issue_id = i.id
  AND i.repository_id = r.id
  AND o.id = r.organization_id
  AND o.slug = $1
  AND r.name = $2
  AND i.number = $3
  AND c.id = $4::uuid
RETURNING c.id::text;
