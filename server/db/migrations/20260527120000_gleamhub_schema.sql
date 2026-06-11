-- migrate:up
create table users (
  id varchar(255) primary key not null,
  display_name varchar(255),
  email varchar(255),
  created_at timestamptz not null default now()
);

create table organizations (
  id uuid primary key default gen_random_uuid(),
  slug varchar(64) not null unique,
  name varchar(255) not null,
  created_at timestamptz not null default now()
);

create table organization_members (
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id varchar(255) not null references users(id) on delete cascade,
  role varchar(32) not null,
  primary key (organization_id, user_id)
);

create table repositories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name varchar(64) not null,
  description text,
  disk_path varchar(512) not null,
  created_at timestamptz not null default now(),
  unique (organization_id, name)
);

create table ssh_public_keys (
  id uuid primary key default gen_random_uuid(),
  user_id varchar(255) not null references users(id) on delete cascade,
  title varchar(255) not null,
  public_key text not null,
  key_blob text not null,
  fingerprint varchar(255) not null,
  created_at timestamptz not null default now(),
  unique (user_id, fingerprint)
);

create index organization_members_user_id_idx on organization_members(user_id);
create index repositories_organization_id_idx on repositories(organization_id);
create index ssh_public_keys_key_blob_idx on ssh_public_keys(key_blob);

-- migrate:down
drop table if exists ssh_public_keys;
drop table if exists repositories;
drop table if exists organization_members;
drop table if exists organizations;
drop table if exists users;
