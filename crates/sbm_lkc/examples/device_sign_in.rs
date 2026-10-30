//! Signs in with a device code for real, reads the account from homebase and
//! refreshes once due (never a token printed):
//! `cargo run -p sbm_lkc --example device_sign_in`.

use sbm_lkc::{Client, DevicePoll, Failure, REFRESH_WINDOW, now_ms};
use std::time::Duration;

#[tokio::main]
async fn main() {
    let client = Client::new().expect("client");
    let mut device = client.start_device().await.expect("device code");
    println!("Open {}", device.verification_uri_complete.as_deref().unwrap_or(&device.verification_uri));
    println!("Code: {}", device.user_code);
    let tokens = loop {
        tokio::time::sleep(Duration::from_secs(device.interval_secs)).await;
        match client.poll_device(&device).await {
            Ok(DevicePoll::Pending) => {}
            Ok(DevicePoll::SlowDown(secs)) => device.interval_secs = secs,
            Ok(DevicePoll::Done(tokens)) => break tokens,
            Err(e) if e.failure == Failure::Unreachable => eprintln!("retrying: {e}"),
            Err(e) => panic!("poll: {e}"),
        }
    };
    println!("{:#?}", client.user(&tokens.access).await.expect("user"));
    assert!(tokens.refresh.is_some(), "refresh token");
    println!("access token lifetime: {}s", (tokens.expires_at_ms - now_ms()) / 1000);
    assert_eq!(client.refresh(&tokens).await.unwrap_err().failure, Failure::TooEarly);
    let wait = (tokens.expires_at_ms - REFRESH_WINDOW.as_millis() as i64 - now_ms()).max(0) as u64 + 1_000;
    println!("refreshing in {}s", wait / 1000);
    tokio::time::sleep(Duration::from_millis(wait)).await;
    let again = client.refresh(&tokens).await.expect("refresh");
    println!("new refresh token: {}", again.refresh != tokens.refresh);
    client.user(&again.access).await.expect("user after refresh");
    client.revoke(again.refresh.as_deref().expect("refresh token")).await.expect("revoke");
    println!("revoked");
}
