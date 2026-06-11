SELECT COUNT(*)::int AS approval_count
FROM (
  SELECT DISTINCT ON (r.user_id) r.user_id, r.state
  FROM merge_request_reviews r
  WHERE r.merge_request_id = $1::uuid
    AND r.user_id != $2
  ORDER BY r.user_id, r.submitted_at DESC
) latest
WHERE latest.state = 'approved';
