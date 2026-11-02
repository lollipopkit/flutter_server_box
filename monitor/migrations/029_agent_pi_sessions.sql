-- Whether each task is also written as a session file of pi's coding agent
-- (`~/.pi/agent/sessions/`), so `pi` on this machine lists it. Off until an
-- admin turns it on.
ALTER TABLE agent_settings ADD COLUMN pi_sessions INTEGER NOT NULL DEFAULT 0;
