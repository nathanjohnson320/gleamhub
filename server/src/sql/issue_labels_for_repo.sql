SELECT
  il.issue_id::text,
  l.id::text,
  l.name,
  l.color
FROM issue_labels il
INNER JOIN repository_labels l ON l.id = il.label_id
INNER JOIN issues i ON i.id = il.issue_id
INNER JOIN repositories r ON r.id = i.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE o.slug = $1 AND r.name = $2;
