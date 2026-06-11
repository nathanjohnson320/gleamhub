SELECT
  (
    SELECT COUNT(*)::int
    FROM merge_requests mr
    WHERE mr.author_user_id = $1
      AND mr.state = 'open'
  ) AS open_merge_requests,
  (
    SELECT COUNT(*)::int
    FROM merge_requests mr
    WHERE mr.author_user_id = $1
      AND mr.state = 'merged'
  ) AS merged_merge_requests,
  (
    SELECT COUNT(*)::int
    FROM issues i
    WHERE i.author_user_id = $1
      AND i.state = 'open'
  ) AS open_issues_authored,
  (
    SELECT COUNT(*)::int
    FROM issue_assignees ia
    INNER JOIN issues i ON i.id = ia.issue_id
    WHERE ia.user_id = $1
      AND i.state = 'open'
  ) AS open_issues_assigned,
  (
    SELECT COUNT(*)::int
    FROM merge_request_reviews r
    WHERE r.user_id = $1
  ) AS reviews_given;
