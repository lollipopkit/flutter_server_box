//! Trust-on-first-use record for the sshd the browser terminal connects to.
//!
//! The agent reaches sshd over loopback, where a man in the middle already
//! needs local access — but pinning still catches the case that matters:
//! something else taking over the port after a restart, which is exactly when
//! a user would be typing their password into it without looking.
//!
//! A mismatch is refused, never re-pinned. Recovering is a deliberate act
//! (delete the row), because silently accepting a changed key would make the
//! record worthless.
//!
//! The app's tunnel has no rows here. It verifies the host key itself, at its
//! own end, against its own store — the agent is a byte relay on that path and
//! could not check it even if it wanted to.

use russh::keys::ssh_key::PublicKey;
use sqlx::SqlitePool;

use crate::utils::error::Result;

/// What checking a presented key concluded.
#[derive(Debug, PartialEq, Eq)]
pub enum Verdict {
    /// Matches what was recorded.
    Known,
    /// Nothing recorded yet; this call stored it.
    Pinned,
    /// A key is on record and this isn't it.
    Mismatch {
        expected: String,
        actual: String,
    },
}

/// OpenSSH's `SHA256:...` form, the same string `ssh-keygen -lf` prints, so an
/// operator can compare a mismatch against the host without conversion.
pub fn fingerprint(key: &PublicKey) -> String {
    key.fingerprint(Default::default()).to_string()
}

/// Checks `key` against the record for `addr`, pinning it if there is none.
pub async fn verify(pool: &SqlitePool, addr: &str, key: &PublicKey) -> Result<Verdict> {
    let actual = fingerprint(key);
    let key_type = key.algorithm().to_string();

    let existing: Option<String> =
        sqlx::query_scalar("SELECT fingerprint FROM ssh_known_hosts WHERE addr = ?")
            .bind(addr)
            .fetch_optional(pool)
            .await?;

    match existing {
        Some(expected) if expected == actual => Ok(Verdict::Known),
        Some(expected) => Ok(Verdict::Mismatch { expected, actual }),
        None => pin_or_compare(pool, addr, &key_type, &actual).await,
    }
}

async fn pin_or_compare(
    pool: &SqlitePool,
    addr: &str,
    key_type: &str,
    actual: &str,
) -> Result<Verdict> {
    // `OR IGNORE`, not `REPLACE`: two terminals opening at once must
    // not turn a race into a silent re-pin.
    let inserted = sqlx::query(
        "INSERT OR IGNORE INTO ssh_known_hosts (addr, key_type, fingerprint) \
         VALUES (?, ?, ?)",
    )
    .bind(addr)
    .bind(key_type)
    .bind(actual)
    .execute(pool)
    .await?;
    if inserted.rows_affected() == 1 {
        tracing::info!("Pinned SSH host key for {addr}: {actual} ({key_type})");
        return Ok(Verdict::Pinned);
    }

    // Another connection won the first-pin race. Never report our key as
    // pinned until it has been compared with the row that won.
    let expected: String =
        sqlx::query_scalar("SELECT fingerprint FROM ssh_known_hosts WHERE addr = ?")
            .bind(addr)
            .fetch_one(pool)
            .await?;
    if expected == actual {
        Ok(Verdict::Known)
    } else {
        Ok(Verdict::Mismatch {
            expected,
            actual: actual.to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Two fixed ed25519 public keys, in the form `~/.ssh/known_hosts` holds.
    /// Fixed rather than generated: these tests are about which fingerprint
    /// ends up stored, so the inputs may as well be visible and stable.
    const KEY_A: &str =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/8CDdhCJFw4MDlAbvKw2kXAlC5Jia/ujNcPJ+3JI+y";
    const KEY_B: &str =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII+H9P6DcbdOp8NY/sIHU6loGRl58YMfSAHQgEfcI0fh";

    async fn pool() -> SqlitePool {
        let pool = SqlitePool::connect("sqlite::memory:").await.unwrap();
        sqlx::migrate!("./migrations").run(&pool).await.unwrap();
        pool
    }

    fn key(openssh: &str) -> PublicKey {
        PublicKey::from_openssh(openssh).unwrap()
    }

    #[tokio::test]
    async fn first_key_is_pinned_then_recognised() {
        let pool = pool().await;
        let k = key(KEY_A);

        assert_eq!(verify(&pool, "127.0.0.1:22", &k).await.unwrap(), Verdict::Pinned);
        assert_eq!(verify(&pool, "127.0.0.1:22", &k).await.unwrap(), Verdict::Known);
    }

    #[tokio::test]
    async fn a_changed_key_is_refused_not_repinned() {
        let pool = pool().await;
        let original = key(KEY_A);
        let impostor = key(KEY_B);

        verify(&pool, "127.0.0.1:22", &original).await.unwrap();
        let verdict = verify(&pool, "127.0.0.1:22", &impostor).await.unwrap();
        assert!(matches!(verdict, Verdict::Mismatch { .. }));

        // The original must still be the one on record: a refused key that
        // silently replaced the pin would defeat the whole point
        assert_eq!(
            verify(&pool, "127.0.0.1:22", &original).await.unwrap(),
            Verdict::Known
        );
    }

    #[tokio::test]
    async fn different_addresses_are_pinned_separately() {
        let pool = pool().await;
        let a = key(KEY_A);
        let b = key(KEY_B);

        assert_eq!(verify(&pool, "127.0.0.1:22", &a).await.unwrap(), Verdict::Pinned);
        assert_eq!(verify(&pool, "127.0.0.1:2222", &b).await.unwrap(), Verdict::Pinned);
        assert_eq!(verify(&pool, "127.0.0.1:22", &a).await.unwrap(), Verdict::Known);
    }

    #[tokio::test]
    async fn lost_first_pin_race_compares_the_winning_row() {
        let pool = pool().await;
        let a = key(KEY_A);
        let b = key(KEY_B);
        let addr = "127.0.0.1:22";
        let expected = fingerprint(&a);
        sqlx::query(
            "INSERT INTO ssh_known_hosts (addr, key_type, fingerprint) VALUES (?, ?, ?)",
        )
        .bind(addr)
        .bind(a.algorithm().to_string())
        .bind(&expected)
        .execute(&pool)
        .await
        .unwrap();

        assert!(matches!(
            pin_or_compare(&pool, addr, b.algorithm().as_ref(), &fingerprint(&b))
                .await
                .unwrap(),
            Verdict::Mismatch { .. }
        ));
        assert_eq!(
            pin_or_compare(&pool, addr, a.algorithm().as_ref(), &expected)
                .await
                .unwrap(),
            Verdict::Known
        );
    }

    #[tokio::test]
    async fn the_fingerprint_is_the_openssh_form() {
        let k = key(KEY_A);
        assert!(
            fingerprint(&k).starts_with("SHA256:"),
            "operators compare this against `ssh-keygen -lf` output"
        );
    }
}
