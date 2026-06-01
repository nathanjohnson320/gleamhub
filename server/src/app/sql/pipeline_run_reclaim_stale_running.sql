UPDATE pipeline_runs
SET
  state = 'failure',
  finished_at = now(),
  log_text = CASE
    WHEN COALESCE(log_text, '') = '' THEN 'CI job timed out or worker stopped'
    ELSE log_text
  END
WHERE state = 'running'
  AND started_at < now() - interval '5 minutes';
