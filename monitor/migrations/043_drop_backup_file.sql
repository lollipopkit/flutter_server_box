-- The blob store `api::backup` kept for the app's backup sync, which the app
-- no longer uses: its rows go, and `core::blobs` removes the files no row
-- names any more at the next start. `backup_blob` (migration 015) is dropped
-- too, for an agent that never ran `move_database_backups`.

DROP TABLE IF EXISTS backup_file;
DROP TABLE IF EXISTS backup_blob;
