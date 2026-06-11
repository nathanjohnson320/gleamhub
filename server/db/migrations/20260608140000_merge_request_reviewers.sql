-- migrate:up
create table merge_request_reviewers (
  merge_request_id uuid not null references merge_requests(id) on delete cascade,
  user_id varchar(255) not null references users(id) on delete cascade,
  requested_by_user_id varchar(255) not null references users(id),
  requested_at timestamptz not null default now(),
  primary key (merge_request_id, user_id)
);

create index merge_request_reviewers_merge_request_id_idx
  on merge_request_reviewers(merge_request_id);

-- migrate:down
drop table if exists merge_request_reviewers;
