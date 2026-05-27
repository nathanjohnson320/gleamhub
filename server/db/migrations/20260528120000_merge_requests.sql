-- migrate:up
create table merge_requests (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid not null references repositories(id) on delete cascade,
  number int not null,
  title varchar(255) not null,
  description text,
  author_user_id varchar(255) not null references users(id) on delete cascade,
  source_branch varchar(255) not null,
  target_branch varchar(255) not null,
  state varchar(32) not null,
  merge_commit_sha varchar(40),
  merged_by_user_id varchar(255) references users(id) on delete set null,
  merged_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (repository_id, number)
);

create table merge_request_comments (
  id uuid primary key default gen_random_uuid(),
  merge_request_id uuid not null references merge_requests(id) on delete cascade,
  author_user_id varchar(255) not null references users(id) on delete cascade,
  body text not null,
  file_path varchar(1024),
  line int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index merge_requests_repository_id_idx on merge_requests(repository_id);
create index merge_requests_state_idx on merge_requests(repository_id, state);
create index merge_request_comments_mr_id_idx on merge_request_comments(merge_request_id);

-- migrate:down
drop table if exists merge_request_comments;
drop table if exists merge_requests;
