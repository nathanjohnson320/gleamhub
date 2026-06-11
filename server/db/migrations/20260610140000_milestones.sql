-- migrate:up
create table milestones (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid not null references repositories(id) on delete cascade,
  number int not null,
  title varchar(255) not null,
  description text,
  state varchar(32) not null default 'open',
  due_on date,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (repository_id, number)
);

alter table issues add column milestone_id uuid references milestones(id) on delete set null;
create index issues_milestone_id_idx on issues(milestone_id);

-- migrate:down
drop index if exists issues_milestone_id_idx;
alter table issues drop column if exists milestone_id;
drop table if exists milestones;
