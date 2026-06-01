SELECT pr.id::text
FROM pipeline_runs pr
WHERE pr.merge_request_id = $1::uuid
  AND pr.commit_sha = $2
LIMIT 1;
