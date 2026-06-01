INSERT INTO pipeline_runs (
  repository_id,
  merge_request_id,
  commit_sha,
  module_path,
  entry_function,
  state,
  trigger
)
VALUES ($1::uuid, $2::uuid, $3, NULLIF($4, ''), $5, $6, $7)
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
