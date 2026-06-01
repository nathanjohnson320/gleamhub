SELECT
  pr.id::text,
  pr.repository_id::text,
  pr.merge_request_id::text,
  pr.commit_sha,
  COALESCE(pr.module_path, '') AS module_path,
  pr.entry_function,
  pr.state,
  pr.trigger,
  COALESCE(pr.log_text, '') AS log_text,
  COALESCE(pr.started_at::text, '') AS started_at,
  COALESCE(pr.finished_at::text, '') AS finished_at,
  pr.created_at::text
FROM pipeline_runs pr
WHERE pr.merge_request_id = $1::uuid
ORDER BY pr.created_at DESC
LIMIT 1;
