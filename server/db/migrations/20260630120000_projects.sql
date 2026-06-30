-- migrate:up
create table projects (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  number int not null,
  title varchar(255) not null,
  description text,
  state varchar(32) not null default 'open',
  created_by_user_id varchar(255) not null references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, number)
);

create table project_columns (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  name varchar(255) not null,
  position int not null,
  unique (project_id, position)
);

create table project_items (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  column_id uuid not null references project_columns(id) on delete cascade,
  position int not null,
  item_type varchar(32) not null,
  repository_id uuid not null references repositories(id) on delete cascade,
  item_number int not null,
  created_at timestamptz not null default now(),
  unique (project_id, item_type, repository_id, item_number)
);

create index projects_organization_id_idx on projects(organization_id);
create index project_columns_project_id_idx on project_columns(project_id);
create index project_items_project_id_idx on project_items(project_id);
create index project_items_column_id_idx on project_items(column_id);
create index project_items_repository_id_idx on project_items(repository_id);

-- migrate:down
drop index if exists project_items_repository_id_idx;
drop index if exists project_items_column_id_idx;
drop index if exists project_items_project_id_idx;
drop index if exists project_columns_project_id_idx;
drop index if exists projects_organization_id_idx;
drop table if exists project_items;
drop table if exists project_columns;
drop table if exists projects;
