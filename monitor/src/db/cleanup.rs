use anyhow::Result;
use sqlx::SqlitePool;
use tracing::{info, warn, error};
use chrono::{Duration, Utc};
use crate::core::config::DataRetentionConfig;

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

    /// Time-series tables trimmed oldest-first when the database exceeds the
    /// size cap (allowlist, same injection rationale as POLICY_TABLES)
    const SIZE_CAPPED_TABLES: &'static [&'static str] = &[
        "system_metrics",
        "velocity_metrics",
        "cpu_core_metrics",
        "network_totals",
        "component_metrics",
        "rule_executions",
        "performance_metrics",
    ];

    /// Live data size: pages in use excluding the freelist, so deletions count
    /// immediately without waiting for VACUUM (the scheduler vacuums afterwards)
    async fn live_db_bytes(&self) -> Result<u64> {
        let page_count: i64 = sqlx::query_scalar("PRAGMA page_count").fetch_one(&self.pool).await?;
        let freelist: i64 = sqlx::query_scalar("PRAGMA freelist_count").fetch_one(&self.pool).await?;
        let page_size: i64 = sqlx::query_scalar("PRAGMA page_size").fetch_one(&self.pool).await?;
        Ok((page_count - freelist).max(0) as u64 * page_size.max(0) as u64)
    }

    /// Enforce `max_db_size_mb`: while over the cap, drop the oldest ~10% of
    /// each time-series table. Bounded iterations; 0 disables the cap.
    pub async fn enforce_db_size_limit(&self) -> Result<u64> {
        let max_bytes = self.config.max_db_size_mb.saturating_mul(1024 * 1024);
        if max_bytes == 0 {
            return Ok(0);
        }

        let mut deleted_total = 0u64;
        for _ in 0..10 {
            let size = self.live_db_bytes().await?;
            if size <= max_bytes {
                break;
            }
            let mut deleted_round = 0u64;
            for table in Self::SIZE_CAPPED_TABLES {
                let deleted = sqlx::query(sqlx::AssertSqlSafe(format!(
                    "DELETE FROM {table} WHERE rowid IN                      (SELECT rowid FROM {table} ORDER BY timestamp LIMIT                       (SELECT count(*) / 10 + 1 FROM {table}))"
                )))
                .execute(&self.pool)
                .await?
                .rows_affected();
                deleted_round += deleted;
            }
            deleted_total += deleted_round;
            // Nothing meaningful left to trim: schema/index overhead alone
            // exceeds the cap; stop rather than spin
            if deleted_round <= Self::SIZE_CAPPED_TABLES.len() as u64 {
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

    /// Cleanup driven by retention_policies. Table names are allowlisted against SQL
    /// injection; system_metrics/alerts are governed explicitly by DataRetentionConfig
    /// and excluded here
    const POLICY_TABLES: &'static [&'static str] = &[
        "velocity_metrics",
        "cpu_core_metrics",
        "network_totals",
        "enhanced_alerts",
        "component_metrics",
        "rule_executions",
        "performance_metrics",
        "config_audit_log",
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
            info!("Deleted {} old metrics records older than {} days", 
                  deleted_count, self.config.metrics_days);
        }

        Ok(deleted_count)
    }

    async fn cleanup_old_alerts(&self) -> Result<u64> {
        let cutoff_date = Utc::now() - Duration::days(self.config.alerts_days as i64);
        
        let result = sqlx::query!(
            "DELETE FROM alerts WHERE timestamp < ?",
            cutoff_date
        )
        .execute(&self.pool)
        .await?;

        let deleted_count = result.rows_affected();
        
        if deleted_count > 0 {
            info!("Deleted {} old alert records older than {} days", 
                  deleted_count, self.config.alerts_days);
        }

        Ok(deleted_count)
    }

    pub async fn get_data_statistics(&self) -> Result<DataStatistics> {
        let metrics_count = sqlx::query_scalar!(
            "SELECT COUNT(*) FROM system_metrics"
        )
        .fetch_one(&self.pool)
        .await?;

        let alerts_count = sqlx::query_scalar!(
            "SELECT COUNT(*) FROM alerts"
        )
        .fetch_one(&self.pool)
        .await?;

        let oldest_metric = sqlx::query_scalar!(
            "SELECT MIN(timestamp) FROM system_metrics"
        )
        .fetch_optional(&self.pool)
        .await?
        .flatten()
        .map(|dt| dt.to_string());

        let oldest_alert = sqlx::query_scalar!(
            "SELECT MIN(timestamp) FROM alerts"
        )
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
        
        sqlx::query("VACUUM")
            .execute(&self.pool)
            .await?;
            
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

pub async fn start_cleanup_scheduler(
    pool: SqlitePool,
    config: DataRetentionConfig,
) -> Result<()> {
    let cleanup_service = DataCleanupService::new(pool, config.clone());
    
    info!(
        "Starting data cleanup scheduler: metrics retention {} days, alerts retention {} days, cleanup interval {} hours",
        config.metrics_days, config.alerts_days, config.cleanup_interval_hours
    );

    tokio::spawn(async move {
        let mut interval = tokio::time::interval(
            tokio::time::Duration::from_secs(config.cleanup_interval_hours as u64 * 3600)
        );
        
        loop {
            interval.tick().await;
            
            if let Err(e) = cleanup_service.cleanup_expired_data().await {
                error!("Failed to cleanup expired data: {}", e);
            }
            
            if let Err(e) = cleanup_service.vacuum_database().await {
                warn!("Failed to vacuum database: {}", e);
            }
        }
    });

    Ok(())
}