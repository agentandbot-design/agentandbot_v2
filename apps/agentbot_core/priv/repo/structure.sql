--
-- PostgreSQL database dump
--

\restrict B2kT1dH6ZEeT1Vqd1h9TXGybZAv1Bii4qOJzbm0pLTqIodsjZNtaJuEbZ7W6BbS

-- Dumped from database version 15.18 (Debian 15.18-1.pgdg13+1)
-- Dumped by pg_dump version 15.18 (Debian 15.18-0+deb12u1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
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
-- Name: agent_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_credentials (
    id bigint NOT NULL,
    agent_id character varying(255) NOT NULL,
    agent_name character varying(255) NOT NULL,
    token_hash character varying(255) NOT NULL,
    public_key character varying(255),
    capabilities character varying(255)[] DEFAULT ARRAY[]::character varying[],
    expires_at timestamp(0) without time zone,
    is_active boolean DEFAULT true,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: agent_credentials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_credentials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_credentials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_credentials_id_seq OWNED BY public.agent_credentials.id;


--
-- Name: approval_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approval_requests (
    id bigint NOT NULL,
    room_id bigint,
    requester_id character varying(255) NOT NULL,
    requester_name character varying(255),
    title character varying(255) NOT NULL,
    description text,
    status character varying(255) DEFAULT 'pending'::character varying,
    resolved_by character varying(255),
    resolution_note text,
    expires_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: approval_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.approval_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: approval_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.approval_requests_id_seq OWNED BY public.approval_requests.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id bigint NOT NULL,
    room_id bigint NOT NULL,
    sender_id character varying(255) NOT NULL,
    sender_name character varying(255),
    content text NOT NULL,
    message_type character varying(255) DEFAULT 'text'::character varying,
    event_type character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: rooms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rooms (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    room_type character varying(255) DEFAULT 'general'::character varying,
    max_agents integer DEFAULT 50,
    is_active boolean DEFAULT true,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: rooms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rooms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rooms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rooms_id_seq OWNED BY public.rooms.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: agent_credentials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_credentials ALTER COLUMN id SET DEFAULT nextval('public.agent_credentials_id_seq'::regclass);


--
-- Name: approval_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_requests ALTER COLUMN id SET DEFAULT nextval('public.approval_requests_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: rooms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rooms ALTER COLUMN id SET DEFAULT nextval('public.rooms_id_seq'::regclass);


--
-- Name: agent_credentials agent_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_credentials
    ADD CONSTRAINT agent_credentials_pkey PRIMARY KEY (id);


--
-- Name: approval_requests approval_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: rooms rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: agent_credentials_agent_id_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX agent_credentials_agent_id_is_active_index ON public.agent_credentials USING btree (agent_id, is_active);


--
-- Name: agent_credentials_token_hash_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX agent_credentials_token_hash_index ON public.agent_credentials USING btree (token_hash);


--
-- Name: approval_requests_requester_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approval_requests_requester_id_index ON public.approval_requests USING btree (requester_id);


--
-- Name: approval_requests_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approval_requests_status_index ON public.approval_requests USING btree (status);


--
-- Name: messages_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_inserted_at_index ON public.messages USING btree (inserted_at);


--
-- Name: messages_room_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_room_id_index ON public.messages USING btree (room_id);


--
-- Name: messages_sender_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_sender_id_index ON public.messages USING btree (sender_id);


--
-- Name: rooms_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rooms_is_active_index ON public.rooms USING btree (is_active);


--
-- Name: rooms_room_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rooms_room_type_index ON public.rooms USING btree (room_type);


--
-- Name: approval_requests approval_requests_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE SET NULL;


--
-- Name: messages messages_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict B2kT1dH6ZEeT1Vqd1h9TXGybZAv1Bii4qOJzbm0pLTqIodsjZNtaJuEbZ7W6BbS

INSERT INTO public."schema_migrations" (version) VALUES (20260806000001);
INSERT INTO public."schema_migrations" (version) VALUES (20260806000002);
INSERT INTO public."schema_migrations" (version) VALUES (20260806000003);
INSERT INTO public."schema_migrations" (version) VALUES (20260806000004);
