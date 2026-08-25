use crate::core::config::DataRetentionConfig;
use anyhow::Result;
use chrono::{Duration, Utc};
use sqlx::SqlitePool;
use tracing::{error, info, warn};

const MIN_AUDIT_ROWS: i64 = 100;

pub struct DataCleanupService {
    pool: SqlitePool,
    config: DataRetentionConfig,
}

impl DataCleanupService {
    pub fn new(pool: SqlitePool, config: DataRetentionConfig) -> Self {
        Self { pool, config }
    }

    pub async fn cleanup_expired_data(&self) -> Result<()> {
        let start_time = std::time::Instant::now();
        info!("Starting data cleanup task");

        let metrics_deleted = self.cleanup_old_metrics().await?;
        let alerts_deleted = self.cleanup_old_alerts().await?;
        let policy_deleted = self.cleanup_policy_tables().await?;
        let size_deleted = self.enforce_db_size_limit().await?;

        let duration = start_time.elapsed();
        info!(
            "Data cleanup completed in {:?}. Deleted {} metrics records, {} alerts records, {} policy-table records, {} size-cap records",
            duration, metrics_deleted, alerts_deleted, policy_deleted, size_deleted
        );

        Ok(())
    }

    /// Tables trimmed oldest-first when the database exceeds the size cap.
    /// Includes metric tables plus audit/access logs that would otherwise
    /// grow unbounded when retention is disabled; alert tables are handled
    /// separately via their own retention.
    const SIZE_CAPPED_TABLES: &'static [&'static str] = &[
        "system_metrics",
        "network_totals",
        "component_metrics",
        "rule_executions",
        "performance_metrics",
        "alerts",
        "enhanced_alerts",
        "config_audit_log",
        "access_log",
    ];

    /// Live data size: pages in use excluding the freelist, so deletions count
    /// immediately without requiring a blocking full-database VACUUM.
    async fn live_db_bytes(&self) -> Result<u64> {
        let page_count: i64 = sqlx::query_scalar("PRAGMA page_count")
            .fetch_one(&self.pool)
            .await?;
        let freelist: i64 = sqlx::query_scalar("PRAGMA freelist_count")
            .fetch_one(&self.pool)
            .await?;
        let page_size: i64 = sqlx::query_scalar("PRAGMA page_size")
            .fetch_one(&self.pool)
            .await?;
        Ok((page_count - freelist).max(0) as u64 * page_size.max(0) as u64)
    }

    /// Enforce `max_db_size_mb`: while over the cap, drop the oldest ~10% of
    /// each time-series table. Zero disables the cap.
    pub async fn enforce_db_size_limit(&self) -> Result<u64> {
        let max_bytes = self.config.max_db_size_mb.saturating_mul(1024 * 1024);
        if max_bytes == 0 {
            return Ok(0);
        }

        let mut deleted_total = 0u64;
        loop {
            let size = self.live_db_bytes().await?;
            if size <= max_bytes {
                break;
            }
            let mut deleted_round = 0u64;
            for table in Self::SIZE_CAPPED_TABLES {
                let keep = if matches!(*table, "config_audit_log" | "access_log") {
                    MIN_AUDIT_ROWS
                } else {
                    0
                };
                let deleted = self.trim_oldest(table, keep).await?;
                deleted_round += deleted;
                if self.live_db_bytes().await? <= max_bytes {
                    break;
                }
            }
            deleted_total += deleted_round;
            // Only stop when nothing was deletable; a sparse table set can
            // delete fewer than SIZE_CAPPED_TABLES rows yet still have rows
            // left, so breaking on <= len() would leave the DB over cap.
            if deleted_round == 0 {
                break;
            }
        }

        if deleted_total > 0 {
            warn!(
                "Database exceeded the {} MB size cap; deleted {} oldest time-series rows",
                self.config.max_db_size_mb, deleted_total
            );
        }
        Ok(deleted_total)
    }

    async fn trim_oldest(&self, table: &'static str, keep: i64) -> Result<u64> {
        Ok(sqlx::query(sqlx::AssertSqlSafe(format!(
            "DELETE FROM {table} WHERE rowid IN              (SELECT rowid FROM {table} ORDER BY timestamp LIMIT               (SELECT MIN(count(*) / 10 + 1, MAX(count(*) - {keep}, 0)) FROM {table}))"
        )))
        .execute(&self.pool)
        .await?
        .rows_affected())
    }

    /// Cleanup driven by retention_policies. Table names are allowlisted against SQL
    /// injection; system_metrics/alerts are governed explicitly by DataRetentionConfig
    /// and excluded here
    const POLICY_TABLES: &'static [&'static str] = &[
        "network_totals",
        "enhanced_alerts",
        "component_metrics",
        "rule_executions",
        "performance_metrics",
        "config_audit_log",
        "access_log",
    ];

    async fn cleanup_policy_tables(&self) -> Result<u64> {
        use sqlx::Row;

        let policies = sqlx::query(
            "SELECT table_name, retention_days FROM retention_policies WHERE enabled = 1",
        )
        .fetch_all(&self.pool)
        .await?;

        let mut total = 0u64;
        for p in policies {
            let table_name: String = p.get("table_name");
            let retention_days: i64 = p.get("retention_days");
            let Some(&table) = Self::POLICY_TABLES.iter().find(|t| **t == table_name) else {
                continue;
            };
            if retention_days <= 0 {
                warn!(
                    "Ignoring invalid retention policy for {}: {} days",
                    table, retention_days
                );
                continue;
            }
            let cutoff = Utc::now() - Duration::days(retention_days);
            // Table name comes from the &'static str allowlist above; injection is impossible
            let deleted = sqlx::query(sqlx::AssertSqlSafe(format!(
                "DELETE FROM {table} WHERE timestamp < ?"
            )))
            .bind(cutoff)
            .execute(&self.pool)
            .await?
            .rows_affected();
            if deleted > 0 {
                info!(
                    "Deleted {} rows from {} older than {} days",
                    deleted, table, retention_days
                );
            }
            sqlx::query(
                "UPDATE retention_policies SET last_cleanup = CURRENT_TIMESTAMP WHERE table_name = ?",
            )
            .bind(table)
            .execute(&self.pool)
            .await?;
            total += deleted;
        }
        Ok(total)
    }

    async fn cleanup_old_metrics(&self) -> Result<u64> {
        let cutoff_date = Utc::now() - Duration::days(self.config.metrics_days as i64);

        let result = sqlx::query!(
            "DELETE FROM system_metrics WHERE timestamp < ?",
            cutoff_date
        )
        .execute(&self.pool)
        .await?;

        let deleted_count = result.rows_affected();

        if deleted_count > 0 {
            info!(
                "Deleted {} old metrics records older than {} days",
                deleted_count, self.config.metrics_days
            );
        }

        Ok(deleted_count)
    }

    async fn cleanup_old_alerts(&self) -> Result<u64> {
        let cutoff_date = Utc::now() - Duration::days(self.config.alerts_days as i64);

        let result = sqlx::query!("DELETE FROM alerts WHERE timestamp < ?", cutoff_date)
            .execute(&self.pool)
            .await?;

        let deleted_count = result.rows_affected();

        if deleted_count > 0 {
            info!(
                "Deleted {} old alert records older than {} days",
                deleted_count, self.config.alerts_days
            );
        }

        Ok(deleted_count)
    }

    pub async fn get_data_statistics(&self) -> Result<DataStatistics> {
        let metrics_count = sqlx::query_scalar!("SELECT COUNT(*) FROM system_metrics")
            .fetch_one(&self.pool)
            .await?;

        let alerts_count = sqlx::query_scalar!("SELECT COUNT(*) FROM alerts")
            .fetch_one(&self.pool)
            .await?;

        let oldest_metric = sqlx::query_scalar!("SELECT MIN(timestamp) FROM system_metrics")
            .fetch_optional(&self.pool)
            .await?
            .flatten()
            .map(|dt| dt.to_string());

        let oldest_alert = sqlx::query_scalar!("SELECT MIN(timestamp) FROM alerts")
            .fetch_optional(&self.pool)
            .await?
            .flatten()
            .map(|dt| dt.to_string());

        Ok(DataStatistics {
            metrics_count: metrics_count as u64,
            alerts_count: alerts_count as u64,
            oldest_metric,
            oldest_alert,
        })
    }

    pub async fn vacuum_database(&self) -> Result<()> {
        info!("Running database VACUUM to reclaim space");

        let start_time = std::time::Instant::now();

        sqlx::query("VACUUM").execute(&self.pool).await?;

        let duration = start_time.elapsed();
        info!("Database VACUUM completed in {:?}", duration);

        Ok(())
    }
}

#[derive(Debug, Clone)]
pub struct DataStatistics {
    pub metrics_count: u64,
    pub alerts_count: u64,
    pub oldest_metric: Option<String>,
    pub oldest_alert: Option<String>,
}

pub async fn start_cleanup_scheduler(pool: SqlitePool, config: DataRetentionConfig) -> Result<()> {
    config.validate().map_err(anyhow::Error::msg)?;
    let cleanup_service = DataCleanupService::new(pool, config.clone());

    info!(
        "Starting data cleanup scheduler: metrics retention {} days, alerts retention {} days, cleanup interval {} hours",
        config.metrics_days, config.alerts_days, config.cleanup_interval_hours
    );

    tokio::spawn(async move {
        let cleanup_period =
            tokio::time::Duration::from_secs(config.cleanup_interval_hours as u64 * 3600);
        let vacuum_period = cleanup_period.saturating_mul(7);
        let mut interval = tokio::time::interval(cleanup_period);
        let mut vacuum =
            tokio::time::interval_at(tokio::time::Instant::now() + vacuum_period, vacuum_period);

        loop {
            tokio::select! {
                _ = interval.tick() => {
                    if let Err(e) = cleanup_service.cleanup_expired_data().await {
                        error!("Failed to cleanup expired data: {}", e);
                    }
                }
                _ = vacuum.tick() => {
                    if let Err(e) = cleanup_service.vacuum_database().await {
                        error!("Failed to vacuum database: {}", e);
                    }
                }
            }
        }
    });

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use sqlx::sqlite::SqlitePoolOptions;

    #[tokio::test]
    async fn size_cap_includes_alerts_and_preserves_recent_audit_rows() {
        assert!(DataCleanupService::SIZE_CAPPED_TABLES.contains(&"alerts"));

        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect("sqlite::memory:")
            .await
            .unwrap();
        sqlx::query("CREATE TABLE config_audit_log (timestamp INTEGER NOT NULL)")
            .execute(&pool)
            .await
            .unwrap();
        for timestamp in 0..150 {
            sqlx::query("INSERT INTO config_audit_log (timestamp) VALUES (?)")
                .bind(timestamp)
                .execute(&pool)
                .await
                .unwrap();
        }

        let cleanup = DataCleanupService::new(pool.clone(), DataRetentionConfig::default());
        while cleanup
            .trim_oldest("config_audit_log", MIN_AUDIT_ROWS)
            .await
            .unwrap()
            > 0
        {}

        let remaining: i64 = sqlx::query_scalar("SELECT count(*) FROM config_audit_log")
            .fetch_one(&pool)
            .await
            .unwrap();
        assert_eq!(remaining, MIN_AUDIT_ROWS);
    }
}
