-- no-transaction
--
-- One account: the agent's own. What it may do is what the system account
-- the agent runs as may do, so roles, grants, the other accounts and the
-- accounts' names go: the password alone signs in.
--
-- The account kept is the oldest admin (the lowest id holding the admin
-- role; the lowest id at all, if somehow none does): its password signs in
-- from now on. What the others made is moved to it where it does not collide
-- with its own: Agent mode's tasks and memory files, desk themes, desk app
-- data for apps it has none for, notifications read. Their desk layout,
-- wallpaper and windows go with them, as do their paired watches: a device
-- someone else paired must not keep reading as the one account left. Watch
-- tokens lose their `subject`.
--
-- Not in a transaction of sqlx's: `users` is rebuilt without its `role`
-- column, and dropping a table other tables reference needs `foreign_keys`
-- off, which SQLite ignores inside a transaction. The transaction is this
-- file's own.

PRAGMA foreign_keys = OFF;
PRAGMA legacy_alter_table = ON;

BEGIN;

CREATE TEMP TABLE owner AS
SELECT id FROM users
ORDER BY (role = 'admin') DESC, id
LIMIT 1;

UPDATE agent_flow SET user_id = (SELECT id FROM owner)
WHERE user_id <> (SELECT id FROM owner);

INSERT OR IGNORE INTO agent_memory (user_id, path, content, updated_at)
SELECT (SELECT id FROM owner), path, content, updated_at FROM agent_memory
WHERE user_id <> (SELECT id FROM owner)
ORDER BY updated_at DESC;

INSERT OR IGNORE INTO desk_theme (user_id, installation_id, theme_id, name, summary, installed_at)
SELECT (SELECT id FROM owner), installation_id, theme_id, name, summary, installed_at FROM desk_theme
WHERE user_id <> (SELECT id FROM owner);

INSERT OR IGNORE INTO desk_theme_background (user_id, installation_id, variant, mime, sha256, size)
SELECT (SELECT id FROM owner), b.installation_id, b.variant, b.mime, b.sha256, b.size
FROM desk_theme_background b
WHERE b.user_id <> (SELECT id FROM owner)
  AND EXISTS (
    SELECT 1 FROM desk_theme t
    WHERE t.user_id = (SELECT id FROM owner) AND t.installation_id = b.installation_id
  );

-- Whole apps only, so no app's data is a mix of two accounts' and none grows
-- past what one account kept for it.
INSERT OR IGNORE INTO desk_app_storage (user_id, app_id, key, value, updated_at)
SELECT (SELECT id FROM owner), s.app_id, s.key, s.value, s.updated_at
FROM desk_app_storage s
WHERE s.user_id = (
    SELECT min(o.user_id) FROM desk_app_storage o
    WHERE o.app_id = s.app_id AND o.user_id <> (SELECT id FROM owner)
  )
  AND NOT EXISTS (
    SELECT 1 FROM desk_app_storage m
    WHERE m.user_id = (SELECT id FROM owner) AND m.app_id = s.app_id
  );

INSERT OR IGNORE INTO desk_notification_read (user_id, notification_id)
SELECT (SELECT id FROM owner), notification_id FROM desk_notification_read
WHERE user_id <> (SELECT id FROM owner);

-- With `foreign_keys` off nothing cascades: every row of the others goes by
-- hand.
DELETE FROM agent_memory WHERE user_id <> (SELECT id FROM owner);
DELETE FROM desk_preferences WHERE user_id <> (SELECT id FROM owner);
DELETE FROM desk_dock WHERE user_id <> (SELECT id FROM owner);
DELETE FROM desk_icon WHERE user_id <> (SELECT id FROM owner);
DELETE FROM desk_wallpaper WHERE user_id <> (SELECT id FROM owner);
DELETE FROM desk_window WHERE user_id <> (SELECT id FROM owner);
DELETE FROM desk_session WHERE user_id <> (SELECT id FROM owner);
DELETE FROM desk_notification_read WHERE user_id <> (SELECT id FROM owner);
DELETE FROM desk_background_denied WHERE user_id <> (SELECT id FROM owner);
DELETE FROM desk_app_storage WHERE user_id <> (SELECT id FROM owner);
DELETE FROM desk_theme_background WHERE user_id <> (SELECT id FROM owner);
DELETE FROM desk_theme WHERE user_id <> (SELECT id FROM owner);
-- The owner's watches only, keyed by the device alone.
CREATE TABLE watch_tokens_new (
    client_id TEXT PRIMARY KEY,
    token_hash TEXT NOT NULL UNIQUE,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    scope TEXT NOT NULL DEFAULT 'read'
);
INSERT INTO watch_tokens_new (client_id, token_hash, created_at, expires_at, scope)
SELECT client_id, token_hash, created_at, expires_at, scope FROM watch_tokens
WHERE subject = (SELECT u.username FROM users u JOIN owner o ON o.id = u.id);
DROP TABLE watch_tokens;
ALTER TABLE watch_tokens_new RENAME TO watch_tokens;
CREATE INDEX idx_watch_tokens_expires_at ON watch_tokens(expires_at);

CREATE TABLE users_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    password_hash TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME,
    -- When the password was last set, in Unix milliseconds: a panel token
    -- issued before it is refused (migration 010).
    password_changed_ms INTEGER NOT NULL
        DEFAULT (CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER))
);

INSERT INTO users_new (id, password_hash, created_at, last_login, password_changed_ms)
SELECT id, password_hash, created_at, last_login, password_changed_ms
FROM users WHERE id = (SELECT id FROM owner);

DROP TABLE users;
ALTER TABLE users_new RENAME TO users;
DROP TABLE roles;

-- Which account did something: there is one.
ALTER TABLE stack DROP COLUMN license_accepted_by;
ALTER TABLE stack DROP COLUMN installed_by;
ALTER TABLE desk_app_package DROP COLUMN installed_by;
ALTER TABLE container_backup_schedule DROP COLUMN created_by;
ALTER TABLE storage_maintenance DROP COLUMN updated_by;

DROP TABLE owner;

COMMIT;

PRAGMA legacy_alter_table = OFF;
PRAGMA foreign_keys = ON;
