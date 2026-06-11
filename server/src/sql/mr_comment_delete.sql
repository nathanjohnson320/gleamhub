DELETE FROM merge_request_comments c
USING merge_requests mr, repositories r, organizations o
WHERE c.merge_request_id = mr.id
  AND mr.repository_id = r.id
  AND o.id = r.organization_id
  AND o.slug = $1
  AND r.name = $2
  AND mr.number = $3
  AND c.id = $4::uuid
RETURNING c.id::text;
