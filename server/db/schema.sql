\restrict CE1xDmhKrnwa6gSpsfn1GJ2RxYm2fWuvCDc4dDtSVyCWuJCGw3Tgv7bXw5cfOMk

-- Dumped from database version 16.14
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: issue_assignees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.issue_assignees (
    issue_id uuid NOT NULL,
    user_id character varying(255) NOT NULL
);


--
-- Name: issue_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.issue_comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    issue_id uuid NOT NULL,
    author_user_id character varying(255) NOT NULL,
    body text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    mentioned_user_ids jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: issue_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.issue_labels (
    issue_id uuid NOT NULL,
    label_id uuid NOT NULL
);


--
-- Name: issue_merge_request_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.issue_merge_request_links (
    issue_id uuid NOT NULL,
    merge_request_id uuid NOT NULL,
    link_type character varying(32) DEFAULT 'closes'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: issues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.issues (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    repository_id uuid NOT NULL,
    number integer NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    author_user_id character varying(255) NOT NULL,
    state character varying(32) NOT NULL,
    closed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    milestone_id uuid
);


--
-- Name: items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.items (
    id character varying(64) NOT NULL,
    title character varying(255) NOT NULL,
    status character varying(255) NOT NULL
);


--
-- Name: merge_request_assignees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.merge_request_assignees (
    merge_request_id uuid NOT NULL,
    user_id character varying(255) NOT NULL
);


--
-- Name: merge_request_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.merge_request_comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    merge_request_id uuid NOT NULL,
    author_user_id character varying(255) NOT NULL,
    body text NOT NULL,
    file_path character varying(1024),
    line integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    mentioned_user_ids jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: merge_request_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.merge_request_labels (
    merge_request_id uuid NOT NULL,
    label_id uuid NOT NULL
);


--
-- Name: merge_request_reviewers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.merge_request_reviewers (
    merge_request_id uuid NOT NULL,
    user_id character varying(255) NOT NULL,
    requested_by_user_id character varying(255) NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: merge_request_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.merge_request_reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    merge_request_id uuid NOT NULL,
    user_id character varying(255) NOT NULL,
    state character varying(32) NOT NULL,
    body text,
    submitted_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT merge_request_reviews_state_check CHECK (((state)::text = ANY ((ARRAY['approved'::character varying, 'changes_requested'::character varying, 'commented'::character varying])::text[])))
);


--
-- Name: merge_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.merge_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    repository_id uuid NOT NULL,
    number integer NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    author_user_id character varying(255) NOT NULL,
    source_branch character varying(255) NOT NULL,
    target_branch character varying(255) NOT NULL,
    state character varying(32) NOT NULL,
    merge_commit_sha character varying(40),
    merged_by_user_id character varying(255),
    merged_at timestamp with time zone,
    closed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_draft boolean DEFAULT false NOT NULL
);


--
-- Name: milestones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.milestones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    repository_id uuid NOT NULL,
    number integer NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    state character varying(32) DEFAULT 'open'::character varying NOT NULL,
    due_on date,
    closed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id character varying NOT NULL,
    type character varying NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: organization_invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organization_invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    invited_user_id character varying(255) NOT NULL,
    role character varying(32) DEFAULT 'member'::character varying NOT NULL,
    invited_by_user_id character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: organization_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organization_members (
    organization_id uuid NOT NULL,
    user_id character varying(255) NOT NULL,
    role character varying(32) NOT NULL
);


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug character varying(64) NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pipeline_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    repository_id uuid NOT NULL,
    merge_request_id uuid,
    commit_sha character varying(40) NOT NULL,
    module_path character varying(255),
    entry_function character varying(64) DEFAULT 'ci'::character varying NOT NULL,
    state character varying(32) NOT NULL,
    trigger character varying(32) NOT NULL,
    log_text text,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    branch_name character varying(255)
);


--
-- Name: project_columns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_columns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    "position" integer NOT NULL
);


--
-- Name: project_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    column_id uuid NOT NULL,
    "position" integer NOT NULL,
    item_type character varying(32) NOT NULL,
    repository_id uuid NOT NULL,
    item_number integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    number integer NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    state character varying(32) DEFAULT 'open'::character varying NOT NULL,
    created_by_user_id character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: protected_branches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.protected_branches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    repository_id uuid NOT NULL,
    branch_name character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: releases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.releases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    repository_id uuid NOT NULL,
    tag_name character varying(255) NOT NULL,
    target_commit_sha character varying(40) NOT NULL,
    title character varying(255) NOT NULL,
    body text,
    author_user_id character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: repositories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.repositories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name character varying(64) NOT NULL,
    description text,
    disk_path character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    required_approvals integer DEFAULT 0 NOT NULL
);


--
-- Name: repository_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.repository_labels (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    repository_id uuid NOT NULL,
    name character varying(50) NOT NULL,
    color character varying(7) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying(128) NOT NULL
);


--
-- Name: ssh_public_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ssh_public_keys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id character varying(255) NOT NULL,
    title character varying(255) NOT NULL,
    public_key text NOT NULL,
    key_blob text NOT NULL,
    fingerprint character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id character varying(255) NOT NULL,
    display_name character varying(255),
    email character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: issue_assignees issue_assignees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issue_assignees
    ADD CONSTRAINT issue_assignees_pkey PRIMARY KEY (issue_id, user_id);


--
-- Name: issue_comments issue_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issue_comments
    ADD CONSTRAINT issue_comments_pkey PRIMARY KEY (id);


--
-- Name: issue_labels issue_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issue_labels
    ADD CONSTRAINT issue_labels_pkey PRIMARY KEY (issue_id, label_id);


--
-- Name: issue_merge_request_links issue_merge_request_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issue_merge_request_links
    ADD CONSTRAINT issue_merge_request_links_pkey PRIMARY KEY (issue_id, merge_request_id);


--
-- Name: issues issues_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issues
    ADD CONSTRAINT issues_pkey PRIMARY KEY (id);


--
-- Name: issues issues_repository_id_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issues
    ADD CONSTRAINT issues_repository_id_number_key UNIQUE (repository_id, number);


--
-- Name: items items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_pkey PRIMARY KEY (id);


--
-- Name: merge_request_assignees merge_request_assignees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_assignees
    ADD CONSTRAINT merge_request_assignees_pkey PRIMARY KEY (merge_request_id, user_id);


--
-- Name: merge_request_comments merge_request_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_comments
    ADD CONSTRAINT merge_request_comments_pkey PRIMARY KEY (id);


--
-- Name: merge_request_labels merge_request_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_labels
    ADD CONSTRAINT merge_request_labels_pkey PRIMARY KEY (merge_request_id, label_id);


--
-- Name: merge_request_reviewers merge_request_reviewers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_reviewers
    ADD CONSTRAINT merge_request_reviewers_pkey PRIMARY KEY (merge_request_id, user_id);


--
-- Name: merge_request_reviews merge_request_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_reviews
    ADD CONSTRAINT merge_request_reviews_pkey PRIMARY KEY (id);


--
-- Name: merge_requests merge_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_requests
    ADD CONSTRAINT merge_requests_pkey PRIMARY KEY (id);


--
-- Name: merge_requests merge_requests_repository_id_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_requests
    ADD CONSTRAINT merge_requests_repository_id_number_key UNIQUE (repository_id, number);


--
-- Name: milestones milestones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.milestones
    ADD CONSTRAINT milestones_pkey PRIMARY KEY (id);


--
-- Name: milestones milestones_repository_id_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.milestones
    ADD CONSTRAINT milestones_repository_id_number_key UNIQUE (repository_id, number);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: organization_invitations organization_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_invitations
    ADD CONSTRAINT organization_invitations_pkey PRIMARY KEY (id);


--
-- Name: organization_members organization_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_members
    ADD CONSTRAINT organization_members_pkey PRIMARY KEY (organization_id, user_id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_slug_key UNIQUE (slug);


--
-- Name: pipeline_runs pipeline_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_runs
    ADD CONSTRAINT pipeline_runs_pkey PRIMARY KEY (id);


--
-- Name: project_columns project_columns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_columns
    ADD CONSTRAINT project_columns_pkey PRIMARY KEY (id);


--
-- Name: project_columns project_columns_project_id_position_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_columns
    ADD CONSTRAINT project_columns_project_id_position_key UNIQUE (project_id, "position");


--
-- Name: project_items project_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_items
    ADD CONSTRAINT project_items_pkey PRIMARY KEY (id);


--
-- Name: project_items project_items_project_id_item_type_repository_id_item_numbe_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_items
    ADD CONSTRAINT project_items_project_id_item_type_repository_id_item_numbe_key UNIQUE (project_id, item_type, repository_id, item_number);


--
-- Name: projects projects_organization_id_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_organization_id_number_key UNIQUE (organization_id, number);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: protected_branches protected_branches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.protected_branches
    ADD CONSTRAINT protected_branches_pkey PRIMARY KEY (id);


--
-- Name: protected_branches protected_branches_repository_id_branch_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.protected_branches
    ADD CONSTRAINT protected_branches_repository_id_branch_name_key UNIQUE (repository_id, branch_name);


--
-- Name: releases releases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.releases
    ADD CONSTRAINT releases_pkey PRIMARY KEY (id);


--
-- Name: releases releases_repository_id_tag_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.releases
    ADD CONSTRAINT releases_repository_id_tag_name_key UNIQUE (repository_id, tag_name);


--
-- Name: repositories repositories_organization_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_organization_id_name_key UNIQUE (organization_id, name);


--
-- Name: repositories repositories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_pkey PRIMARY KEY (id);


--
-- Name: repository_labels repository_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repository_labels
    ADD CONSTRAINT repository_labels_pkey PRIMARY KEY (id);


--
-- Name: repository_labels repository_labels_repository_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repository_labels
    ADD CONSTRAINT repository_labels_repository_id_name_key UNIQUE (repository_id, name);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: ssh_public_keys ssh_public_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ssh_public_keys
    ADD CONSTRAINT ssh_public_keys_pkey PRIMARY KEY (id);


--
-- Name: ssh_public_keys ssh_public_keys_user_id_fingerprint_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ssh_public_keys
    ADD CONSTRAINT ssh_public_keys_user_id_fingerprint_key UNIQUE (user_id, fingerprint);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: issue_assignees_issue_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issue_assignees_issue_id_idx ON public.issue_assignees USING btree (issue_id);


--
-- Name: issue_comments_issue_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issue_comments_issue_id_idx ON public.issue_comments USING btree (issue_id);


--
-- Name: issue_labels_issue_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issue_labels_issue_id_idx ON public.issue_labels USING btree (issue_id);


--
-- Name: issue_merge_request_links_mr_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issue_merge_request_links_mr_id_idx ON public.issue_merge_request_links USING btree (merge_request_id);


--
-- Name: issues_milestone_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issues_milestone_id_idx ON public.issues USING btree (milestone_id);


--
-- Name: issues_repository_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issues_repository_id_idx ON public.issues USING btree (repository_id);


--
-- Name: issues_state_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issues_state_idx ON public.issues USING btree (repository_id, state);


--
-- Name: merge_request_assignees_merge_request_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX merge_request_assignees_merge_request_id_idx ON public.merge_request_assignees USING btree (merge_request_id);


--
-- Name: merge_request_comments_mr_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX merge_request_comments_mr_id_idx ON public.merge_request_comments USING btree (merge_request_id);


--
-- Name: merge_request_labels_merge_request_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX merge_request_labels_merge_request_id_idx ON public.merge_request_labels USING btree (merge_request_id);


--
-- Name: merge_request_reviewers_merge_request_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX merge_request_reviewers_merge_request_id_idx ON public.merge_request_reviewers USING btree (merge_request_id);


--
-- Name: merge_request_reviews_merge_request_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX merge_request_reviews_merge_request_id_idx ON public.merge_request_reviews USING btree (merge_request_id);


--
-- Name: merge_request_reviews_mr_user_submitted_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX merge_request_reviews_mr_user_submitted_idx ON public.merge_request_reviews USING btree (merge_request_id, user_id, submitted_at DESC);


--
-- Name: merge_requests_repository_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX merge_requests_repository_id_idx ON public.merge_requests USING btree (repository_id);


--
-- Name: merge_requests_state_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX merge_requests_state_idx ON public.merge_requests USING btree (repository_id, state);


--
-- Name: notifications_user_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_user_created_idx ON public.notifications USING btree (user_id, created_at DESC);


--
-- Name: notifications_user_unread_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_user_unread_idx ON public.notifications USING btree (user_id) WHERE (read_at IS NULL);


--
-- Name: organization_invitations_invited_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organization_invitations_invited_user_id_idx ON public.organization_invitations USING btree (invited_user_id);


--
-- Name: organization_invitations_org_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX organization_invitations_org_user_idx ON public.organization_invitations USING btree (organization_id, invited_user_id);


--
-- Name: organization_members_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organization_members_user_id_idx ON public.organization_members USING btree (user_id);


--
-- Name: pipeline_runs_merge_request_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pipeline_runs_merge_request_id_created_at_idx ON public.pipeline_runs USING btree (merge_request_id, created_at DESC);


--
-- Name: pipeline_runs_repo_branch_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pipeline_runs_repo_branch_created_at_idx ON public.pipeline_runs USING btree (repository_id, branch_name, created_at DESC) WHERE (branch_name IS NOT NULL);


--
-- Name: pipeline_runs_state_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pipeline_runs_state_created_at_idx ON public.pipeline_runs USING btree (state, created_at) WHERE ((state)::text = 'queued'::text);


--
-- Name: project_columns_project_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_columns_project_id_idx ON public.project_columns USING btree (project_id);


--
-- Name: project_items_column_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_items_column_id_idx ON public.project_items USING btree (column_id);


--
-- Name: project_items_project_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_items_project_id_idx ON public.project_items USING btree (project_id);


--
-- Name: project_items_repository_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_items_repository_id_idx ON public.project_items USING btree (repository_id);


--
-- Name: projects_organization_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_organization_id_idx ON public.projects USING btree (organization_id);


--
-- Name: protected_branches_repository_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX protected_branches_repository_id_idx ON public.protected_branches USING btree (repository_id);


--
-- Name: releases_repository_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX releases_repository_id_idx ON public.releases USING btree (repository_id);


--
-- Name: repositories_organization_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX repositories_organization_id_idx ON public.repositories USING btree (organization_id);


--
-- Name: repository_labels_repository_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX repository_labels_repository_id_idx ON public.repository_labels USING btree (repository_id);


--
-- Name: ssh_public_keys_key_blob_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ssh_public_keys_key_blob_idx ON public.ssh_public_keys USING btree (key_blob);


--
-- Name: issue_assignees issue_assignees_issue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issue_assignees
    ADD CONSTRAINT issue_assignees_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES public.issues(id) ON DELETE CASCADE;


--
-- Name: issue_assignees issue_assignees_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issue_assignees
    ADD CONSTRAINT issue_assignees_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: issue_comments issue_comments_author_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issue_comments
    ADD CONSTRAINT issue_comments_author_user_id_fkey FOREIGN KEY (author_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: issue_comments issue_comments_issue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issue_comments
    ADD CONSTRAINT issue_comments_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES public.issues(id) ON DELETE CASCADE;


--
-- Name: issue_labels issue_labels_issue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issue_labels
    ADD CONSTRAINT issue_labels_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES public.issues(id) ON DELETE CASCADE;


--
-- Name: issue_labels issue_labels_label_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issue_labels
    ADD CONSTRAINT issue_labels_label_id_fkey FOREIGN KEY (label_id) REFERENCES public.repository_labels(id) ON DELETE CASCADE;


--
-- Name: issue_merge_request_links issue_merge_request_links_issue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issue_merge_request_links
    ADD CONSTRAINT issue_merge_request_links_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES public.issues(id) ON DELETE CASCADE;


--
-- Name: issue_merge_request_links issue_merge_request_links_merge_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issue_merge_request_links
    ADD CONSTRAINT issue_merge_request_links_merge_request_id_fkey FOREIGN KEY (merge_request_id) REFERENCES public.merge_requests(id) ON DELETE CASCADE;


--
-- Name: issues issues_author_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issues
    ADD CONSTRAINT issues_author_user_id_fkey FOREIGN KEY (author_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: issues issues_milestone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issues
    ADD CONSTRAINT issues_milestone_id_fkey FOREIGN KEY (milestone_id) REFERENCES public.milestones(id) ON DELETE SET NULL;


--
-- Name: issues issues_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issues
    ADD CONSTRAINT issues_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id) ON DELETE CASCADE;


--
-- Name: merge_request_assignees merge_request_assignees_merge_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_assignees
    ADD CONSTRAINT merge_request_assignees_merge_request_id_fkey FOREIGN KEY (merge_request_id) REFERENCES public.merge_requests(id) ON DELETE CASCADE;


--
-- Name: merge_request_assignees merge_request_assignees_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_assignees
    ADD CONSTRAINT merge_request_assignees_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: merge_request_comments merge_request_comments_author_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_comments
    ADD CONSTRAINT merge_request_comments_author_user_id_fkey FOREIGN KEY (author_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: merge_request_comments merge_request_comments_merge_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_comments
    ADD CONSTRAINT merge_request_comments_merge_request_id_fkey FOREIGN KEY (merge_request_id) REFERENCES public.merge_requests(id) ON DELETE CASCADE;


--
-- Name: merge_request_labels merge_request_labels_label_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_labels
    ADD CONSTRAINT merge_request_labels_label_id_fkey FOREIGN KEY (label_id) REFERENCES public.repository_labels(id) ON DELETE CASCADE;


--
-- Name: merge_request_labels merge_request_labels_merge_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_labels
    ADD CONSTRAINT merge_request_labels_merge_request_id_fkey FOREIGN KEY (merge_request_id) REFERENCES public.merge_requests(id) ON DELETE CASCADE;


--
-- Name: merge_request_reviewers merge_request_reviewers_merge_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_reviewers
    ADD CONSTRAINT merge_request_reviewers_merge_request_id_fkey FOREIGN KEY (merge_request_id) REFERENCES public.merge_requests(id) ON DELETE CASCADE;


--
-- Name: merge_request_reviewers merge_request_reviewers_requested_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_reviewers
    ADD CONSTRAINT merge_request_reviewers_requested_by_user_id_fkey FOREIGN KEY (requested_by_user_id) REFERENCES public.users(id);


--
-- Name: merge_request_reviewers merge_request_reviewers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_reviewers
    ADD CONSTRAINT merge_request_reviewers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: merge_request_reviews merge_request_reviews_merge_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_reviews
    ADD CONSTRAINT merge_request_reviews_merge_request_id_fkey FOREIGN KEY (merge_request_id) REFERENCES public.merge_requests(id) ON DELETE CASCADE;


--
-- Name: merge_request_reviews merge_request_reviews_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_reviews
    ADD CONSTRAINT merge_request_reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: merge_requests merge_requests_author_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_requests
    ADD CONSTRAINT merge_requests_author_user_id_fkey FOREIGN KEY (author_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: merge_requests merge_requests_merged_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_requests
    ADD CONSTRAINT merge_requests_merged_by_user_id_fkey FOREIGN KEY (merged_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: merge_requests merge_requests_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_requests
    ADD CONSTRAINT merge_requests_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id) ON DELETE CASCADE;


--
-- Name: milestones milestones_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.milestones
    ADD CONSTRAINT milestones_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: organization_invitations organization_invitations_invited_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_invitations
    ADD CONSTRAINT organization_invitations_invited_by_user_id_fkey FOREIGN KEY (invited_by_user_id) REFERENCES public.users(id);


--
-- Name: organization_invitations organization_invitations_invited_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_invitations
    ADD CONSTRAINT organization_invitations_invited_user_id_fkey FOREIGN KEY (invited_user_id) REFERENCES public.users(id);


--
-- Name: organization_invitations organization_invitations_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_invitations
    ADD CONSTRAINT organization_invitations_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: organization_members organization_members_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_members
    ADD CONSTRAINT organization_members_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: organization_members organization_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_members
    ADD CONSTRAINT organization_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: pipeline_runs pipeline_runs_merge_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_runs
    ADD CONSTRAINT pipeline_runs_merge_request_id_fkey FOREIGN KEY (merge_request_id) REFERENCES public.merge_requests(id) ON DELETE CASCADE;


--
-- Name: pipeline_runs pipeline_runs_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_runs
    ADD CONSTRAINT pipeline_runs_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id) ON DELETE CASCADE;


--
-- Name: project_columns project_columns_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_columns
    ADD CONSTRAINT project_columns_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_items project_items_column_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_items
    ADD CONSTRAINT project_items_column_id_fkey FOREIGN KEY (column_id) REFERENCES public.project_columns(id) ON DELETE CASCADE;


--
-- Name: project_items project_items_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_items
    ADD CONSTRAINT project_items_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_items project_items_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_items
    ADD CONSTRAINT project_items_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id) ON DELETE CASCADE;


--
-- Name: projects projects_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: projects projects_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: protected_branches protected_branches_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.protected_branches
    ADD CONSTRAINT protected_branches_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id) ON DELETE CASCADE;


--
-- Name: releases releases_author_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.releases
    ADD CONSTRAINT releases_author_user_id_fkey FOREIGN KEY (author_user_id) REFERENCES public.users(id);


--
-- Name: releases releases_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.releases
    ADD CONSTRAINT releases_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id) ON DELETE CASCADE;


--
-- Name: repositories repositories_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: repository_labels repository_labels_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repository_labels
    ADD CONSTRAINT repository_labels_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id) ON DELETE CASCADE;


--
-- Name: ssh_public_keys ssh_public_keys_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ssh_public_keys
    ADD CONSTRAINT ssh_public_keys_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict CE1xDmhKrnwa6gSpsfn1GJ2RxYm2fWuvCDc4dDtSVyCWuJCGw3Tgv7bXw5cfOMk


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20240511203036'),
    ('20260527120000'),
    ('20260528120000'),
    ('20260529120000'),
    ('20260529130000'),
    ('20260601120000'),
    ('20260603120000'),
    ('20260604120000'),
    ('20260604130000'),
    ('20260605120000'),
    ('20260605130000'),
    ('20260606120000'),
    ('20260607120000'),
    ('20260608120000'),
    ('20260608130000'),
    ('20260608140000'),
    ('20260610120000'),
    ('20260610140000'),
    ('20260630120000');
