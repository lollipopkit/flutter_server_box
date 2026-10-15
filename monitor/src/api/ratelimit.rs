//! Login throttling.
//!
//! `POST /login` had no limit at all, which was survivable while the panel
//! only exposed metrics. Once the panel can open a terminal, the password
//! guards shell access to the machine, and an unthrottled login endpoint is
//! the cheapest way in.
//!
//! Failure-triggered exponential backoff rather than a fixed-rate token
//! bucket: legitimate users mistype a password once or twice and should see
//! no delay, while a guessing loop should get slower without bound. A token
//! bucket gives the attacker a steady, predictable allowance forever.
//!
//! Two independent keys, both of which must pass: **the source IP**, which
//! stops one host from grinding through passwords, and one that depends on
//! who is asking ([`Who`]):
//!
//! - **a known device** (one that signed in before, `db::accounts`
//!   `login_device`): its own counter. Failures from anywhere else never
//!   lock it out.
//! - **a stranger**: the account-wide counter, which every unknown client
//!   shares, so a botnet spreading one guessing run across many addresses
//!   still meets a limit. It allows more failures before any delay
//!   ([`ACCOUNT_FREE_ATTEMPTS`]) since it is shared, and at worst it delays
//!   signing in on a new device, never on a known one.
//! - **a signed-in caller re-entering the password**: a counter only such
//!   callers share, out of strangers' reach.

use std::collections::HashMap;
use std::net::IpAddr;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

/// Failures allowed before any delay is imposed, per address and per device.
const FREE_ATTEMPTS: u32 = 3;
/// The same for the counter every unknown client shares.
const ACCOUNT_FREE_ATTEMPTS: u32 = 20;
const BASE_DELAY: Duration = Duration::from_secs(1);
const MAX_DELAY: Duration = Duration::from_secs(300);
/// Entries idle for longer than this carry no useful history.
const ENTRY_TTL: Duration = Duration::from_secs(3600);
/// Only walk the map to prune once it is big enough to be worth it — an
/// unthrottled attacker rotating source addresses is the only way to get here.
const PRUNE_THRESHOLD: usize = 1024;
const PRUNE_INTERVAL: Duration = Duration::from_secs(60);

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
enum Key {
    Ip(IpAddr),
    /// A known device, by its token's SHA-256.
    Device(String),
    Account,
    Reauth,
}

impl Key {
    fn free_attempts(&self) -> u32 {
        match self {
            Key::Account => ACCOUNT_FREE_ATTEMPTS,
            _ => FREE_ATTEMPTS,
        }
    }
}

/// Who is entering the password, which decides the second key.
#[derive(Debug, Clone)]
pub enum Who {
    /// A client the agent does not know.
    Stranger,
    /// A device that signed in before, by its token's SHA-256.
    Device(String),
    /// A signed-in caller confirming a change (`admin::reauth`).
    SignedIn,
}

#[derive(Debug)]
struct Entry {
    failures: u32,
    /// Attempts admitted but not yet resolved. They count provisionally as
    /// failures so concurrent guesses cannot all pass the same stale check.
    in_flight: u32,
    last_seen: Instant,
}

impl Entry {
    /// How long after `last_seen` this key stays blocked.
    fn penalty(&self, free: u32) -> Duration {
        let effective = self.failures.saturating_add(self.in_flight);
        let Some(excess) = effective.checked_sub(free) else {
            return Duration::ZERO;
        };
        if excess == 0 {
            return Duration::ZERO;
        }
        // Saturating shift: `failures` is unbounded, the exponent is not.
        let shift = (excess - 1).min(20);
        BASE_DELAY.saturating_mul(1u32 << shift).min(MAX_DELAY)
    }
}

#[derive(Default)]
pub struct LoginThrottle {
    last_prune: Mutex<Option<Instant>>,
    entries: Arc<Mutex<HashMap<Key, Entry>>>,
}

#[derive(Debug)]
pub struct LoginAttempt {
    entries: Arc<Mutex<HashMap<Key, Entry>>>,
    keys: Vec<Key>,
    resolved: bool,
}

impl Drop for LoginAttempt {
    fn drop(&mut self) {
        if !self.resolved {
            release_reservation(&self.entries, &self.keys);
        }
    }
}

impl LoginThrottle {
    pub fn new() -> Self {
        Self::default()
    }

    /// Atomically admits and reserves one password verification.
    pub fn begin(&self, ip: Option<IpAddr>, who: Who) -> std::result::Result<LoginAttempt, Duration> {
        let now = Instant::now();
        let attempt_keys = keys(ip, who);
        let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        if entries.len() > PRUNE_THRESHOLD {
            let mut last = self.last_prune.lock().unwrap_or_else(|e| e.into_inner());
            if last.is_none_or(|at| now.saturating_duration_since(at) >= PRUNE_INTERVAL) {
                entries.retain(|_, e| {
                    e.in_flight > 0 || now.saturating_duration_since(e.last_seen) < ENTRY_TTL
                });
                *last = Some(now);
            }
        }

        let wait = attempt_keys
            .iter()
            .filter_map(|key| {
                let entry = entries.get(key)?;
                let elapsed = now.saturating_duration_since(entry.last_seen);
                entry
                    .penalty(key.free_attempts())
                    .checked_sub(elapsed)
                    .filter(|d| !d.is_zero())
            })
            .max();
        if let Some(wait) = wait {
            return Err(wait);
        }

        for key in &attempt_keys {
            let entry = entries.entry(key.clone()).or_insert(Entry {
                failures: 0,
                in_flight: 0,
                last_seen: now,
            });
            if entry.in_flight == 0 && now.saturating_duration_since(entry.last_seen) >= ENTRY_TTL {
                entry.failures = 0;
            }
            entry.in_flight = entry.in_flight.saturating_add(1);
            entry.last_seen = now;
        }
        Ok(LoginAttempt {
            entries: Arc::clone(&self.entries),
            keys: attempt_keys,
            resolved: false,
        })
    }

    pub fn record_failure(&self, mut attempt: LoginAttempt) {
        self.finish_failure_at(&attempt.keys, Instant::now());
        attempt.resolved = true;
    }

    /// Clears both counters. A correct password proves the client isn't the
    /// guessing loop the counters exist for.
    pub fn record_success(&self, mut attempt: LoginAttempt) {
        self.clear(&attempt.keys);
        attempt.resolved = true;
    }

    fn clear(&self, attempt_keys: &[Key]) {
        let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        for key in attempt_keys {
            entries.remove(key);
        }
    }

    /// Releases a reservation when the attempt could not be evaluated.
    pub fn cancel(&self, attempt: LoginAttempt) {
        drop(attempt);
    }

    fn finish_failure_at(&self, attempt_keys: &[Key], now: Instant) {
        let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        for key in attempt_keys {
            let entry = entries.entry(key.clone()).or_insert(Entry {
                failures: 0,
                in_flight: 0,
                last_seen: now,
            });
            entry.in_flight = entry.in_flight.saturating_sub(1);
            entry.failures = entry.failures.saturating_add(1);
            entry.last_seen = now;
        }
    }
}

fn release_reservation(entries: &Mutex<HashMap<Key, Entry>>, attempt_keys: &[Key]) {
    let mut entries = entries.lock().unwrap_or_else(|e| e.into_inner());
    for key in attempt_keys {
        let remove = if let Some(entry) = entries.get_mut(key) {
            entry.in_flight = entry.in_flight.saturating_sub(1);
            entry.failures == 0 && entry.in_flight == 0
        } else {
            false
        };
        if remove {
            entries.remove(key);
        }
    }
}

fn keys(ip: Option<IpAddr>, who: Who) -> Vec<Key> {
    let second = match who {
        Who::Stranger => Key::Account,
        Who::Device(hash) => Key::Device(hash),
        Who::SignedIn => Key::Reauth,
    };
    ip.map(Key::Ip).into_iter().chain([second]).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ip(last: u8) -> Option<IpAddr> {
        Some(IpAddr::from([192, 168, 0, last]))
    }

    fn fail(throttle: &LoginThrottle, ip: Option<IpAddr>) {
        let attempt = throttle
            .begin(ip, Who::Stranger)
            .expect("the attempt should be admitted");
        throttle.record_failure(attempt);
    }

    fn assert_admitted(throttle: &LoginThrottle, ip: Option<IpAddr>) {
        let attempt = throttle
            .begin(ip, Who::Stranger)
            .expect("the attempt should be admitted");
        throttle.cancel(attempt);
    }

    fn age_entries(throttle: &LoginThrottle, age: Duration) {
        let mut entries = throttle.entries.lock().unwrap_or_else(|e| e.into_inner());
        for entry in entries.values_mut() {
            entry.last_seen = entry
                .last_seen
                .checked_sub(age)
                .expect("test duration fits in Instant");
        }
    }

    #[test]
    fn typos_are_not_punished() {
        let throttle = LoginThrottle::new();
        for _ in 0..FREE_ATTEMPTS {
            fail(&throttle, ip(1));
            assert_admitted(&throttle, ip(1));
        }
    }

    #[test]
    fn penalty_doubles_and_is_capped() {
        let mut entry = Entry {
            failures: FREE_ATTEMPTS + 1,
            in_flight: 0,
            last_seen: Instant::now(),
        };
        assert_eq!(entry.penalty(FREE_ATTEMPTS), BASE_DELAY);
        entry.failures += 1;
        assert_eq!(entry.penalty(FREE_ATTEMPTS), BASE_DELAY * 2);
        entry.failures = u32::MAX;
        assert_eq!(entry.penalty(FREE_ATTEMPTS), MAX_DELAY);
    }

    #[test]
    fn failures_block_the_real_admission_path_until_the_delay_passes() {
        let throttle = LoginThrottle::new();
        for _ in 0..FREE_ATTEMPTS + 1 {
            fail(&throttle, ip(1));
        }
        assert!(matches!(throttle.begin(ip(1), Who::Stranger), Err(wait) if wait <= BASE_DELAY));

        age_entries(&throttle, BASE_DELAY);
        assert_admitted(&throttle, ip(1));
    }

    #[test]
    fn success_clears_both_counters() {
        let throttle = LoginThrottle::new();
        for _ in 0..FREE_ATTEMPTS + 1 {
            fail(&throttle, ip(1));
        }
        age_entries(&throttle, BASE_DELAY);
        let attempt = throttle.begin(ip(1), Who::Stranger).unwrap();
        throttle.record_success(attempt);

        assert_admitted(&throttle, ip(2));
    }

    #[test]
    fn distributed_guessing_trips_the_account_counter() {
        let throttle = LoginThrottle::new();
        // Every attempt from a different address: per-IP counters never trip
        for i in 0..ACCOUNT_FREE_ATTEMPTS + 1 {
            fail(&throttle, ip(i as u8));
        }
        assert!(
            throttle.begin(ip(200), Who::Stranger).is_err(),
            "spreading attempts across addresses must still throttle the account"
        );
    }

    #[test]
    fn a_known_device_is_not_locked_out_by_strangers() {
        let throttle = LoginThrottle::new();
        for i in 0..ACCOUNT_FREE_ATTEMPTS + 1 {
            fail(&throttle, ip(i as u8));
        }
        assert!(throttle.begin(ip(200), Who::Stranger).is_err());
        let device = || Who::Device("d1".into());
        let attempt = throttle.begin(ip(200), device()).expect("a known device signs in");
        throttle.cancel(attempt);
        // Nor is a signed-in caller confirming a change.
        let attempt = throttle.begin(ip(200), Who::SignedIn).expect("reauth is its own counter");
        throttle.cancel(attempt);
    }

    #[test]
    fn a_devices_failures_lock_only_that_device() {
        let throttle = LoginThrottle::new();
        for i in 0..FREE_ATTEMPTS + 1 {
            let attempt = throttle.begin(ip(i as u8), Who::Device("d1".into())).unwrap();
            throttle.record_failure(attempt);
        }
        assert!(throttle.begin(ip(100), Who::Device("d1".into())).is_err());
        assert!(throttle.begin(ip(100), Who::Device("d2".into())).is_ok());
        assert!(throttle.begin(ip(101), Who::Stranger).is_ok());
    }

    #[test]
    fn an_idle_key_starts_over() {
        let throttle = LoginThrottle::new();
        for _ in 0..FREE_ATTEMPTS + 1 {
            fail(&throttle, ip(1));
        }
        age_entries(&throttle, ENTRY_TTL + Duration::from_secs(1));
        fail(&throttle, ip(1));
        assert_admitted(&throttle, ip(1));
    }

    #[test]
    fn a_missing_peer_address_still_throttles_the_account() {
        let throttle = LoginThrottle::new();
        for _ in 0..ACCOUNT_FREE_ATTEMPTS + 1 {
            fail(&throttle, None);
        }
        assert!(throttle.begin(None, Who::Stranger).is_err());
    }

    #[test]
    fn concurrent_attempts_reserve_the_limit_atomically() {
        let throttle = LoginThrottle::new();
        let mut attempts = Vec::new();
        for _ in 0..FREE_ATTEMPTS + 1 {
            attempts.push(throttle.begin(ip(1), Who::Stranger).unwrap());
        }
        assert!(matches!(
            throttle.begin(ip(1), Who::Stranger),
            Err(wait) if wait <= BASE_DELAY
        ));

        for attempt in attempts {
            throttle.cancel(attempt);
        }
        assert_admitted(&throttle, ip(1));
    }

    #[test]
    fn dropping_an_unfinished_attempt_releases_its_reservation() {
        let throttle = LoginThrottle::new();
        let attempts: Vec<_> = (0..FREE_ATTEMPTS + 1)
            .map(|_| throttle.begin(ip(1), Who::Stranger).unwrap())
            .collect();
        assert!(throttle.begin(ip(1), Who::Stranger).is_err());

        drop(attempts);
        assert_admitted(&throttle, ip(1));
    }
    #[test]
    fn rotating_sources_workload() {
        let throttle = LoginThrottle::new();
        let started = Instant::now();
        for n in 0..10_000u32 {
            let attempt = throttle.begin(Some(IpAddr::from(n.to_be_bytes())), Who::Stranger).unwrap();
            throttle.record_failure(attempt);
            // Only the addresses are measured here.
            throttle.entries.lock().unwrap().remove(&Key::Account);
        }
        eprintln!("10,000 rotating addresses: {:?}", started.elapsed());
        assert_eq!(throttle.entries.lock().unwrap().len(), 10_000);
    }

    #[test]
    fn sweeps_are_periodic_and_preserve_reservations() {
        let throttle = LoginThrottle::new();
        let addr = |n: u32| Some(IpAddr::from((n + 1).to_be_bytes()));
        for n in 0..PRUNE_THRESHOLD as u32 + 2 {
            let attempt = throttle.begin(addr(n), Who::Stranger).unwrap();
            throttle.record_success(attempt);
            let mut entries = throttle.entries.lock().unwrap();
            entries.insert(Key::Ip(addr(n).unwrap()), Entry { failures: 1, in_flight: 0, last_seen: Instant::now() });
        }
        let pending = throttle.begin(addr(u32::MAX - 1), Who::Stranger).unwrap();
        age_entries(&throttle, ENTRY_TTL + Duration::from_secs(1));
        assert_admitted(&throttle, addr(u32::MAX - 2));
        assert!(throttle.entries.lock().unwrap().contains_key(&Key::Ip(addr(0).unwrap())));
        *throttle.last_prune.lock().unwrap() = Some(Instant::now() - PRUNE_INTERVAL);
        assert_admitted(&throttle, addr(u32::MAX - 2));
        let entries = throttle.entries.lock().unwrap();
        assert!(!entries.contains_key(&Key::Ip(addr(0).unwrap())));
        assert_eq!(entries[&Key::Ip(addr(u32::MAX - 1).unwrap())].in_flight, 1);
        drop(entries);
        drop(pending);
    }
}
