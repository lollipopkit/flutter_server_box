-- Hosted backups (`api::backup`) as files: the bytes are a file in the blob
-- directory beside the database (`core::blobs`), named by `sha256`. The rows
-- of `backup_blob` (migration 015), which kept the bytes here, are moved over
-- and that table dropped by `core::blobs::move_database_backups` once this
-- has run: moving bytes into files is not something SQL can do.

CREATE TABLE backup_file (
    name TEXT PRIMARY KEY,
    sha256 TEXT NOT NULL,
    size INTEGER NOT NULL,
    updated_at TEXT NOT NULL
);
