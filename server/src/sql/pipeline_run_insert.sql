INSERT INTO pipeline_runs (
  repository_id,
  merge_request_id,
  branch_name,
  commit_sha,
  module_path,
  entry_function,
  state,
  trigger
)
VALUES (
  $1::uuid,
  NULLIF($2, '')::uuid,
  NULLIF($3, ''),
  $4,
  NULLIF($5, ''),
  $6,
  $7,
  $8
)
RETURNING
  id::text,
  repository_id::text,
  COALESCE(merge_request_id::text, '') AS merge_request_id,
  COALESCE(branch_name, '') AS branch_name,
  commit_sha,
  COALESCE(module_path, '') AS module_path,
  entry_function,
  state,
  trigger,
  COALESCE(log_text, '') AS log_text,
  COALESCE(started_at::text, '') AS started_at,
  COALESCE(finished_at::text, '') AS finished_at,
  created_at::text;
