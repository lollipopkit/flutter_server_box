//! 密码学随机凭据生成(getrandom 系统熵源)

use crate::utils::error::Result;

/// n 字节随机数的十六进制串(2n 字符)
pub fn random_hex(n: usize) -> Result<String> {
    let mut buf = vec![0u8; n];
    getrandom::fill(&mut buf)
        .map_err(|e| anyhow::anyhow!("System RNG unavailable: {e}"))?;
    Ok(buf.iter().map(|b| format!("{b:02x}")).collect())
}

/// n 位字母数字随机密码(拒绝采样,无取模偏差)
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
