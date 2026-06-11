-- migrate:up
create table issues (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid not null references repositories(id) on delete cascade,
  number int not null,
  title varchar(255) not null,
  description text,
  author_user_id varchar(255) not null references users(id) on delete cascade,
  state varchar(32) not null,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (repository_id, number)
);

create table issue_comments (
  id uuid primary key default gen_random_uuid(),
  issue_id uuid not null references issues(id) on delete cascade,
  author_user_id varchar(255) not null references users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index issues_repository_id_idx on issues(repository_id);
create index issues_state_idx on issues(repository_id, state);
create index issue_comments_issue_id_idx on issue_comments(issue_id);

-- migrate:down
drop table if exists issue_comments;
drop table if exists issues;
