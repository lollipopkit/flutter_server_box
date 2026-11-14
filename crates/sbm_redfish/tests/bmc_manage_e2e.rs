//! Opt-in test that **changes a real BMC**: the locator light, the boot
//! override, the event log. Never its power. What it changes it puts back,
//! except the event log it clears — so run it against a BMC kept for tests
//! (the OpenBMC VM in `doc/vendors.md`), never one in use.
//!
//! The variables of `bmc_e2e.rs`, plus `SBM_E2E_BMC_MUTABLE=1`:
//!
//! `cargo test -p sbm_redfish --test bmc_manage_e2e -- --ignored --nocapture`

use std::time::Duration;

use sbm_redfish::client::{Client, ClientConfig};
use sbm_redfish::logs::{clear_log, log_entries, log_services};
use sbm_redfish::media::media_slots;
use sbm_redfish::model::BootRequest;
use sbm_redfish::storage::storage;
use sbm_redfish::{cert, discover, read_system, set_boot, set_locator};

fn env(var: &str) -> Option<String> {
    let root_env = concat!(env!("CARGO_MANIFEST_DIR"), "/../../.env");
    dotenvy::from_path(root_env).ok();
    std::env::var(var).ok().filter(|s| !s.is_empty())
}

async fn client() -> Option<Client> {
    let url = env("SBM_E2E_BMC_URL")?;
    if env("SBM_E2E_BMC_MUTABLE").as_deref() != Some("1") {
        eprintln!("SBM_E2E_BMC_MUTABLE not 1; skipped");
        return None;
    }
    let parsed = reqwest::Url::parse(&url).unwrap();
    let host = parsed.host_str().unwrap().trim_matches(['[', ']']).to_string();
    let info = cert::fetch_server_cert(&host, parsed.port_or_known_default().unwrap(), Duration::from_secs(10))
        .await
        .unwrap();
    Some(
        Client::new(ClientConfig {
            base_url: url.trim_end_matches('/').to_string(),
            user: env("SBM_E2E_BMC_USER").unwrap_or_default(),
            password: env("SBM_E2E_BMC_PWD"),
            pinned_sha256: Some(info.fingerprint),
            timeout: Duration::from_secs(30),
            ..ClientConfig::default()
        })
        .unwrap(),
    )
}

#[tokio::test]
#[ignore]
async fn a_real_bmc_is_managed_and_put_back() {
    let Some(client) = client().await else { return };
    let topology = discover(&client).await.unwrap();

    // Logs: every one read, the machine's event log cleared.
    let services = log_services(&client, &topology).await.unwrap();
    assert!(!services.is_empty(), "no log at all");
    for service in &services {
        let page = log_entries(&client, service).await.unwrap();
        println!(
            "log {:?} ({:?}): {} kept of {:?}, truncated {}",
            service.id, service.scope, page.entries.len(), page.total, page.truncated
        );
    }
    let clearable = services.iter().find(|s| s.clear_target.is_some());
    if let Some(log) = clearable {
        match clear_log(&client, log).await {
            Ok(_) => {
                let after = log_entries(&client, log).await.unwrap();
                assert!(after.entries.is_empty(), "{:?} not empty after a clear", log.id);
            }
            // OpenBMC romulus under QEMU answers its ClearLog with 500
            // (`doc/vendors.md`): the request is what is checked there.
            Err(e) if e.detail.as_deref().is_some_and(|d| d.starts_with("HTTP 500")) => {
                println!("{:?}: the BMC failed its own ClearLog ({e:?})", log.id);
            }
            Err(e) => panic!("{:?}: {e:?}", log.id),
        }
    }

    // The locator, on and back.
    let before = read_system(&client, &topology).await.unwrap();
    if let Some(locator) = before.locator {
        set_locator(&client, &topology, !locator.on).await.unwrap();
        let flipped = read_system(&client, &topology).await.unwrap().locator.unwrap();
        assert_eq!(flipped.on, !locator.on);
        set_locator(&client, &topology, locator.on).await.unwrap();
        assert_eq!(read_system(&client, &topology).await.unwrap().locator.unwrap().on, locator.on);
    }

    // The boot override, set once to something else and back.
    if let Some(boot) = before.boot.filter(|b| b.can_set()) {
        let target = boot.targets.iter().find(|t| Some(*t) != boot.target.as_ref() && *t != "None").unwrap();
        set_boot(&client, &topology, &BootRequest { target: target.clone(), enabled: "Once".into(), mode: None })
            .await
            .unwrap();
        let set = read_system(&client, &topology).await.unwrap().boot.unwrap();
        assert_eq!((set.target.as_ref(), set.enabled.as_deref()), (Some(target), Some("Once")));
        set_boot(
            &client,
            &topology,
            &BootRequest {
                target: boot.target.clone().unwrap_or_else(|| "None".into()),
                enabled: boot.enabled.clone().unwrap_or_else(|| "Disabled".into()),
                mode: None,
            },
        )
        .await
        .unwrap();
        let back = read_system(&client, &topology).await.unwrap().boot.unwrap();
        assert_eq!((back.target, back.enabled), (boot.target, boot.enabled));
    }

    let drives = storage(&client, &topology).await.unwrap();
    println!("drives: {}, unsupported {}", drives.drives.len(), drives.unsupported);
    println!("virtual media slots: {}", media_slots(&client, &topology).await.unwrap().len());
    client.close().await;
}
