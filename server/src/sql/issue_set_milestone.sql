UPDATE issues i
SET
  milestone_id = NULLIF($4, '')::uuid,
  updated_at = now()
FROM repositories r
INNER JOIN organizations o ON o.id = r.organization_id
WHERE i.repository_id = r.id
  AND o.slug = $1
  AND r.name = $2
  AND i.number = $3
  AND (
    $4 = ''
    OR EXISTS (
      SELECT 1
      FROM milestones m
      WHERE m.id = NULLIF($4, '')::uuid
        AND m.repository_id = r.id
    )
  )
RETURNING
  i.id::text,
  i.number,
  i.title,
  i.description,
  i.author_user_id,
  i.state,
  COALESCE(i.closed_at::text, '') AS closed_at,
  i.created_at::text,
  i.updated_at::text;
