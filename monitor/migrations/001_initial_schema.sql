-- Create system_metrics table to store historical monitoring data
CREATE TABLE system_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    server_name TEXT NOT NULL,
    cpu_usage REAL,
    memory_total BIGINT,
    memory_used BIGINT,
    memory_free BIGINT,
    swap_total BIGINT,
    swap_used BIGINT,
    disk_total BIGINT,
    disk_used BIGINT,
    disk_free BIGINT,
    network_rx_bytes BIGINT,
    network_tx_bytes BIGINT,
    temperature REAL
);

-- Create index for faster queries
CREATE INDEX idx_system_metrics_timestamp ON system_metrics(timestamp);
CREATE INDEX idx_system_metrics_server_name ON system_metrics(server_name);

-- Create alerts table to store alert history
CREATE TABLE alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    server_name TEXT NOT NULL,
    rule_name TEXT NOT NULL,
    alert_type TEXT NOT NULL,
    message TEXT NOT NULL,
    threshold_value TEXT NOT NULL,
    actual_value TEXT NOT NULL,
    resolved_at DATETIME
);

-- Create index for alerts
CREATE INDEX idx_alerts_timestamp ON alerts(timestamp);
CREATE INDEX idx_alerts_server_name ON alerts(server_name);
CREATE INDEX idx_alerts_resolved ON alerts(resolved_at);

-- Create users table for authentication
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME
);

-- 无种子账号:初始 admin 由首次启动生成随机密码创建(db::bootstrap)
