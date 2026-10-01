-- Roles, and the role each account holds (issue #1610).
--
-- Until now every account could do whatever `config.toml` allowed the agent
-- to do: a second panel login was a second key to the same door. A role is
-- what one account may do, and the agent checks the caller's role on every
-- request instead of reading switches out of the config file.
--
-- The two built-in roles are created here with `grants` NULL, meaning "not
-- decided yet". The agent decides them on its first start after this
-- migration (`db::bootstrap::ensure_roles`), because the answer depends on
-- things SQL cannot see: whether this is a fresh install or an upgrade, the
-- installer's choice, and on an upgrade what the old switches in
-- `config.toml` effectively granted.

CREATE TABLE roles (
    name TEXT PRIMARY KEY NOT NULL,
    -- May manage accounts, roles and the agent's own configuration. Only the
    -- built-in `admin` role has it; the API refuses to set it anywhere else.
    admin INTEGER NOT NULL DEFAULT 0,
    -- `admin` and `viewer`: cannot be renamed or deleted.
    builtin INTEGER NOT NULL DEFAULT 0,
    -- JSON, the shape `core::permissions::Grants` reads. NULL only on a
    -- built-in role the agent has not resolved yet.
    grants TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

INSERT INTO roles (name, admin, builtin, grants, created_at, updated_at) VALUES
    ('admin', 1, 1, NULL,
     strftime('%Y-%m-%dT%H:%M:%S', 'now') || '+00:00',
     strftime('%Y-%m-%dT%H:%M:%S', 'now') || '+00:00'),
    ('viewer', 0, 1, NULL,
     strftime('%Y-%m-%dT%H:%M:%S', 'now') || '+00:00',
     strftime('%Y-%m-%dT%H:%M:%S', 'now') || '+00:00');

-- `users` is rebuilt rather than altered: SQLite will not add a column that
-- references another table with a non-NULL default while foreign keys are
-- enforced, and a role column that nothing enforces is a role column that can
-- name a role nobody can find. Nothing references `users`, so the rebuild
-- needs no foreign-key juggling.
--
-- Every account that exists now becomes an admin. That is what each of them
-- was until this migration — every login could do everything the agent
-- allowed — so nobody loses access by upgrading, and the admin role's grants
-- are set to exactly what that access was.
CREATE TABLE users_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME,
    role TEXT NOT NULL DEFAULT 'viewer' REFERENCES roles(name),
    -- When this account's password was last set, in Unix milliseconds: a
    -- panel token issued before it is refused, and what ran under the old
    -- password is ended. Set on creation too, so a token for a deleted
    -- account is not good for a new one of the same name. Milliseconds so
    -- that a change in the same second as a connection opened still moves it.
    password_changed_ms INTEGER NOT NULL
        DEFAULT (CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER))
);

INSERT INTO users_new (id, username, password_hash, created_at, last_login, role, password_changed_ms)
SELECT id, username, password_hash, created_at, last_login, 'admin',
       COALESCE(CAST(strftime('%s', created_at) AS INTEGER), 0) * 1000
FROM users;

DROP TABLE users;
ALTER TABLE users_new RENAME TO users;

-- A watch token says what it may do rather than relying on which routes
-- happen to accept it. Every token minted so far was a read token.
ALTER TABLE watch_tokens ADD COLUMN scope TEXT NOT NULL DEFAULT 'read';
