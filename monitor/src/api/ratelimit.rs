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
//! Two independent keys, both of which must pass:
//!
//! - **by source IP** — stops one host from grinding through passwords, and
//!   from enumerating usernames by watching which ones respond differently.
//! - **by username** — stops a botnet from spreading the same guessing run
//!   across many source addresses, where per-IP counters would never trip.
//!
//! Blocking by username is a denial-of-service lever against that account by
//! design; the alternative is leaving distributed guessing unthrottled, which
//! is worse for a credential that grants shell access. The cap keeps the
//! worst case at five minutes.

use std::collections::HashMap;
use std::net::IpAddr;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

/// Failures allowed before any delay is imposed.
const FREE_ATTEMPTS: u32 = 3;
const BASE_DELAY: Duration = Duration::from_secs(1);
const MAX_DELAY: Duration = Duration::from_secs(300);
/// Entries idle for longer than this carry no useful history.
const ENTRY_TTL: Duration = Duration::from_secs(3600);
/// Only walk the map to prune once it is big enough to be worth it — an
/// unthrottled attacker rotating source addresses is the only way to get here.
const PRUNE_THRESHOLD: usize = 1024;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
enum Key {
    Ip(IpAddr),
    /// Stored lowercased: usernames are matched case-sensitively by the
    /// login query, but throttling by the exact case would let an attacker
    /// reset the counter by varying capitalisation.
    User(String),
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
    fn penalty(&self) -> Duration {
        let effective = self.failures.saturating_add(self.in_flight);
        let Some(excess) = effective.checked_sub(FREE_ATTEMPTS) else {
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
    pub fn begin(
        &self,
        ip: Option<IpAddr>,
        username: &str,
    ) -> std::result::Result<LoginAttempt, Duration> {
        let now = Instant::now();
        let attempt_keys = keys(ip, username);
        let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        if entries.len() > PRUNE_THRESHOLD {
            entries.retain(|_, e| {
                e.in_flight > 0 || now.saturating_duration_since(e.last_seen) < ENTRY_TTL
            });
        }

        let wait = attempt_keys
            .iter()
            .filter_map(|key| {
                let entry = entries.get(key)?;
                let elapsed = now.saturating_duration_since(entry.last_seen);
                entry
                    .penalty()
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

fn keys(ip: Option<IpAddr>, username: &str) -> Vec<Key> {
    let mut keys = Vec::with_capacity(2);
    if let Some(ip) = ip {
        keys.push(Key::Ip(ip));
    }
    if !username.is_empty() {
        keys.push(Key::User(username.to_lowercase()));
    }
    keys
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ip(last: u8) -> Option<IpAddr> {
        Some(IpAddr::from([192, 168, 0, last]))
    }

    fn fail(throttle: &LoginThrottle, ip: Option<IpAddr>, username: &str) {
        let attempt = throttle
            .begin(ip, username)
            .expect("the attempt should be admitted");
        throttle.record_failure(attempt);
    }

    fn assert_admitted(throttle: &LoginThrottle, ip: Option<IpAddr>, username: &str) {
        let attempt = throttle
            .begin(ip, username)
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
            fail(&throttle, ip(1), "admin");
            assert_admitted(&throttle, ip(1), "admin");
        }
    }

    #[test]
    fn penalty_doubles_and_is_capped() {
        let mut entry = Entry {
            failures: FREE_ATTEMPTS + 1,
            in_flight: 0,
            last_seen: Instant::now(),
        };
        assert_eq!(entry.penalty(), BASE_DELAY);
        entry.failures += 1;
        assert_eq!(entry.penalty(), BASE_DELAY * 2);
        entry.failures = u32::MAX;
        assert_eq!(entry.penalty(), MAX_DELAY);
    }

    #[test]
    fn failures_block_the_real_admission_path_until_the_delay_passes() {
        let throttle = LoginThrottle::new();
        for _ in 0..FREE_ATTEMPTS + 1 {
            fail(&throttle, ip(1), "admin");
        }
        assert!(matches!(throttle.begin(ip(1), "admin"), Err(wait) if wait <= BASE_DELAY));

        age_entries(&throttle, BASE_DELAY);
        assert_admitted(&throttle, ip(1), "admin");
    }

    #[test]
    fn success_clears_both_counters() {
        let throttle = LoginThrottle::new();
        for _ in 0..FREE_ATTEMPTS + 1 {
            fail(&throttle, ip(1), "admin");
        }
        age_entries(&throttle, BASE_DELAY);
        let attempt = throttle.begin(ip(1), "admin").unwrap();
        throttle.record_success(attempt);

        assert_admitted(&throttle, ip(2), "admin");
        assert_admitted(&throttle, ip(1), "someone-else");
    }

    #[test]
    fn distributed_guessing_trips_the_username_counter() {
        let throttle = LoginThrottle::new();
        // Every attempt from a different address: per-IP counters never trip
        for i in 0..FREE_ATTEMPTS + 1 {
            fail(&throttle, ip(i as u8), "admin");
        }
        assert!(
            throttle.begin(ip(200), "admin").is_err(),
            "spreading attempts across addresses must still throttle the account"
        );
        assert_admitted(&throttle, ip(200), "someone-else");
    }

    #[test]
    fn case_changes_do_not_reset_the_username_counter() {
        let throttle = LoginThrottle::new();
        for _ in 0..FREE_ATTEMPTS + 1 {
            fail(&throttle, ip(1), "Admin");
        }
        assert!(throttle.begin(ip(9), "aDMIN").is_err());
    }

    #[test]
    fn an_idle_key_starts_over() {
        let throttle = LoginThrottle::new();
        for _ in 0..FREE_ATTEMPTS + 1 {
            fail(&throttle, ip(1), "admin");
        }
        age_entries(&throttle, ENTRY_TTL + Duration::from_secs(1));
        fail(&throttle, ip(1), "admin");
        assert_admitted(&throttle, ip(1), "admin");
    }

    #[test]
    fn a_missing_peer_address_still_throttles_by_username() {
        let throttle = LoginThrottle::new();
        for _ in 0..FREE_ATTEMPTS + 1 {
            fail(&throttle, None, "admin");
        }
        assert!(throttle.begin(None, "admin").is_err());
    }

    #[test]
    fn concurrent_attempts_reserve_the_limit_atomically() {
        let throttle = LoginThrottle::new();
        let mut attempts = Vec::new();
        for _ in 0..FREE_ATTEMPTS + 1 {
            attempts.push(throttle.begin(ip(1), "admin").unwrap());
        }
        assert!(matches!(
            throttle.begin(ip(1), "admin"),
            Err(wait) if wait <= BASE_DELAY
        ));

        for attempt in attempts {
            throttle.cancel(attempt);
        }
        assert_admitted(&throttle, ip(1), "admin");
    }

    #[test]
    fn dropping_an_unfinished_attempt_releases_its_reservation() {
        let throttle = LoginThrottle::new();
        let attempts: Vec<_> = (0..FREE_ATTEMPTS + 1)
            .map(|_| throttle.begin(ip(1), "admin").unwrap())
            .collect();
        assert!(throttle.begin(ip(1), "admin").is_err());

        drop(attempts);
        assert_admitted(&throttle, ip(1), "admin");
    }
}
