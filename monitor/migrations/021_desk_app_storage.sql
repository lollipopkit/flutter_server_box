-- What a desk app keeps for itself (`sys.storage`), per account: JSON values
-- by key, bounded per app by the agent (`api::desk_storage`).
CREATE TABLE desk_app_storage (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    app_id TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (user_id, app_id, key)
);
