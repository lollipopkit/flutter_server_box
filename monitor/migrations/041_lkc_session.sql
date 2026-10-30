-- The LK Cloud account this agent is signed in to (`lkc`), at most one: who it
-- is as homebase last answered, and the tokens, never read back out over the
-- API.
CREATE TABLE lkc_session (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    -- `sbm_lkc::User` as JSON.
    user TEXT NOT NULL,
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    -- Milliseconds since the epoch, on this side's clock.
    expires_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
