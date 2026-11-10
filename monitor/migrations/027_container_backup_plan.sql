-- Where container backups go and when they are made (`container_backups`).
--
-- `container_backup_settings` is one row: the folder backups are written to
-- (a backup disk's mount; NULL for the default beside the database) and how
-- many of each one's backups are kept (0 keeps all).
-- `container_backup_schedule`: one row per scheduled backup. `containers`
-- is a JSON array of container names (ids change when a project is
-- recreated); `every` is daily or weekly, at `at` (HH:MM, the machine's
-- time) and, weekly, `weekday` (0 Monday). Text times are RFC 3339.
CREATE TABLE container_backup_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    destination TEXT,
    keep INTEGER NOT NULL DEFAULT 7 CHECK (keep >= 0)
);

CREATE TABLE container_backup_schedule (
    id TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    containers TEXT NOT NULL,
    project INTEGER NOT NULL DEFAULT 0,
    stop INTEGER NOT NULL DEFAULT 1,
    every TEXT NOT NULL CHECK (every IN ('daily', 'weekly')),
    at TEXT NOT NULL,
    weekday INTEGER CHECK (weekday BETWEEN 0 AND 6),
    keep INTEGER CHECK (keep >= 0),
    last_run TEXT,
    last_error TEXT,
    created_by TEXT NOT NULL,
    created_at TEXT NOT NULL
);
