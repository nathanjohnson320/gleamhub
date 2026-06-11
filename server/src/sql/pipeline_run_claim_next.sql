UPDATE pipeline_runs pr
SET
  state = 'running',
  started_at = now()
FROM (
  SELECT id
  FROM pipeline_runs
  WHERE state = 'queued'
  ORDER BY created_at
  FOR UPDATE SKIP LOCKED
  LIMIT 1
) picked
WHERE pr.id = picked.id
RETURNING
  pr.id::text,
  pr.repository_id::text,
  COALESCE(pr.merge_request_id::text, '') AS merge_request_id,
  pr.commit_sha,
  COALESCE(pr.module_path, '') AS module_path,
  pr.entry_function,
  pr.state,
  pr.trigger;
