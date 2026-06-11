SELECT
  mrl.merge_request_id::text,
  l.id::text,
  l.name,
  l.color
FROM merge_request_labels mrl
INNER JOIN repository_labels l ON l.id = mrl.label_id
INNER JOIN merge_requests mr ON mr.id = mrl.merge_request_id
INNER JOIN repositories r ON r.id = mr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2;
