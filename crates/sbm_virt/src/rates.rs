//! Guests' cumulative counters turned into rates.
//!
//! Ported from the app's `lib/data/model/virt/virt_rates.dart`.

use std::collections::{HashMap, HashSet};

use crate::model::Stats;

/// One guest's cumulative counters at one moment, as a host reports them.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct CounterSample {
    /// Unix milliseconds.
    pub at: i64,
    /// Cumulative CPU time (libvirt). Turned into a percentage of `vcpus`.
    pub cpu_time_ns: Option<u64>,
    /// CPU already as a percentage (PVE), used as is.
    pub cpu_percent: Option<f64>,
    pub vcpus: Option<u32>,
    pub mem_used: Option<u64>,
    pub mem_total: Option<u64>,
    pub disk_used: Option<u64>,
    pub disk_total: Option<u64>,
    /// Cumulative bytes.
    pub disk_read: Option<u64>,
    pub disk_write: Option<u64>,
    pub net_in: Option<u64>,
    pub net_out: Option<u64>,
}

impl CounterSample {
    fn same_counters(&self, o: &CounterSample) -> bool {
        self.disk_read == o.disk_read
            && self.disk_write == o.disk_write
            && self.net_in == o.net_in
            && self.net_out == o.net_out
    }
}

/// Turns successive [`CounterSample`]s into [`Stats`] rates, per guest.
///
/// A rate is Δcounter / Δt against the guest's previous sample; CPU from
/// cumulative time is Δcpu_time / (Δt · vcpus). A counter that went backwards
/// (the guest restarted, or a disk was detached) reads as not measured for
/// that sample rather than as a negative rate.
///
/// `hold_until_changed` is for a host whose counters advance in steps slower
/// than the poll: PVE's `/cluster/resources` is refreshed by `pvestatd` every
/// ten seconds or so, so diffing every poll would alternate zeros and spikes.
/// With it, the base for a rate is the last sample whose byte counters
/// *changed*, and an unchanged reading repeats the last rate for up to
/// `hold_for_ms`; past that, unchanged counters really are idle and read as
/// zero, and the base moves to that reading.
#[derive(Debug, Clone)]
pub struct RateTracker {
    pub hold_until_changed: bool,
    pub hold_for_ms: i64,
    last: HashMap<String, CounterSample>,
    base: HashMap<String, CounterSample>,
    rates: HashMap<String, Stats>,
}

/// How long an unchanged reading repeats the last rate.
pub const DEFAULT_HOLD_MS: i64 = 25_000;

impl RateTracker {
    pub fn new(hold_until_changed: bool) -> Self {
        Self {
            hold_until_changed,
            hold_for_ms: DEFAULT_HOLD_MS,
            last: HashMap::new(),
            base: HashMap::new(),
            rates: HashMap::new(),
        }
    }

    /// The rates for guest `id` as of `sample`, and remembers it.
    pub fn add(&mut self, id: &str, sample: CounterSample) -> Stats {
        let last = self.last.insert(id.to_owned(), sample.clone());
        let cpu = sample
            .cpu_percent
            .or_else(|| cpu_percent(last.as_ref(), &sample, sample.vcpus.unwrap_or(1)));
        let plain = Stats {
            at: sample.at,
            cpu,
            mem_used: sample.mem_used,
            mem_total: sample.mem_total,
            disk_used: sample.disk_used,
            disk_total: sample.disk_total,
            ..Stats::default()
        };

        let stats = if !self.hold_until_changed {
            match &last {
                None => plain,
                Some(last) => diff(last, &sample, plain),
            }
        } else {
            match self.base.get(id) {
                None => {
                    self.base.insert(id.to_owned(), sample);
                    plain
                }
                Some(base) if sample.same_counters(base) => {
                    let held = self
                        .rates
                        .get(id)
                        .filter(|_| sample.at - base.at < self.hold_for_ms)
                        .map(|previous| Stats { at: sample.at, ..previous.clone() });
                    match held {
                        Some(previous) => Stats {
                            cpu,
                            mem_used: sample.mem_used,
                            mem_total: sample.mem_total,
                            disk_used: sample.disk_used,
                            disk_total: sample.disk_total,
                            ..previous
                        },
                        // Idle past the hold: re-anchored here, so the first
                        // step after it is divided by at most the hold more,
                        // not by the whole idle stretch.
                        None => {
                            let base = self.base.insert(id.to_owned(), sample.clone()).unwrap();
                            diff(&base, &sample, plain)
                        }
                    }
                }
                Some(_) => {
                    let base = self.base.insert(id.to_owned(), sample.clone()).unwrap();
                    diff(&base, &sample, plain)
                }
            }
        };
        self.rates.insert(id.to_owned(), stats.clone());
        stats
    }

    /// Forgets guests not in `ids`, so a deleted guest's base does not linger.
    pub fn retain<'a>(&mut self, ids: impl IntoIterator<Item = &'a str>) {
        let keep: HashSet<&str> = ids.into_iter().collect();
        self.last.retain(|k, _| keep.contains(k.as_str()));
        self.base.retain(|k, _| keep.contains(k.as_str()));
        self.rates.retain(|k, _| keep.contains(k.as_str()));
    }

    pub fn clear(&mut self) {
        self.last.clear();
        self.base.clear();
        self.rates.clear();
    }
}

fn diff(from: &CounterSample, to: &CounterSample, stats: Stats) -> Stats {
    let seconds = (to.at - from.at) as f64 / 1000.0;
    if seconds <= 0.0 {
        return stats;
    }
    let rate = |a: Option<u64>, b: Option<u64>| match (a, b) {
        (Some(a), Some(b)) if b >= a => Some((b - a) as f64 / seconds),
        _ => None,
    };
    Stats {
        disk_read: rate(from.disk_read, to.disk_read),
        disk_write: rate(from.disk_write, to.disk_write),
        net_in: rate(from.net_in, to.net_in),
        net_out: rate(from.net_out, to.net_out),
        ..stats
    }
}

fn cpu_percent(from: Option<&CounterSample>, to: &CounterSample, vcpus: u32) -> Option<f64> {
    let a = from?.cpu_time_ns?;
    let b = to.cpu_time_ns?;
    if b < a {
        return None;
    }
    let ns = (to.at - from?.at) as f64 * 1_000_000.0;
    if ns <= 0.0 {
        return None;
    }
    let pct = (b - a) as f64 / (ns * vcpus.max(1) as f64) * 100.0;
    // Clock skew between the host's accounting and the reader's clock can
    // push a busy guest just past 100.
    Some(pct.clamp(0.0, 100.0))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn at(seconds: i64, net_in: u64) -> CounterSample {
        CounterSample { at: seconds * 1000, net_in: Some(net_in), ..Default::default() }
    }

    #[test]
    fn an_unchanged_reading_within_the_hold_repeats_the_last_rate() {
        let mut r = RateTracker::new(true);
        r.add("g", at(0, 0));
        assert_eq!(r.add("g", at(10, 1000)).net_in, Some(100.0));
        assert_eq!(r.add("g", at(12, 1000)).net_in, Some(100.0));
        assert_eq!(r.add("g", at(40, 1000)).net_in, Some(0.0), "past the hold: idle");
    }

    #[test]
    fn the_first_step_after_a_long_idle_is_not_spread_over_the_idle() {
        let mut r = RateTracker::new(true);
        r.add("g", at(0, 0));
        r.add("g", at(10, 1000));
        for s in (20..=3600).step_by(10) {
            let rate = r.add("g", at(s, 1000)).net_in;
            assert!(rate == Some(0.0) || rate == Some(100.0), "{s}: {rate:?}");
        }
        // 10 MB in pvestatd's latest step, an hour after the last one.
        let mb10 = 10_000_000u64;
        let rate = r.add("g", at(3610, 1000 + mb10)).net_in.unwrap();
        assert!(rate >= mb10 as f64 / (r.hold_for_ms as f64 / 1000.0 + 10.0), "{rate}");
    }

    #[test]
    fn plain_diffing_and_cpu_time() {
        let mut r = RateTracker::new(false);
        let s = |sec: i64, cpu_ns: u64, read: u64| CounterSample {
            at: sec * 1000,
            cpu_time_ns: Some(cpu_ns),
            vcpus: Some(2),
            disk_read: Some(read),
            ..Default::default()
        };
        let first = r.add("g", s(0, 0, 0));
        assert_eq!((first.cpu, first.disk_read), (None, None), "nothing to diff against");
        // 1 s of CPU over 1 s on 2 vCPUs: 50 %
        let second = r.add("g", s(1, 1_000_000_000, 4096));
        assert_eq!(second.cpu, Some(50.0));
        assert_eq!(second.disk_read, Some(4096.0));
        // A counter going backwards (a restart) is not a negative rate.
        let third = r.add("g", s(2, 0, 0));
        assert_eq!((third.cpu, third.disk_read), (None, None));
    }

    #[test]
    fn retain_forgets_removed_guests() {
        let mut r = RateTracker::new(false);
        r.add("a", at(0, 0));
        r.add("b", at(0, 0));
        r.retain(["a"]);
        assert_eq!(r.add("b", at(1, 100)).net_in, None, "b starts over");
        assert_eq!(r.add("a", at(1, 100)).net_in, Some(100.0));
    }
}
