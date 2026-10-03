-- The backups this agent hosts for its clients: the app's sync file
-- (`srvbox_bak_v3.json`) and whatever an operator uploads from the panel.
--
-- Opaque bytes under a name. The app encrypts a backup before it is sent, and
-- nothing in the agent reads one. A row rather than a file so the blobs share
-- the database's protection (`fs_roots::Protected`) and a replace is one
-- statement.
--
-- `updated_at` is RFC 3339 text bound by the writer (see migration 012).

CREATE TABLE backup_blob (
    name TEXT PRIMARY KEY,
    data BLOB NOT NULL,
    size INTEGER NOT NULL,
    updated_at TEXT NOT NULL
);
