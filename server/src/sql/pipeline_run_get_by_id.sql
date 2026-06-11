SELECT
  pr.id::text,
  pr.repository_id::text,
  COALESCE(pr.merge_request_id::text, '') AS merge_request_id,
  pr.commit_sha,
  COALESCE(pr.module_path, '') AS module_path,
  pr.entry_function,
  pr.state,
  pr.trigger,
  COALESCE(pr.log_text, '') AS log_text,
  COALESCE(pr.started_at::text, '') AS started_at,
  COALESCE(pr.finished_at::text, '') AS finished_at,
  pr.created_at::text,
  o.slug AS org_slug,
  r.name AS repo_name,
  r.disk_path
FROM pipeline_runs pr
INNER JOIN repositories r ON r.id = pr.repository_id
INNER JOIN organizations o ON o.id = r.organization_id
WHERE pr.id = $1::uuid;
