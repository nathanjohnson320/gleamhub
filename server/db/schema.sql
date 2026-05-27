-- Gleamhub schema for squirrel type inference (keep in sync with migrations)

CREATE TABLE users (
  id varchar(255) PRIMARY KEY NOT NULL,
  display_name varchar(255),
  email varchar(255),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug varchar(64) NOT NULL UNIQUE,
  name varchar(255) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE organization_members (
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id varchar(255) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role varchar(32) NOT NULL,
  PRIMARY KEY (organization_id, user_id)
);

CREATE TABLE repositories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name varchar(64) NOT NULL,
  description text,
  disk_path varchar(512) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, name)
);

CREATE TABLE ssh_public_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id varchar(255) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title varchar(255) NOT NULL,
  public_key text NOT NULL,
  key_blob text NOT NULL,
  fingerprint varchar(255) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, fingerprint)
);
