-- API tokens and MCP access policy (#1681): bearer credentials for MCP
-- clients, and the operator's ceiling on what MCP may do as a whole.
--
-- Everything starts open: all scopes enabled (`disabled_scopes = ''`,
-- `scopes = '*'`) and every command allowed (`command_mode = 'allow_all'`),
-- with fine-grained restrictions available both globally (`mcp_policy`) and
-- on each token (`api_tokens`). Effective reach is their intersection.
--
-- The token itself (`sbt_` + 64 hex) is shown once at creation and never
-- stored: the row holds its BLAKE3 hash, so a copy of the database is a list
-- of hashes, not a way in. A lookup by hash answers the bearer on every use,
-- which also refreshes `last_used_at` / `last_used_ip`.
--
-- A password change deletes every token (`db::accounts::set_password_hash`,
-- the same transaction that ends the sessions).

CREATE TABLE mcp_policy (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    -- Comma-separated scopes turned off globally; empty means every scope is on.
    disabled_scopes TEXT NOT NULL DEFAULT '',
    -- `allow_all` (default) or `allowlist`.
    command_mode TEXT NOT NULL DEFAULT 'allow_all',
    -- JSON arrays of command patterns (`fl_pi_llm::permissions::rules`).
    command_allow TEXT NOT NULL DEFAULT '[]',
    command_deny TEXT NOT NULL DEFAULT '[]',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE api_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    -- The label the owner gave it, shown beside its use in the audit log.
    name TEXT NOT NULL,
    -- BLAKE3 hex of the whole token.
    token_hash TEXT NOT NULL UNIQUE,
    -- `*` for every scope, or comma-separated out of `db::api_tokens::Scope`.
    scopes TEXT NOT NULL,
    -- Per-token command policy, intersected with `mcp_policy`.
    command_mode TEXT NOT NULL DEFAULT 'allow_all',
    command_allow TEXT NOT NULL DEFAULT '[]',
    command_deny TEXT NOT NULL DEFAULT '[]',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- No default: an expiry is decided at creation, 90 days by the endpoint.
    expires_at DATETIME NOT NULL,
    last_used_at DATETIME,
    last_used_ip TEXT
);
