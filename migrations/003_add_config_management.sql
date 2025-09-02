-- Add configuration management tables for versioning and backup

-- Configuration versions table to store historical configurations
CREATE TABLE config_versions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version INTEGER NOT NULL UNIQUE,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    description TEXT,
    config_hash TEXT NOT NULL,
    config_json TEXT NOT NULL,
    created_by TEXT DEFAULT 'system',
    is_active BOOLEAN DEFAULT FALSE
);

-- Create indexes for configuration versions
CREATE INDEX idx_config_versions_version ON config_versions(version);
CREATE INDEX idx_config_versions_timestamp ON config_versions(timestamp);
CREATE INDEX idx_config_versions_hash ON config_versions(config_hash);
CREATE INDEX idx_config_versions_active ON config_versions(is_active);

-- Configuration changes audit log
CREATE TABLE config_audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    action_type TEXT NOT NULL, -- 'create', 'update', 'rollback', 'import', 'export'
    from_version INTEGER,
    to_version INTEGER,
    description TEXT,
    user_agent TEXT,
    ip_address TEXT,
    changes_summary TEXT -- JSON string describing what changed
);

-- Create indexes for audit log
CREATE INDEX idx_config_audit_timestamp ON config_audit_log(timestamp);
CREATE INDEX idx_config_audit_action ON config_audit_log(action_type);
CREATE INDEX idx_config_audit_versions ON config_audit_log(from_version, to_version);

-- Enhanced alerts table with more context for component-level monitoring
CREATE TABLE enhanced_alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    server_name TEXT NOT NULL,
    rule_name TEXT NOT NULL,
    monitor_type TEXT NOT NULL, -- 'cpu', 'memory', 'disk', 'network', 'temperature'
    component_name TEXT, -- specific component like 'cpu0', 'eth0', 'sda1', etc.
    threshold_operator TEXT NOT NULL, -- '>=', '<=', '>', '<', '==', '!='
    threshold_value REAL NOT NULL,
    threshold_unit TEXT, -- '%', 'B/s', '°C', etc.
    actual_value REAL NOT NULL,
    actual_formatted TEXT NOT NULL, -- human-readable value like "85.5%", "1.2 MB/s"
    message TEXT NOT NULL,
    severity TEXT DEFAULT 'warning', -- 'info', 'warning', 'critical'
    resolved_at DATETIME,
    resolution_type TEXT, -- 'auto', 'manual', 'timeout'
    config_version INTEGER,
    FOREIGN KEY (config_version) REFERENCES config_versions(version)
);

-- Create indexes for enhanced alerts
CREATE INDEX idx_enhanced_alerts_timestamp ON enhanced_alerts(timestamp);
CREATE INDEX idx_enhanced_alerts_server ON enhanced_alerts(server_name);
CREATE INDEX idx_enhanced_alerts_rule ON enhanced_alerts(rule_name);
CREATE INDEX idx_enhanced_alerts_type ON enhanced_alerts(monitor_type);
CREATE INDEX idx_enhanced_alerts_component ON enhanced_alerts(component_name);
CREATE INDEX idx_enhanced_alerts_severity ON enhanced_alerts(severity);
CREATE INDEX idx_enhanced_alerts_resolved ON enhanced_alerts(resolved_at);
CREATE INDEX idx_enhanced_alerts_composite ON enhanced_alerts(server_name, monitor_type, timestamp);

-- Component metrics for detailed monitoring
CREATE TABLE component_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    server_name TEXT NOT NULL,
    component_type TEXT NOT NULL, -- 'cpu_core', 'network_interface', 'disk_partition', 'temp_sensor'
    component_name TEXT NOT NULL, -- 'cpu0', 'eth0', '/dev/sda1', 'acpi_thermal_zone'
    metric_name TEXT NOT NULL, -- 'usage_percent', 'rx_speed', 'tx_speed', 'temperature'
    metric_value REAL NOT NULL,
    metric_unit TEXT, -- '%', 'B/s', '°C', 'RPM', etc.
    metadata TEXT -- JSON string for additional component-specific data
);

-- Create indexes for component metrics
CREATE INDEX idx_component_metrics_timestamp ON component_metrics(timestamp);
CREATE INDEX idx_component_metrics_server ON component_metrics(server_name);
CREATE INDEX idx_component_metrics_type ON component_metrics(component_type);
CREATE INDEX idx_component_metrics_name ON component_metrics(component_name);
CREATE INDEX idx_component_metrics_metric ON component_metrics(metric_name);
CREATE INDEX idx_component_metrics_composite ON component_metrics(server_name, component_type, component_name, timestamp);

-- Rule execution history for debugging and analytics
CREATE TABLE rule_executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    server_name TEXT NOT NULL,
    rule_name TEXT NOT NULL,
    execution_duration_ms INTEGER NOT NULL,
    result TEXT NOT NULL, -- 'no_alert', 'alert_triggered', 'error'
    error_message TEXT,
    actual_value REAL,
    threshold_met BOOLEAN,
    config_version INTEGER,
    FOREIGN KEY (config_version) REFERENCES config_versions(version)
);

-- Create indexes for rule executions
CREATE INDEX idx_rule_executions_timestamp ON rule_executions(timestamp);
CREATE INDEX idx_rule_executions_server_rule ON rule_executions(server_name, rule_name);
CREATE INDEX idx_rule_executions_result ON rule_executions(result);
CREATE INDEX idx_rule_executions_duration ON rule_executions(execution_duration_ms);

-- Performance metrics for system monitoring
CREATE TABLE performance_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    metric_type TEXT NOT NULL, -- 'monitoring_loop', 'rule_check', 'database_write', 'api_request'
    metric_name TEXT NOT NULL,
    duration_ms INTEGER,
    memory_usage_bytes BIGINT,
    cpu_usage_percent REAL,
    error_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    metadata TEXT -- JSON for additional context
);

-- Create indexes for performance metrics
CREATE INDEX idx_performance_metrics_timestamp ON performance_metrics(timestamp);
CREATE INDEX idx_performance_metrics_type ON performance_metrics(metric_type);
CREATE INDEX idx_performance_metrics_name ON performance_metrics(metric_name);

-- Data retention policy settings
CREATE TABLE retention_policies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name TEXT NOT NULL UNIQUE,
    retention_days INTEGER NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    last_cleanup DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Insert default retention policies
INSERT INTO retention_policies (table_name, retention_days) VALUES
('system_metrics', 90),           -- Keep system metrics for 90 days
('velocity_metrics', 30),         -- Keep velocity metrics for 30 days
('cpu_core_metrics', 7),          -- Keep CPU core metrics for 7 days
('network_totals', 30),           -- Keep network totals for 30 days
('enhanced_alerts', 365),         -- Keep alerts for 1 year
('component_metrics', 14),        -- Keep component metrics for 14 days
('rule_executions', 30),          -- Keep rule execution history for 30 days
('performance_metrics', 7),       -- Keep performance metrics for 7 days
('config_audit_log', 730);        -- Keep config audit log for 2 years

-- Migration tracking
INSERT INTO config_versions (version, description, config_hash, config_json, is_active)
VALUES (0, 'Initial migration - adding configuration management', 
        'migration_003', 
        '{"migration": "003_add_config_management", "timestamp": "' || datetime('now') || '"}',
        FALSE);