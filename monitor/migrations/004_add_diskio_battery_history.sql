-- Trend history for diskio (cumulative bytes, summed across all devices —
-- same shape as network_rx_bytes/network_tx_bytes) and battery percent
-- (first battery only, matching the home page card's existing behavior).
-- sensors/disk_smart are intentionally left out: no single numeric trend to
-- chart (arbitrary key-value readings / health+temperature better suited to
-- alerts than a line chart).
ALTER TABLE system_metrics ADD COLUMN diskio_read_bytes BIGINT;
ALTER TABLE system_metrics ADD COLUMN diskio_write_bytes BIGINT;
ALTER TABLE system_metrics ADD COLUMN battery_percent REAL;
