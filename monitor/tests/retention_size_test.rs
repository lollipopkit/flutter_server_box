//! Size-cap retention: oldest time-series rows are dropped until the
//! database fits under max_db_size_mb.

use server_box_monitor::core::config::DataRetentionConfig;
use server_box_monitor::db::cleanup::DataCleanupService;
use server_box_monitor::db::database;

#[tokio::test]
async fn size_cap_drops_oldest_rows() {
    let dir = std::env::temp_dir().join("sbm_size_cap_test");
    std::fs::remove_dir_all(&dir).ok();
    std::fs::create_dir_all(&dir).unwrap();
    let db_path = dir.join("cap.db");
    let pool = database::init(&format!("sqlite:{}", db_path.display())).await.unwrap();

    // Bloat well past 1 MB with padded rows; timestamps ascending so
    // "oldest first" is meaningful
    let pad = "x".repeat(512);
    for i in 0..4000i64 {
        sqlx::query(
            "INSERT INTO system_metrics (
                timestamp, server_name, cpu_usage, memory_total, memory_used, memory_free,
                swap_total, swap_used, disk_total, disk_used, disk_free,
                network_rx_bytes, network_tx_bytes, temperature
            ) VALUES (datetime('2026-01-01', ?1 || ' seconds'), ?2, 1.0, 1, 1, 0, 0, 0, 1, 1, 0, ?3, ?3, NULL)",
        )
        .bind(i)
        .bind(format!("srv-{pad}"))
        .bind(i)
        .execute(&pool)
        .await
        .unwrap();
    }

    let before: i64 = sqlx::query_scalar("SELECT count(*) FROM system_metrics")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(before, 4000);

    let service = DataCleanupService::new(
        pool.clone(),
        DataRetentionConfig {
            metrics_days: 3650, // day-based retention must not interfere
            alerts_days: 3650,
            cleanup_interval_hours: 24,
            max_db_size_mb: 1,
        },
    );
    let deleted = service.enforce_db_size_limit().await.unwrap();
    assert!(deleted > 0, "over-cap database must shed rows");

    let page_count: i64 = sqlx::query_scalar("PRAGMA page_count")
        .fetch_one(&pool)
        .await
        .unwrap();
    let freelist: i64 = sqlx::query_scalar("PRAGMA freelist_count")
        .fetch_one(&pool)
        .await
        .unwrap();
    let page_size: i64 = sqlx::query_scalar("PRAGMA page_size")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert!(
        (page_count - freelist) * page_size <= 1024 * 1024,
        "cleanup must continue until the live database fits the hard cap"
    );

    let after: i64 = sqlx::query_scalar("SELECT count(*) FROM system_metrics")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert!(after < before, "row count must shrink ({before} -> {after})");

    // Survivors are the newest rows: the oldest remaining marker is higher
    // than the number of dropped rows implies for an oldest-first policy
    let min_rx: i64 = sqlx::query_scalar("SELECT min(network_rx_bytes) FROM system_metrics")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(min_rx as i64 + after, 4000, "deletions must be oldest-first");

    // Disabled cap deletes nothing
    let service_off = DataCleanupService::new(
        pool.clone(),
        DataRetentionConfig {
            metrics_days: 3650,
            alerts_days: 3650,
            cleanup_interval_hours: 24,
            max_db_size_mb: 0,
        },
    );
    assert_eq!(service_off.enforce_db_size_limit().await.unwrap(), 0);

    pool.close().await;
    std::fs::remove_dir_all(&dir).ok();
}
