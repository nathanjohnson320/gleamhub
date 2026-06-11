SELECT 1 AS found
FROM pipeline_runs
WHERE repository_id = $1::uuid
  AND branch_name = $2
  AND commit_sha = $3
LIMIT 1;
