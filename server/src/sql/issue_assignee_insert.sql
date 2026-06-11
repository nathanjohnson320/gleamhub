INSERT INTO issue_assignees (issue_id, user_id)
VALUES ($1::uuid, $2);
