-- Per-device detail behind each sample in `system_metrics`, as time ranges
-- rather than one row per sample.
--
-- A machine sampled every 7 seconds writes 12 000 rows a day per device if a
-- row means "one sample". Most of those rows say the same thing: a disk that
-- sat at 10 % all day is one fact, not twelve thousand. So a row here is an
-- interval — `start` to `end`, the value it held throughout — and a new row
-- is written only when the reading moves further than the table's threshold,
-- or when the device appears or disappears. An interval younger than
-- `MIN_SEGMENT` seconds is extended rather than cut, so sustained load
-- cannot turn the table back into one row per sample.
--
-- A window that predates migration 044 has no rows at all: a chart over it
-- shows the aggregate and a gap for the detail, never a backfilled value the
-- machine was never sampled with.

-- Every mount, not the largest few: a mount whose reading never moves is one
-- row for the whole retention window, which is cheaper than deciding which
-- few to keep.
CREATE TABLE metrics_disk_usage (
    mount TEXT NOT NULL,
    start DATETIME NOT NULL,
    end DATETIME NOT NULL,
    used BIGINT NOT NULL,
    total BIGINT NOT NULL,
    PRIMARY KEY (mount, start)
);
CREATE INDEX idx_metrics_disk_usage_end ON metrics_disk_usage(end);

-- Rates, not counters: a counter cannot be merged across an idle stretch
-- without losing the bytes that flowed during it, and an idle interface is
-- exactly what this table is meant to leave out.
CREATE TABLE metrics_iface (
    name TEXT NOT NULL,
    start DATETIME NOT NULL,
    end DATETIME NOT NULL,
    rx_bytes_per_sec REAL NOT NULL,
    tx_bytes_per_sec REAL NOT NULL,
    PRIMARY KEY (name, start)
);
CREATE INDEX idx_metrics_iface_end ON metrics_iface(end);

CREATE TABLE metrics_gpu (
    id TEXT NOT NULL,
    start DATETIME NOT NULL,
    end DATETIME NOT NULL,
    name TEXT NOT NULL,
    usage_percent REAL,
    memory_used BIGINT,
    memory_total BIGINT,
    PRIMARY KEY (id, start)
);
CREATE INDEX idx_metrics_gpu_end ON metrics_gpu(end);

CREATE TABLE metrics_temp (
    device TEXT NOT NULL,
    start DATETIME NOT NULL,
    end DATETIME NOT NULL,
    celsius REAL NOT NULL,
    PRIMARY KEY (device, start)
);
CREATE INDEX idx_metrics_temp_end ON metrics_temp(end);
