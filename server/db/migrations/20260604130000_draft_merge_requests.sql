-- migrate:up
alter table merge_requests add column is_draft boolean not null default false;

-- migrate:down
alter table merge_requests drop column if exists is_draft;
