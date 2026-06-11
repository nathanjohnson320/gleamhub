-- migrate:up
create table protected_branches (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid not null references repositories(id) on delete cascade,
  branch_name varchar(255) not null,
  created_at timestamptz not null default now(),
  unique (repository_id, branch_name)
);

create index protected_branches_repository_id_idx on protected_branches(repository_id);

-- migrate:down
drop table if exists protected_branches;
