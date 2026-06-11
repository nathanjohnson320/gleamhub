-- migrate:up
create table issue_merge_request_links (
  issue_id uuid not null references issues(id) on delete cascade,
  merge_request_id uuid not null references merge_requests(id) on delete cascade,
  link_type varchar(32) not null default 'closes',
  created_at timestamptz not null default now(),
  primary key (issue_id, merge_request_id)
);

create index issue_merge_request_links_mr_id_idx on issue_merge_request_links(merge_request_id);

-- migrate:down
drop table if exists issue_merge_request_links;
