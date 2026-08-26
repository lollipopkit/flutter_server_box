use anyhow::Result;
use chrono::{Duration, Utc};
use server_box_monitor::db::cleanup::{DataCleanupService, start_cleanup_scheduler};
use server_box_monitor::core::config::DataRetentionConfig;
use sqlx::SqlitePool;

async fn setup_test_db() -> Result<SqlitePool> {
    let db_url = "sqlite::memory:";
    let pool = SqlitePool::connect(db_url).await?;
    
    // Run migrations
    sqlx::migrate!("./migrations").run(&pool).await?;
    
    Ok(pool)
}

#[tokio::test]
async fn test_cleanup_service_creation() -> Result<()> {
    let pool = setup_test_db().await?;
    let config = DataRetentionConfig {
        metrics_days: 30,
        alerts_days: 90,
        cleanup_interval_hours: 24,
        max_db_size_mb: 256,
    };
    
    let cleanup_service = DataCleanupService::new(pool, config);
    
    // Test getting statistics on empty database
    let stats = cleanup_service.get_data_statistics().await?;
    assert_eq!(stats.metrics_count, 0);
    assert_eq!(stats.alerts_count, 0);
    assert!(stats.oldest_metric.is_none());
    assert!(stats.oldest_alert.is_none());
    
    Ok(())
}

#[tokio::test]
async fn test_cleanup_with_test_data() -> Result<()> {
    let pool = setup_test_db().await?;
    let config = DataRetentionConfig {
        metrics_days: 7,
        alerts_days: 14,
        cleanup_interval_hours: 24,
        max_db_size_mb: 256,
    };
    
    // Insert old test data
    let old_date = Utc::now() - Duration::days(10);
    let recent_date = Utc::now() - Duration::days(1);
    
    // Insert old and recent metrics
    sqlx::query!(
        "INSERT INTO system_metrics (timestamp, server_name, cpu_usage) VALUES (?, ?, ?)",
        old_date,
        "test-server",
        50.0
    ).execute(&pool).await?;
    
    sqlx::query!(
        "INSERT INTO system_metrics (timestamp, server_name, cpu_usage) VALUES (?, ?, ?)",
        recent_date,
        "test-server",
        60.0
    ).execute(&pool).await?;
    
    // Insert old and recent alerts
    sqlx::query!(
        "INSERT INTO alerts (timestamp, server_name, rule_name, alert_type, message, threshold_value, actual_value) VALUES (?, ?, ?, ?, ?, ?, ?)",
        old_date,
        "test-server",
        "test-rule",
        "cpu",
        "High CPU",
        "80%",
        "85%"
    ).execute(&pool).await?;
    
    sqlx::query!(
        "INSERT INTO alerts (timestamp, server_name, rule_name, alert_type, message, threshold_value, actual_value) VALUES (?, ?, ?, ?, ?, ?, ?)",
        recent_date,
        "test-server",
        "test-rule",
        "cpu",
        "High CPU",
        "80%",
        "85%"
    ).execute(&pool).await?;
    
    let cleanup_service = DataCleanupService::new(pool, config);
    
    // Check initial counts
    let initial_stats = cleanup_service.get_data_statistics().await?;
    assert_eq!(initial_stats.metrics_count, 2);
    assert_eq!(initial_stats.alerts_count, 2);
    
    // Run cleanup
    cleanup_service.cleanup_expired_data().await?;
    
    // Check final counts - old metrics should be deleted but not old alerts (14 day retention vs 10 day old data)
    let final_stats = cleanup_service.get_data_statistics().await?;
    assert_eq!(final_stats.metrics_count, 1); // Only recent metric remains
    assert_eq!(final_stats.alerts_count, 2);  // Both alerts remain (within 14 days)
    
    Ok(())
}

#[tokio::test]
async fn test_vacuum_database() -> Result<()> {
    let pool = setup_test_db().await?;
    let config = DataRetentionConfig {
        metrics_days: 30,
        alerts_days: 90,
        cleanup_interval_hours: 24,
        max_db_size_mb: 256,
    };
    
    let cleanup_service = DataCleanupService::new(pool, config);
    
    // This should not fail
    cleanup_service.vacuum_database().await?;
    
    Ok(())
}

#[test]
fn a_zero_cleanup_interval_is_rejected() {
    let config = DataRetentionConfig {
        metrics_days: 30,
        alerts_days: 90,
        cleanup_interval_hours: 0,
        max_db_size_mb: 256,
    };

    assert_eq!(
        config.validate().unwrap_err(),
        "data_retention.cleanup_interval_hours must be at least 1"
    );
}

#[test]
fn zero_retention_windows_are_rejected() {
    let mut config = DataRetentionConfig {
        metrics_days: 0,
        alerts_days: 90,
        cleanup_interval_hours: 24,
        max_db_size_mb: 256,
    };
    assert_eq!(
        config.validate().unwrap_err(),
        "data_retention.metrics_days must be at least 1"
    );

    config.metrics_days = 30;
    config.alerts_days = 0;
    assert_eq!(
        config.validate().unwrap_err(),
        "data_retention.alerts_days must be at least 1"
    );
}

#[tokio::test]
async fn a_negative_table_policy_does_not_delete_current_data() -> Result<()> {
    let pool = setup_test_db().await?;
    sqlx::query("UPDATE retention_policies SET retention_days = -1 WHERE table_name = 'access_log'")
        .execute(&pool)
        .await?;
    sqlx::query(
        "INSERT INTO access_log (kind, action, result) VALUES ('terminal', 'open', 'ok')",
    )
    .execute(&pool)
    .await?;

    let service = DataCleanupService::new(
        pool.clone(),
        DataRetentionConfig {
            metrics_days: 30,
            alerts_days: 90,
            cleanup_interval_hours: 24,
            max_db_size_mb: 0,
        },
    );
    service.cleanup_expired_data().await?;

    let count: i64 = sqlx::query_scalar("SELECT count(*) FROM access_log")
        .fetch_one(&pool)
        .await?;
    assert_eq!(count, 1);
    Ok(())
}

#[tokio::test]
async fn the_cleanup_scheduler_refuses_a_zero_interval_before_spawning() -> Result<()> {
    let pool = setup_test_db().await?;
    let config = DataRetentionConfig {
        metrics_days: 30,
        alerts_days: 90,
        cleanup_interval_hours: 0,
        max_db_size_mb: 256,
    };

    assert!(start_cleanup_scheduler(pool, config).await.is_err());
    Ok(())
}
