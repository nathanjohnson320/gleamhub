SELECT
  m.id::text,
  m.number,
  m.title,
  m.description,
  m.state,
  COALESCE(m.due_on::text, '') AS due_on,
  COALESCE(m.closed_at::text, '') AS closed_at,
  m.created_at::text,
  m.updated_at::text,
  (
    SELECT COUNT(*)::int
    FROM issues i
    WHERE i.milestone_id = m.id AND i.state = 'open'
  ) AS open_issues,
  (
    SELECT COUNT(*)::int
    FROM issues i
    WHERE i.milestone_id = m.id AND i.state = 'closed'
  ) AS closed_issues,
  0::int AS open_mrs
FROM milestones m
INNER JOIN repositories r ON r.id = m.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2 AND m.number = $3;
