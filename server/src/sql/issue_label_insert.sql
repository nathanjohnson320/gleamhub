INSERT INTO issue_labels (issue_id, label_id)
VALUES ($1::uuid, $2::uuid);
