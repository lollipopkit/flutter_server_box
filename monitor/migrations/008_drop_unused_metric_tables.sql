-- These tables were populated on every collection cycle but never queried.
-- `cpu_core_metrics` multiplied one sample into one row per logical core;
-- velocity history is already kept in the bounded in-memory TimeSeries used
-- by the API and rules engine.
DROP TABLE IF EXISTS velocity_metrics;
DROP TABLE IF EXISTS cpu_core_metrics;

DELETE FROM retention_policies
WHERE table_name IN ('velocity_metrics', 'cpu_core_metrics');
