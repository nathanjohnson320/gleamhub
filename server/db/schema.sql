\restrict lu5vKGILaSaBMVu4ZFHp2IeNSxy12z9lgyQZMAOhv2hFICFkH7Xl08KnAb7EKex

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
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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
-- Name: protected_branches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.protected_branches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    repository_id uuid NOT NULL,
    branch_name character varying(255) NOT NULL,
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
-- Name: merge_request_comments merge_request_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_request_comments
    ADD CONSTRAINT merge_request_comments_pkey PRIMARY KEY (id);


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
-- Name: merge_request_comments_mr_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX merge_request_comments_mr_id_idx ON public.merge_request_comments USING btree (merge_request_id);


--
-- Name: merge_requests_repository_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX merge_requests_repository_id_idx ON public.merge_requests USING btree (repository_id);


--
-- Name: merge_requests_state_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX merge_requests_state_idx ON public.merge_requests USING btree (repository_id, state);


--
-- Name: organization_members_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organization_members_user_id_idx ON public.organization_members USING btree (user_id);


--
-- Name: protected_branches_repository_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX protected_branches_repository_id_idx ON public.protected_branches USING btree (repository_id);


--
-- Name: repositories_organization_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX repositories_organization_id_idx ON public.repositories USING btree (organization_id);


--
-- Name: ssh_public_keys_key_blob_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ssh_public_keys_key_blob_idx ON public.ssh_public_keys USING btree (key_blob);


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
-- Name: protected_branches protected_branches_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.protected_branches
    ADD CONSTRAINT protected_branches_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id) ON DELETE CASCADE;


--
-- Name: repositories repositories_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: ssh_public_keys ssh_public_keys_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ssh_public_keys
    ADD CONSTRAINT ssh_public_keys_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict lu5vKGILaSaBMVu4ZFHp2IeNSxy12z9lgyQZMAOhv2hFICFkH7Xl08KnAb7EKex


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20260527120000'),
    ('20260528120000'),
    ('20260529120000');
