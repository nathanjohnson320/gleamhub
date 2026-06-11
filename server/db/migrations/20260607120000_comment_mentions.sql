-- migrate:up
alter table merge_request_comments
  add column mentioned_user_ids jsonb not null default '[]';

alter table issue_comments
  add column mentioned_user_ids jsonb not null default '[]';

-- migrate:down
alter table merge_request_comments drop column if exists mentioned_user_ids;
alter table issue_comments drop column if exists mentioned_user_ids;
