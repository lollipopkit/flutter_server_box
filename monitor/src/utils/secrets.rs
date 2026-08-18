//! Cryptographically random credential generation (getrandom system entropy)

use crate::utils::error::Result;

/// Hex string of n random bytes (2n characters)
pub fn random_hex(n: usize) -> Result<String> {
    let mut buf = vec![0u8; n];
    getrandom::fill(&mut buf)
        .map_err(|e| anyhow::anyhow!("System RNG unavailable: {e}"))?;
    Ok(buf.iter().map(|b| format!("{b:02x}")).collect())
}

/// Byte comparison whose running time depends only on the length.
///
/// For anything an attacker can submit repeatedly against a stored secret —
/// WebSocket tickets, terminal session ids. `==` on slices short-circuits at
/// the first differing byte, which over enough attempts reveals a correct
/// prefix. The length is not secret here (every caller compares fixed-width
/// values), so returning early on a length mismatch leaks nothing.
pub fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let mut diff = 0u8;
    for (x, y) in a.iter().zip(b.iter()) {
        diff |= x ^ y;
    }
    diff == 0
}

/// n-character alphanumeric random password (rejection sampling, no modulo bias)
pub fn random_password(n: usize) -> Result<String> {
    const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    const LIMIT: u8 = (u8::MAX / CHARSET.len() as u8) * CHARSET.len() as u8; // 248
    let mut out = String::with_capacity(n);
    let mut buf = [0u8; 64];
    while out.len() < n {
        getrandom::fill(&mut buf)
            .map_err(|e| anyhow::anyhow!("System RNG unavailable: {e}"))?;
        for &b in buf.iter() {
            if b < LIMIT && out.len() < n {
                out.push(CHARSET[(b % CHARSET.len() as u8) as usize] as char);
            }
        }
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn constant_time_eq_matches_ordinary_equality() {
        assert!(constant_time_eq(b"", b""));
        assert!(constant_time_eq(b"abcd", b"abcd"));
        assert!(!constant_time_eq(b"abcd", b"abce"));
        // Differing in the first byte must be as false as the last
        assert!(!constant_time_eq(b"abcd", b"zbcd"));
        assert!(!constant_time_eq(b"abc", b"abcd"));
        assert!(!constant_time_eq(b"abcd", b"abc"));
    }

    #[test]
    fn random_hex_has_the_requested_width_and_varies() {
        let a = random_hex(16).unwrap();
        assert_eq!(a.len(), 32);
        assert!(a.chars().all(|c| c.is_ascii_hexdigit()));
        assert_ne!(a, random_hex(16).unwrap());
    }
}
