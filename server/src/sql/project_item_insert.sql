INSERT INTO project_items (
  project_id,
  column_id,
  position,
  item_type,
  repository_id,
  item_number
)
SELECT
  p.id,
  (
    SELECT pc.id
    FROM project_columns pc
    WHERE pc.project_id = p.id
    ORDER BY pc.position
    LIMIT 1
  ),
  COALESCE(
    (
      SELECT MAX(pi.position)
      FROM project_items pi
      WHERE pi.column_id = (
        SELECT pc2.id
        FROM project_columns pc2
        WHERE pc2.project_id = p.id
        ORDER BY pc2.position
        LIMIT 1
      )
    ),
    -1
  ) + 1,
  $4::varchar,
  r.id,
  $5
FROM projects p
INNER JOIN organizations o ON o.id = p.organization_id
INNER JOIN repositories r ON r.organization_id = o.id AND r.name = $3
WHERE o.slug = $1
  AND p.number = $2
  AND EXISTS (
    SELECT 1 FROM project_columns pc WHERE pc.project_id = p.id
  )
  AND (
    ($4 = 'issue' AND EXISTS (
      SELECT 1 FROM issues i WHERE i.repository_id = r.id AND i.number = $5
    ))
    OR ($4 = 'merge_request' AND EXISTS (
      SELECT 1 FROM merge_requests mr
      WHERE mr.repository_id = r.id AND mr.number = $5
    ))
  )
RETURNING
  id::text,
  column_id::text,
  position,
  item_type,
  repository_id::text,
  item_number,
  created_at::text;
