DELETE FROM issue_labels
WHERE issue_id = $1::uuid;
