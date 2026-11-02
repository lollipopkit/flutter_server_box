-- The Storage app's maintenance schedule (`storage_watch`): one row per task
-- that is on. `task` is scrub (every pool scrubbed, every redundant md array
-- checked), smartShort or smartLong (a SMART self-test on every disk that
-- answers SMART); `every` weekly (`day` 0 Monday … 6 Sunday) or monthly
-- (`day` 1 … 28), at `at` (HH:MM, the machine's time). Text times are
-- RFC 3339.
CREATE TABLE storage_maintenance (
    task TEXT PRIMARY KEY CHECK (task IN ('scrub', 'smartShort', 'smartLong')),
    every TEXT NOT NULL CHECK (every IN ('weekly', 'monthly')),
    at TEXT NOT NULL,
    day INTEGER NOT NULL CHECK (day BETWEEN 0 AND 28),
    last_run TEXT,
    last_error TEXT,
    updated_by TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
