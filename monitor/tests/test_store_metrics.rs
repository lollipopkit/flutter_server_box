use anyhow::Result;
use chrono::Utc;
use server_box_monitor::monitoring::{
    timeseries::CpuCoreTime, DiskMetrics, MemoryMetrics, NetworkMetrics,
    SwapMetrics, SystemMetrics,
};
use sqlx::{Row, SqlitePool};

async fn setup_test_db() -> Result<SqlitePool> {
    let pool = SqlitePool::connect("sqlite::memory:").await?;
    sqlx::migrate!("./migrations").run(&pool).await?;
    Ok(pool)
}

fn sample_metrics() -> SystemMetrics {
    SystemMetrics {
        timestamp: Utc::now(),
        extended_updated_at: Utc::now(),
        server_name: "test-server".to_string(),
        cpu_usage: 12.5,
        // The per-core table was removed. A non-empty snapshot proves storage
        // does not still attempt to write it.
        cpu_cores: vec![CpuCoreTime { used: 25, total: 100, usage_percent: Some(25.0) }],
        memory: MemoryMetrics { total: 100, used: 50, free: 50, usage_percent: 50.0 },
        swap: SwapMetrics { total: 0, used: 0, usage_percent: 0.0 },
        disk: DiskMetrics { total: 100, used: 50, free: 50, usage_percent: 50.0 },
        network: NetworkMetrics { rx_bytes: 0, tx_bytes: 0 },
        temperature: None,
        temps: vec![],
        sys: None,
        os_id: None,
        os_id_like: Vec::new(),
        cpu_brand: None,
        gpus: vec![],
        disk_details: vec![],
        ifaces: vec![],
        uptime: None,
        conn: None,
        diskio: vec![
            sbm_parser_types_diskio("sda", 2000, 1000),
            sbm_parser_types_diskio("sdb", 1000, 500),
        ],
        diskio_rate: vec![],
        batteries: vec![sbm_parser_types_battery(Some(77))],
        sensors: vec![],
        disk_smart: vec![],
        ips: vec![],
        custom_cmds: vec![],
        amd_cache: vec![],
    }
}

// Small local constructors so this test doesn't need to import sbm_parser
// directly just to build two fields' worth of nested structs
fn sbm_parser_types_diskio(dev: &str, read: i64, write: i64) -> sbm_parser::types::DiskIoPiece {
    sbm_parser::types::DiskIoPiece { dev: dev.to_string(), sectors_read: read, sectors_write: write }
}

fn sbm_parser_types_battery(percent: Option<i64>) -> sbm_parser::types::Battery {
    sbm_parser::types::Battery {
        percent,
        status: sbm_parser::types::BatteryStatus::Discharging,
        name: None,
        cycle: None,
        tech: None,
    }
}

/// diskio_read_bytes/diskio_write_bytes should be the SUM across all
/// devices (sectors * 512), and battery_percent should come from the first
/// battery — the same aggregation `get_metrics_history` assumes downstream
#[tokio::test]
async fn store_metrics_writes_diskio_and_battery_columns() -> Result<()> {
    let pool = setup_test_db().await?;
    let metrics = sample_metrics();

    server_box_monitor::monitoring::store_metrics(&pool, &metrics).await?;

    let row = sqlx::query("SELECT diskio_read_bytes, diskio_write_bytes, battery_percent FROM system_metrics")
        .fetch_one(&pool)
        .await?;

    let read_bytes: i64 = row.get("diskio_read_bytes");
    let write_bytes: i64 = row.get("diskio_write_bytes");
    let battery_percent: f64 = row.get("battery_percent");

    // (2000 + 1000) sectors * 512 bytes/sector
    assert_eq!(read_bytes, 3000 * 512);
    // (1000 + 500) sectors * 512 bytes/sector
    assert_eq!(write_bytes, 1500 * 512);
    assert_eq!(battery_percent, 77.0);

    Ok(())
}
