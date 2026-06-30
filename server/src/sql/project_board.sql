SELECT
  pc.id::text AS column_id,
  pc.name AS column_name,
  pc.position AS column_position,
  COALESCE(pi.id::text, '') AS item_id,
  pi.position AS item_position,
  pi.item_type,
  pi.item_number,
  r.name AS repo_name,
  o.slug AS org_slug,
  COALESCE(i.title, mr.title, '') AS item_title,
  COALESCE(i.state, mr.state, '') AS item_state,
  COALESCE(pi.created_at::text, '') AS item_created_at
FROM projects p
INNER JOIN organizations o ON o.id = p.organization_id
INNER JOIN project_columns pc ON pc.project_id = p.id
LEFT JOIN project_items pi ON pi.column_id = pc.id
LEFT JOIN repositories r ON r.id = pi.repository_id
LEFT JOIN issues i
  ON pi.item_type = 'issue'
  AND i.repository_id = r.id
  AND i.number = pi.item_number
LEFT JOIN merge_requests mr
  ON pi.item_type = 'merge_request'
  AND mr.repository_id = r.id
  AND mr.number = pi.item_number
WHERE o.slug = $1 AND p.number = $2
ORDER BY pc.position, pi.position;
