SELECT
  i.id::text AS issue_id,
  m.id::text AS milestone_id,
  m.number AS milestone_number,
  m.title AS milestone_title
FROM issues i
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
INNER JOIN milestones m ON m.id = i.milestone_id
WHERE o.slug = $1 AND r.name = $2;
