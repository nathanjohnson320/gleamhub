UPDATE pipeline_runs
SET
  state = $2::varchar,
  log_text = NULLIF($3, ''),
  finished_at = CASE
    WHEN $2::varchar IN ('success', 'failure', 'cancelled', 'skipped') THEN now()
    ELSE finished_at
  END
WHERE id = $1::uuid
RETURNING
  id::text,
  repository_id::text,
  merge_request_id::text,
  commit_sha,
  COALESCE(module_path, '') AS module_path,
  entry_function,
  state,
  trigger,
  COALESCE(log_text, '') AS log_text,
  COALESCE(started_at::text, '') AS started_at,
  COALESCE(finished_at::text, '') AS finished_at,
  created_at::text;
