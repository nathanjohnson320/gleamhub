SELECT COUNT(*)::int AS changes_requested_count
FROM (
  SELECT DISTINCT ON (rr.user_id) rr.user_id, rv.state
  FROM merge_request_reviewers rr
  LEFT JOIN LATERAL (
    SELECT r.state
    FROM merge_request_reviews r
    WHERE r.merge_request_id = rr.merge_request_id
      AND r.user_id = rr.user_id
    ORDER BY r.submitted_at DESC
    LIMIT 1
  ) rv ON TRUE
  WHERE rr.merge_request_id = $1::uuid
) latest
WHERE latest.state = 'changes_requested';
