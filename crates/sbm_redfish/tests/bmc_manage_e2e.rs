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
use sbm_redfish::Outcome;
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
    let mut failures: Vec<String> = Vec::new();

    // Logs: every one read, the clearable one cleared.
    let services = log_services(&client, &topology).await.unwrap();
    if services.is_empty() {
        failures.push("no log at all".into());
    }
    for service in &services {
        let page = log_entries(&client, service).await.unwrap();
        println!(
            "log {:?} ({:?}): {} kept of {:?}, truncated {}",
            service.id, service.scope, page.entries.len(), page.total, page.truncated
        );
    }
    if let Some(log) = services.iter().find(|s| s.clear_target.is_some()) {
        match clear_log(&client, log).await {
            Ok(outcome) => {
                // `Accepted` means the work is not done yet; reading before it
                // finishes says nothing about the clear.
                if let Outcome::Accepted(task) = outcome {
                    let _ = client.await_task(&task, Duration::from_secs(60), Duration::from_secs(2)).await;
                }
                let after = log_entries(&client, log).await.unwrap();
                if !after.entries.is_empty() {
                    failures.push(format!("{:?} not empty after a clear", log.id));
                }
            }
            // OpenBMC romulus under QEMU answers its ClearLog with 500
            // (`doc/vendors.md`): the request is what is checked there.
            Err(e) if e.detail.as_deref().is_some_and(|d| d.starts_with("HTTP 500")) => {
                println!("{:?}: the BMC failed its own ClearLog ({e:?})", log.id);
            }
            Err(e) => failures.push(format!("{:?}: {e:?}", log.id)),
        }
    }

    let before = read_system(&client, &topology).await.unwrap();

    // The locator, on and back.
    if let Some(locator) = before.locator {
        let flipped = async {
            set_locator(&client, &topology, !locator.on).await?;
            read_system(&client, &topology).await
        }
        .await;
        match flipped {
            Ok(after) if after.locator.is_some_and(|l| l.on != locator.on) => {}
            Ok(_) => failures.push("the locator did not move".into()),
            Err(e) => failures.push(format!("locator: {e:?}")),
        }
        if let Err(e) = set_locator(&client, &topology, locator.on).await {
            failures.push(format!("locator not put back: {e:?}"));
        }
    }

    // The boot override, set once to something else and back.
    if let Some(boot) = before.boot.clone().filter(|b| b.can_set()) {
        let current = boot.target.clone();
        let other = boot
            .settable_targets()
            .into_iter()
            .find(|t| Some(t) != current.as_ref());
        match (other, boot.enabled_values.iter().any(|e| e == "Once")) {
            (Some(target), true) => {
                let set = BootRequest { target: target.clone(), enabled: "Once".into(), mode: None };
                let applied = async {
                    set_boot(&client, &topology, &set).await?;
                    read_system(&client, &topology).await
                }
                .await;
                match applied {
                    Ok(after) => match after.boot {
                        Some(after) if after.target.as_ref() == Some(&target) && after.enabled.as_deref() == Some("Once") => {}
                        other => failures.push(format!("boot not set: {other:?}")),
                    },
                    Err(e) => failures.push(format!("boot: {e:?}")),
                }
                let back = BootRequest {
                    target: current.clone().unwrap_or_else(|| "None".into()),
                    enabled: boot.enabled.clone().unwrap_or_else(|| "Disabled".into()),
                    mode: None,
                };
                if let Err(e) = set_boot(&client, &topology, &back).await {
                    failures.push(format!("boot not put back: {e:?}"));
                }
            }
            (None, _) => println!("boot: no other target to try"),
            (Some(_), false) => println!("boot: `Once` not offered"),
        }
    }

    let drives = storage(&client, &topology).await.unwrap();
    println!("drives: {}, unsupported {}", drives.drives.len(), drives.unsupported);
    println!("virtual media slots: {}", media_slots(&client, &topology).await.unwrap().len());
    client.close().await;
    assert!(failures.is_empty(), "{failures:#?}");
}
