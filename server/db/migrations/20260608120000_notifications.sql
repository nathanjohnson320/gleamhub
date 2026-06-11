-- migrate:up
create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id varchar not null references users(id) on delete cascade,
  type varchar not null,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_user_created_idx
  on notifications (user_id, created_at desc);

create index notifications_user_unread_idx
  on notifications (user_id)
  where read_at is null;

-- migrate:down
drop table if exists notifications;
