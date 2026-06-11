-- migrate:up
create table repository_labels (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid not null references repositories(id) on delete cascade,
  name varchar(50) not null,
  color varchar(7) not null,
  created_at timestamptz not null default now(),
  unique (repository_id, name)
);

create table issue_labels (
  issue_id uuid not null references issues(id) on delete cascade,
  label_id uuid not null references repository_labels(id) on delete cascade,
  primary key (issue_id, label_id)
);

create table issue_assignees (
  issue_id uuid not null references issues(id) on delete cascade,
  user_id varchar(255) not null references users(id) on delete cascade,
  primary key (issue_id, user_id)
);

create table merge_request_labels (
  merge_request_id uuid not null references merge_requests(id) on delete cascade,
  label_id uuid not null references repository_labels(id) on delete cascade,
  primary key (merge_request_id, label_id)
);

create index repository_labels_repository_id_idx on repository_labels(repository_id);
create index issue_labels_issue_id_idx on issue_labels(issue_id);
create index issue_assignees_issue_id_idx on issue_assignees(issue_id);
create index merge_request_labels_merge_request_id_idx on merge_request_labels(merge_request_id);

-- migrate:down
drop table if exists merge_request_labels;
drop table if exists issue_assignees;
drop table if exists issue_labels;
drop table if exists repository_labels;
