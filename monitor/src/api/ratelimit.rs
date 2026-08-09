//! Login throttling.
//!
//! `POST /login` had no limit at all, which was survivable while the panel
//! only exposed metrics. Once the panel can open an SSH tunnel or a terminal,
//! the password guards shell access to the machine, and an unthrottled login
//! endpoint is the cheapest way in.
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
use std::sync::Mutex;
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
    last_seen: Instant,
}

impl Entry {
    /// How long after `last_seen` this key stays blocked.
    fn penalty(&self) -> Duration {
        let Some(excess) = self.failures.checked_sub(FREE_ATTEMPTS) else {
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
    entries: Mutex<HashMap<Key, Entry>>,
}

impl LoginThrottle {
    pub fn new() -> Self {
        Self::default()
    }

    /// `None` when the attempt may proceed, otherwise how long to wait.
    ///
    /// Does not consume anything: only [`record_failure`](Self::record_failure)
    /// moves the counters, so a correct password is never penalised for
    /// arriving during someone else's backoff on the same IP.
    pub fn check(&self, ip: Option<IpAddr>, username: &str) -> Option<Duration> {
        self.check_at(ip, username, Instant::now())
    }

    pub fn record_failure(&self, ip: Option<IpAddr>, username: &str) {
        self.record_failure_at(ip, username, Instant::now());
    }

    /// Clears both counters. A correct password proves the client isn't the
    /// guessing loop the counters exist for.
    pub fn record_success(&self, ip: Option<IpAddr>, username: &str) {
        let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        for key in keys(ip, username) {
            entries.remove(&key);
        }
    }

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

    fn record_failure_at(&self, ip: Option<IpAddr>, username: &str, now: Instant) {
        let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        if entries.len() > PRUNE_THRESHOLD {
            entries.retain(|_, e| now.saturating_duration_since(e.last_seen) < ENTRY_TTL);
        }
        for key in keys(ip, username) {
            let entry = entries.entry(key).or_insert(Entry {
                failures: 0,
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
        throttle.record_success(ip(1), "admin");
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
}
