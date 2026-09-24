-- The benchmark runs this agent has started.
--
-- The app keeps the same table (`lib/data/store/db.dart`, `BenchmarkRuns`),
-- for the same reason: a yabs run takes ten to twenty minutes and outlives the
-- connection that started it, so the record of one is written **before** the
-- run is started rather than after it finishes. Everything the far side
-- reported afterwards — the exit code, yabs' JSON, the log — is filled in by
-- whoever sees the run end.
--
-- One column is deliberately absent. There is no `server_id`: this agent *is*
-- the server, and a row here belongs to the machine it runs on.
--
-- `run_dir` is stored rather than derived from `options.work_dir`, which is
-- what `bench::poll_command` asks for by name: a run that is going has a
-- directory, and a later caller that re-derived it from changed code would look
-- somewhere the benchmark is not.
--
-- Timestamps are bound as RFC 3339 text by the writer, the shape migration 009
-- put `access_log.timestamp` into. `DEFAULT CURRENT_TIMESTAMP` is not used
-- here at all: it writes `YYYY-MM-DD HH:MM:SS`, which does not compare against
-- the text everything else in this database is written as.

CREATE TABLE benchmark_run (
    -- Minted by the agent per run. It is also what the run directory's `owner`
    -- file carries, and `bench::cleanup_command` refuses to remove a directory
    -- whose marker does not match — so this is what makes cleanup of a path
    -- built from a user-typed working directory safe.
    id TEXT PRIMARY KEY,
    started_at TEXT NOT NULL,
    finished_at TEXT,
    -- 'running' | 'completed' | 'failed' | 'cancelled'. Stored by name, never
    -- by index: these rows outlive the build that wrote them.
    status TEXT NOT NULL,
    -- `bench::BenchOptions` as JSON, so a result always says what produced it.
    options TEXT NOT NULL,
    run_dir TEXT NOT NULL,
    -- yabs' `-w` output, verbatim. Kept as the document it was rather than
    -- parsed: yabs assembles it with `+=` on a shell string, so a field it
    -- could not collect arrives as an empty slot and a distro name containing a
    -- quote produces a document no parser accepts. A later build can read what
    -- this one could not.
    result_json TEXT,
    -- What the run printed. The only record of a phase yabs skipped and why —
    -- "less than 2GB of space available" is here and nowhere in the JSON.
    log TEXT NOT NULL DEFAULT '',
    exit_code INTEGER,
    -- Why a run that has no exit code ended, in one of a few fixed phrases.
    -- Never what a command printed.
    error TEXT NOT NULL DEFAULT ''
);

-- The history list is newest first and that is the only way this table is read
-- as a whole.
CREATE INDEX idx_benchmark_run_started_at ON benchmark_run(started_at DESC);

-- At most one run at a time, enforced by the database rather than by a check
-- that two concurrent starts would both pass. A partial unique index is the one
-- place this can be said once and hold: the start path inserts, and a second
-- concurrent insert fails on the constraint instead of leaving two rows
-- claiming the same run directory.
CREATE UNIQUE INDEX idx_benchmark_run_single_running
    ON benchmark_run(status) WHERE status = 'running';
