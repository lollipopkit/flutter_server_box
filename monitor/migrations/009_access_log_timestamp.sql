-- `access_log.timestamp` in the one text shape the rest of this database uses.
--
-- It was `DATETIME DEFAULT CURRENT_TIMESTAMP`, which writes
-- `2026-09-08 08:28:18`, while every timestamp the agent binds itself is a
-- `DateTime<Utc>` that sqlx encodes as RFC 3339
-- (`2026-09-08T08:28:18.493098803+00:00`). Retention compares this column
-- against a bound cutoff, SQLite compares the two as text, and `'T'` (0x54)
-- sorts above `' '` (0x20) — so the comparison only ever distinguished the
-- date, and every row from the cutoff's own day read as older than the cutoff
-- whatever its time. Up to a day of audit log past the cutoff was deleted on
-- each cleanup pass.
--
-- The default goes with it rather than being corrected. `NOT NULL` with
-- nothing to fall back on means a writer that forgets the column fails at the
-- insert, which is the failure this is trying not to have again; a default
-- that happens to produce the right text is a second encoder to keep in step
-- with chrono's.
--
-- No foreign key points at this table or out of it, so the rebuild needs
-- neither `foreign_keys` nor `legacy_alter_table` handling. Dropping the old
-- table takes its index with it, hence the recreate at the end.

CREATE TABLE access_log_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    -- 'ticket' | 'terminal'
    kind TEXT NOT NULL,
    -- 'open' | 'attach' | 'detach' | 'close' | 'denied'
    action TEXT NOT NULL,
    -- panel account (JWT subject)
    subject TEXT,
    remote_ip TEXT,
    -- system account for terminal sessions
    ssh_user TEXT,
    -- 'ok' | 'denied' | 'error'
    result TEXT NOT NULL,
    detail TEXT
);

-- `strftime` reads both shapes, so a row already written in the new one
-- survives this unchanged apart from losing sub-second digits it does not
-- have. A row whose timestamp is NULL — which the writer cannot produce, but
-- the nullable column allowed — is dated now rather than at the epoch: an
-- undatable audit record should expire a retention period from here, not be
-- collected on the first pass after this migration.
INSERT INTO access_log_new
    (id, timestamp, kind, action, subject, remote_ip, ssh_user, result, detail)
SELECT
    id,
    strftime('%Y-%m-%dT%H:%M:%S', COALESCE(timestamp, 'now')) || '+00:00',
    kind, action, subject, remote_ip, ssh_user, result, detail
FROM access_log;

DROP TABLE access_log;
ALTER TABLE access_log_new RENAME TO access_log;
CREATE INDEX idx_access_log_timestamp ON access_log(timestamp);
