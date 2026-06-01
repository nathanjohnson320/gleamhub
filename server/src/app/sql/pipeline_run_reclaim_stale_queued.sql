UPDATE pipeline_runs
SET
  state = 'failure',
  finished_at = now(),
  log_text = 'No CI worker claimed this job'
WHERE state = 'queued'
  AND created_at < now() - interval '10 minutes';
