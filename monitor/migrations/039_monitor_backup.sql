-- Where this monitor's own settings are backed up (`monitor_backup`): one row, a
-- WebDAV folder. `password` is write-only over the API. `recipient` is the
-- age public key backups are encrypted to (`age1…`); its secret half lives
-- only in the folder, encrypted with the operator's passphrase, so the monitor
-- can back up without the passphrase and cannot read its own backups.
-- `stable_hash` / `full_hash` are what the last backup held, without and
-- with the fields that change on their own (`monitor_backup::snapshot`).
-- `instance` names this monitor's files in the folder (8 hex digits, random),
-- so monitors sharing a folder never prune each other's.
-- Never itself backed up.
CREATE TABLE monitor_backup (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    instance TEXT NOT NULL,
    url TEXT NOT NULL,
    username TEXT NOT NULL DEFAULT '',
    password TEXT,
    allow_insecure INTEGER NOT NULL DEFAULT 0 CHECK (allow_insecure IN (0, 1)),
    enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
    keep INTEGER NOT NULL DEFAULT 10 CHECK (keep BETWEEN 1 AND 100),
    recipient TEXT,
    stable_hash TEXT,
    full_hash TEXT,
    last_backup_at TEXT,
    last_name TEXT,
    last_error TEXT,
    last_error_at TEXT,
    updated_at TEXT NOT NULL
);
