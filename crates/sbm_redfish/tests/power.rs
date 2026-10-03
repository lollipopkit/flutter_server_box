//! Power control and the poll around it: every decision, and none of the
//! consequences — `power_test.dart`, plus the decisions of the app's
//! `BmcNotifier` (`_awaitPowerChange`, `_readSensors`) that now live here.
//!
//! **Nothing in this file resets real hardware.** The transport is a fake;
//! the only thing it does with a reset is write it down.

mod common;

use std::collections::HashMap;

use common::{FakeTransport, vendor};
use sbm_redfish::model::{PowerIntent, PowerState, PowerWatch, RedfishSystem, ResetRequest};
use sbm_redfish::{Failure, MAX_SENSOR_MEMBERS, Outcome, discover, power, read_system, snapshot};
use serde_json::{Value, json};

fn system_allowing(types: &[&str], target: &str) -> RedfishSystem {
    RedfishSystem::from_json(&json!({
        "PowerState": "On",
        "Actions": {"#ComputerSystem.Reset": {
            "target": target,
            "ResetType@Redfish.AllowableValues": types,
        }},
    }))
}

// --- which actions a service can offer ---

#[test]
fn an_intent_with_nothing_behind_it_is_not_offered() {
    let system = system_allowing(&["On", "ForceOff"], "/reset");
    let offered: Vec<_> = PowerIntent::ALL
        .into_iter()
        .filter(|i| ResetRequest::build(&system, *i).is_some())
        .collect();
    assert_eq!(offered, [PowerIntent::On, PowerIntent::ForceOff]);
}

#[test]
fn a_service_with_no_reset_action_offers_nothing_at_all() {
    let system = RedfishSystem::from_json(&json!({"PowerState": "On"}));
    for intent in PowerIntent::ALL {
        assert_eq!(ResetRequest::build(&system, intent), None);
    }
}

// --- which ResetType an intent becomes ---

fn resolved(types: &[&str], intent: PowerIntent) -> Option<String> {
    ResetRequest::build(&system_allowing(types, "/reset"), intent).map(|r| r.reset_type)
}

#[test]
fn restart_prefers_the_graceful_one_where_it_exists() {
    assert_eq!(resolved(&["GracefulRestart", "ForceRestart"], PowerIntent::Restart).as_deref(), Some("GracefulRestart"));
}

#[test]
fn and_falls_back_where_it_does_not() {
    assert_eq!(resolved(&["ForceRestart", "ForceOff", "On"], PowerIntent::Restart).as_deref(), Some("ForceRestart"));
}

#[test]
fn power_on_falls_back_to_force_on() {
    assert_eq!(resolved(&["ForceOn"], PowerIntent::On).as_deref(), Some("ForceOn"));
}

#[test]
fn a_power_cycle_falls_back_to_a_forced_restart() {
    assert_eq!(resolved(&["ForceRestart"], PowerIntent::PowerCycle).as_deref(), Some("ForceRestart"));
}

#[test]
fn a_graceful_shutdown_has_no_fallback_by_design() {
    // ForceOff is not a shutdown, and quietly substituting it would take a
    // machine down hard when someone asked for the polite thing
    assert_eq!(resolved(&["ForceOff"], PowerIntent::GracefulShutdown), None);
}

// --- the request itself ---

fn service_with(system: Value) -> FakeTransport {
    let mut resources: HashMap<String, Value> = HashMap::new();
    resources.insert(
        "/redfish/v1/".into(),
        json!({"Systems": {"@odata.id": "/redfish/v1/Systems"}}),
    );
    resources.insert(
        "/redfish/v1/Systems".into(),
        json!({"Members": [{"@odata.id": "/redfish/v1/Systems/1"}]}),
    );
    resources.insert("/redfish/v1/Systems/1".into(), system);
    FakeTransport::new(resources)
}

#[tokio::test]
async fn goes_to_the_target_the_service_named_and_carries_only_the_reset_type() {
    let t = FakeTransport::new(vendor("dell_idrac9"));
    let topology = discover(&t).await.unwrap();
    let outcome = power(&t, &topology, PowerIntent::ForceOff).await.unwrap();
    assert_eq!(outcome, Outcome::Done);
    let posted = t.posted.lock().unwrap();
    assert_eq!(posted.len(), 1);
    assert_eq!(posted[0].0, "/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset");
    assert_eq!(posted[0].1, json!({"ResetType": "ForceOff"}));
}

#[tokio::test]
async fn an_unsupported_intent_sends_nothing() {
    let t = FakeTransport::new(vendor("dell_idrac9"));
    let topology = discover(&t).await.unwrap();
    // A service that allows only `On` has nothing behind a shutdown.
    let mut narrowed = topology.clone();
    narrowed.system.as_mut().unwrap().reset_types = vec!["On".into()];
    let err = power(&t, &narrowed, PowerIntent::GracefulShutdown).await.unwrap_err();
    assert_eq!(err.failure, Failure::NotSupported);
    assert!(t.posted.lock().unwrap().is_empty());
}

#[tokio::test]
async fn read_system_rereads_the_power_state() {
    let t = FakeTransport::new(vendor("supermicro_x11"));
    let topology = discover(&t).await.unwrap();
    let system = read_system(&t, &topology).await.unwrap();
    assert_eq!(system.power_state, PowerState::Off);
}

#[tokio::test]
async fn reset_types_stated_in_an_action_info_are_read_there() {
    // bmcweb (OpenBMC), as measured: no inline allowable values.
    let mut t = service_with(json!({
        "PowerState": "Off",
        "Actions": {"#ComputerSystem.Reset": {
            "@Redfish.ActionInfo": "/redfish/v1/Systems/1/ResetActionInfo",
            "target": "/redfish/v1/Systems/1/Actions/ComputerSystem.Reset",
        }},
    }));
    t.resources.insert(
        "/redfish/v1/Systems/1/ResetActionInfo".into(),
        json!({"Parameters": [
            {"Name": "Other", "AllowableValues": ["X"]},
            {"Name": "ResetType", "AllowableValues": ["ForceOff", "On", "GracefulRestart"], "Required": true},
        ]}),
    );
    let topology = discover(&t).await.unwrap();
    assert_eq!(topology.system.as_ref().unwrap().reset_types, ["ForceOff", "On", "GracefulRestart"]);
    let system = read_system(&t, &topology).await.unwrap();
    assert_eq!(system.reset_types, ["ForceOff", "On", "GracefulRestart"]);
    power(&t, &topology, PowerIntent::Restart).await.unwrap();
    assert_eq!(t.posted.lock().unwrap()[0].1, json!({"ResetType": "GracefulRestart"}));
}

#[tokio::test]
async fn an_unreadable_action_info_offers_nothing_but_keeps_the_state() {
    let t = service_with(json!({
        "PowerState": "On",
        "Actions": {"#ComputerSystem.Reset": {
            "@Redfish.ActionInfo": "/redfish/v1/Systems/1/ResetActionInfo",
            "target": "/redfish/v1/Systems/1/Actions/ComputerSystem.Reset",
        }},
    }))
    .forbidding("/redfish/v1/Systems/1/ResetActionInfo");
    let topology = discover(&t).await.unwrap();
    let system = topology.system.unwrap();
    assert_eq!(system.power_state, PowerState::On);
    assert!(system.reset_types.is_empty());
}

// --- what counts as done (`_awaitPowerChange`) ---

#[test]
fn a_transitional_state_is_not_arrival() {
    assert!(PowerState::PoweringOff.is_transitional());
    assert!(!PowerState::Off.is_transitional());
    let resting: Vec<_> = PowerState::ALL.into_iter().filter(|s| !s.is_transitional()).collect();
    assert!(resting.contains(&PowerState::On));
    assert!(resting.contains(&PowerState::Off));
    assert!(!resting.contains(&PowerState::PoweringOn));
}

#[test]
fn a_shutdown_lands_when_the_machine_is_off() {
    let mut watch = PowerWatch::new(PowerState::On, PowerIntent::GracefulShutdown);
    assert!(!watch.observe(PowerState::On), "not yet");
    assert!(!watch.observe(PowerState::PoweringOff), "on its way is not there");
    assert!(watch.observe(PowerState::Off));
}

#[test]
fn a_restart_seen_only_on_is_not_confirmed() {
    // Nothing shows it moved: it may not have restarted at all.
    let mut watch = PowerWatch::new(PowerState::On, PowerIntent::Restart);
    for _ in 0..5 {
        assert!(!watch.observe(PowerState::On));
    }
}

#[test]
fn a_restart_that_passed_through_a_transition_is_confirmed_back_on() {
    // A machine that finishes rebooting between two polls is only ever seen
    // `On` — but if it was once seen on its way, that is the evidence.
    let mut watch = PowerWatch::new(PowerState::On, PowerIntent::Restart);
    assert!(!watch.observe(PowerState::PoweringOn));
    assert!(watch.observe(PowerState::On));
}

#[test]
fn a_power_cycle_seen_off_then_on_is_confirmed() {
    let mut watch = PowerWatch::new(PowerState::On, PowerIntent::PowerCycle);
    assert!(!watch.observe(PowerState::Off));
    assert!(watch.observe(PowerState::On));
}

#[test]
fn powering_on_from_off_lands_on_the_first_on() {
    let mut watch = PowerWatch::new(PowerState::Off, PowerIntent::On);
    assert!(!watch.observe(PowerState::Off));
    assert!(watch.observe(PowerState::On));
}

#[test]
fn an_intent_that_ends_where_the_machine_already_was_needs_movement() {
    // Off already, and asked to force off: `moved` starts false because the
    // expected state is where it began.
    let mut watch = PowerWatch::new(PowerState::Off, PowerIntent::ForceOff);
    assert!(!watch.observe(PowerState::Off));
    assert!(!watch.observe(PowerState::On));
    assert!(watch.observe(PowerState::Off));
}

#[test]
fn from_an_unknown_state_any_arrival_counts() {
    // `before != expected` makes `moved` true from the start, as in Dart.
    let mut watch = PowerWatch::new(PowerState::Unknown, PowerIntent::On);
    assert!(watch.observe(PowerState::On));
}

#[test]
fn an_unexpected_resting_state_is_movement_but_not_arrival() {
    let mut watch = PowerWatch::new(PowerState::On, PowerIntent::Restart);
    assert!(!watch.observe(PowerState::Paused));
    assert!(watch.observe(PowerState::On));
}

// --- one poll (`refresh` / `_readSensors`) ---

fn modern_service(members: usize) -> FakeTransport {
    let mut t = service_with(json!({"PowerState": "On"}));
    let root = json!({
        "Systems": {"@odata.id": "/redfish/v1/Systems"},
        "Chassis": {"@odata.id": "/redfish/v1/Chassis"},
    });
    t.resources.insert("/redfish/v1/".into(), root);
    t.resources.insert(
        "/redfish/v1/Chassis".into(),
        json!({"Members": [{"@odata.id": "/redfish/v1/Chassis/1"}]}),
    );
    t.resources.insert(
        "/redfish/v1/Chassis/1".into(),
        json!({
            "ThermalSubsystem": {"@odata.id": "/redfish/v1/Chassis/1/ThermalSubsystem"},
            "Sensors": {"@odata.id": "/redfish/v1/Chassis/1/Sensors"},
        }),
    );
    let paths: Vec<String> = (0..members).map(|i| format!("/redfish/v1/Chassis/1/Sensors/t{i}")).collect();
    t.resources.insert(
        "/redfish/v1/Chassis/1/Sensors".into(),
        json!({"Members": paths.iter().map(|p| json!({"@odata.id": p})).collect::<Vec<_>>()}),
    );
    for (i, path) in paths.iter().enumerate() {
        t.resources.insert(
            path.clone(),
            json!({"Name": format!("t{i}"), "ReadingType": "Temperature", "Reading": 30 + (i % 10)}),
        );
    }
    t
}

#[tokio::test]
async fn a_sensors_collection_over_the_cap_is_read_to_the_cap_and_says_so() {
    let t = modern_service(MAX_SENSOR_MEMBERS + 6);
    let snap = snapshot(&t, None).await.unwrap();
    assert!(snap.sensors_truncated);
    assert_eq!(snap.sensors.temperatures.len(), MAX_SENSOR_MEMBERS);
    let gets = t.gets.lock().unwrap();
    assert!(!gets.iter().any(|p| p.ends_with(&format!("/t{MAX_SENSOR_MEMBERS}"))));
}

#[tokio::test]
async fn a_collection_at_the_cap_is_not_truncated() {
    let snap = snapshot(&modern_service(MAX_SENSOR_MEMBERS), None).await.unwrap();
    assert!(!snap.sensors_truncated);
    assert_eq!(snap.sensors.temperatures.len(), MAX_SENSOR_MEMBERS);
}

#[tokio::test]
async fn one_unreadable_member_costs_the_readings_not_the_snapshot() {
    let t = modern_service(3).forbidding("/redfish/v1/Chassis/1/Sensors/t1");
    let snap = snapshot(&t, None).await.unwrap();
    assert!(snap.sensors.is_empty());
    assert!(!snap.sensors_truncated);
    assert_eq!(snap.topology.system.unwrap().power_state, PowerState::On);
}

#[tokio::test]
async fn the_legacy_pair_is_read_and_a_refused_half_costs_both() {
    let mut resources = vendor("dell_idrac9");
    resources.insert(
        "/redfish/v1/Chassis/System.Embedded.1/Thermal".into(),
        json!({"Temperatures": [{"Name": "Inlet", "ReadingCelsius": 22}]}),
    );
    resources.insert(
        "/redfish/v1/Chassis/System.Embedded.1/Power".into(),
        json!({"PowerControl": [{"PowerConsumedWatts": 250}]}),
    );
    let snap = snapshot(&FakeTransport::new(resources.clone()), None).await.unwrap();
    assert_eq!(snap.sensors.temperatures[0].name, "Inlet");
    assert_eq!(snap.sensors.watts, Some(250.0));

    // As in the app: either GET failing is the whole sweep failing.
    let t = FakeTransport::new(resources).forbidding("/redfish/v1/Chassis/System.Embedded.1/Power");
    let snap = snapshot(&t, None).await.unwrap();
    assert!(snap.sensors.is_empty());
}

#[tokio::test]
async fn a_known_topology_skips_discovery_and_rereads_the_system() {
    let t = modern_service(2);
    let first = snapshot(&t, None).await.unwrap();
    t.gets.lock().unwrap().clear();

    let second = snapshot(&t, Some(&first.topology)).await.unwrap();
    let gets = t.gets.lock().unwrap().clone();
    assert_eq!(gets[0], "/redfish/v1/Systems/1", "the system first");
    assert!(!gets.contains(&"/redfish/v1/".to_string()), "no discovery");
    assert!(!gets.contains(&"/redfish/v1/Systems".to_string()));
    assert_eq!(second.topology, first.topology);
    assert_eq!(second.sensors.temperatures.len(), 2);
}

#[tokio::test]
async fn a_known_topology_whose_system_fails_is_an_error() {
    let t = modern_service(1);
    let first = snapshot(&t, None).await.unwrap();
    let t = t.forbidding("/redfish/v1/Systems/1");
    let err = snapshot(&t, Some(&first.topology)).await.unwrap_err();
    assert_eq!(err.failure, Failure::Forbidden);
}

#[tokio::test]
async fn a_snapshot_serializes_for_the_panel() {
    let snap = snapshot(&modern_service(1), None).await.unwrap();
    let value = serde_json::to_value(&snap).unwrap();
    assert_eq!(value["sensors_truncated"], false);
    assert_eq!(value["topology"]["system"]["power_state"], "on");
    assert_eq!(value["sensors"]["temperatures"][0]["unit"], "Cel");
}
