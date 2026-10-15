//! Panel tokens (JWT, HS256 only) and passwords.
//!
//! The token is signed and checked here with `ring`'s HMAC, the one crypto
//! implementation the agent ships: a JWT library would bring RSA and elliptic
//! curves for algorithms a token of this agent never uses.

use base64::Engine;
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use serde::{Deserialize, Serialize};
use chrono::{Duration, Utc};
use crate::utils::error::{MonitorError, Result};

// Cost 12, matching bcrypt::DEFAULT_COST. The plaintext is irrelevant: this
// is only used to spend the same verification work when an account is absent.
const DUMMY_PASSWORD_HASH: &str =
    "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxDr5E6a6E9E/sy0tESrQ6D7x8e";

/// What every panel token names: the agent has one account, so the subject
/// says only that the token is one of this agent's.
pub const SUBJECT: &str = "owner";

/// How far past `exp` a token still counts, for clocks a little apart.
const LEEWAY_SECS: i64 = 60;

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,  // always [`SUBJECT`]
    pub exp: usize,   // expiration time
    pub iat: usize,   // issued at
}

#[derive(Deserialize)]
struct Header {
    alg: String,
}

fn key(secret: &str) -> ring::hmac::Key {
    ring::hmac::Key::new(ring::hmac::HMAC_SHA256, secret.as_bytes())
}

/// [claims] as an HS256 token signed with [secret].
pub fn sign_token(claims: &Claims, secret: &str) -> Result<String> {
    let header = URL_SAFE_NO_PAD.encode(br#"{"alg":"HS256","typ":"JWT"}"#);
    let payload = serde_json::to_vec(claims).map_err(|e| MonitorError::Auth(e.to_string()))?;
    let signed = format!("{header}.{}", URL_SAFE_NO_PAD.encode(payload));
    let tag = ring::hmac::sign(&key(secret), signed.as_bytes());
    Ok(format!("{signed}.{}", URL_SAFE_NO_PAD.encode(tag.as_ref())))
}

pub fn generate_token(secret: &str) -> Result<String> {
    let now = Utc::now();
    let expiration = now
        .checked_add_signed(Duration::hours(1))
        .expect("valid timestamp")
        .timestamp() as usize;
    sign_token(&Claims { sub: SUBJECT.to_string(), exp: expiration, iat: now.timestamp() as usize }, secret)
}

/// The claims of a token this agent signed with [secret] and not expired.
/// Only HS256: a header naming anything else (`none` included) is refused
/// before the signature is looked at.
pub fn verify_token(token: &str, secret: &str) -> Result<Claims> {
    let bad = |why: &str| MonitorError::Auth(why.to_string());
    let mut parts = token.split('.');
    let (Some(header), Some(payload), Some(signature), None) = (parts.next(), parts.next(), parts.next(), parts.next())
    else {
        return Err(bad("malformed token"));
    };
    let decode = |part: &str| URL_SAFE_NO_PAD.decode(part).map_err(|_| bad("malformed token"));
    let header: Header = serde_json::from_slice(&decode(header)?).map_err(|_| bad("malformed token"))?;
    if header.alg != "HS256" {
        return Err(bad("unsupported algorithm"));
    }
    let signed = &token[..token.len() - signature.len() - 1];
    ring::hmac::verify(&key(secret), signed.as_bytes(), &decode(signature)?).map_err(|_| bad("invalid signature"))?;
    let claims: Claims = serde_json::from_slice(&decode(payload)?).map_err(|_| bad("malformed token"))?;
    if (claims.exp as i64) + LEEWAY_SECS < Utc::now().timestamp() {
        return Err(bad("expired token"));
    }
    Ok(claims)
}

pub fn verify_password(password: &str, hash: &str) -> Result<bool> {
    bcrypt::verify(password, hash)
        .map_err(|e| MonitorError::Auth(e.to_string()))
}

/// Verifies a login password without revealing whether the account exists by
/// always calling [`verify_password`]. An absent account is checked against
/// [`DUMMY_PASSWORD_HASH`] and still always returns false.
pub fn verify_login_password(password: &str, hash: Option<&str>) -> Result<bool> {
    let matched = verify_password(password, hash.unwrap_or(DUMMY_PASSWORD_HASH)).unwrap_or_default();
    Ok(hash.is_some() && matched)
}

pub fn hash_password(password: &str) -> Result<String> {
    bcrypt::hash(password, bcrypt::DEFAULT_COST)
        .map_err(|e| MonitorError::Auth(e.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    const SECRET: &str = "test-secret-that-is-long-enough-32ch";

    fn token_with(header: &str, claims: &Claims, secret: &str) -> String {
        let signed = format!(
            "{}.{}",
            URL_SAFE_NO_PAD.encode(header),
            URL_SAFE_NO_PAD.encode(serde_json::to_vec(claims).unwrap())
        );
        let tag = ring::hmac::sign(&key(secret), signed.as_bytes());
        format!("{signed}.{}", URL_SAFE_NO_PAD.encode(tag.as_ref()))
    }

    fn claims(exp_in: i64) -> Claims {
        let now = Utc::now().timestamp();
        Claims { sub: SUBJECT.into(), exp: (now + exp_in) as usize, iat: now as usize }
    }

    #[test]
    fn a_token_round_trips() {
        let token = generate_token(SECRET).unwrap();
        let read = verify_token(&token, SECRET).unwrap();
        assert_eq!(read.sub, SUBJECT);
        assert!(read.exp > read.iat);
    }

    /// The wire format other JWT readers accept: `HS256` in the header, the
    /// signature over `header.payload`, unpadded base64url throughout.
    #[test]
    fn a_token_is_a_standard_hs256_jwt() {
        let token = generate_token(SECRET).unwrap();
        let header = URL_SAFE_NO_PAD.decode(token.split('.').next().unwrap()).unwrap();
        assert_eq!(header, br#"{"alg":"HS256","typ":"JWT"}"#);
        // Signed the way any HS256 signer does.
        let claims: Claims =
            serde_json::from_slice(&URL_SAFE_NO_PAD.decode(token.split('.').nth(1).unwrap()).unwrap()).unwrap();
        assert_eq!(token_with(r#"{"alg":"HS256","typ":"JWT"}"#, &claims, SECRET), token);
    }

    #[test]
    fn a_token_not_ours_is_refused() {
        let token = generate_token(SECRET).unwrap();
        assert!(verify_token(&token, "another-secret-that-is-long-enough").is_err());
        // Payload swapped under the old signature.
        let (signed, signature) = token.rsplit_once('.').unwrap();
        let (header, _) = signed.split_once('.').unwrap();
        let forged = format!(
            "{header}.{}.{signature}",
            URL_SAFE_NO_PAD.encode(serde_json::to_vec(&claims(86_400)).unwrap())
        );
        assert!(verify_token(&forged, SECRET).is_err());
        for broken in ["", "a.b", "a.b.c.d", &format!("{token}x"), &token.replace('.', "")] {
            assert!(verify_token(broken, SECRET).is_err(), "{broken}");
        }
    }

    #[test]
    fn only_hs256_is_read() {
        let unsigned = format!(
            "{}.{}.",
            URL_SAFE_NO_PAD.encode(r#"{"alg":"none","typ":"JWT"}"#),
            URL_SAFE_NO_PAD.encode(serde_json::to_vec(&claims(3600)).unwrap())
        );
        assert!(verify_token(&unsigned, SECRET).is_err());
        let other = token_with(r#"{"alg":"HS512","typ":"JWT"}"#, &claims(3600), SECRET);
        assert!(verify_token(&other, SECRET).is_err());
    }

    #[test]
    fn an_expired_token_is_refused_past_the_leeway() {
        assert!(verify_token(&sign_token(&claims(-LEEWAY_SECS + 5), SECRET).unwrap(), SECRET).is_ok());
        assert!(verify_token(&sign_token(&claims(-LEEWAY_SECS - 5), SECRET).unwrap(), SECRET).is_err());
    }

    #[test]
    fn a_missing_account_still_uses_a_valid_bcrypt_hash() {
        assert!(!verify_login_password("not-an-account", None).unwrap());
    }

    #[test]
    fn an_existing_account_keeps_normal_password_matching() {
        let hash = bcrypt::hash("correct", 4).unwrap();
        assert!(verify_login_password("correct", Some(&hash)).unwrap());
        assert!(!verify_login_password("wrong", Some(&hash)).unwrap());
    }
}
