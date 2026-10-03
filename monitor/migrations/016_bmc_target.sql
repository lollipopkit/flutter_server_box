-- The BMCs (Redfish) the panel reaches through this agent: this machine's own
-- and its neighbours', since a machine that is off cannot be turned on by an
-- agent running on it.
--
-- `password` is write-only over the API: a read answers whether one is
-- stored, a write sending `null` keeps it. Stored as the other credentials in
-- this agent's state are (`config.toml`'s push keys): readable by the agent's
-- account and protected from `/fs` with the database.
--
-- `cert_sha256` is the pinned leaf certificate, in the app's format
-- (`BmcCfg.certSha256`); without one the agent refuses to connect.
--
-- `updated_at` is RFC 3339 text bound by the writer (see migration 012).

CREATE TABLE bmc_target (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    username TEXT NOT NULL,
    password TEXT,
    cert_sha256 TEXT,
    -- Display order, the operator's. A write replaces the whole set.
    position INTEGER NOT NULL,
    updated_at TEXT NOT NULL
);
