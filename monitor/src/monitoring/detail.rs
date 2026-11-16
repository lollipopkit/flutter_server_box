//! Per-device detail for `system_metrics`, stored as time ranges.
//!
//! A monitor samples every cycle, and every cycle writes one aggregate row.
//! Writing the devices behind that row the same way turns a 7-second
//! interval into 12 000 rows a day per mount — almost all of them saying what
//! the rows before them said. What a reader wants from a past window is
//! "this disk was at 10 % for six hours", and that is one fact however many
//! times it was sampled.
//!
//! So each device gets a row per *stretch*, not per sample: `start` to `end`
//! and the value held throughout. A new stretch opens when the reading moves
//! further than [`Change`] allows, when the device appears, or when the
//! previous stretch has been open for [`MAX_SEGMENT`] — the last so a value
//! that drifts slowly still splits into answerable chunks. A stretch younger
//! than [`MIN_SEGMENT`] is extended regardless, because otherwise a busy
//! device would open a new row at every sample and the table would be back to
//! one row per sample with extra steps.
//!
//! Storage for a machine that does not change: one row per device per
//! [`MAX_SEGMENT`], so four devices at the cap are ~2 880 rows a day shared
//! across the detail tables — against 49 000 for one row per sample.

use chrono::{DateTime, Duration, Utc};
use sqlx::SqlitePool;

use crate::utils::error::Result;
use super::metrics::SystemMetrics;

/// A stretch too young to cut, however far the reading moved: a device
/// working hard moves further than the threshold every cycle, and cutting
/// there is one row per sample again.
const MIN_SEGMENT: Duration = Duration::seconds(30);

/// A stretch older than this is closed and reopened even without a change,
/// so a value that drifts by less than the threshold still leaves a trail of
/// points a chart can draw over days rather than one flat row.
const MAX_SEGMENT: Duration = Duration::hours(1);

// ---------------------------------------------------------------------------
// The per-device readings, as they come out of one sample. `values` is the
// reading as the columns hold it, in the order the INSERT binds them; a
// reading the device does not report is NaN, which compares as itself below.
// ---------------------------------------------------------------------------

#[derive(Clone, Copy)]
pub(super) struct DiskUsage {
    pub(super) used: u64,
    pub(super) total: u64,
}

impl DiskUsage {
    fn values(self) -> [f64; 2] {
        [self.used as f64, self.total as f64]
    }
}

#[derive(Clone, Copy)]
pub(super) struct IfaceRate {
    pub(super) rx: f64,
    pub(super) tx: f64,
}

impl IfaceRate {
    fn values(self) -> [f64; 2] {
        [self.rx, self.tx]
    }
}

#[derive(Clone, Copy)]
pub(super) struct GpuUsage {
    pub(super) usage: Option<f64>,
    pub(super) mem_used: Option<i64>,
    pub(super) mem_total: Option<i64>,
}

impl GpuUsage {
    fn values(self) -> [f64; 3] {
        [
            self.usage.unwrap_or(f64::NAN),
            self.mem_used.unwrap_or(-1) as f64,
            self.mem_total.unwrap_or(-1) as f64,
        ]
    }
}

#[derive(Clone, Copy)]
pub(super) struct Temp {
    pub(super) celsius: f64,
}

impl Temp {
    fn values(self) -> [f64; 1] {
        [self.celsius]
    }
}

// ---------------------------------------------------------------------------
// What one sample says about each device, ready to be stored.
// ---------------------------------------------------------------------------

/// Everything one sample contributes to the detail tables, keyed by device.
///
/// Built by [`detail_of`] and handed to [`store`], which decides for each key
/// whether it continues an open stretch or starts a new one. Separating the
/// two is what makes the decision testable without a database.
pub(super) struct DetailSample {
    /// When the sample before this one was taken, if there was one: a
    /// stretch is still open only if its `end` is that instant. Everything
    /// else — a device absent last cycle, a monitor just started — closed
    /// whatever row it had, whatever the reading says.
    pub(super) prev_at: Option<DateTime<Utc>>,
    pub(super) disk: Vec<(String, DiskUsage)>,
    pub(super) ifaces: Vec<(String, IfaceRate)>,
    pub(super) gpus: Vec<(String, GpuUsage, String)>,
    pub(super) temps: Vec<(String, Temp)>,
}

/// What to keep of one sample.
///
/// Rates come from the device's counters against `prev`'s; a device with no
/// previous reading is skipped rather than reported at zero. Disk usage is
/// absolute, and every mount is kept — a mount that does not move costs one
/// row per [`MAX_SEGMENT`], not one per sample.
pub(super) fn detail_of(
    metrics: &SystemMetrics,
    prev: Option<&SystemMetrics>,
) -> DetailSample {
    let elapsed = prev
        .map(|p| (metrics.timestamp - p.timestamp).num_milliseconds() as f64 / 1000.0)
        .filter(|s| *s > 0.0);

    let ifaces = match (elapsed, prev) {
        (Some(dt), Some(prev)) => metrics
            .ifaces
            .iter()
            .filter_map(|i| {
                let before = prev.ifaces.iter().find(|p| p.name == i.name)?;
                // A counter that went backwards is a reset, not negative
                // traffic: skip the cycle rather than report a spike.
                if i.rx_bytes < before.rx_bytes || i.tx_bytes < before.tx_bytes {
                    return None;
                }
                let rate = IfaceRate {
                    rx: (i.rx_bytes - before.rx_bytes) as f64 / dt,
                    tx: (i.tx_bytes - before.tx_bytes) as f64 / dt,
                };
                // An idle link is no detail: it is the absence of one, which
                // is what makes 12 000 idle rows a day disappear.
                if rate.rx < IFACE_FLOOR && rate.tx < IFACE_FLOOR {
                    return None;
                }
                Some((i.name.clone(), rate))
            })
            .collect(),
        _ => Vec::new(),
    };

    DetailSample {
        prev_at: prev.map(|p| p.timestamp),
        disk: metrics
            .disk_details
            .iter()
            .filter(|d| !d.mount.is_empty() && d.total > 0)
            .map(|d| {
                (
                    d.mount.clone(),
                    DiskUsage {
                        used: d.used,
                        total: d.total,
                    },
                )
            })
            .collect(),
        ifaces,
        gpus: metrics
            .gpus
            .iter()
            .map(|g| {
                (
                    g.id.clone(),
                    GpuUsage {
                        usage: g.usage_percent.map(f64::from),
                        mem_used: g.memory_used,
                        mem_total: g.memory_total,
                    },
                    g.name.clone(),
                )
            })
            .collect(),
        temps: metrics
            .temps
            .iter()
            .map(|t| (t.device.clone(), Temp { celsius: t.value }))
            .collect(),
    }
}

/// Whether `next` continues `open` or closes it.
///
/// Open means the stretch was extended at the previous sample — its `end` is
/// [`DetailSample::prev_at`]. A device absent last cycle, a monitor just
/// started, an interface whose last traffic was cycles ago: none of these is
/// a continuation, however equal the readings look, and the stretch is left
/// with the `end` it had.
///
/// A stretch that is open extends unless it has reached [`MAX_SEGMENT`], or
/// the reading moved further than its column's threshold — one per column,
/// in the same order as [`Stretch::values`] — before [`MIN_SEGMENT`] had
/// passed. Young stretches extend regardless of the reading: a device under
/// load moves every cycle, and cutting there is one row per sample again.
pub(super) fn continues(
    open: &Stretch,
    next_values: &[f64],
    thresholds: &[f64],
    at: DateTime<Utc>,
    prev_at: Option<DateTime<Utc>>,
) -> bool {
    if prev_at != Some(open.end) {
        return false;
    }
    let age = at - open.start;
    if age >= MAX_SEGMENT {
        return false;
    }
    if age < MIN_SEGMENT {
        return true;
    }
    open.values.iter().zip(next_values).zip(thresholds).all(|((a, b), t)| {
        // Two missing readings are the same missing reading; NaN minus NaN
        // is NaN, which no comparison accepts.
        a.is_nan() && b.is_nan() || (a - b).abs() <= *t
    })
}

/// The stretch of one device, as the database holds it.
#[derive(Debug, Clone)]
pub(super) struct Stretch {
    pub(super) start: DateTime<Utc>,
    pub(super) end: DateTime<Utc>,
    /// The reading, in the order the table's INSERT binds it. The lookup's
    /// SELECT names its columns in this same order, and the destructure ties
    /// the two — reorder one and reorder both.
    pub(super) values: Vec<f64>,
}

/// Writes one sample's detail.
///
/// Each device's open stretch (the last row, which the table opens with
/// `end = start`) is extended or closed in one statement, and a new one
/// opened where the reading moved. A closed row's `end` is the instant the
/// next sample was taken, not the instant before it: the value held until it
/// was next observed.
pub(super) async fn store(db: &SqlitePool, metrics: &SystemMetrics, detail: &DetailSample) -> Result<()> {
    let at = metrics.timestamp;
    let mut tx = db.begin().await?;

    store_disk(&mut tx, at, detail.prev_at, &detail.disk).await?;
    store_ifaces(&mut tx, at, detail.prev_at, &detail.ifaces).await?;
    store_gpus(&mut tx, at, detail.prev_at, &detail.gpus).await?;
    store_temps(&mut tx, at, detail.prev_at, &detail.temps).await?;

    tx.commit().await?;
    Ok(())
}

// Each of the four below is the same shape: read the open stretch for the
// keys this sample has, extend or cut it, then write what is left. They are
// separate functions rather than one generic one because the key column and
// the extra columns differ, and SQLite has no way to bind a column name.

async fn store_disk(
    tx: &mut sqlx::Transaction<'_, sqlx::Sqlite>,
    at: DateTime<Utc>,
    prev_at: Option<DateTime<Utc>>,
    rows: &[(String, DiskUsage)],
) -> Result<()> {
    for (mount, reading) in rows {
        let open = sqlx::query_as::<_, (DateTime<Utc>, DateTime<Utc>, i64, i64)>(
            "SELECT start, end, used, total FROM metrics_disk_usage
             WHERE mount = ? ORDER BY start DESC LIMIT 1",
        )
        .bind(mount)
        .fetch_optional(&mut **tx)
        .await?;
        match open {
            Some((start, end, used, total))
                if continues(
                    // The threshold is 1 percentage point of usage, which
                    // over bytes is 1% of the total — not 1 byte.
                    &Stretch { start, end, values: vec![used as f64, total as f64] },
                    &reading.values(),
                    &[total as f64 * 0.01, total as f64 * 0.01],
                    at,
                    prev_at,
                ) =>
            {
                sqlx::query("UPDATE metrics_disk_usage SET end = ? WHERE mount = ? AND start = ?")
                    .bind(at)
                    .bind(mount)
                    .bind(start)
                    .execute(&mut **tx)
                    .await?;
            }
            _ => {
                sqlx::query(
                    "INSERT INTO metrics_disk_usage (mount, start, end, used, total)
                     VALUES (?, ?, ?, ?, ?)",
                )
                .bind(mount)
                .bind(at)
                .bind(at)
                .bind(reading.used as i64)
                .bind(reading.total as i64)
                .execute(&mut **tx)
                .await?;
            }
        }
    }
    Ok(())
}

async fn store_ifaces(
    tx: &mut sqlx::Transaction<'_, sqlx::Sqlite>,
    at: DateTime<Utc>,
    prev_at: Option<DateTime<Utc>>,
    rows: &[(String, IfaceRate)],
) -> Result<()> {
    // An idle interface never reaches this loop: [`detail_of`] leaves it out,
    // and absence is how its stretch ends — at the last sample that saw
    // traffic, without the idle cycles bolted on.
    for (name, reading) in rows {
        let open = sqlx::query_as::<_, (DateTime<Utc>, DateTime<Utc>, f64, f64)>(
            "SELECT start, end, rx_bytes_per_sec, tx_bytes_per_sec FROM metrics_iface
             WHERE name = ? ORDER BY start DESC LIMIT 1",
        )
        .bind(name)
        .fetch_optional(&mut **tx)
        .await?;
        match open {
            Some((start, end, rx, tx_))
                if continues(
                    &Stretch { start, end, values: vec![rx, tx_] },
                    &reading.values(),
                    // Traffic varies by nature; a stretch is cut only when
                    // the rate is off by more than this share, per column.
                    &[
                        rx.max(reading.rx).max(1.0) * 0.5,
                        tx_.max(reading.tx).max(1.0) * 0.5,
                    ],
                    at,
                    prev_at,
                ) =>
            {
                sqlx::query("UPDATE metrics_iface SET end = ? WHERE name = ? AND start = ?")
                    .bind(at)
                    .bind(name)
                    .bind(start)
                    .execute(&mut **tx)
                    .await?;
            }
            _ => {
                sqlx::query(
                    "INSERT INTO metrics_iface (name, start, end, rx_bytes_per_sec, tx_bytes_per_sec)
                     VALUES (?, ?, ?, ?, ?)",
                )
                .bind(name)
                .bind(at)
                .bind(at)
                .bind(reading.rx)
                .bind(reading.tx)
                .execute(&mut **tx)
                .await?;
            }
        }
    }
    Ok(())
}

async fn store_gpus(
    tx: &mut sqlx::Transaction<'_, sqlx::Sqlite>,
    at: DateTime<Utc>,
    prev_at: Option<DateTime<Utc>>,
    rows: &[(String, GpuUsage, String)],
) -> Result<()> {
    for (id, reading, name) in rows {
        let open = sqlx::query_as::<_, (
            DateTime<Utc>,
            DateTime<Utc>,
            Option<f64>,
            Option<i64>,
            Option<i64>,
        )>(
            "SELECT start, end, usage_percent, memory_used, memory_total FROM metrics_gpu
             WHERE id = ? ORDER BY start DESC LIMIT 1",
        )
        .bind(id)
        .fetch_optional(&mut **tx)
        .await?;
        match open {
            Some((start, end, usage, mem_used, mem_total))
                if continues(
                    &Stretch {
                        start,
                        end,
                        values: vec![
                            usage.unwrap_or(f64::NAN),
                            mem_used.unwrap_or(-1) as f64,
                            mem_total.unwrap_or(-1) as f64,
                        ],
                    },
                    &reading.values(),
                    // Usage by points, memory by a share of its total; a
                    // total the driver does not report (the -1 sentinel)
                    // compares as held only while it stays unreported.
                    &[
                        5.0,
                        mem_total.unwrap_or(0).max(0) as f64 * 0.05 + 1.0,
                        mem_total.unwrap_or(0).max(0) as f64 * 0.05 + 1.0,
                    ],
                    at,
                    prev_at,
                ) =>
            {
                // The name is not a reading: it follows the driver's label
                // and is refreshed rather than held.
                sqlx::query("UPDATE metrics_gpu SET end = ?, name = ? WHERE id = ? AND start = ?")
                    .bind(at)
                    .bind(name)
                    .bind(id)
                    .bind(start)
                    .execute(&mut **tx)
                    .await?;
            }
            _ => {
                sqlx::query(
                    "INSERT INTO metrics_gpu (id, start, end, name, usage_percent, memory_used, memory_total)
                     VALUES (?, ?, ?, ?, ?, ?, ?)",
                )
                .bind(id)
                .bind(at)
                .bind(at)
                .bind(name)
                .bind(reading.usage)
                .bind(reading.mem_used)
                .bind(reading.mem_total)
                .execute(&mut **tx)
                .await?;
            }
        }
    }
    Ok(())
}

async fn store_temps(
    tx: &mut sqlx::Transaction<'_, sqlx::Sqlite>,
    at: DateTime<Utc>,
    prev_at: Option<DateTime<Utc>>,
    rows: &[(String, Temp)],
) -> Result<()> {
    for (device, reading) in rows {
        let open = sqlx::query_as::<_, (DateTime<Utc>, DateTime<Utc>, f64)>(
            "SELECT start, end, celsius FROM metrics_temp
             WHERE device = ? ORDER BY start DESC LIMIT 1",
        )
        .bind(device)
        .fetch_optional(&mut **tx)
        .await?;
        match open {
            Some((start, end, celsius))
                if continues(
                    &Stretch { start, end, values: vec![celsius] },
                    &reading.values(),
                    &[1.0],
                    at,
                    prev_at,
                ) =>
            {
                sqlx::query("UPDATE metrics_temp SET end = ? WHERE device = ? AND start = ?")
                    .bind(at)
                    .bind(device)
                    .bind(start)
                    .execute(&mut **tx)
                    .await?;
            }
            _ => {
                sqlx::query(
                    "INSERT INTO metrics_temp (device, start, end, celsius) VALUES (?, ?, ?, ?)",
                )
                .bind(device)
                .bind(at)
                .bind(at)
                .bind(reading.celsius)
                .execute(&mut **tx)
                .await?;
            }
        }
    }
    Ok(())
}

/// Below this, an interface is idle and gets no rows: its stretch ends at
/// the last sample that saw traffic.
const IFACE_FLOOR: f64 = 10_000.0;

#[cfg(test)]
mod tests {
    use super::*;

    fn at(secs: i64) -> DateTime<Utc> {
        DateTime::from_timestamp(1_700_000_000 + secs, 0).unwrap()
    }

    fn stretch(start: i64, values: &[f64]) -> Stretch {
        Stretch {
            start: at(start),
            end: at(start + 7),
            values: values.to_vec(),
        }
    }

    #[test]
    fn a_reading_inside_its_threshold_extends_the_stretch() {
        let open = stretch(0, &[10.0]);
        assert!(continues(&open, &[10.4], &[1.0], at(60), Some(open.end)));
    }

    #[test]
    fn a_reading_past_its_threshold_opens_a_new_one() {
        let open = stretch(0, &[10.0]);
        assert!(!continues(&open, &[12.0], &[1.0], at(60), Some(open.end)));
    }

    #[test]
    fn a_stretch_not_extended_last_cycle_is_not_open() {
        // A device absent last cycle (or a monitor just started) reads the
        // same, but its stretch ended when it was last seen: bolt the two
        // together and a remount claims its old reading through the gap.
        let open = stretch(0, &[10.0]);
        assert!(!continues(&open, &[10.0], &[1.0], at(60), Some(at(50))));
        assert!(!continues(&open, &[10.0], &[1.0], at(60), None));
    }

    #[test]
    fn a_young_stretch_is_never_cut() {
        // Far past the threshold, but only 7 seconds old: a device under load
        // moves every cycle, and cutting here is one row per sample again.
        let open = stretch(0, &[10.0]);
        assert!(continues(&open, &[90.0], &[1.0], at(7), Some(open.end)));
    }

    #[test]
    fn an_old_stretch_is_cut_even_without_a_change() {
        let open = stretch(0, &[10.0]);
        assert!(!continues(&open, &[10.0], &[1.0], at(3600), Some(open.end)));
    }

    #[test]
    fn thresholds_are_per_column() {
        // Usage within 5 points, memory moved: the stretch opens again.
        let open = stretch(0, &[10.0, 100.0]);
        assert!(!continues(&open, &[12.0, 500.0], &[5.0, 10.0], at(60), Some(open.end)));
        // And the other way.
        assert!(!continues(&open, &[90.0, 105.0], &[5.0, 10.0], at(60), Some(open.end)));
    }

    #[test]
    fn nan_counts_as_the_same_missing_reading() {
        let open = stretch(0, &[f64::NAN]);
        assert!(continues(&open, &[f64::NAN], &[1.0], at(60), Some(open.end)));
    }
}
