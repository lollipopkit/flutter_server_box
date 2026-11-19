-- API tokens (#1681): bearer credentials for MCP clients, as the watch
-- tokens are for the widgets — but these name what the client may do.
--
-- The token itself (`sbt_` + 64 hex) is shown once at creation and never
-- stored: the row holds its SHA-256, so a copy of the database is a list of
-- hashes, not a way in. A lookup by hash answers the bearer on every use,
-- which also refreshes `last_used_at` / `last_used_ip` — what the owner
-- reads to see what a token has been doing.
--
-- A password change deletes every row (`db::accounts::set_password_hash`,
-- the same transaction that ends the sessions): a token outlives a reset
-- password only if nobody could have taken it, which a reset assumes they
-- might have.
--
-- `scopes` is a comma-separated list out of a fixed set, read by
-- `db::api_tokens::parse_scopes` — never matched in SQL, so its shape is
-- this module's own.

CREATE TABLE api_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    -- The label the owner gave it, shown beside its use in the audit log.
    name TEXT NOT NULL,
    -- SHA-256 hex of the whole token.
    token_hash TEXT NOT NULL UNIQUE,
    -- Comma-separated; the fixed set is in `api::mcp::Scope`.
    scopes TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- No default: an expiry is decided at creation, 90 days by the endpoint.
    expires_at DATETIME NOT NULL,
    last_used_at DATETIME,
    last_used_ip TEXT
);
