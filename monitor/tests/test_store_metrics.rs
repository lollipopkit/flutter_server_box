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
        block_devices: vec![],
        swap_areas: vec![],
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

    server_box_monitor::monitoring::store_metrics(&pool, &metrics, None).await?;

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

/// The detail tables hold stretches, not samples: a reading that does not
/// move occupies one row however often it is sampled, and one that moves
/// opens a new row.
#[tokio::test]
async fn a_detail_reading_that_does_not_move_is_one_row() -> Result<()> {
    use chrono::Duration;

    let pool = setup_test_db().await?;
    let mut metrics = sample_metrics();
    metrics.disk_details = vec![server_box_monitor::monitoring::DiskDetail {
        path: "/dev/sda1".into(),
        mount: "/".into(),
        fs_type: Some("ext4".into()),
        used: 40,
        total: 100,
        usage_percent: 40.0,
    }];

    // Ten samples a minute apart, every one of them at 40 %: the whole run is
    // one stretch. The loop's prev is the cycle before, as the monitor's own
    // sampling loop passes it.
    let start = Utc::now();
    let mut prev: Option<SystemMetrics> = None;
    for i in 0..10 {
        metrics.timestamp = start + Duration::minutes(i);
        let prev_ref = prev.as_ref();
        server_box_monitor::monitoring::store_metrics(&pool, &metrics, prev_ref).await?;
        prev = Some(metrics.clone());
    }

    let (count,): (i64,) = sqlx::query_as("SELECT count(*) FROM metrics_disk_usage")
        .fetch_one(&pool)
        .await?;
    assert_eq!(count, 1, "ten unchanged samples are one stretch");

    let (end,): (chrono::DateTime<Utc>,) =
        sqlx::query_as("SELECT end FROM metrics_disk_usage LIMIT 1")
            .fetch_one(&pool)
            .await?;
    assert_eq!(end, start + Duration::minutes(9), "the stretch runs to the last sample");

    // And one that moves opens a second row, while extending the closed row to
    // the transition instant so there is no gap between them.
    metrics.timestamp = start + Duration::minutes(10);
    metrics.disk_details[0].used = 90;
    let prev_ref = prev.as_ref();
    server_box_monitor::monitoring::store_metrics(&pool, &metrics, prev_ref).await?;
    let (count,): (i64,) = sqlx::query_as("SELECT count(*) FROM metrics_disk_usage")
        .fetch_one(&pool)
        .await?;
    assert_eq!(count, 2, "a moved reading opens a new stretch");

    let rows: Vec<(chrono::DateTime<Utc>, chrono::DateTime<Utc>, i64)> =
        sqlx::query_as("SELECT start, end, used FROM metrics_disk_usage ORDER BY start")
            .fetch_all(&pool)
            .await?;
    assert_eq!(rows[0].1, rows[1].0, "contiguous cut leaves no gap");
    assert_eq!(rows[1].2, 90);

    Ok(())
}

#[tokio::test]
async fn duplicate_mounts_do_not_fail_and_young_ifaces_blend() -> Result<()> {
    use chrono::Duration;
    use server_box_monitor::monitoring::{DiskDetail, IfaceMetrics};

    let pool = setup_test_db().await?;
    let start = Utc::now();

    let mut m0 = sample_metrics();
    m0.timestamp = start;
    m0.disk_details = vec![
        DiskDetail {
            path: "/dev/sda1".into(),
            mount: "/".into(),
            fs_type: Some("ext4".into()),
            used: 40,
            total: 100,
            usage_percent: 40.0,
        },
        DiskDetail {
            path: "overmount".into(),
            mount: "/".into(),
            fs_type: Some("overlay".into()),
            used: 80,
            total: 100,
            usage_percent: 80.0,
        },
    ];
    m0.ifaces = vec![IfaceMetrics {
        name: "eth0".into(),
        rx_bytes: 0,
        tx_bytes: 0,
    }];
    server_box_monitor::monitoring::store_metrics(&pool, &m0, None).await?;

    // Cycle 1 (+7s): just above IFACE_FLOOR (~11 KB/s) -> opens [start, start+7s].
    let mut m1 = m0.clone();
    m1.timestamp = start + Duration::seconds(7);
    m1.ifaces[0].rx_bytes = 77_000;
    server_box_monitor::monitoring::store_metrics(&pool, &m1, Some(&m0)).await?;

    // Cycle 2 (+14s): ramps to 1 MB/s within MIN_SEGMENT -> blends rather than freezing 11 KB/s.
    let mut m2 = m1.clone();
    m2.timestamp = start + Duration::seconds(14);
    m2.ifaces[0].rx_bytes = 77_000 + 7_000_000;
    server_box_monitor::monitoring::store_metrics(&pool, &m2, Some(&m1)).await?;

    let (disk_count,): (i64,) = sqlx::query_as("SELECT count(*) FROM metrics_disk_usage")
        .fetch_one(&pool)
        .await?;
    assert_eq!(disk_count, 1, "duplicate mount is deduplicated without error");

    let (iface_start, iface_end, rx): (chrono::DateTime<Utc>, chrono::DateTime<Utc>, f64) =
        sqlx::query_as(
            "SELECT start, end, rx_bytes_per_sec FROM metrics_iface WHERE name = 'eth0'",
        )
        .fetch_one(&pool)
        .await?;
    assert_eq!(iface_start, start);
    assert_eq!(iface_end, start + Duration::seconds(14));
    assert!(
        rx > 400_000.0 && rx < 600_000.0,
        "expected blended ramp rate around 505 KB/s, got {rx}"
    );

    Ok(())
}

#[tokio::test]
async fn gpus_temps_and_disk_boundaries_store_cleanly() -> Result<()> {
    use chrono::Duration;
    use server_box_monitor::monitoring::{DiskDetail, GpuMetrics, TempReading};

    let pool = setup_test_db().await?;
    let start = Utc::now();

    let mut m0 = sample_metrics();
    m0.timestamp = start;
    m0.disk_details = vec![DiskDetail {
        path: "/dev/sda1".into(),
        mount: "/".into(),
        fs_type: Some("ext4".into()),
        used: 100,
        total: 1000,
        usage_percent: 10.0,
    }];
    m0.gpus = vec![GpuMetrics {
        id: "gpu0".into(),
        vendor: "nvidia".into(),
        name: "RTX".into(),
        usage_percent: Some(10.0),
        temperature: None,
        power: None,
        memory_used: None,
        memory_total: None,
        memory_unit: None,
        fan_speed: None,
        clock_speed: None,
        processes: Vec::new(),
    }];
    m0.temps = vec![TempReading {
        device: "coretemp".into(),
        value: 40.0,
    }];
    server_box_monitor::monitoring::store_metrics(&pool, &m0, None).await?;

    // +10s (within MIN_SEGMENT): GPU memory changes from None -> Some(0), disk jumps 100 -> 500, temp 40 -> 50.
    let mut m1 = m0.clone();
    m1.timestamp = start + Duration::seconds(10);
    m1.disk_details[0].used = 500;
    m1.gpus[0].usage_percent = Some(50.0);
    m1.gpus[0].memory_used = Some(0);
    m1.gpus[0].memory_total = Some(0);
    m1.temps[0].value = 50.0;
    server_box_monitor::monitoring::store_metrics(&pool, &m1, Some(&m0)).await?;

    // Same timestamp (at <= end) must be skipped without primary key failure.
    server_box_monitor::monitoring::store_metrics(&pool, &m1, Some(&m0)).await?;

    // +3610s (>= MAX_SEGMENT): cuts even if unchanged.
    let mut m2 = m1.clone();
    m2.timestamp = start + Duration::seconds(3610);
    server_box_monitor::monitoring::store_metrics(&pool, &m2, Some(&m1)).await?;

    // Device missing for one cycle, then returns at same value -> new stretch, gap left open.
    let mut m3 = m2.clone();
    m3.timestamp = start + Duration::seconds(3620);
    m3.temps.clear();
    server_box_monitor::monitoring::store_metrics(&pool, &m3, Some(&m2)).await?;

    let mut m4 = m2.clone();
    m4.timestamp = start + Duration::seconds(3630);
    server_box_monitor::monitoring::store_metrics(&pool, &m4, Some(&m3)).await?;

    let (disk_rows,): (i64,) = sqlx::query_as("SELECT count(*) FROM metrics_disk_usage")
        .fetch_one(&pool)
        .await?;
    assert_eq!(disk_rows, 2, "blended inside MIN_SEGMENT, then cut at MAX_SEGMENT");

    let (gpu_rows,): (i64,) = sqlx::query_as("SELECT count(*) FROM metrics_gpu")
        .fetch_one(&pool)
        .await?;
    // Memory appearing (None -> Some) opens a stretch even inside MIN_SEGMENT,
    // then MAX_SEGMENT cuts once more.
    assert_eq!(gpu_rows, 3);

    let temp_rows: Vec<(chrono::DateTime<Utc>, chrono::DateTime<Utc>, f64)> =
        sqlx::query_as("SELECT start, end, celsius FROM metrics_temp ORDER BY start")
            .fetch_all(&pool)
            .await?;
    assert_eq!(temp_rows.len(), 3, "young blend -> MAX_SEGMENT cut -> gap reopen");
    assert!(
        (temp_rows[0].2 - 45.0).abs() < 1e-6,
        "expected blended 45.0C, got {}",
        temp_rows[0].2
    );
    assert_eq!(temp_rows[1].1, m2.timestamp, "ended when last seen before gap");
    assert_eq!(temp_rows[2].0, m4.timestamp, "reopened as a fresh stretch after gap");

    Ok(())
}
