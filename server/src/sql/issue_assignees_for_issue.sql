SELECT ia.user_id
FROM issue_assignees ia
WHERE ia.issue_id = $1::uuid;
