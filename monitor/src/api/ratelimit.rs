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
        self.begin_at(ip, username, Instant::now())
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

    fn begin_at(
        &self,
        ip: Option<IpAddr>,
        username: &str,
        now: Instant,
    ) -> std::result::Result<LoginAttempt, Duration> {
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
                entry.penalty().checked_sub(elapsed).filter(|d| !d.is_zero())
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
            if entry.in_flight == 0
                && now.saturating_duration_since(entry.last_seen) >= ENTRY_TTL
            {
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

    #[cfg(test)]
    fn check_at(&self, ip: Option<IpAddr>, username: &str, now: Instant) -> Option<Duration> {
        let entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        keys(ip, username)
            .into_iter()
            .filter_map(|key| {
                let entry = entries.get(&key)?;
                let elapsed = now.saturating_duration_since(entry.last_seen);
                entry.penalty().checked_sub(elapsed).filter(|d| !d.is_zero())
            })
            .max()
    }

    #[cfg(test)]
    fn record_failure_at(&self, ip: Option<IpAddr>, username: &str, now: Instant) {
        let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        if entries.len() > PRUNE_THRESHOLD {
            entries.retain(|_, e| now.saturating_duration_since(e.last_seen) < ENTRY_TTL);
        }
        for key in keys(ip, username) {
            let entry = entries.entry(key).or_insert(Entry {
                failures: 0,
                in_flight: 0,
                last_seen: now,
            });
            // A key idle past the TTL starts over rather than resuming a
            // penalty from hours ago.
            if now.saturating_duration_since(entry.last_seen) >= ENTRY_TTL {
                entry.failures = 0;
            }
            entry.failures = entry.failures.saturating_add(1);
            entry.last_seen = now;
        }
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

    #[test]
    fn typos_are_not_punished() {
        let throttle = LoginThrottle::new();
        let now = Instant::now();
        for _ in 0..FREE_ATTEMPTS {
            throttle.record_failure_at(ip(1), "admin", now);
            assert!(throttle.check_at(ip(1), "admin", now).is_none());
        }
    }

    #[test]
    fn delay_doubles_and_is_capped() {
        let throttle = LoginThrottle::new();
        let now = Instant::now();
        for _ in 0..FREE_ATTEMPTS + 1 {
            throttle.record_failure_at(ip(1), "admin", now);
        }
        assert_eq!(throttle.check_at(ip(1), "admin", now), Some(BASE_DELAY));

        throttle.record_failure_at(ip(1), "admin", now);
        assert_eq!(throttle.check_at(ip(1), "admin", now), Some(BASE_DELAY * 2));

        for _ in 0..64 {
            throttle.record_failure_at(ip(1), "admin", now);
        }
        assert_eq!(throttle.check_at(ip(1), "admin", now), Some(MAX_DELAY));
    }

    #[test]
    fn waiting_out_the_delay_clears_it() {
        let throttle = LoginThrottle::new();
        let now = Instant::now();
        for _ in 0..FREE_ATTEMPTS + 1 {
            throttle.record_failure_at(ip(1), "admin", now);
        }
        assert!(throttle.check_at(ip(1), "admin", now).is_some());
        assert!(
            throttle
                .check_at(ip(1), "admin", now + BASE_DELAY)
                .is_none()
        );
    }

    #[test]
    fn success_clears_both_counters() {
        let throttle = LoginThrottle::new();
        let now = Instant::now();
        for _ in 0..FREE_ATTEMPTS + 2 {
            throttle.record_failure_at(ip(1), "admin", now);
        }
        throttle.clear(&keys(ip(1), "admin"));
        assert!(throttle.check_at(ip(1), "admin", now).is_none());
        // The username counter must be gone too, not just the IP one
        assert!(throttle.check_at(ip(2), "admin", now).is_none());
    }

    #[test]
    fn distributed_guessing_trips_the_username_counter() {
        let throttle = LoginThrottle::new();
        let now = Instant::now();
        // Every attempt from a different address: per-IP counters never trip
        for i in 0..FREE_ATTEMPTS + 1 {
            throttle.record_failure_at(ip(i as u8), "admin", now);
        }
        assert!(
            throttle.check_at(ip(200), "admin", now).is_some(),
            "spreading attempts across addresses must still throttle the account"
        );
        assert!(
            throttle.check_at(ip(200), "someone-else", now).is_none(),
            "other accounts must stay reachable"
        );
    }

    #[test]
    fn case_changes_do_not_reset_the_username_counter() {
        let throttle = LoginThrottle::new();
        let now = Instant::now();
        for _ in 0..FREE_ATTEMPTS + 1 {
            throttle.record_failure_at(ip(1), "Admin", now);
        }
        assert!(throttle.check_at(ip(9), "aDMIN", now).is_some());
    }

    #[test]
    fn an_idle_key_starts_over() {
        let throttle = LoginThrottle::new();
        let now = Instant::now();
        for _ in 0..FREE_ATTEMPTS + 4 {
            throttle.record_failure_at(ip(1), "admin", now);
        }
        let later = now + ENTRY_TTL + Duration::from_secs(1);
        throttle.record_failure_at(ip(1), "admin", later);
        assert!(
            throttle.check_at(ip(1), "admin", later).is_none(),
            "history older than the TTL should not carry a penalty forward"
        );
    }

    #[test]
    fn a_missing_peer_address_still_throttles_by_username() {
        let throttle = LoginThrottle::new();
        let now = Instant::now();
        for _ in 0..FREE_ATTEMPTS + 1 {
            throttle.record_failure_at(None, "admin", now);
        }
        assert!(throttle.check_at(None, "admin", now).is_some());
    }

    #[test]
    fn concurrent_attempts_reserve_the_limit_atomically() {
        let throttle = LoginThrottle::new();
        let now = Instant::now();
        let mut attempts = Vec::new();
        for _ in 0..FREE_ATTEMPTS + 1 {
            attempts.push(throttle.begin_at(ip(1), "admin", now).unwrap());
        }
        assert!(matches!(
            throttle.begin_at(ip(1), "admin", now),
            Err(wait) if wait == BASE_DELAY
        ));

        for attempt in attempts {
            throttle.cancel(attempt);
        }
        assert!(throttle.begin_at(ip(1), "admin", now).is_ok());
    }

    #[test]
    fn dropping_an_unfinished_attempt_releases_its_reservation() {
        let throttle = LoginThrottle::new();
        let now = Instant::now();
        let attempts: Vec<_> = (0..FREE_ATTEMPTS + 1)
            .map(|_| throttle.begin_at(ip(1), "admin", now).unwrap())
            .collect();
        assert!(throttle.begin_at(ip(1), "admin", now).is_err());

        drop(attempts);
        assert!(throttle.begin_at(ip(1), "admin", now).is_ok());
    }
}
