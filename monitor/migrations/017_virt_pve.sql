-- How this agent reaches the Proxmox VE API of the host it runs on (the
-- panel's Virtualization page). One row at most: an agent manages its own
-- host, and a cluster's other nodes are reached through it.
--
-- `password` and `token_secret` are write-only over the API: a read answers
-- whether one is stored, a write sending `null` keeps it. Stored as the other
-- credentials in this agent's state are (`bmc_target.password`): readable by
-- the agent's account and protected from `/fs` with the database.
--
-- `cert_sha256` is the confirmed leaf certificate, in the app's format
-- (`PveConfig.certSha256`); without one, a certificate no CA vouches for is
-- shown for review and nothing is sent.
--
-- `updated_at` is RFC 3339 text bound by the writer (see migration 012).

CREATE TABLE virt_pve (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    addr TEXT NOT NULL,
    auth TEXT NOT NULL CHECK (auth IN ('password', 'token')),
    username TEXT,
    password TEXT,
    token_id TEXT,
    token_secret TEXT,
    cert_sha256 TEXT,
    updated_at TEXT NOT NULL
);
