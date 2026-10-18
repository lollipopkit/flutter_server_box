-- API tokens for the MCP endpoint (issue #1681).
--
-- A token is a long-lived credential an MCP client holds instead of a panel
-- JWT. The secret is shown once (`sbt_` + 64 hex); only its SHA-256 lives
-- here. Scopes are a JSON array of grant names; `admin` is never stored, and
-- the grants a token can actually use are those names intersected with the
-- account's role at the moment of use.
--
-- Deleted with the account, and on a password change, in `db::accounts` —
-- a token is the account's, and must not outlive a credential it was paid
-- for with. No foreign key: `watch_tokens` is the same, so a users rebuild
-- cannot strand rows behind a constraint SQLite would then refuse to drop.

CREATE TABLE api_tokens (
    id TEXT PRIMARY KEY NOT NULL,
    subject TEXT NOT NULL,
    name TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    scopes TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    last_used_at INTEGER,
    last_used_ip TEXT
);

CREATE INDEX idx_api_tokens_subject ON api_tokens(subject);
CREATE INDEX idx_api_tokens_expires_at ON api_tokens(expires_at);
