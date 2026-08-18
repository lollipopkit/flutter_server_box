-- Add velocity metrics table for time series data processing
CREATE TABLE velocity_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    server_name TEXT NOT NULL,
    network_rx_speed REAL,    -- bytes per second
    network_tx_speed REAL,    -- bytes per second
    cpu_usage_percent REAL
);

-- Create indexes for performance
CREATE INDEX idx_velocity_metrics_timestamp ON velocity_metrics(timestamp);
CREATE INDEX idx_velocity_metrics_server_name ON velocity_metrics(server_name);
CREATE INDEX idx_velocity_metrics_composite ON velocity_metrics(server_name, timestamp);

-- Add network totals table to track cumulative data
CREATE TABLE network_totals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    server_name TEXT NOT NULL,
    interface TEXT NOT NULL,
    rx_bytes BIGINT,
    tx_bytes BIGINT
);

-- Create index for network totals
CREATE INDEX idx_network_totals_timestamp ON network_totals(timestamp);
CREATE INDEX idx_network_totals_server_interface ON network_totals(server_name, interface);

-- Add CPU core data table for detailed CPU tracking
CREATE TABLE cpu_core_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    server_name TEXT NOT NULL,
    core_id INTEGER NOT NULL,
    used_time BIGINT,
    total_time BIGINT,
    usage_percent REAL
);

-- Create index for CPU core metrics
CREATE INDEX idx_cpu_core_metrics_timestamp ON cpu_core_metrics(timestamp);
CREATE INDEX idx_cpu_core_metrics_server_core ON cpu_core_metrics(server_name, core_id);
CREATE INDEX idx_cpu_core_metrics_composite ON cpu_core_metrics(server_name, core_id, timestamp);