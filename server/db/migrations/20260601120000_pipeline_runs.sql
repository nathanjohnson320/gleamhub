-- migrate:up
create table pipeline_runs (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid not null references repositories(id) on delete cascade,
  merge_request_id uuid not null references merge_requests(id) on delete cascade,
  commit_sha varchar(40) not null,
  module_path varchar(255),
  entry_function varchar(64) not null default 'ci',
  state varchar(32) not null,
  trigger varchar(32) not null,
  log_text text,
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default now()
);

create index pipeline_runs_merge_request_id_created_at_idx
  on pipeline_runs(merge_request_id, created_at desc);

create index pipeline_runs_state_created_at_idx
  on pipeline_runs(state, created_at)
  where state = 'queued';

-- migrate:down
drop table if exists pipeline_runs;
