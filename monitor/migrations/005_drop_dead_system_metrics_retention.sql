-- retention_policies seeded a 'system_metrics' row (90 days) in migration 003,
-- but the cleanup service never honors it: DataCleanupService::POLICY_TABLES
-- deliberately excludes system_metrics because its retention is owned by
-- DataRetentionConfig.metrics_days (config.toml / SBM env). The row was a
-- second, silently-ignored source of truth — editing it did nothing.
--
-- 'alerts' is likewise owned by DataRetentionConfig.alerts_days and was never
-- seeded here; 'enhanced_alerts' is a different table and stays policy-driven.
DELETE FROM retention_policies WHERE table_name = 'system_metrics';
