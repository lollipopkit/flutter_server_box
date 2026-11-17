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
//! further than its table's threshold, when the device appears, or when the
//! previous stretch has been open for [`MAX_SEGMENT`] — the last so a value
//! that drifts slowly still splits into answerable chunks. A stretch younger
//! than [`MIN_SEGMENT`] is extended and blended instead, because otherwise a
//! busy device would open a new row at every sample and the table would be
//! back to one row per sample with extra steps.
//!
//! Storage for a machine that does not change: one row per device per
//! [`MAX_SEGMENT`], so four devices at the cap are under a hundred rows a day
//! across the detail tables — against ~49 000 for one row per sample.

use std::collections::HashSet;

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
    pub(super) used: i64,
    pub(super) total: i64,
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
            self.mem_used.map(|v| v as f64).unwrap_or(f64::NAN),
            self.mem_total.map(|v| v as f64).unwrap_or(f64::NAN),
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

/// Normalizes a GPU memory value to MiB using the tool's unit label.
fn to_mib(val: i64, unit: Option<&str>) -> Option<i64> {
    if val < 0 {
        return None;
    }
    match unit.map(str::trim) {
        Some(u) if u.eq_ignore_ascii_case("B") => Some(val / (1024 * 1024)),
        Some(u) if u.eq_ignore_ascii_case("KB") || u.eq_ignore_ascii_case("KiB") => Some(val / 1024),
        Some(u) if u.eq_ignore_ascii_case("GB") || u.eq_ignore_ascii_case("GiB") => val.checked_mul(1024),
        _ => Some(val),
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

    let mut seen_ifaces = HashSet::new();
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
                if !rate.rx.is_finite() || !rate.tx.is_finite() {
                    return None;
                }
                // An idle link is no detail: it is the absence of one, which
                // is what makes 12 000 idle rows a day disappear.
                if rate.rx < IFACE_FLOOR && rate.tx < IFACE_FLOOR {
                    return None;
                }
                if !seen_ifaces.insert(i.name.as_str()) {
                    return None;
                }
                Some((i.name.clone(), rate))
            })
            .collect(),
        _ => Vec::new(),
    };

    let mut seen_mounts = HashSet::new();
    let disk = metrics
        .disk_details
        .iter()
        .filter_map(|d| {
            if d.mount.is_empty() || d.total == 0 {
                return None;
            }
            let total = i64::try_from(d.total).ok()?;
            let used = i64::try_from(d.used).ok()?;
            if total <= 0 || used < 0 || !seen_mounts.insert(d.mount.as_str()) {
                return None;
            }
            Some((d.mount.clone(), DiskUsage { used, total }))
        })
        .collect();

    let mut seen_gpus = HashSet::new();
    let gpus = metrics
        .gpus
        .iter()
        .filter_map(|g| {
            if !seen_gpus.insert(g.id.as_str()) {
                return None;
            }
            let unit = g.memory_unit.as_deref();
            Some((
                g.id.clone(),
                GpuUsage {
                    usage: g.usage_percent.map(f64::from).filter(|v| v.is_finite()),
                    mem_used: g.memory_used.and_then(|v| to_mib(v, unit)),
                    mem_total: g.memory_total.and_then(|v| to_mib(v, unit)),
                },
                g.name.clone(),
            ))
        })
        .collect();

    let mut seen_temps = HashSet::new();
    let temps = metrics
        .temps
        .iter()
        .filter_map(|t| {
            if !t.value.is_finite() || !seen_temps.insert(t.device.as_str()) {
                return None;
            }
            Some((t.device.clone(), Temp { celsius: t.value }))
        })
        .collect();

    DetailSample {
        prev_at: prev.map(|p| p.timestamp),
        disk,
        ifaces,
        gpus,
        temps,
    }
}

/// How an existing stretch handles the next sample.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum Decision {
    /// Close the existing stretch (or leave it closed) and open a new one.
    Close,
    /// Reading stayed within threshold: extend `end` while keeping baseline values.
    ExtendKeep,
    /// Stretch is younger than [`MIN_SEGMENT`] and reading moved past threshold:
    /// extend `end` and blend the reading over elapsed time.
    ExtendBlend,
}

/// Duration-weighted blend of an existing stretch value and a new reading.
fn blend_f64(open_start: DateTime<Utc>, open_end: DateTime<Utc>, at: DateTime<Utc>, old: f64, new: f64) -> f64 {
    let prev_ms = (open_end - open_start).num_milliseconds().max(0) as f64;
    let step_ms = (at - open_end).num_milliseconds().max(1) as f64;
    if prev_ms == 0.0 {
        (old + new) * 0.5
    } else {
        (old * prev_ms + new * step_ms) / (prev_ms + step_ms)
    }
}

fn blend_opt_f64(
    open_start: DateTime<Utc>,
    open_end: DateTime<Utc>,
    at: DateTime<Utc>,
    old: Option<f64>,
    new: Option<f64>,
) -> Option<f64> {
    match (old, new) {
        (Some(a), Some(b)) => Some(blend_f64(open_start, open_end, at, a, b)),
        (_, b) => b,
    }
}

fn blend_opt_i64(
    open_start: DateTime<Utc>,
    open_end: DateTime<Utc>,
    at: DateTime<Utc>,
    old: Option<i64>,
    new: Option<i64>,
) -> Option<i64> {
    match (old, new) {
        (Some(a), Some(b)) => Some(blend_f64(open_start, open_end, at, a as f64, b as f64).round() as i64),
        (_, b) => b,
    }
}

/// Decides whether `next_values` continues `open` (keeping or blending) or closes it.
pub(super) fn decide(
    open: &Stretch,
    next_values: &[f64],
    thresholds: &[f64],
    at: DateTime<Utc>,
    prev_at: Option<DateTime<Utc>>,
) -> Decision {
    if prev_at != Some(open.end) {
        return Decision::Close;
    }
    let age = at - open.start;
    if age >= MAX_SEGMENT {
        return Decision::Close;
    }
    // A reading that appeared or disappeared is a new stretch, never a blend:
    // blending a present value with an absent one would overwrite it with
    // nothing.
    if open.values.iter().zip(next_values).any(|(a, b)| a.is_nan() != b.is_nan()) {
        return Decision::Close;
    }
    let within = open.values.iter().zip(next_values).zip(thresholds).all(|((a, b), t)| {
        // Two missing readings are the same missing reading; NaN minus NaN
        // is NaN, which no comparison accepts.
        a.is_nan() && b.is_nan() || (a - b).abs() <= *t
    });
    if within {
        Decision::ExtendKeep
    } else if age < MIN_SEGMENT {
        Decision::ExtendBlend
    } else {
        Decision::Close
    }
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
            Some((start, end, _, _)) if at <= start || at <= end => continue,
            Some((start, end, used, total)) => {
                match decide(
                    // The threshold is 1 percentage point of usage, which
                    // over bytes is 1% of the total — not 1 byte.
                    &Stretch { start, end, values: vec![used as f64, total as f64] },
                    &reading.values(),
                    &[total as f64 * 0.01, total as f64 * 0.01],
                    at,
                    prev_at,
                ) {
                    Decision::ExtendKeep => {
                        sqlx::query("UPDATE metrics_disk_usage SET end = ? WHERE mount = ? AND start = ?")
                            .bind(at)
                            .bind(mount)
                            .bind(start)
                            .execute(&mut **tx)
                            .await?;
                    }
                    // A capacity change is a new stretch: blending `used`
                    // against a replaced `total` stores a pair no sample had.
                    Decision::ExtendBlend if total == reading.total => {
                        let blended = blend_f64(start, end, at, used as f64, reading.used as f64)
                            .round() as i64;
                        sqlx::query(
                            "UPDATE metrics_disk_usage SET end = ?, used = ?
                             WHERE mount = ? AND start = ?",
                        )
                        .bind(at)
                        .bind(blended)
                        .bind(mount)
                        .bind(start)
                        .execute(&mut **tx)
                        .await?;
                    }
                    Decision::Close | Decision::ExtendBlend => {
                        if prev_at == Some(end) {
                            sqlx::query("UPDATE metrics_disk_usage SET end = ? WHERE mount = ? AND start = ?")
                                .bind(at)
                                .bind(mount)
                                .bind(start)
                                .execute(&mut **tx)
                                .await?;
                        }
                        sqlx::query(
                            "INSERT INTO metrics_disk_usage (mount, start, end, used, total)
                             VALUES (?, ?, ?, ?, ?)",
                        )
                        .bind(mount)
                        .bind(at)
                        .bind(at)
                        .bind(reading.used)
                        .bind(reading.total)
                        .execute(&mut **tx)
                        .await?;
                    }
                }
            }
            None => {
                sqlx::query(
                    "INSERT INTO metrics_disk_usage (mount, start, end, used, total)
                     VALUES (?, ?, ?, ?, ?)",
                )
                .bind(mount)
                .bind(at)
                .bind(at)
                .bind(reading.used)
                .bind(reading.total)
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
            Some((start, end, _, _)) if at <= start || at <= end => continue,
            Some((start, end, rx, tx_)) => {
                match decide(
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
                ) {
                    Decision::ExtendKeep => {
                        sqlx::query("UPDATE metrics_iface SET end = ? WHERE name = ? AND start = ?")
                            .bind(at)
                            .bind(name)
                            .bind(start)
                            .execute(&mut **tx)
                            .await?;
                    }
                    Decision::ExtendBlend => {
                        let blended_rx = blend_f64(start, end, at, rx, reading.rx);
                        let blended_tx = blend_f64(start, end, at, tx_, reading.tx);
                        sqlx::query(
                            "UPDATE metrics_iface SET end = ?, rx_bytes_per_sec = ?, tx_bytes_per_sec = ?
                             WHERE name = ? AND start = ?",
                        )
                        .bind(at)
                        .bind(blended_rx)
                        .bind(blended_tx)
                        .bind(name)
                        .bind(start)
                        .execute(&mut **tx)
                        .await?;
                    }
                    Decision::Close => {
                        let new_start = prev_at
                            .filter(|p| *p < at && *p >= end && *p > start)
                            .unwrap_or(at);
                        sqlx::query(
                            "INSERT INTO metrics_iface (name, start, end, rx_bytes_per_sec, tx_bytes_per_sec)
                             VALUES (?, ?, ?, ?, ?)",
                        )
                        .bind(name)
                        .bind(new_start)
                        .bind(at)
                        .bind(reading.rx)
                        .bind(reading.tx)
                        .execute(&mut **tx)
                        .await?;
                    }
                }
            }
            None => {
                let new_start = prev_at.filter(|p| *p < at).unwrap_or(at);
                sqlx::query(
                    "INSERT INTO metrics_iface (name, start, end, rx_bytes_per_sec, tx_bytes_per_sec)
                     VALUES (?, ?, ?, ?, ?)",
                )
                .bind(name)
                .bind(new_start)
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
            Some((start, end, _, _, _)) if at <= start || at <= end => continue,
            Some((start, end, usage, mem_used, mem_total)) => {
                let mem_threshold = mem_total.or(reading.mem_total).unwrap_or(0).max(0) as f64 * 0.05;
                match decide(
                    &Stretch {
                        start,
                        end,
                        values: vec![
                            usage.unwrap_or(f64::NAN),
                            mem_used.map(|v| v as f64).unwrap_or(f64::NAN),
                            mem_total.map(|v| v as f64).unwrap_or(f64::NAN),
                        ],
                    },
                    &reading.values(),
                    &[5.0, mem_threshold, mem_threshold],
                    at,
                    prev_at,
                ) {
                    Decision::ExtendKeep => {
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
                    Decision::ExtendBlend => {
                        let blended_usage = blend_opt_f64(start, end, at, usage, reading.usage);
                        let blended_mem_used = blend_opt_i64(start, end, at, mem_used, reading.mem_used);
                        let blended_mem_total = reading.mem_total.or(mem_total);
                        sqlx::query(
                            "UPDATE metrics_gpu SET end = ?, name = ?, usage_percent = ?, memory_used = ?, memory_total = ?
                             WHERE id = ? AND start = ?",
                        )
                        .bind(at)
                        .bind(name)
                        .bind(blended_usage)
                        .bind(blended_mem_used)
                        .bind(blended_mem_total)
                        .bind(id)
                        .bind(start)
                        .execute(&mut **tx)
                        .await?;
                    }
                    Decision::Close => {
                        if prev_at == Some(end) {
                            sqlx::query("UPDATE metrics_gpu SET end = ? WHERE id = ? AND start = ?")
                                .bind(at)
                                .bind(id)
                                .bind(start)
                                .execute(&mut **tx)
                                .await?;
                        }
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
            None => {
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
            Some((start, end, _)) if at <= start || at <= end => continue,
            Some((start, end, celsius)) => {
                match decide(
                    &Stretch { start, end, values: vec![celsius] },
                    &reading.values(),
                    &[1.0],
                    at,
                    prev_at,
                ) {
                    Decision::ExtendKeep => {
                        sqlx::query("UPDATE metrics_temp SET end = ? WHERE device = ? AND start = ?")
                            .bind(at)
                            .bind(device)
                            .bind(start)
                            .execute(&mut **tx)
                            .await?;
                    }
                    Decision::ExtendBlend => {
                        let blended = blend_f64(start, end, at, celsius, reading.celsius);
                        sqlx::query(
                            "UPDATE metrics_temp SET end = ?, celsius = ? WHERE device = ? AND start = ?",
                        )
                        .bind(at)
                        .bind(blended)
                        .bind(device)
                        .bind(start)
                        .execute(&mut **tx)
                        .await?;
                    }
                    Decision::Close => {
                        if prev_at == Some(end) {
                            sqlx::query("UPDATE metrics_temp SET end = ? WHERE device = ? AND start = ?")
                                .bind(at)
                                .bind(device)
                                .bind(start)
                                .execute(&mut **tx)
                                .await?;
                        }
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
            None => {
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
        assert_eq!(decide(&open, &[10.4], &[1.0], at(60), Some(open.end)), Decision::ExtendKeep);
    }

    #[test]
    fn a_reading_past_its_threshold_opens_a_new_one() {
        let open = stretch(0, &[10.0]);
        assert_eq!(decide(&open, &[12.0], &[1.0], at(60), Some(open.end)), Decision::Close);
    }

    #[test]
    fn a_stretch_not_extended_last_cycle_is_not_open() {
        // A device absent last cycle (or a monitor just started) reads the
        // same, but its stretch ended when it was last seen: bolt the two
        // together and a remount claims its old reading through the gap.
        let open = stretch(0, &[10.0]);
        assert_eq!(decide(&open, &[10.0], &[1.0], at(60), Some(at(50))), Decision::Close);
        assert_eq!(decide(&open, &[10.0], &[1.0], at(60), None), Decision::Close);
    }

    #[test]
    fn a_young_stretch_is_blended_instead_of_cut() {
        // Far past the threshold, but only 14 seconds old: a device under load
        // moves every cycle, so extend and blend rather than cutting or freezing
        // the initial reading.
        let open = stretch(0, &[10.0]);
        assert_eq!(decide(&open, &[90.0], &[1.0], at(14), Some(open.end)), Decision::ExtendBlend);
        // Inside the threshold it stays ExtendKeep.
        assert_eq!(decide(&open, &[10.5], &[1.0], at(14), Some(open.end)), Decision::ExtendKeep);
    }

    #[test]
    fn an_old_stretch_is_cut_even_without_a_change() {
        let open = stretch(0, &[10.0]);
        assert_eq!(decide(&open, &[10.0], &[1.0], at(3600), Some(open.end)), Decision::Close);
    }

    #[test]
    fn thresholds_are_per_column() {
        // Usage within 5 points, memory moved: the stretch opens again.
        let open = stretch(0, &[10.0, 100.0]);
        assert_eq!(decide(&open, &[12.0, 500.0], &[5.0, 10.0], at(60), Some(open.end)), Decision::Close);
        // And the other way.
        assert_eq!(decide(&open, &[90.0, 105.0], &[5.0, 10.0], at(60), Some(open.end)), Decision::Close);
    }

    #[test]
    fn nan_counts_as_the_same_missing_reading() {
        let open = stretch(0, &[f64::NAN]);
        assert_eq!(decide(&open, &[f64::NAN], &[1.0], at(60), Some(open.end)), Decision::ExtendKeep);
        assert_eq!(decide(&open, &[0.0], &[1.0], at(60), Some(open.end)), Decision::Close);
    }

    #[test]
    fn a_reading_appearing_or_disappearing_closes_even_a_young_stretch() {
        let open = stretch(0, &[50.0, f64::NAN]);
        assert_eq!(decide(&open, &[f64::NAN, f64::NAN], &[5.0, 1.0], at(14), Some(open.end)), Decision::Close);
        assert_eq!(decide(&open, &[50.0, 10.0], &[5.0, 1.0], at(14), Some(open.end)), Decision::Close);
    }

    #[test]
    fn detail_of_deduplicates_keys_filters_overflow_and_normalizes_gpu_units() {
        use super::super::metrics::*;

        let base = SystemMetrics {
            timestamp: at(10),
            extended_updated_at: at(10),
            server_name: "host".into(),
            cpu_usage: 0.0,
            cpu_cores: Vec::new(),
            memory: MemoryMetrics { total: 1, used: 0, free: 1, usage_percent: 0.0 },
            swap: SwapMetrics { total: 0, used: 0, usage_percent: 0.0 },
            swap_areas: Vec::new(),
            disk: DiskMetrics { total: 1, used: 0, free: 1, usage_percent: 0.0 },
            network: NetworkMetrics { rx_bytes: 0, tx_bytes: 0 },
            temperature: None,
            temps: vec![
                TempReading { device: "core".into(), value: 40.0 },
                TempReading { device: "core".into(), value: 55.0 },
                TempReading { device: "bad".into(), value: f64::NAN },
            ],
            sys: None,
            os_id: None,
            os_id_like: Vec::new(),
            cpu_brand: None,
            gpus: vec![
                GpuMetrics {
                    id: "gpu0".into(),
                    vendor: "amd".into(),
                    name: "GPU A".into(),
                    usage_percent: Some(20.0),
                    temperature: None,
                    power: None,
                    memory_used: Some(2 * 1024 * 1024),
                    memory_total: Some(1024 * 1024 * 1024),
                    memory_unit: Some("B".into()),
                    fan_speed: None,
                    clock_speed: None,
                    processes: Vec::new(),
                },
                GpuMetrics {
                    id: "gpu0".into(),
                    vendor: "amd".into(),
                    name: "GPU A dup".into(),
                    usage_percent: Some(90.0),
                    temperature: None,
                    power: None,
                    memory_used: None,
                    memory_total: None,
                    memory_unit: None,
                    fan_speed: None,
                    clock_speed: None,
                    processes: Vec::new(),
                },
                GpuMetrics {
                    id: "gpu1".into(),
                    vendor: "nvidia".into(),
                    name: "GPU B".into(),
                    usage_percent: Some(50.0),
                    temperature: None,
                    power: None,
                    memory_used: Some(2),
                    memory_total: Some(16),
                    memory_unit: Some("GiB".into()),
                    fan_speed: None,
                    clock_speed: None,
                    processes: Vec::new(),
                },
            ],
            disk_details: vec![
                DiskDetail {
                    path: "/dev/sda1".into(),
                    mount: "/".into(),
                    fs_type: None,
                    used: 100,
                    total: 1000,
                    usage_percent: 10.0,
                },
                DiskDetail {
                    path: "overmount".into(),
                    mount: "/".into(),
                    fs_type: None,
                    used: 200,
                    total: 2000,
                    usage_percent: 10.0,
                },
                DiskDetail {
                    path: "fuse".into(),
                    mount: "/mnt/huge".into(),
                    fs_type: None,
                    used: 10,
                    total: u64::MAX,
                    usage_percent: 0.0,
                },
            ],
            block_devices: Vec::new(),
            ifaces: vec![
                IfaceMetrics { name: "eth0".into(), rx_bytes: 200_000, tx_bytes: 0 },
                IfaceMetrics { name: "eth0".into(), rx_bytes: 999_999, tx_bytes: 0 },
            ],
            uptime: None,
            conn: None,
            diskio: Vec::new(),
            diskio_rate: Vec::new(),
            batteries: Vec::new(),
            sensors: Vec::new(),
            disk_smart: Vec::new(),
            ips: Vec::new(),
            custom_cmds: Vec::new(),
            amd_cache: Vec::new(),
        };
        let mut prev = base.clone();
        prev.timestamp = at(0);
        prev.ifaces = vec![IfaceMetrics { name: "eth0".into(), rx_bytes: 0, tx_bytes: 0 }];

        let sample = detail_of(&base, Some(&prev));
        assert_eq!(sample.disk.len(), 1);
        assert_eq!(sample.disk[0].0, "/");
        assert_eq!(sample.disk[0].1.used, 100);
        assert_eq!(sample.ifaces.len(), 1);
        assert_eq!(sample.ifaces[0].0, "eth0");
        assert_eq!(sample.temps.len(), 1);
        assert_eq!(sample.temps[0].0, "core");
        assert_eq!(sample.gpus.len(), 2);
        assert_eq!(sample.gpus[0].1.mem_used, Some(2));
        assert_eq!(sample.gpus[0].1.mem_total, Some(1024));
        assert_eq!(sample.gpus[1].1.mem_used, Some(2048));
        assert_eq!(sample.gpus[1].1.mem_total, Some(16384));
    }
}
