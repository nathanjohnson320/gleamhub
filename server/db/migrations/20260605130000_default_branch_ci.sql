-- migrate:up
alter table pipeline_runs
  alter column merge_request_id drop not null;

alter table pipeline_runs
  add column branch_name varchar(255);

create index pipeline_runs_repo_branch_created_at_idx
  on pipeline_runs(repository_id, branch_name, created_at desc)
  where branch_name is not null;

-- migrate:down
drop index if exists pipeline_runs_repo_branch_created_at_idx;

alter table pipeline_runs
  drop column if exists branch_name;

delete from pipeline_runs where merge_request_id is null;

alter table pipeline_runs
  alter column merge_request_id set not null;
