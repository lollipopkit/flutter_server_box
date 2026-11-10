-- Services the agent deployed from its catalog (`stacks`): one Docker
-- Compose project per catalog entry, its files in
-- `<database dir>/stacks/<id>/` (`stacks::Stacks::dir`).
--
-- Only what was chosen is kept here; the generated secrets (a database
-- password) live in the stack's env file alone (0600), which is what Compose
-- reads. Text times are RFC 3339.
CREATE TABLE stack (
    -- The catalog entry's id (`immich`), also the project name's suffix.
    id TEXT PRIMARY KEY,
    -- The entry's version these files were written from.
    version TEXT NOT NULL,
    -- The entry's settings as JSON (paths, port, acceleration).
    settings TEXT NOT NULL,
    -- The agent's own port in front of the service (`stacks::proxy`).
    proxy_port INTEGER NOT NULL UNIQUE,
    -- `installing` | `installed` | `failed`. A stack being removed keeps its
    -- state until the row goes.
    state TEXT NOT NULL CHECK (state IN ('installing', 'installed', 'failed')),
    -- Who accepted the service's licence, which one and when.
    license TEXT NOT NULL,
    license_accepted_by TEXT NOT NULL,
    license_accepted_at TEXT NOT NULL,
    installed_by TEXT NOT NULL,
    installed_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    -- The last failed step's summary; NULL once a step succeeds.
    last_error TEXT
);
