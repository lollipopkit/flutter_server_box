-- What an agent-side plugin remembers between cycles.
--
-- `sb.store` on the app is a plugin's own key-value space, and a plugin that
-- runs in both hosts must find one here too — see PLUGINS.md 9.5. Keyed by
-- plugin so one cannot read another's, and by scope so the same plugin code
-- works in either host: on the app `server` is per machine, and here there is
-- one machine and it is this one.
--
-- No foreign key to anything: a plugin's data outlives a config edit that
-- takes its entry out, and putting the entry back should find what it left.
-- Removing it for good is `DELETE FROM plugin_kv WHERE plugin_id = ...`, which
-- is a thing an operator does deliberately.
CREATE TABLE IF NOT EXISTS plugin_kv (
    plugin_id  TEXT NOT NULL,
    scope      TEXT NOT NULL,
    key        TEXT NOT NULL,
    value      TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (plugin_id, scope, key)
) WITHOUT ROWID;
