DELETE FROM issue_assignees
WHERE issue_id = $1::uuid;
