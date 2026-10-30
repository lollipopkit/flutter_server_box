use super::*;
use serde_json::json;

const ISS: &str = "https://auth.example/auth/v1/";

fn discovery() -> Value {
    json!({
        "issuer": ISS,
        "authorization_endpoint": "https://auth.example/auth/v1/oidc/authorize",
        "token_endpoint": "https://auth.example/auth/v1/oidc/token",
        "device_authorization_endpoint": "https://auth.example/auth/v1/oidc/device",
        "revocation_endpoint": "https://auth.example/auth/v1/oidc/token/revoke",
    })
}

#[test]
fn discovery_must_name_its_issuer_over_https() {
    assert_eq!(Metadata::from_json(ISS, &discovery()).unwrap().token_endpoint, "https://auth.example/auth/v1/oidc/token");
    let mut other = discovery();
    other["issuer"] = json!("https://evil.example/");
    assert!(Metadata::from_json(ISS, &other).is_err());
    let mut plain = discovery();
    plain["device_authorization_endpoint"] = json!("http://auth.example/device");
    assert!(Metadata::from_json(ISS, &plain).is_err());
    let mut missing = discovery();
    missing.as_object_mut().unwrap().remove("token_endpoint");
    assert!(Metadata::from_json(ISS, &missing).is_err());
}

#[test]
fn a_device_answer_reads_with_its_deadline() {
    let device = parse_device(
        &json!({ "device_code": "d", "user_code": "ABCD", "verification_uri": "https://auth.example/device",
                 "verification_uri_complete": "https://auth.example/device?code=ABCD", "expires_in": 300, "interval": 5 }),
        1_000,
    )
    .unwrap();
    assert_eq!((device.expires_at_ms, device.interval_secs), (301_000, 5));
    assert!(parse_device(&json!({ "device_code": "d", "user_code": "u", "verification_uri": "http://x/" }), 0).is_err());
    assert!(parse_device(&json!({ "user_code": "u", "verification_uri": "https://x/" }), 0).is_err());
}

#[test]
fn only_invalid_grant_ends_the_session() {
    let refused = |error: &str| TokenError::Refused { error: error.into(), description: String::new() }.into_error().failure;
    assert_eq!(refused("invalid_grant"), Failure::Rejected);
    assert_eq!(refused("access_denied"), Failure::Denied);
    assert_eq!(refused("expired_token"), Failure::Expired);
    assert_eq!(refused("Forbidden"), Failure::Refused);
    assert_eq!(refused("invalid_client"), Failure::Refused);
    assert_eq!(refused("temporarily_unavailable"), Failure::Unreachable);
}

#[test]
fn only_an_oauth_error_is_a_refusal() {
    let failure = |status: u16, body: &str| match answer("u", status, body.as_bytes()) {
        Ok(_) => None,
        Err(e) => Some(e.into_error().failure),
    };
    assert_eq!(failure(200, r#"{"access_token":"a"}"#), None);
    assert_eq!(failure(200, "<html>"), Some(Failure::InvalidResponse));
    assert_eq!(failure(400, r#"{"error":"invalid_grant"}"#), Some(Failure::Rejected));
    // A proxy's page, a challenge, a rate limit, an IdP error: try again.
    assert_eq!(failure(403, "<html>challenge</html>"), Some(Failure::Unreachable));
    assert_eq!(failure(400, r#"{"message":"no code"}"#), Some(Failure::Unreachable));
    assert_eq!(failure(429, r#"{"error":"invalid_grant"}"#), Some(Failure::Unreachable));
    assert_eq!(failure(502, "<html>bad gateway</html>"), Some(Failure::Unreachable));
}

#[test]
fn a_homebase_reply_unwraps_to_its_data() {
    let failure = |status: u16, body: &str| unwrap("u", status, body.as_bytes()).map_err(|e| e.failure);
    assert_eq!(failure(200, r#"{"data":{"id":"u1"}}"#), Ok(json!({ "id": "u1" })));
    assert_eq!(failure(200, r#"{"code":0,"data":1}"#), Ok(json!(1)));
    assert_eq!(failure(401, r#"{"code":2,"reason":"token"}"#), Err(Failure::Rejected));
    assert_eq!(failure(500, r#"{"code":1}"#), Err(Failure::Unreachable));
    assert_eq!(failure(404, r#"{"code":3}"#), Err(Failure::Refused));
    assert_eq!(failure(403, "<html>challenge</html>"), Err(Failure::Unreachable));
}

#[test]
fn a_user_reads_as_homebase_answers_it() {
    let user: User = serde_json::from_value(json!({
        "id": "u1", "name": "Ada", "group": "user",
        "created_at": "2026-10-01T00:00:00Z", "updated_at": "2026-10-02T00:00:00Z",
    }))
    .unwrap();
    assert_eq!((user.name.as_str(), user.avatar), ("Ada", None));
    assert!(serde_json::from_value::<User>(json!({ "name": "Ada" })).is_err());
}

#[test]
fn tokens_are_due_in_the_last_45_seconds() {
    let tokens = Tokens::from_response(&json!({ "access_token": "a", "refresh_token": "r", "expires_in": 300 }), 0, None).unwrap();
    assert_eq!(tokens.expires_at_ms, 300_000);
    assert!(!tokens.due(300_000 - 45_000));
    assert!(tokens.due(300_000 - 44_999));
    // A refresh that rotates none keeps the one it had; one with no expiry is due at once.
    let renewed = Tokens::from_response(&json!({ "access_token": "b" }), 1_000, Some(&tokens)).unwrap();
    assert_eq!((renewed.refresh.as_deref(), renewed.due(1_000)), (Some("r"), true));
    assert!(Tokens::from_response(&json!({}), 0, None).is_err());
}

#[tokio::test]
async fn a_refresh_waits_until_due() {
    let tokens = Tokens { access: "a".into(), refresh: Some("r".into()), expires_at_ms: now_ms() + 120_000 };
    // Refused here, before anything is sent (this issuer does not exist).
    let client = Client::with("https://auth.invalid/", CLIENT_ID, "https://api.invalid").unwrap();
    assert_eq!(client.refresh(&tokens).await.unwrap_err().failure, Failure::TooEarly);
    let none = Tokens { refresh: None, ..tokens };
    assert_eq!(client.refresh(&none).await.unwrap_err().failure, Failure::Rejected);
}

/// The real IdP: discovery and a device code (which expires unused).
/// `cargo test -p sbm_lkc -- --ignored`.
#[tokio::test]
#[ignore]
async fn the_idp_answers() {
    let client = Client::new().unwrap();
    assert_eq!(client.metadata().await.unwrap().issuer, ISSUER);
    let device = client.start_device().await.unwrap();
    assert!(device.verification_uri.starts_with("https://auth.lollipopkit.com/"));
    tokio::time::sleep(Duration::from_secs(device.interval_secs)).await;
    assert_eq!(client.poll_device(&device).await.unwrap(), DevicePoll::Pending);
    // Homebase refuses a token it did not see the IdP hand out.
    assert_eq!(client.user("not-a-token").await.unwrap_err().failure, Failure::Rejected);
}
