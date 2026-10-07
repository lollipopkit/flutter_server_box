-- Desk apps an admin installed (`api::apps`): the package's checked manifest
-- and its files. Approved permissions are NULL until an admin approves them;
-- an app nobody approved is served to no one.
CREATE TABLE desk_app_package (
    app_id TEXT PRIMARY KEY,
    version TEXT NOT NULL,
    manifest TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    approved_permissions TEXT,
    installed_by TEXT NOT NULL,
    installed_at TEXT NOT NULL,
    approved_at TEXT
);

CREATE TABLE desk_app_file (
    app_id TEXT NOT NULL REFERENCES desk_app_package(app_id) ON DELETE CASCADE,
    path TEXT NOT NULL,
    bytes BLOB NOT NULL,
    PRIMARY KEY (app_id, path)
);
