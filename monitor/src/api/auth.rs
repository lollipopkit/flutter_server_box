use jsonwebtoken::{decode, encode, Algorithm, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use chrono::{Duration, Utc};
use crate::utils::error::{MonitorError, Result};

// Cost 12, matching bcrypt::DEFAULT_COST. The plaintext is irrelevant: this
// is only used to spend the same verification work when an account is absent.
const DUMMY_PASSWORD_HASH: &str =
    "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxDr5E6a6E9E/sy0tESrQ6D7x8e";

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,  // subject (user id)
    pub exp: usize,   // expiration time
    pub iat: usize,   // issued at
}

pub fn generate_token(user_id: &str, secret: &str) -> Result<String> {
    let expiration = Utc::now()
        .checked_add_signed(Duration::hours(1))
        .expect("valid timestamp")
        .timestamp() as usize;
    
    let claims = Claims {
        sub: user_id.to_string(),
        exp: expiration,
        iat: Utc::now().timestamp() as usize,
    };
    
    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_ref()),
    ).map_err(|e| MonitorError::Auth(e.to_string()))?;
    
    Ok(token)
}

pub fn verify_token(token: &str, secret: &str) -> Result<Claims> {
    let token_data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_ref()),
        &Validation::new(Algorithm::HS256),
    ).map_err(|e| MonitorError::Auth(e.to_string()))?;
    
    Ok(token_data.claims)
}


pub fn verify_password(password: &str, hash: &str) -> Result<bool> {
    bcrypt::verify(password, hash)
        .map_err(|e| MonitorError::Auth(e.to_string()))
}

/// Verifies a login password without revealing whether the account exists by
/// always calling [`verify_password`]. An absent account is checked against
/// [`DUMMY_PASSWORD_HASH`] and still always returns false.
pub fn verify_login_password(password: &str, hash: Option<&str>) -> Result<bool> {
    let matched = match verify_password(password, hash.unwrap_or(DUMMY_PASSWORD_HASH)) {
        Ok(v) => v,
        Err(_) => false,
    };
    Ok(hash.is_some() && matched)
}

pub fn hash_password(password: &str) -> Result<String> {
    bcrypt::hash(password, bcrypt::DEFAULT_COST)
        .map_err(|e| MonitorError::Auth(e.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

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
