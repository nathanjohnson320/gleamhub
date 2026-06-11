SELECT
  l.id::text,
  l.name,
  l.color
FROM issue_labels il
INNER JOIN repository_labels l ON l.id = il.label_id
WHERE il.issue_id = $1::uuid;
