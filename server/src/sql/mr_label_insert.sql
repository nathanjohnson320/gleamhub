INSERT INTO merge_request_labels (merge_request_id, label_id)
VALUES ($1::uuid, $2::uuid);
