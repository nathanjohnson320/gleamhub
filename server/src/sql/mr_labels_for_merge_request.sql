SELECT
  l.id::text,
  l.name,
  l.color
FROM merge_request_labels ml
INNER JOIN repository_labels l ON l.id = ml.label_id
WHERE ml.merge_request_id = $1::uuid;
