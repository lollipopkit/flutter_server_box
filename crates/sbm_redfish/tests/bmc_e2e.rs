//! Opt-in test against a real BMC, ported from the Dart package's
//! `e2e_test.dart`.
//!
//! **Read-only. Nothing here changes the machine's power state, and nothing
//! here may be made to.** The reset action is *read* — its target and its
//! allowable values are what the whole negotiation rests on — but no POST is
//! sent to it; `tests/power.rs` covers the request with fixtures.
//!
//! What this tells that no fixture can: which sensor model the firmware in
//! front of you presents, whether its ids are shaped like the recorded ones,
//! and whether a session is really given back. **When it answers on a model
//! not yet listed in `doc/vendors.md`, add a row.**
//!
//! Configuration, from the environment or the workspace-root `.env`
//! (gitignored); ignored by default, skipped when unset:
//!
//! ```text
//! SBM_E2E_BMC_URL=https://10.0.0.9
//! SBM_E2E_BMC_USER=...
//! SBM_E2E_BMC_PWD=...
//! ```
//!
//! `cargo test -p sbm_redfish --test bmc_e2e -- --ignored --nocapture`. The
//! certificate is read and pinned by the test itself, as the edit page does.

use std::time::Duration;

use sbm_redfish::client::{Client, ClientConfig};
use sbm_redfish::model::{PowerIntent, ResetRequest};
use sbm_redfish::{cert, discover, snapshot};

fn env(var: &str) -> Option<String> {
    let root_env = concat!(env!("CARGO_MANIFEST_DIR"), "/../../.env");
    dotenvy::from_path(root_env).ok();
    std::env::var(var).ok().filter(|s| !s.is_empty())
}

#[tokio::test]
#[ignore]
async fn a_real_bmc_is_read_without_being_changed() {
    let Some(url) = env("SBM_E2E_BMC_URL") else {
        eprintln!("SBM_E2E_BMC_URL not set; skipped");
        return;
    };
    let parsed = reqwest::Url::parse(&url).expect("SBM_E2E_BMC_URL must be a URL");
    let host = parsed.host_str().unwrap().trim_matches(|c| c == '[' || c == ']').to_string();
    let port = parsed.port_or_known_default().unwrap();
    let info = cert::fetch_server_cert(&host, port, Duration::from_secs(10)).await.unwrap();
    println!("certificate: {} (issued by {})", info.subject, info.issuer);

    let client = Client::new(ClientConfig {
        base_url: url.trim_end_matches('/').to_string(),
        user: env("SBM_E2E_BMC_USER").unwrap_or_default(),
        password: env("SBM_E2E_BMC_PWD"),
        pinned_sha256: Some(info.fingerprint.clone()),
        timeout: Duration::from_secs(30),
        ..ClientConfig::default()
    })
    .unwrap();

    let topology = discover(&client).await.unwrap();
    println!("service: {:?} {:?} Redfish {:?}", topology.root.vendor, topology.root.product, topology.root.version);
    let system = topology.system.clone().expect("a system to manage");
    println!("power state: {:?}, reset types: {:?}", system.power_state, system.reset_types);
    assert!(system.reset_target.is_some(), "the reset action has a target");
    let plannable: Vec<_> = PowerIntent::ALL
        .into_iter()
        .filter(|intent| ResetRequest::build(&system, *intent).is_some())
        .collect();
    println!("intents this system answers: {plannable:?}");
    assert!(!plannable.is_empty());

    let snap = snapshot(&client, Some(&topology)).await.unwrap();
    println!(
        "sensors: {} temperatures, {} fans, watts {:?}, truncated {}",
        snap.sensors.temperatures.len(),
        snap.sensors.fans.len(),
        snap.sensors.watts,
        snap.sensors_truncated
    );
    client.close().await;
}
