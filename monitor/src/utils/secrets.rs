//! Cryptographically random credential generation (getrandom system entropy)

use crate::utils::error::Result;

/// Hex string of n random bytes (2n characters)
pub fn random_hex(n: usize) -> Result<String> {
    let mut buf = vec![0u8; n];
    getrandom::fill(&mut buf)
        .map_err(|e| anyhow::anyhow!("System RNG unavailable: {e}"))?;
    Ok(buf.iter().map(|b| format!("{b:02x}")).collect())
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
