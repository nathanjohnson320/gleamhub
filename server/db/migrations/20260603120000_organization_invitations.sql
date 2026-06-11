-- migrate:up
create table organization_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  invited_user_id varchar(255) not null references users(id),
  role varchar(32) not null default 'member',
  invited_by_user_id varchar(255) not null references users(id),
  created_at timestamptz not null default now()
);

create unique index organization_invitations_org_user_idx
  on organization_invitations (organization_id, invited_user_id);

create index organization_invitations_invited_user_id_idx
  on organization_invitations (invited_user_id);

-- migrate:down
drop table if exists organization_invitations;
