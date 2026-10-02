-- The remote desktops the panel opens through this agent's `/stream/ws`
-- relay: where each one is, as seen from this machine, and how to open it.
--
-- No password column, deliberately. A desktop's password is typed in the
-- browser that runs the session and goes from there to the desktop only; the
-- agent relays bytes it does not read and stores nothing it could leak.
--
-- The app keeps its own profiles per server (`lib/data/store/remote_desktop.dart`);
-- these are the agent's, for the panel.
--
-- `updated_at` is RFC 3339 text bound by the writer (see migration 012).

CREATE TABLE desktop_profile (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    -- `vnc`; `rdp` once the panel has an RDP client.
    protocol TEXT NOT NULL,
    -- Dialled by this agent, so `127.0.0.1` is this machine.
    host TEXT NOT NULL,
    port INTEGER NOT NULL,
    username TEXT,
    domain TEXT,
    view_only INTEGER NOT NULL DEFAULT 0,
    shared INTEGER NOT NULL DEFAULT 1,
    -- Display order, the operator's. A write replaces the whole set.
    position INTEGER NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX idx_desktop_profile_position ON desktop_profile(position);
