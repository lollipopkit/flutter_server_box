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
    -- 1 from just before the refresh token is sent until its answer is
    -- stored: a row read back with it set holds a token that may be spent,
    -- and sending that again ends every session of the person.
    refreshing INTEGER NOT NULL DEFAULT 0,
    updated_at INTEGER NOT NULL
);
