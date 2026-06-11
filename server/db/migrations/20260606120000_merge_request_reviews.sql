-- migrate:up
create table merge_request_reviews (
  id uuid primary key default gen_random_uuid(),
  merge_request_id uuid not null references merge_requests(id) on delete cascade,
  user_id varchar(255) not null references users(id) on delete cascade,
  state varchar(32) not null check (state in ('approved', 'changes_requested', 'commented')),
  body text,
  submitted_at timestamptz not null default now()
);

create index merge_request_reviews_merge_request_id_idx
  on merge_request_reviews(merge_request_id);

create index merge_request_reviews_mr_user_submitted_idx
  on merge_request_reviews(merge_request_id, user_id, submitted_at desc);

alter table repositories
  add column required_approvals integer not null default 0;

-- migrate:down
alter table repositories drop column if exists required_approvals;
drop table if exists merge_request_reviews;
