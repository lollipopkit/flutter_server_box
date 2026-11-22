//! MCP bearer tokens: `sbt_` and 64 hex digits, stored as their BLAKE3
//! digest and looked up by it. The same credential shape for the monitor and
//! the app, so a token pasted somewhere says what it is.

/// The prefix every token starts with — the same idea as `sbw_` on a watch
/// token.
pub const PREFIX: &str = "sbt_";

/// A new token: [`PREFIX`] and 32 random bytes in hex.
pub fn mint() -> Result<String, String> {
    let mut buf = [0u8; 32];
    getrandom::fill(&mut buf).map_err(|e| format!("system RNG unavailable: {e}"))?;
    Ok(format!("{PREFIX}{}", hex(&buf)))
}

/// What a token is stored and looked up by.
pub fn hash(token: &str) -> String {
    blake3::hash(token.as_bytes()).to_hex().to_string()
}

/// Whether [s] is a digest [`hash`] could have made.
pub fn is_hash(s: &str) -> bool {
    s.len() == 64 && s.bytes().all(|b| matches!(b, b'0'..=b'9' | b'a'..=b'f'))
}

/// The digest of the token in an `Authorization` header's value, when it
/// carries one of ours: a bearer credential with [`PREFIX`].
pub fn bearer(authorization: &str) -> Option<String> {
    let token = authorization.strip_prefix("Bearer ")?.trim();
    token.starts_with(PREFIX).then(|| hash(token))
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_minted_token_has_the_shape_and_its_digest_is_found_from_the_header() {
        let token = mint().unwrap();
        assert!(token.starts_with(PREFIX));
        assert_eq!(token.len(), PREFIX.len() + 64);
        assert_ne!(token, mint().unwrap());
        let digest = hash(&token);
        assert!(is_hash(&digest));
        assert_eq!(bearer(&format!("Bearer {token}")), Some(digest));
        assert_eq!(bearer(&token), None);
        assert_eq!(bearer("Bearer other"), None);
        assert!(!is_hash("ABC"));
    }
}
