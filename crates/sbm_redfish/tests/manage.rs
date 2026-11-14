//! Logs, drives, boot override, the locator light and virtual media, against
//! a recorded OpenBMC (romulus, under QEMU) and DMTF's public mockups
//! (`public-rackmount1`, `public-localstorage`, from DMTF/Redfish-Publications,
//! BSD-3-Clause).

mod common;

use std::collections::HashMap;

use common::{FakeTransport, vendor};
use sbm_redfish::logs::{LogScope, MAX_LOG_ENTRIES, clear_log, log_entries, log_services};
use sbm_redfish::media::{eject_media, insert_media, is_image_url, media_slots};
use sbm_redfish::model::BootRequest;
use sbm_redfish::storage::{MAX_DRIVES, storage};
use sbm_redfish::{Failure, discover, set_boot, set_locator};
use serde_json::{Value, json};

async fn discovered(name: &str) -> (FakeTransport, sbm_redfish::model::Topology) {
    let fake = FakeTransport::new(vendor(name));
    let topology = discover(&fake).await.unwrap();
    (fake, topology)
}

// --- discovery ---

#[tokio::test]
async fn the_manager_is_found_beside_the_system() {
    let (_, topology) = discovered("openbmc_romulus").await;

    assert_eq!(topology.manager_path.as_deref(), Some("/redfish/v1/Managers/bmc"));
    let manager = topology.manager.unwrap();
    assert_eq!(manager.log_services.as_deref(), Some("/redfish/v1/Managers/bmc/LogServices"));
}

// --- logs ---

#[tokio::test]
async fn the_machines_log_is_listed_before_the_bmcs_own() {
    let (fake, topology) = discovered("openbmc_romulus").await;

    let services = log_services(&fake, &topology).await.unwrap();

    let ids: Vec<_> = services.iter().map(|s| (s.id.as_deref(), s.scope)).collect();
    assert_eq!(ids, [(Some("EventLog"), LogScope::System), (Some("Journal"), LogScope::Manager)]);
    // Only the event log can be cleared on OpenBMC.
    assert!(services[0].clear_target.is_some());
    assert!(services[1].clear_target.is_none());
}

#[tokio::test]
async fn entries_come_newest_first() {
    let (fake, topology) = discovered("dmtf_rackmount1").await;
    let services = log_services(&fake, &topology).await.unwrap();
    let log = services.iter().find(|s| s.id.as_deref() == Some("Log1")).unwrap();

    let page = log_entries(&fake, log).await.unwrap();

    let ids: Vec<_> = page.entries.iter().map(|e| e.id.as_deref()).collect();
    assert_eq!(ids, [Some("2"), Some("1")]);
    assert_eq!(page.entries[0].severity.as_deref(), Some("Critical"));
    assert!(!page.truncated);
}

#[tokio::test]
async fn a_log_with_more_than_was_returned_says_so() {
    // OpenBMC's journal: 819 entries counted, three kept in the recording.
    let (fake, topology) = discovered("openbmc_romulus").await;
    let services = log_services(&fake, &topology).await.unwrap();
    let journal = services.iter().find(|s| s.id.as_deref() == Some("Journal")).unwrap();

    let page = log_entries(&fake, journal).await.unwrap();

    assert_eq!(page.entries.len(), 3);
    assert_eq!(page.total, Some(819));
    assert!(page.truncated);
}

fn paged_log(pages: usize, per_page: usize) -> FakeTransport {
    let mut resources = HashMap::new();
    for page in 0..pages {
        let path = if page == 0 {
            "/redfish/v1/Systems/1/LogServices/Sel/Entries".to_string()
        } else {
            format!("/redfish/v1/Systems/1/LogServices/Sel/Entries?$skip={}", page * per_page)
        };
        let members: Vec<Value> = (0..per_page)
            .map(|i| {
                let n = page * per_page + i;
                json!({"Id": n.to_string(), "Created": format!("2026-01-01T00:{:02}:{:02}Z", n / 60, n % 60)})
            })
            .collect();
        let mut doc = json!({"Members": members, "Members@odata.count": pages * per_page});
        if page + 1 < pages {
            doc["Members@odata.nextLink"] =
                json!(format!("/redfish/v1/Systems/1/LogServices/Sel/Entries?$skip={}", (page + 1) * per_page));
        }
        resources.insert(path, doc);
    }
    FakeTransport::new(resources)
}

fn sel() -> sbm_redfish::logs::LogService {
    sbm_redfish::logs::LogService::from_json(
        "/redfish/v1/Systems/1/LogServices/Sel",
        &json!({"Id": "Sel", "Entries": {"@odata.id": "/redfish/v1/Systems/1/LogServices/Sel/Entries"}}),
        LogScope::System,
    )
}

#[tokio::test]
async fn pages_are_followed_and_the_newest_kept() {
    let fake = paged_log(3, 100);

    let page = log_entries(&fake, &sel()).await.unwrap();

    assert_eq!(fake.get_count(), 3);
    assert_eq!(page.entries.len(), MAX_LOG_ENTRIES);
    assert_eq!(page.entries[0].id.as_deref(), Some("299"));
    assert!(page.truncated);
}

#[tokio::test]
async fn a_service_paging_by_ten_cannot_make_a_read_endless() {
    let fake = paged_log(100, 10);

    let page = log_entries(&fake, &sel()).await.unwrap();

    // The first page, then the tail by `$skip`: twenty pages in all from it.
    assert_eq!(fake.get_count(), 21);
    assert!(fake.gets.lock().unwrap()[1].ends_with("?$skip=800"));
    assert_eq!(page.entries.len(), MAX_LOG_ENTRIES);
    assert_eq!(page.entries[0].id.as_deref(), Some("999"));
    assert!(page.truncated);
}

#[tokio::test]
async fn a_page_that_fails_after_the_first_keeps_what_was_read() {
    let fake = paged_log(3, 10).forbidding("/redfish/v1/Systems/1/LogServices/Sel/Entries?$skip=20");

    let page = log_entries(&fake, &sel()).await.unwrap();

    assert_eq!(page.entries.len(), 20);
    assert!(page.truncated);
}

#[tokio::test]
async fn a_log_listing_nobody_can_read_is_an_error_not_an_empty_list() {
    let (fake, topology) = discovered("dmtf_rackmount1").await;
    let system = topology.system.as_ref().unwrap().log_services.clone().unwrap();
    let mut fake = fake.forbidding(&system);
    if let Some(manager) = topology.manager.as_ref().and_then(|m| m.log_services.clone()) {
        fake = fake.forbidding(&manager);
    }

    let error = log_services(&fake, &topology).await.unwrap_err();

    assert_eq!(error.failure, Failure::Forbidden);
}

#[tokio::test]
async fn clearing_posts_to_the_logs_own_action() {
    let (fake, topology) = discovered("openbmc_romulus").await;
    let services = log_services(&fake, &topology).await.unwrap();

    clear_log(&fake, &services[0]).await.unwrap();
    let journal = clear_log(&fake, &services[1]).await.unwrap_err();

    let posted = fake.posted.lock().unwrap().clone();
    assert_eq!(
        posted,
        [(
            "/redfish/v1/Systems/system/LogServices/EventLog/Actions/LogService.ClearLog".to_string(),
            json!({})
        )]
    );
    assert_eq!(journal.failure, Failure::NotSupported);
}

// --- drives ---

#[tokio::test]
async fn drives_are_read_through_their_controller() {
    let (fake, topology) = discovered("dmtf_localstorage").await;

    let report = storage(&fake, &topology).await.unwrap();

    assert_eq!(report.drives.len(), 4);
    assert!(!report.unsupported && !report.truncated);
    let drive = &report.drives[0];
    assert_eq!(drive.controller.as_deref(), Some("Local Storage Controller"));
    assert_eq!(drive.health.as_deref(), Some("OK"));
    assert!(report.drives.iter().all(|d| !d.needs_attention()));
}

#[tokio::test]
async fn simple_storage_is_read_where_storage_is_not() {
    let (fake, topology) = discovered("dmtf_rackmount1").await;

    let report = storage(&fake, &topology).await.unwrap();

    assert!(!report.drives.is_empty());
    assert!(report.drives.iter().all(|d| d.controller.is_some()));
}

#[tokio::test]
async fn a_failing_drive_needs_attention() {
    let failing = sbm_redfish::storage::Drive::from_json(&json!({
        "Status": {"Health": "OK"}, "FailurePredicted": true,
    }));
    let warning = sbm_redfish::storage::Drive::from_json(&json!({"Status": {"Health": "Warning"}}));

    assert!(failing.needs_attention() && warning.needs_attention());
}

#[tokio::test]
async fn more_drives_than_the_cap_are_cut_and_said_to_be() {
    let mut resources = vendor("dmtf_localstorage");
    let links: Vec<Value> = (0..MAX_DRIVES + 5)
        .map(|i| {
            let path = format!("/redfish/v1/Chassis/1U/Drives/d{i}");
            resources.insert(path.clone(), json!({"Name": format!("d{i}")}));
            json!({"@odata.id": path})
        })
        .collect();
    resources
        .get_mut("/redfish/v1/Systems/437XR1138R2/Storage/1")
        .unwrap()["Drives"] = json!(links);
    let fake = FakeTransport::new(resources);
    let topology = discover(&fake).await.unwrap();

    let report = storage(&fake, &topology).await.unwrap();

    assert_eq!(report.drives.len(), MAX_DRIVES);
    assert!(report.truncated);
}

#[tokio::test]
async fn storage_nobody_can_read_is_an_error_not_no_drives() {
    let (fake, topology) = discovered("dmtf_localstorage").await;
    let collection = topology.system.as_ref().unwrap().storage.clone().unwrap();

    let error = storage(&fake.forbidding(&collection), &topology).await.unwrap_err();

    assert_eq!(error.failure, Failure::Forbidden);
}

#[tokio::test]
async fn storage_naming_no_drive_falls_back_to_simple_storage() {
    let (mut fake, mut topology) = discovered("dmtf_rackmount1").await;
    let system = topology.system.as_mut().unwrap();
    system.storage = Some("/redfish/v1/Systems/1/Storage".into());
    fake.resources.insert(
        "/redfish/v1/Systems/1/Storage".into(),
        json!({"Members": [], "Members@odata.count": 0}),
    );

    let report = storage(&fake, &topology).await.unwrap();

    assert!(!report.drives.is_empty());
}

// --- boot override ---

#[tokio::test]
async fn the_boot_override_states_what_it_takes() {
    let (_, topology) = discovered("openbmc_romulus").await;

    let boot = topology.system.unwrap().boot.unwrap();

    assert_eq!(boot.enabled.as_deref(), Some("Disabled"));
    assert!(boot.targets.contains(&"Pxe".to_string()));
    assert_eq!(boot.modes, ["Legacy", "UEFI"]);
    // Not listed by bmcweb: the three the schema defines.
    assert_eq!(boot.enabled_values, ["Disabled", "Once", "Continuous"]);
    assert!(!boot.is_active());
    // Nothing in effect: the first device, for the next boot only.
    let start = boot.default_request().unwrap();
    assert_eq!((start.target.as_str(), start.enabled.as_str()), (boot.settable_targets()[0].as_str(), "Once"));
    assert!(!boot.settable_targets().contains(&"None".to_string()));
}

#[test]
fn a_service_listing_only_none_offers_no_override() {
    use sbm_redfish::model::BootOverride;
    let boot = BootOverride {
        targets: vec!["None".into()],
        enabled_values: vec!["Disabled".into(), "Once".into()],
        ..Default::default()
    };
    assert!(!boot.can_set());
    assert_eq!(boot.default_request(), None);
}

#[tokio::test]
async fn setting_it_patches_the_system_as_last_read() {
    let mut fake = FakeTransport::new(vendor("openbmc_romulus"));
    fake.etags.insert("/redfish/v1/Systems/system".into(), "W/\"42\"".into());
    let topology = discover(&fake).await.unwrap();

    set_boot(
        &fake,
        &topology,
        &BootRequest { target: "Pxe".into(), enabled: "Once".into(), mode: Some("UEFI".into()) },
    )
    .await
    .unwrap();

    let patched = fake.patched.lock().unwrap().clone();
    assert_eq!(
        patched,
        [(
            "/redfish/v1/Systems/system".to_string(),
            json!({"Boot": {
                "BootSourceOverrideTarget": "Pxe",
                "BootSourceOverrideEnabled": "Once",
                "BootSourceOverrideMode": "UEFI",
            }}),
            Some("W/\"42\"".to_string()),
        )]
    );
}

#[tokio::test]
async fn a_target_the_service_did_not_list_is_never_sent() {
    let (fake, topology) = discovered("openbmc_romulus").await;

    let error = set_boot(
        &fake,
        &topology,
        &BootRequest { target: "Floppy".into(), enabled: "Once".into(), mode: None },
    )
    .await
    .unwrap_err();

    assert_eq!(error.failure, Failure::NotSupported);
    assert!(fake.patched.lock().unwrap().is_empty());
}

// --- locator light ---

#[tokio::test]
async fn the_locator_is_set_by_whichever_property_the_system_has() {
    let (romulus, topology) = discovered("openbmc_romulus").await;
    set_locator(&romulus, &topology, true).await.unwrap();
    let (mockup, topology) = discovered("dmtf_rackmount1").await;
    set_locator(&mockup, &topology, true).await.unwrap();

    assert_eq!(romulus.patched.lock().unwrap()[0].1, json!({"LocationIndicatorActive": true}));
    // No list given: `Lit`, the one value every firmware with it takes.
    assert_eq!(mockup.patched.lock().unwrap()[0].1, json!({"IndicatorLED": "Lit"}));
}

#[test]
fn a_legacy_locator_takes_only_what_it_lists() {
    use sbm_redfish::model::Locator;
    let blinking = json!({"IndicatorLED": "Off", "IndicatorLED@Redfish.AllowableValues": ["Blinking", "Off"]});
    assert_eq!(Locator::body_for(&blinking, true), Some(json!({"IndicatorLED": "Blinking"})));
    assert_eq!(Locator::body_for(&blinking, false), Some(json!({"IndicatorLED": "Off"})));
    let lit_only = json!({"IndicatorLED": "Off", "IndicatorLED@Redfish.AllowableValues": ["Lit"]});
    assert_eq!(Locator::body_for(&lit_only, false), None);
    assert_eq!(Locator::body_for(&json!({}), true), None);
}

// --- virtual media ---

#[tokio::test]
async fn slots_are_listed_with_what_is_in_them() {
    let (fake, topology) = discovered("dmtf_rackmount1").await;

    let slots = media_slots(&fake, &topology).await.unwrap();

    let cd = slots.iter().find(|s| s.id.as_deref() == Some("CD1")).unwrap();
    assert!(cd.inserted);
    assert_eq!(cd.media_types, ["CD", "DVD"]);
    assert!(cd.image.is_some());
}

#[tokio::test]
async fn a_slot_with_no_action_is_set_by_its_properties() {
    let (fake, topology) = discovered("dmtf_rackmount1").await;
    let slots = media_slots(&fake, &topology).await.unwrap();
    let cd = slots.iter().find(|s| s.id.as_deref() == Some("CD1")).unwrap();

    insert_media(&fake, cd, "https://images.example/debian.iso").await.unwrap();
    eject_media(&fake, cd).await.unwrap();

    let patched: Vec<_> = fake.patched.lock().unwrap().iter().map(|p| p.1.clone()).collect();
    assert_eq!(
        patched,
        [
            json!({"Image": "https://images.example/debian.iso", "Inserted": true, "WriteProtected": true}),
            json!({"Image": null, "Inserted": false}),
        ]
    );
}

#[tokio::test]
async fn a_slot_with_actions_is_set_through_them() {
    let slot = sbm_redfish::media::MediaSlot::from_json(
        "/redfish/v1/Managers/1/VirtualMedia/CD",
        &json!({"Id": "CD", "Inserted": false, "Actions": {
            "#VirtualMedia.InsertMedia": {"target": "/redfish/v1/Managers/1/VirtualMedia/CD/Actions/VirtualMedia.InsertMedia"},
            "#VirtualMedia.EjectMedia": {"target": "/redfish/v1/Managers/1/VirtualMedia/CD/Actions/VirtualMedia.EjectMedia"},
        }}),
    );
    let fake = FakeTransport::new(HashMap::new());

    insert_media(&fake, &slot, "nfs://10.0.0.5/isos/alpine.iso").await.unwrap();
    eject_media(&fake, &slot).await.unwrap();

    let posted: Vec<_> = fake.posted.lock().unwrap().iter().map(|p| p.0.clone()).collect();
    assert!(posted[0].ends_with("VirtualMedia.InsertMedia"));
    assert!(posted[1].ends_with("VirtualMedia.EjectMedia"));
    assert!(fake.patched.lock().unwrap().is_empty());
}

#[test]
fn only_an_image_address_is_sent() {
    assert!(is_image_url("https://images.example/a.iso"));
    assert!(is_image_url("cifs://nas/share/a.iso"));
    // Credentials would be stored and shown by the BMC.
    assert!(!is_image_url("https://user:pw@images.example/a.iso"));
    assert!(!is_image_url("file:///etc/passwd"));
    assert!(!is_image_url("images.example/a.iso"));
    assert!(!is_image_url("https://images.example/a b.iso"));
    assert!(!is_image_url("https://images.example"));
}

#[tokio::test]
async fn a_refused_address_sends_nothing() {
    let (fake, topology) = discovered("dmtf_rackmount1").await;
    let slots = media_slots(&fake, &topology).await.unwrap();

    let error = insert_media(&fake, &slots[0], "ftp://x/a.iso").await.unwrap_err();

    assert_eq!(error.failure, Failure::NotSupported);
    assert!(fake.patched.lock().unwrap().is_empty() && fake.posted.lock().unwrap().is_empty());
}
