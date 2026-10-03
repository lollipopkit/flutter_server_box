//! Redfish against the shapes vendors actually present — `resources_test.dart`.
//!
//! The point of every case here is that nothing about a service's layout may
//! be assumed. The ids differ (`1`, `System.Embedded.1`, `system`), the sensor
//! model differs by firmware generation and transitional firmware carries
//! both, and a reset type being advertised is the only statement a service
//! makes about what it will accept. No test performs a reset; the request a
//! reset *would* be is asserted.

mod common;

use common::{FakeTransport, vendor};
use sbm_redfish::model::{
    PowerIntent, PowerState, RedfishChassis, RedfishRoot, RedfishSystem, ResetRequest, SensorModel,
    collection_members, resolve_reset_type,
};
use sbm_redfish::{Failure, discover};
use serde_json::json;

const DELL_SYSTEM: &str = "/redfish/v1/Systems/System.Embedded.1";

// --- service root ---

#[test]
fn a_static_host_answering_every_path_is_not_a_service() {
    let root = RedfishRoot::from_json(&json!({"title": "ServerBox"}));
    assert!(!root.is_service());
}

#[test]
fn reads_the_session_endpoint_from_either_place_it_is_put() {
    assert_eq!(
        RedfishRoot::from_json(&vendor("dell_idrac9")["/redfish/v1/"]).sessions.as_deref(),
        Some("/redfish/v1/Sessions")
    );
    // Supermicro fills in SessionService and no Links.Sessions
    assert_eq!(
        RedfishRoot::from_json(&vendor("supermicro_x11")["/redfish/v1/"]).sessions.as_deref(),
        Some("/redfish/v1/SessionService")
    );
}

#[test]
fn the_root_keeps_what_it_reports() {
    let root = RedfishRoot::from_json(&vendor("dell_idrac9")["/redfish/v1/"]);
    assert_eq!(root.version.as_deref(), Some("1.13.0"));
    assert_eq!(root.product.as_deref(), Some("Integrated Dell Remote Access Controller"));
    assert_eq!(root.systems.as_deref(), Some("/redfish/v1/Systems"));
}

// --- discovery walks collections rather than building paths ---

#[tokio::test]
async fn discovery_finds_each_vendors_system() {
    for (name, expected) in [
        ("dell_idrac9", DELL_SYSTEM),
        ("supermicro_x11", "/redfish/v1/Systems/1"),
        ("openbmc", "/redfish/v1/Systems/system"),
    ] {
        let topology = discover(&FakeTransport::new(vendor(name))).await.unwrap();
        assert_eq!(topology.system_path.as_deref(), Some(expected), "{name}");
        assert!(topology.is_usable(), "{name}");
    }
}

#[tokio::test]
async fn a_service_that_is_not_one_is_refused_before_anything_else() {
    let t = FakeTransport::new([("/redfish/v1/".to_string(), json!({"title": "not a bmc"}))].into());
    let err = discover(&t).await.unwrap_err();
    assert_eq!(err.failure, Failure::NotAService);
    assert_eq!(t.get_count(), 1);
}

#[tokio::test]
async fn an_empty_systems_collection_is_reported_not_crashed_on() {
    let mut resources = vendor("dell_idrac9");
    resources.insert("/redfish/v1/Systems".into(), json!({"Members": []}));
    let err = discover(&FakeTransport::new(resources)).await.unwrap_err();
    assert_eq!(err.failure, Failure::NoSystem);
}

#[tokio::test]
async fn one_system_is_not_reported_as_several() {
    let topology = discover(&FakeTransport::new(vendor("dell_idrac9"))).await.unwrap();
    assert!(!topology.has_multiple_systems);
}

fn two_systems() -> FakeTransport {
    let mut resources = vendor("dell_idrac9");
    resources.insert(
        "/redfish/v1/Systems".into(),
        json!({"Members": [
            {"@odata.id": "/redfish/v1/Systems/System.Embedded.1"},
            {"@odata.id": "/redfish/v1/Systems/System.Embedded.2"},
        ]}),
    );
    FakeTransport::new(resources)
}

#[tokio::test]
async fn a_chassis_publishing_several_systems_says_so() {
    // A blade enclosure is one Redfish service with one system per node. Only
    // the first is shown, which is a stated limitation — but showing it
    // silently reports one node's power state as if it were the enclosure's.
    let topology = discover(&two_systems()).await.unwrap();
    assert!(topology.has_multiple_systems);
    assert_eq!(topology.system_path.as_deref(), Some(DELL_SYSTEM), "still the first");
}

#[tokio::test]
async fn re_reading_the_system_keeps_what_discovery_worked_out() {
    let topology = discover(&two_systems()).await.unwrap();
    let polled = topology.with_system(topology.system.clone().unwrap());
    assert!(polled.has_multiple_systems);
    assert_eq!(polled.system_path, topology.system_path);
    assert_eq!(polled.chassis_path, topology.chassis_path);
    assert_eq!(polled.chassis, topology.chassis);
}

#[tokio::test]
async fn a_chassis_that_is_refused_costs_the_sensors_and_nothing_else() {
    let t = FakeTransport::new(vendor("dell_idrac9")).forbidding("/redfish/v1/Chassis/System.Embedded.1");
    let topology = discover(&t).await.unwrap();
    assert_eq!(topology.system.as_ref().unwrap().power_state, PowerState::On);
    assert!(topology.chassis.is_none());
    assert_eq!(topology.sensor_model(), SensorModel::None);
}

#[tokio::test]
async fn an_unreadable_chassis_collection_costs_the_chassis_only() {
    let t = FakeTransport::new(vendor("dell_idrac9")).forbidding("/redfish/v1/Chassis");
    let topology = discover(&t).await.unwrap();
    assert!(topology.chassis_path.is_none());
    assert!(topology.is_usable());
}

// --- sensor model ---

#[test]
fn legacy_where_only_thermal_and_power_are_linked() {
    let chassis = RedfishChassis::from_json(&vendor("dell_idrac9")["/redfish/v1/Chassis/System.Embedded.1"]);
    assert_eq!(chassis.model(), SensorModel::Legacy);
    assert_eq!(chassis.name.as_deref(), Some("Computer System Chassis"));
}

#[test]
fn modern_where_the_subsystems_and_sensors_are_linked() {
    let chassis = RedfishChassis::from_json(&vendor("openbmc")["/redfish/v1/Chassis/chassis"]);
    assert_eq!(chassis.model(), SensorModel::Modern);
}

#[test]
fn transitional_firmware_carries_both_and_the_new_one_wins() {
    let chassis = RedfishChassis::from_json(&json!({
        "Thermal": {"@odata.id": "/t"},
        "Power": {"@odata.id": "/p"},
        "ThermalSubsystem": {"@odata.id": "/ts"},
        "PowerSubsystem": {"@odata.id": "/ps"},
        "Sensors": {"@odata.id": "/s"},
    }));
    assert!(chassis.has_legacy_sensors());
    assert!(chassis.has_modern_sensors());
    assert_eq!(chassis.model(), SensorModel::Modern);
}

#[test]
fn a_subsystem_without_sensors_has_nothing_readable_in_it() {
    let chassis = RedfishChassis::from_json(&json!({"ThermalSubsystem": {"@odata.id": "/ts"}}));
    assert_eq!(chassis.model(), SensorModel::None);
}

// --- system ---

#[test]
fn prefers_health_rollup_which_accounts_for_the_subsystems() {
    let system = RedfishSystem::from_json(&vendor("dell_idrac9")[DELL_SYSTEM]);
    assert_eq!(system.health.as_deref(), Some("Warning"));
    assert_eq!(system.model.as_deref(), Some("PowerEdge R740"));
    assert_eq!(system.bios_version.as_deref(), Some("2.19.0"));
    assert_eq!(system.manufacturer.as_deref(), Some("Dell Inc."));
    assert_eq!(system.serial.as_deref(), Some("ABCDEF1"));
}

#[test]
fn health_falls_back_to_health_without_a_rollup() {
    let system = RedfishSystem::from_json(&json!({"Status": {"Health": "OK"}}));
    assert_eq!(system.health.as_deref(), Some("OK"));
    let system = RedfishSystem::from_json(&json!({"Status": {"HealthRollup": null, "Health": "Critical"}}));
    assert_eq!(system.health.as_deref(), Some("Critical"));
}

#[test]
fn an_unfamiliar_power_state_is_shown_not_rejected() {
    let system = RedfishSystem::from_json(&json!({"PowerState": "Hibernating"}));
    assert_eq!(system.power_state, PowerState::Unknown);
}

#[test]
fn a_service_with_no_reset_action_cannot_be_reset() {
    let system = RedfishSystem::from_json(&json!({"PowerState": "On"}));
    assert!(!system.can_reset());
    assert_eq!(ResetRequest::build(&system, PowerIntent::Restart), None);
}

#[test]
fn an_odd_field_costs_that_field_and_nothing_else() {
    // Dart's `as String?` threw on these and lost the whole system; each field
    // is now read on its own.
    let system = RedfishSystem::from_json(&json!({
        "PowerState": "Off",
        "Model": 740,
        "SerialNumber": null,
        "Status": "OK",
        "Actions": {"#ComputerSystem.Reset": {
            "target": 7,
            "ResetType@Redfish.AllowableValues": ["On", 3, null, "ForceOff"],
        }},
    }));
    assert_eq!(system.power_state, PowerState::Off);
    assert_eq!(system.model, None);
    assert_eq!(system.serial, None);
    assert_eq!(system.health, None);
    assert_eq!(system.reset_target, None);
    assert_eq!(system.reset_types, ["On", "ForceOff"]);
}

// --- reset type negotiation ---

#[test]
fn dell_has_no_graceful_restart_so_a_restart_falls_back_to_force() {
    let system = RedfishSystem::from_json(&vendor("dell_idrac9")[DELL_SYSTEM]);
    let req = ResetRequest::build(&system, PowerIntent::Restart).unwrap();
    assert_eq!(req.reset_type, "ForceRestart");
    assert_eq!(req.target, "/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset");
    assert_eq!(req.body(), json!({"ResetType": "ForceRestart"}));
}

#[test]
fn supermicro_has_it_so_the_polite_one_is_used() {
    let system = RedfishSystem::from_json(&vendor("supermicro_x11")["/redfish/v1/Systems/1"]);
    assert_eq!(
        ResetRequest::build(&system, PowerIntent::Restart).unwrap().reset_type,
        "GracefulRestart"
    );
}

#[test]
fn an_intent_the_service_allows_nothing_for_yields_nothing() {
    let system = RedfishSystem::from_json(&json!({"Actions": {"#ComputerSystem.Reset": {
        "target": "/t",
        "ResetType@Redfish.AllowableValues": ["On"],
    }}}));
    assert_eq!(ResetRequest::build(&system, PowerIntent::GracefulShutdown), None);
    assert_eq!(ResetRequest::build(&system, PowerIntent::On).unwrap().reset_type, "On");
}

#[test]
fn the_target_comes_from_the_action_not_from_the_system_path() {
    let system = RedfishSystem::from_json(&json!({"Actions": {"#ComputerSystem.Reset": {
        "target": "/somewhere/else/entirely",
        "ResetType@Redfish.AllowableValues": ["ForceOff"],
    }}}));
    assert_eq!(
        ResetRequest::build(&system, PowerIntent::ForceOff).unwrap().target,
        "/somewhere/else/entirely"
    );
}

#[test]
fn an_action_with_no_allowable_values_is_not_usable() {
    let system = RedfishSystem::from_json(&json!({"Actions": {"#ComputerSystem.Reset": {"target": "/t"}}}));
    assert!(!system.can_reset());
}

// --- what real firmware advertises ---

fn strings(values: &[&str]) -> Vec<String> {
    values.iter().map(|s| s.to_string()).collect()
}

#[test]
fn an_h3c_offering_force_power_cycle_gets_a_power_cycle_not_a_restart() {
    let allowed = strings(&["ForceOff", "ForcePowerCycle", "ForceRestart", "GracefulShutdown", "Nmi", "On"]);
    let resolve = |intent| resolve_reset_type(intent, &allowed);
    assert_eq!(resolve(PowerIntent::PowerCycle).as_deref(), Some("ForcePowerCycle"));
    assert_eq!(resolve(PowerIntent::On).as_deref(), Some("On"));
    assert_eq!(resolve(PowerIntent::GracefulShutdown).as_deref(), Some("GracefulShutdown"));
    assert_eq!(resolve(PowerIntent::ForceOff).as_deref(), Some("ForceOff"));
    assert_eq!(resolve(PowerIntent::Restart).as_deref(), Some("ForceRestart"));
}

#[test]
fn the_standard_name_still_wins_where_a_service_has_both() {
    let allowed = strings(&["ForcePowerCycle", "PowerCycle", "ForceRestart"]);
    assert_eq!(
        resolve_reset_type(PowerIntent::PowerCycle, &allowed).as_deref(),
        Some("PowerCycle"),
        "the vendor extension is a fallback, not a preference"
    );
}

// --- power state ---

#[test]
fn knows_which_states_are_being_passed_through() {
    assert!(PowerState::PoweringOn.is_transitional());
    assert!(PowerState::PoweringOff.is_transitional());
    assert!(!PowerState::On.is_transitional());
    assert!(!PowerState::Unknown.is_transitional());
}

// --- collection parsing ---

#[test]
fn a_malformed_members_is_empty_rather_than_an_exception() {
    assert!(collection_members(&json!({"Members": "nope"})).is_empty());
    assert!(collection_members(&json!({})).is_empty());
    assert_eq!(
        collection_members(&json!({"Members": [
            {"no-odata-id": 1},
            {"@odata.id": ""},
            {"@odata.id": 5},
            {"@odata.id": "/ok"},
        ]})),
        ["/ok"]
    );
}

// --- the wire format the agent and the app read ---

#[tokio::test]
async fn models_serialize_with_snake_case_fields_and_dart_enum_names() {
    let topology = discover(&FakeTransport::new(vendor("openbmc"))).await.unwrap();
    let value = serde_json::to_value(&topology).unwrap();
    assert_eq!(value["system_path"], "/redfish/v1/Systems/system");
    assert_eq!(value["system"]["power_state"], "on");
    assert_eq!(value["has_multiple_systems"], false);
    assert_eq!(value["chassis"]["thermal_subsystem"], "/redfish/v1/Chassis/chassis/ThermalSubsystem");
    assert_eq!(serde_json::to_value(PowerState::PoweringOn).unwrap(), "poweringOn");
    assert_eq!(serde_json::to_value(PowerIntent::GracefulShutdown).unwrap(), "gracefulShutdown");
    assert_eq!(serde_json::from_value::<PowerIntent>(json!("powerCycle")).unwrap(), PowerIntent::PowerCycle);
    assert_eq!(serde_json::to_value(SensorModel::Modern).unwrap(), "modern");
    for intent in PowerIntent::ALL {
        assert_eq!(serde_json::to_value(intent).unwrap(), intent.as_str());
        assert_eq!(PowerIntent::parse(intent.as_str()), Some(intent));
    }
    for state in PowerState::ALL {
        assert_eq!(serde_json::to_value(state).unwrap(), state.as_str());
    }
    // Round-trips, so a caller can cache a topology between polls.
    let back: sbm_redfish::model::Topology = serde_json::from_value(value).unwrap();
    assert_eq!(back, topology);
}

#[test]
fn failures_are_coded_by_their_dart_names() {
    for (failure, code) in [
        (Failure::NotAService, "notAService"),
        (Failure::NoSystem, "noSystem"),
        (Failure::Forbidden, "forbidden"),
        (Failure::CertificateRejected, "certificateRejected"),
        (Failure::Unauthorized, "unauthorized"),
        (Failure::NoCredential, "noCredential"),
        (Failure::PreconditionRequired, "preconditionRequired"),
        (Failure::Unreachable, "unreachable"),
    ] {
        assert_eq!(failure.as_str(), code);
        assert_eq!(serde_json::to_value(failure).unwrap(), code);
    }
    for failure in Failure::ALL {
        assert_eq!(Failure::parse(failure.as_str()), Some(failure));
        assert_eq!(serde_json::to_value(failure).unwrap(), failure.as_str());
    }
}
