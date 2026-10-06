-- Shell Space initial schema (Charter Rev 2 §9, with the approved workspace_id deviation).
-- Roles:
--   migration/owner role  : owns the tables and the SECURITY DEFINER helpers (runs this file)
--   shellspace_app (login): used by the API; subject to row-level security (not the owner, no BYPASSRLS)
-- Row-level security is keyed on two transaction-local settings the API sets for every request:
--   app.user_id, app.workspace_id   (see src/db/scope.js)
-- Encryption columns (*_ciphertext, encryption_meta) are PROVISIONAL until the encryption/key model is approved.
-- There is no plaintext column for content the architecture requires encrypted.

-- ---------------------------------------------------------------- tables
CREATE TABLE users (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email       text NOT NULL,
  full_name   text NOT NULL,
  role        text NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX users_email_key ON users (lower(email));

CREATE TABLE workspaces (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  slug        text NOT NULL CHECK (slug ~ '^[a-z0-9][a-z0-9-]{1,62}$'),
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX workspaces_slug_key ON workspaces (slug);

CREATE TABLE memberships (
  user_id       uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  workspace_id  uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
  role          text NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, workspace_id)
);
CREATE INDEX memberships_workspace_idx ON memberships (workspace_id);

CREATE TABLE channels (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
  name          text NOT NULL,
  description   text NOT NULL DEFAULT '',
  created_by    uuid NOT NULL REFERENCES users (id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, workspace_id),
  UNIQUE (workspace_id, name)
);
CREATE INDEX channels_workspace_idx ON channels (workspace_id);

-- Child tables carry workspace_id and use composite foreign keys so a child can never point at a
-- parent in another workspace.
CREATE TABLE messages (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id     uuid NOT NULL,
  channel_id       uuid NOT NULL,
  author_id        uuid NOT NULL REFERENCES users (id),
  author_name      text NOT NULL, -- author snapshot keeps history readable
  parent_id        uuid,
  body_ciphertext  bytea NOT NULL,
  encryption_meta  jsonb NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, workspace_id),
  FOREIGN KEY (channel_id, workspace_id) REFERENCES channels (id, workspace_id) ON DELETE CASCADE,
  FOREIGN KEY (parent_id, workspace_id) REFERENCES messages (id, workspace_id) ON DELETE CASCADE
);
CREATE INDEX messages_channel_idx ON messages (channel_id, created_at);
CREATE INDEX messages_parent_idx ON messages (parent_id);
CREATE INDEX messages_workspace_idx ON messages (workspace_id);

CREATE TABLE message_reactions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL,
  message_id    uuid NOT NULL,
  emoji         text NOT NULL,
  user_id       uuid NOT NULL REFERENCES users (id),
  user_name     text NOT NULL,
  UNIQUE (message_id, emoji, user_id),
  FOREIGN KEY (message_id, workspace_id) REFERENCES messages (id, workspace_id) ON DELETE CASCADE
);
CREATE INDEX message_reactions_message_idx ON message_reactions (message_id);
CREATE INDEX message_reactions_workspace_idx ON message_reactions (workspace_id);

CREATE TABLE kanban_boards (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL,
  channel_id    uuid, -- NULL = global board
  name          text NOT NULL,
  created_by    uuid NOT NULL REFERENCES users (id),
  UNIQUE (id, workspace_id),
  FOREIGN KEY (channel_id, workspace_id) REFERENCES channels (id, workspace_id) ON DELETE CASCADE
);
CREATE INDEX kanban_boards_workspace_idx ON kanban_boards (workspace_id);
CREATE INDEX kanban_boards_channel_idx ON kanban_boards (channel_id);

CREATE TABLE kanban_cards (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL,
  board_id      uuid NOT NULL,
  title         text NOT NULL,
  column_name   text NOT NULL,
  position      integer NOT NULL,
  created_by    uuid NOT NULL REFERENCES users (id),
  FOREIGN KEY (board_id, workspace_id) REFERENCES kanban_boards (id, workspace_id) ON DELETE CASCADE
);
CREATE INDEX kanban_cards_board_idx ON kanban_cards (board_id, column_name, position);
CREATE INDEX kanban_cards_workspace_idx ON kanban_cards (workspace_id);

CREATE TABLE whiteboard_sessions (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id       uuid NOT NULL,
  channel_id         uuid NOT NULL,
  title              text NOT NULL,
  strokes_ciphertext bytea NOT NULL,
  encryption_meta    jsonb NOT NULL,
  created_by         uuid NOT NULL REFERENCES users (id),
  FOREIGN KEY (channel_id, workspace_id) REFERENCES channels (id, workspace_id) ON DELETE CASCADE
);
CREATE INDEX whiteboard_sessions_channel_idx ON whiteboard_sessions (channel_id);
CREATE INDEX whiteboard_sessions_workspace_idx ON whiteboard_sessions (workspace_id);

CREATE TABLE video_rooms (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL,
  channel_id    uuid NOT NULL,
  room_name     text NOT NULL,
  provider      text NOT NULL, -- opaque provider key; selection is a pending Captain decision
  join_url      text NOT NULL,
  active        boolean NOT NULL DEFAULT true,
  created_by    uuid NOT NULL REFERENCES users (id),
  FOREIGN KEY (channel_id, workspace_id) REFERENCES channels (id, workspace_id) ON DELETE CASCADE
);
CREATE INDEX video_rooms_channel_idx ON video_rooms (channel_id);
CREATE INDEX video_rooms_workspace_idx ON video_rooms (workspace_id);

CREATE TABLE notifications (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  type          text NOT NULL,
  payload       jsonb NOT NULL DEFAULT '{}',
  read_at       timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notifications_user_idx ON notifications (user_id, created_at);

CREATE TABLE audit_events (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  workspace_id  uuid REFERENCES workspaces (id) ON DELETE SET NULL,
  actor_id      uuid REFERENCES users (id) ON DELETE SET NULL,
  action        text NOT NULL,
  target        text,
  meta          jsonb NOT NULL DEFAULT '{}',
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_events_created_idx ON audit_events (created_at);

CREATE FUNCTION audit_events_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'audit_events is append-only';
END $$;
CREATE TRIGGER audit_events_no_update BEFORE UPDATE OR DELETE ON audit_events
  FOR EACH ROW EXECUTE FUNCTION audit_events_immutable();
CREATE TRIGGER audit_events_no_truncate BEFORE TRUNCATE ON audit_events
  FOR EACH STATEMENT EXECUTE FUNCTION audit_events_immutable();

-- ---------------------------------------------------------------- request context helpers
CREATE FUNCTION app_user_id() RETURNS uuid LANGUAGE sql STABLE AS
  $$ SELECT nullif(current_setting('app.user_id', true), '')::uuid $$;
CREATE FUNCTION app_workspace_id() RETURNS uuid LANGUAGE sql STABLE AS
  $$ SELECT nullif(current_setting('app.workspace_id', true), '')::uuid $$;

-- SECURITY DEFINER (owner bypasses RLS) so membership checks inside policies cannot recurse.
CREATE FUNCTION app_is_member(ws uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
  SET search_path = public, pg_temp AS
  $$ SELECT EXISTS (SELECT 1 FROM memberships m WHERE m.workspace_id = ws AND m.user_id = app_user_id()) $$;
CREATE FUNCTION app_is_admin(ws uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
  SET search_path = public, pg_temp AS
  $$ SELECT EXISTS (SELECT 1 FROM memberships m WHERE m.workspace_id = ws AND m.user_id = app_user_id() AND m.role = 'admin') $$;
CREATE FUNCTION app_shares_workspace(uid uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
  SET search_path = public, pg_temp AS
  $$ SELECT EXISTS (
       SELECT 1 FROM memberships a JOIN memberships b ON a.workspace_id = b.workspace_id
       WHERE a.user_id = app_user_id() AND b.user_id = uid) $$;
CREATE FUNCTION app_user_in_workspace(uid uuid, ws uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
  SET search_path = public, pg_temp AS
  $$ SELECT EXISTS (SELECT 1 FROM memberships m WHERE m.workspace_id = ws AND m.user_id = uid) $$;
-- Scope check used by every workspace-owned table: the request's workspace AND real membership.
CREATE FUNCTION app_in_scope(ws uuid) RETURNS boolean LANGUAGE sql STABLE AS
  $$ SELECT ws = app_workspace_id() AND app_is_member(ws) $$;
CREATE FUNCTION app_scope_admin(ws uuid) RETURNS boolean LANGUAGE sql STABLE AS
  $$ SELECT ws = app_workspace_id() AND app_is_admin(ws) $$;

-- Workspace creation is atomic: the creator becomes its first admin.
CREATE FUNCTION create_workspace(p_name text, p_slug text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER
  SET search_path = public, pg_temp AS $$
DECLARE ws uuid;
BEGIN
  IF app_user_id() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  INSERT INTO workspaces (name, slug) VALUES (p_name, p_slug) RETURNING id INTO ws;
  INSERT INTO memberships (user_id, workspace_id, role) VALUES (app_user_id(), ws, 'admin');
  RETURN ws;
END $$;

-- ---------------------------------------------------------------- row-level security
ALTER TABLE users               ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspaces          ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships         ENABLE ROW LEVEL SECURITY;
ALTER TABLE channels            ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages            ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_reactions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE kanban_boards       ENABLE ROW LEVEL SECURITY;
ALTER TABLE kanban_cards        ENABLE ROW LEVEL SECURITY;
ALTER TABLE whiteboard_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE video_rooms         ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications       ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_events        ENABLE ROW LEVEL SECURITY;

CREATE POLICY users_select ON users FOR SELECT USING (id = app_user_id() OR app_shares_workspace(id));
CREATE POLICY users_update_self ON users FOR UPDATE USING (id = app_user_id()) WITH CHECK (id = app_user_id());

CREATE POLICY workspaces_select ON workspaces FOR SELECT USING (app_is_member(id));
CREATE POLICY workspaces_update ON workspaces FOR UPDATE USING (app_is_admin(id)) WITH CHECK (app_is_admin(id));

CREATE POLICY memberships_select ON memberships FOR SELECT USING (user_id = app_user_id() OR app_is_admin(workspace_id));
CREATE POLICY memberships_insert ON memberships FOR INSERT WITH CHECK (app_is_admin(workspace_id));
CREATE POLICY memberships_update ON memberships FOR UPDATE USING (app_is_admin(workspace_id)) WITH CHECK (app_is_admin(workspace_id));
CREATE POLICY memberships_delete ON memberships FOR DELETE USING (user_id = app_user_id() OR app_is_admin(workspace_id));

CREATE POLICY channels_select ON channels FOR SELECT USING (app_in_scope(workspace_id));
CREATE POLICY channels_write  ON channels FOR ALL USING (app_scope_admin(workspace_id)) WITH CHECK (app_scope_admin(workspace_id));

CREATE POLICY messages_select ON messages FOR SELECT USING (app_in_scope(workspace_id));
CREATE POLICY messages_insert ON messages FOR INSERT WITH CHECK (app_in_scope(workspace_id) AND author_id = app_user_id());
CREATE POLICY messages_update ON messages FOR UPDATE
  USING (app_in_scope(workspace_id) AND author_id = app_user_id())
  WITH CHECK (app_in_scope(workspace_id) AND author_id = app_user_id());
CREATE POLICY messages_delete ON messages FOR DELETE
  USING (app_in_scope(workspace_id) AND (author_id = app_user_id() OR app_scope_admin(workspace_id)));

CREATE POLICY reactions_select ON message_reactions FOR SELECT USING (app_in_scope(workspace_id));
CREATE POLICY reactions_insert ON message_reactions FOR INSERT WITH CHECK (app_in_scope(workspace_id) AND user_id = app_user_id());
CREATE POLICY reactions_delete ON message_reactions FOR DELETE USING (app_in_scope(workspace_id) AND user_id = app_user_id());

CREATE POLICY boards_select ON kanban_boards FOR SELECT USING (app_in_scope(workspace_id));
CREATE POLICY boards_insert ON kanban_boards FOR INSERT WITH CHECK (app_in_scope(workspace_id) AND created_by = app_user_id());
CREATE POLICY boards_update ON kanban_boards FOR UPDATE USING (app_in_scope(workspace_id)) WITH CHECK (app_in_scope(workspace_id));
CREATE POLICY boards_delete ON kanban_boards FOR DELETE USING (app_in_scope(workspace_id) AND (created_by = app_user_id() OR app_scope_admin(workspace_id)));

CREATE POLICY cards_select ON kanban_cards FOR SELECT USING (app_in_scope(workspace_id));
CREATE POLICY cards_insert ON kanban_cards FOR INSERT WITH CHECK (app_in_scope(workspace_id) AND created_by = app_user_id());
CREATE POLICY cards_update ON kanban_cards FOR UPDATE USING (app_in_scope(workspace_id)) WITH CHECK (app_in_scope(workspace_id));
CREATE POLICY cards_delete ON kanban_cards FOR DELETE USING (app_in_scope(workspace_id) AND (created_by = app_user_id() OR app_scope_admin(workspace_id)));

CREATE POLICY whiteboards_select ON whiteboard_sessions FOR SELECT USING (app_in_scope(workspace_id));
CREATE POLICY whiteboards_insert ON whiteboard_sessions FOR INSERT WITH CHECK (app_in_scope(workspace_id) AND created_by = app_user_id());
CREATE POLICY whiteboards_update ON whiteboard_sessions FOR UPDATE USING (app_in_scope(workspace_id)) WITH CHECK (app_in_scope(workspace_id));
CREATE POLICY whiteboards_delete ON whiteboard_sessions FOR DELETE USING (app_in_scope(workspace_id) AND (created_by = app_user_id() OR app_scope_admin(workspace_id)));

CREATE POLICY rooms_select ON video_rooms FOR SELECT USING (app_in_scope(workspace_id));
CREATE POLICY rooms_insert ON video_rooms FOR INSERT WITH CHECK (app_in_scope(workspace_id) AND created_by = app_user_id());
CREATE POLICY rooms_update ON video_rooms FOR UPDATE USING (app_in_scope(workspace_id)) WITH CHECK (app_in_scope(workspace_id));
CREATE POLICY rooms_delete ON video_rooms FOR DELETE USING (app_in_scope(workspace_id) AND (created_by = app_user_id() OR app_scope_admin(workspace_id)));

CREATE POLICY notifications_select ON notifications FOR SELECT USING (user_id = app_user_id() AND app_in_scope(workspace_id));
CREATE POLICY notifications_insert ON notifications FOR INSERT WITH CHECK (app_in_scope(workspace_id) AND app_user_in_workspace(user_id, workspace_id));
CREATE POLICY notifications_update ON notifications FOR UPDATE USING (user_id = app_user_id()) WITH CHECK (user_id = app_user_id());

CREATE POLICY audit_insert ON audit_events FOR INSERT WITH CHECK (actor_id = app_user_id() AND (workspace_id IS NULL OR app_in_scope(workspace_id)));
CREATE POLICY audit_select ON audit_events FOR SELECT USING (workspace_id IS NOT NULL AND app_scope_admin(workspace_id));

-- ---------------------------------------------------------------- grants for the API login role
GRANT USAGE ON SCHEMA public TO shellspace_app;
GRANT SELECT ON users, workspaces, memberships, channels, messages, message_reactions, kanban_boards,
  kanban_cards, whiteboard_sessions, video_rooms, notifications, audit_events TO shellspace_app;
GRANT INSERT, UPDATE, DELETE ON memberships, channels, messages, message_reactions, kanban_boards,
  kanban_cards, whiteboard_sessions, video_rooms, notifications TO shellspace_app;
GRANT UPDATE ON users, workspaces TO shellspace_app;
GRANT INSERT ON audit_events TO shellspace_app;
GRANT EXECUTE ON FUNCTION create_workspace(text, text) TO shellspace_app;
