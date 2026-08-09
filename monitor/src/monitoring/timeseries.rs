use chrono::{DateTime, Utc};
use sbm_parser::SystemType;
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimeSeriesData<T> {
    pub timestamp: DateTime<Utc>,
    pub value: T,
}

#[derive(Debug, Clone)]
pub struct TimeSeries<T> {
    data: VecDeque<TimeSeriesData<T>>,
    max_points: usize,
}

impl<T> TimeSeries<T> 
where
    T: Clone,
{
    pub fn new(max_points: usize) -> Self {
        Self {
            data: VecDeque::with_capacity(max_points),
            max_points,
        }
    }

    pub fn add_point(&mut self, value: T, timestamp: DateTime<Utc>) {
        let point = TimeSeriesData { timestamp, value };
        
        // Remove oldest point if we're at capacity
        if self.data.len() >= self.max_points {
            self.data.pop_front();
        }
        
        self.data.push_back(point);
    }

    pub fn get_data(&self) -> Vec<&TimeSeriesData<T>> {
        self.data.iter().collect()
    }

    pub fn len(&self) -> usize {
        self.data.len()
    }

    pub fn is_empty(&self) -> bool {
        self.data.is_empty()
    }

    pub fn clear(&mut self) {
        self.data.clear();
    }
}

#[derive(Debug, Clone)]
pub struct TimeSequence<T> {
    pub old: Option<T>,
    pub new: Option<T>,
}

impl<T> TimeSequence<T> {
    pub fn new() -> Self {
        Self {
            old: None,
            new: None,
        }
    }

    pub fn update(&mut self, value: T) {
        self.old = self.new.take();
        self.new = Some(value);
    }


    pub fn is_ready(&self) -> bool {
        self.old.is_some() && self.new.is_some()
    }
}

impl<T> Default for TimeSequence<T> {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, Clone)]
pub struct NetworkTimeSeries {
    rx_bytes: TimeSequence<u64>,
    tx_bytes: TimeSequence<u64>,
    timestamps: TimeSequence<DateTime<Utc>>,
}

impl NetworkTimeSeries {
    pub fn new() -> Self {
        Self {
            rx_bytes: TimeSequence::new(),
            tx_bytes: TimeSequence::new(),
            timestamps: TimeSequence::new(),
        }
    }

    pub fn update(&mut self, rx_bytes: u64, tx_bytes: u64, timestamp: DateTime<Utc>) {
        self.rx_bytes.update(rx_bytes);
        self.tx_bytes.update(tx_bytes);
        self.timestamps.update(timestamp);
    }

    /// Seconds actually elapsed between the two samples, not the configured
    /// cycle interval. The gap exceeds the interval whenever collection runs
    /// long or the host suspends — dividing an hours-long byte delta by a 7s
    /// interval reported speeds three orders of magnitude too high.
    fn elapsed_seconds(&self) -> Option<f64> {
        let (old, new) = (self.timestamps.old?, self.timestamps.new?);
        let seconds = (new - old).num_milliseconds() as f64 / 1000.0;
        (seconds > 0.0).then_some(seconds)
    }

    fn speed(&self, counter: &TimeSequence<u64>) -> Option<f64> {
        let elapsed = self.elapsed_seconds()?;
        // A counter that went backwards (reboot / interface reset) has no
        // meaningful rate; report nothing rather than a fabricated 0
        let diff = counter.new?.checked_sub(counter.old?)? as f64;
        Some(diff / elapsed)
    }

    pub fn get_rx_speed(&self) -> Option<f64> {
        self.speed(&self.rx_bytes)
    }

    pub fn get_tx_speed(&self) -> Option<f64> {
        self.speed(&self.tx_bytes)
    }

    pub fn get_total_rx(&self) -> Option<u64> {
        self.rx_bytes.new
    }

    pub fn get_total_tx(&self) -> Option<u64> {
        self.tx_bytes.new
    }

    pub fn is_ready(&self) -> bool {
        self.rx_bytes.is_ready() && self.tx_bytes.is_ready()
    }
}

impl Default for NetworkTimeSeries {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, Clone)]
pub struct CpuTimeSeries {
    cores: Vec<TimeSequence<CpuCoreTime>>,
    last_update: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct CpuCoreTime {
    pub used: u64,
    pub total: u64,
    /// Usage for this core over the sampling window, 0.0–100.0. Computed once
    /// by `adapt_cpu` (the only place that knows the platform semantics) and
    /// carried here so no consumer re-derives it from `used`/`total` — see
    /// `core_usage_percent`. `None` until a baseline exists (Linux first
    /// cycle) or when the counters are unusable.
    pub usage_percent: Option<f32>,
}

/// Per-core usage from two consecutive `CpuCoreTime` samples.
///
/// `used`/`total` mean different things per platform (documented on
/// `sbm_parser::types::CpuCore`), so this must branch:
/// - Linux: cumulative `/proc/stat` ticks — usage is the delta between two
///   samples. A direct ratio would be the since-boot average. No baseline, a
///   zero-width window, or counters that went backwards (reboot) yield `None`.
/// - Bsd/Windows: one-shot percentage pseudo-counters where `total` stays
///   ~constant, so the single-sample ratio IS the current usage; a delta would
///   divide by ~0 and report nonsense.
pub fn core_usage_percent(
    system: SystemType,
    prev: Option<CpuCoreTime>,
    now: CpuCoreTime,
) -> Option<f32> {
    let ratio = match system {
        SystemType::Linux => {
            let prev = prev?;
            let total_diff = now.total.checked_sub(prev.total)?;
            let used_diff = now.used.checked_sub(prev.used)?;
            if total_diff == 0 {
                return None;
            }
            used_diff as f32 / total_diff as f32
        }
        SystemType::Bsd | SystemType::Windows => {
            if now.total == 0 {
                return None;
            }
            now.used as f32 / now.total as f32
        }
    };
    Some((ratio * 100.0).clamp(0.0, 100.0))
}

impl CpuTimeSeries {
    pub fn new() -> Self {
        Self {
            cores: Vec::new(),
            last_update: None,
        }
    }

    /// The series sizes itself to each sample rather than being fixed at
    /// construction: the native sysinfo backend reports no cores at all on the
    /// first cycle (it has no delta baseline yet), and a VM can gain or lose
    /// cores later. Sizing it once from the first sample left the series
    /// permanently empty, so every reading came back `None`.
    pub fn update(&mut self, core_times: Vec<CpuCoreTime>, timestamp: DateTime<Utc>) {
        // A cycle whose CPU collection failed must not wipe the existing series
        if core_times.is_empty() {
            return;
        }
        if core_times.len() != self.cores.len() {
            self.cores.resize_with(core_times.len(), TimeSequence::new);
        }
        for (seq, time) in self.cores.iter_mut().zip(core_times) {
            seq.update(time);
        }
        self.last_update = Some(timestamp);
    }


    /// The usage `adapt_cpu` already computed for the latest sample. Recomputing
    /// a delta here would be wrong on Bsd/Windows, where `total` is constant
    /// between samples — see `core_usage_percent`.
    pub fn get_core_usage_percent(&self, core_index: usize) -> Option<f32> {
        self.cores.get(core_index)?.new?.usage_percent
    }

    pub fn get_average_usage_percent(&self) -> Option<f32> {
        if self.cores.is_empty() {
            return None;
        }

        let mut sum = 0.0;
        let mut count = 0;

        for i in 0..self.cores.len() {
            if let Some(usage) = self.get_core_usage_percent(i) {
                sum += usage;
                count += 1;
            }
        }

        if count > 0 {
            Some(sum / count as f32)
        } else {
            None
        }
    }

    /// `all()` is vacuously true on an empty series, which would report a
    /// server with no CPU samples at all as ready
    pub fn is_ready(&self) -> bool {
        !self.cores.is_empty() && self.cores.iter().all(|core| core.is_ready())
    }
}

impl Default for CpuTimeSeries {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VelocityMetrics {
    pub timestamp: DateTime<Utc>,
    pub network_rx_speed: Option<f64>, // bytes per second
    pub network_tx_speed: Option<f64>, // bytes per second
    pub cpu_usage_percent: Option<f32>,
}

impl VelocityMetrics {
    pub fn new() -> Self {
        Self {
            timestamp: Utc::now(),
            network_rx_speed: None,
            network_tx_speed: None,
            cpu_usage_percent: None,
        }
    }

    pub fn with_network_speed(mut self, rx_speed: Option<f64>, tx_speed: Option<f64>) -> Self {
        self.network_rx_speed = rx_speed;
        self.network_tx_speed = tx_speed;
        self
    }

    pub fn with_cpu_usage(mut self, cpu_usage: Option<f32>) -> Self {
        self.cpu_usage_percent = cpu_usage;
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Duration;

    fn core(used: u64, total: u64) -> CpuCoreTime {
        CpuCoreTime { used, total, usage_percent: None }
    }

    #[test]
    fn linux_uses_the_delta_not_the_since_boot_average() {
        // Busy since boot is 50%, but only 20% of the last window was busy
        let prev = core(500, 1000);
        let now = core(520, 1100);
        assert_eq!(core_usage_percent(SystemType::Linux, Some(prev), now), Some(20.0));
    }

    #[test]
    fn linux_without_a_baseline_or_window_reports_nothing() {
        let now = core(520, 1100);
        assert_eq!(core_usage_percent(SystemType::Linux, None, now), None);
        // Idle pause / duplicate sample: no time passed, no reading
        assert_eq!(core_usage_percent(SystemType::Linux, Some(now), now), None);
    }

    #[test]
    fn linux_counters_going_backwards_report_nothing() {
        // Reboot resets /proc/stat; a saturating delta would invent a spike
        let prev = core(500, 1000);
        let now = core(10, 20);
        assert_eq!(core_usage_percent(SystemType::Linux, Some(prev), now), None);
    }

    #[test]
    fn one_shot_percentage_counters_use_the_single_sample_ratio() {
        // Bsd/Windows keep `total` constant, so the delta path would divide by
        // zero and always report 0 — the regression this guards against
        let prev = core(1200, 10000);
        let now = core(8400, 10000);
        assert_eq!(core_usage_percent(SystemType::Bsd, Some(prev), now), Some(84.0));
        assert_eq!(core_usage_percent(SystemType::Windows, Some(prev), now), Some(84.0));
        assert_eq!(core_usage_percent(SystemType::Bsd, None, now), Some(84.0));
        assert_eq!(core_usage_percent(SystemType::Bsd, None, core(0, 0)), None);
    }

    #[test]
    fn usage_is_the_busy_share_not_the_idle_share() {
        // Guards the storage path that used to write (total - used) / total
        let prev = core(0, 0);
        let now = core(1000, 10000);
        assert_eq!(core_usage_percent(SystemType::Bsd, Some(prev), now), Some(10.0));
        assert_eq!(
            core_usage_percent(SystemType::Linux, Some(core(0, 0)), core(1000, 10000)),
            Some(10.0)
        );
    }

    #[test]
    fn series_returns_the_precomputed_value_for_the_latest_sample() {
        let mut series = CpuTimeSeries::new();
        series.update(
            vec![
                CpuCoreTime { used: 1, total: 10, usage_percent: Some(10.0) },
                CpuCoreTime { used: 3, total: 10, usage_percent: Some(30.0) },
            ],
            Utc::now(),
        );
        assert_eq!(series.get_core_usage_percent(0), Some(10.0));
        assert_eq!(series.get_core_usage_percent(1), Some(30.0));
        assert_eq!(series.get_core_usage_percent(2), None);
        assert_eq!(series.get_average_usage_percent(), Some(20.0));
    }

    #[test]
    fn series_grows_when_the_first_sample_reported_no_cores() {
        // The native sysinfo backend's first cycle carries no cpu data; a series
        // fixed at that width stayed empty forever and reported None for good
        let mut series = CpuTimeSeries::new();
        series.update(vec![], Utc::now());
        assert!(!series.is_ready());
        assert_eq!(series.get_average_usage_percent(), None);

        series.update(vec![CpuCoreTime { used: 4, total: 10, usage_percent: Some(40.0) }], Utc::now());
        assert_eq!(series.get_average_usage_percent(), Some(40.0));
    }

    #[test]
    fn network_speed_uses_the_real_gap_not_the_configured_interval() {
        let t0 = DateTime::from_timestamp(1_700_000_000, 0).unwrap();
        let mut series = NetworkTimeSeries::new();
        series.update(0, 0, t0);
        assert_eq!(series.get_rx_speed(), None);

        // Host suspended for an hour: 3600 MB arrived over 3600s, i.e. 1 MB/s.
        // Dividing by a 7s cycle interval reported 514 MB/s.
        series.update(3_600_000_000, 0, t0 + Duration::seconds(3600));
        assert_eq!(series.get_rx_speed(), Some(1_000_000.0));
    }

    #[test]
    fn network_speed_needs_two_samples_and_a_forward_counter() {
        let t0 = DateTime::from_timestamp(1_700_000_000, 0).unwrap();
        let mut series = NetworkTimeSeries::new();
        series.update(1000, 1000, t0);
        assert_eq!(series.get_rx_speed(), None);

        // Interface counter reset — a rate would be fabricated from a wrap
        series.update(10, 10, t0 + Duration::seconds(7));
        assert_eq!(series.get_rx_speed(), None);
        assert_eq!(series.get_tx_speed(), None);
    }

    #[test]
    fn a_failed_cycle_does_not_wipe_the_series() {
        let mut series = CpuTimeSeries::new();
        let sample = CpuCoreTime { used: 4, total: 10, usage_percent: Some(40.0) };
        series.update(vec![sample], Utc::now());
        series.update(vec![], Utc::now());
        assert_eq!(series.get_average_usage_percent(), Some(40.0));
    }
}

impl Default for VelocityMetrics {
    fn default() -> Self {
        Self::new()
    }
}