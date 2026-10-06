-- The panel's desk (its web desktop): what each account arranged there, and
-- what the agent has to tell it.
--
-- Everything an account owns is keyed by `users.id` and goes with it
-- (`ON DELETE CASCADE`): a new account of the same name starts from nothing.
-- Text times are RFC 3339, bound by the writer (see migration 012).

-- One row per account; absent is the defaults.
CREATE TABLE desk_preferences (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    -- `#rrggbb`, or NULL for the panel's own.
    accent TEXT,
    -- `preset:<id>` (a wallpaper the panel ships) or `custom` (desk_wallpaper).
    wallpaper TEXT NOT NULL,
    -- `cover` | `contain` | `fill`.
    wallpaper_fit TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

-- The dock's apps, in order. An app id is the panel's (`desk/apps`).
CREATE TABLE desk_dock (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    app_id TEXT NOT NULL,
    PRIMARY KEY (user_id, position),
    UNIQUE (user_id, app_id)
);

-- The desk's icons: an app, or a path on one server opened with an app.
CREATE TABLE desk_icon (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- Minted by the panel.
    id TEXT NOT NULL,
    -- `app` | `path`.
    kind TEXT NOT NULL,
    app_id TEXT NOT NULL,
    -- The panel's id of the server a `path` is on; NULL for an `app`.
    server_id TEXT,
    path TEXT,
    label TEXT NOT NULL,
    -- The grid cell; NULL lets the panel place it.
    col INTEGER,
    row INTEGER,
    position INTEGER NOT NULL,
    PRIMARY KEY (user_id, id)
);

-- A custom wallpaper, at most one per account.
CREATE TABLE desk_wallpaper (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    mime TEXT NOT NULL,
    bytes BLOB NOT NULL,
    -- Lowercase hex SHA-256 of `bytes`: the ETag, and what tells a panel its
    -- copy is current.
    sha256 TEXT NOT NULL
);

-- The windows one browser had open, so a reload (or another tab) finds them
-- again. Per device: a phone and a desktop arrange the same account apart.
-- `revision` moves on every write; a write made from an older one is refused.
CREATE TABLE desk_session (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    revision INTEGER NOT NULL,
    active_window_id TEXT,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (user_id, device_id)
);

CREATE TABLE desk_window (
    user_id INTEGER NOT NULL,
    device_id TEXT NOT NULL,
    window_id TEXT NOT NULL,
    app_id TEXT NOT NULL,
    -- The panel's id of the server the window works on; NULL for an app that
    -- works on none (Settings).
    server_id TEXT,
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    z INTEGER NOT NULL,
    minimized INTEGER NOT NULL,
    maximized INTEGER NOT NULL,
    -- What the app keeps for itself (a path, a tab): JSON the agent only
    -- bounds, never reads.
    app_state TEXT,
    PRIMARY KEY (user_id, device_id, window_id),
    FOREIGN KEY (user_id, device_id) REFERENCES desk_session(user_id, device_id) ON DELETE CASCADE
);

-- What the machine has to say to whoever is looking: a rule that started
-- firing, for now. Shared by every account; read state is per account.
CREATE TABLE desk_notification (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    -- `info` | `warning` | `critical`.
    level TEXT NOT NULL,
    -- `alert`: a monitoring rule; `subject` is its name.
    source TEXT NOT NULL,
    subject TEXT NOT NULL,
    body TEXT NOT NULL
);

CREATE INDEX idx_desk_notification_created ON desk_notification(created_at);

CREATE TABLE desk_notification_read (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notification_id INTEGER NOT NULL REFERENCES desk_notification(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, notification_id)
);
