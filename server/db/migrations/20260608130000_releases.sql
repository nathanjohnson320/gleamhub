-- migrate:up
create table releases (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid not null references repositories(id) on delete cascade,
  tag_name varchar(255) not null,
  target_commit_sha varchar(40) not null,
  title varchar(255) not null,
  body text,
  author_user_id varchar(255) not null references users(id),
  created_at timestamptz not null default now(),
  unique (repository_id, tag_name)
);

create index releases_repository_id_idx on releases(repository_id);

-- migrate:down
drop table if exists releases;
