-- Theme packages (`.fsbt`) an account installed for its desk, read and
-- checked by `sbm_theme` (the same rules as the app's installer).
--
-- Kept as what was read, not as the package: `summary` is the package's
-- themes (one, or one per variant) as JSON, and a background image is the one
-- file the panel draws from a theme. Installing a theme again (another
-- version, the same `theme_id`) replaces the earlier installation.
CREATE TABLE desk_theme (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- Lowercase hex SHA-256 of the package bytes.
    installation_id TEXT NOT NULL,
    -- The manifest's `id`.
    theme_id TEXT NOT NULL,
    name TEXT NOT NULL,
    summary TEXT NOT NULL,
    installed_at TEXT NOT NULL,
    PRIMARY KEY (user_id, installation_id),
    UNIQUE (user_id, theme_id)
);

-- A theme's background image; `variant` is '' for a package without.
CREATE TABLE desk_theme_background (
    user_id INTEGER NOT NULL,
    installation_id TEXT NOT NULL,
    variant TEXT NOT NULL,
    mime TEXT NOT NULL,
    bytes BLOB NOT NULL,
    PRIMARY KEY (user_id, installation_id, variant),
    FOREIGN KEY (user_id, installation_id) REFERENCES desk_theme(user_id, installation_id) ON DELETE CASCADE
);

-- The theme the desk is drawn with: `<installation_id>` or
-- `<installation_id>#<variant>`; NULL for the panel's own.
ALTER TABLE desk_preferences ADD COLUMN theme TEXT;
