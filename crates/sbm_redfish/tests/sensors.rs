//! Readings out of both sensor models — `sensors_test.dart`.
//!
//! The old pair and the new collection describe the same fans and the same
//! temperatures in different shapes, and firmware in the middle of the
//! migration carries both. Everything here is a case where reading the wrong
//! field, or reading a missing one as zero, would put a wrong number on screen
//! rather than fail.

mod common;

use common::fixture;
use sbm_redfish::model::{BmcReading, BmcSensors, RedfishChassis, sensor_paths};
use serde_json::{Value, json};

fn legacy(thermal: Value) -> BmcSensors {
    BmcSensors::from_legacy(Some(&thermal), None)
}

fn names(readings: &[BmcReading]) -> Vec<&str> {
    readings.iter().map(|r| r.name.as_str()).collect()
}

// --- the deprecated Thermal/Power pair ---

#[test]
fn reads_temperatures_fans_and_chassis_watts() {
    let sensors = BmcSensors::from_legacy(
        Some(&json!({
            "Temperatures": [
                {"Name": "CPU1 Temp", "ReadingCelsius": 47},
                {"Name": "Inlet Temp", "ReadingCelsius": 21.5},
            ],
            "Fans": [{"Name": "FAN1", "Reading": 4800, "ReadingUnits": "RPM"}],
        })),
        Some(&json!({"PowerControl": [{"PowerConsumedWatts": 210}]})),
    );
    assert_eq!(
        sensors.temperatures,
        [
            BmcReading { name: "CPU1 Temp".into(), value: 47.0, unit: Some("Cel".into()) },
            BmcReading { name: "Inlet Temp".into(), value: 21.5, unit: Some("Cel".into()) },
        ]
    );
    assert_eq!(sensors.fans.len(), 1);
    assert_eq!(sensors.fans[0].value, 4800.0);
    assert_eq!(sensors.watts, Some(210.0));
}

#[test]
fn a_sensor_with_nothing_to_say_is_absent_not_zero() {
    let sensors = legacy(json!({"Temperatures": [
        {"Name": "CPU2 Temp", "ReadingCelsius": null},
        {"Name": "CPU1 Temp", "ReadingCelsius": 40},
    ]}));
    assert_eq!(names(&sensors.temperatures), ["CPU1 Temp"]);
}

#[test]
fn an_older_service_calling_it_reading_rpm_is_still_read() {
    let sensors = legacy(json!({"Fans": [{"Name": "FAN1", "ReadingRPM": 3000}]}));
    assert_eq!(sensors.fans[0].value, 3000.0);
    assert_eq!(sensors.fans[0].unit.as_deref(), Some("RPM"));
}

#[test]
fn the_unit_is_kept_rather_than_normalised() {
    let sensors = legacy(json!({"Fans": [{"Name": "FAN1", "Reading": 38, "ReadingUnits": "Percent"}]}));
    assert_eq!(sensors.fans[0].unit.as_deref(), Some("Percent"));
}

#[test]
fn either_resource_may_be_missing_on_its_own() {
    let no_power = legacy(json!({"Temperatures": [{"Name": "T", "ReadingCelsius": 30}]}));
    assert_eq!(no_power.watts, None);
    assert_eq!(no_power.temperatures.len(), 1);
    assert!(BmcSensors::from_legacy(None, None).is_empty());
}

#[test]
fn a_member_without_a_name_falls_back_to_its_id_then_a_placeholder() {
    let sensors = legacy(json!({"Temperatures": [
        {"MemberId": "0", "ReadingCelsius": 30},
        {"ReadingCelsius": 31},
        {"Name": 5, "MemberId": "2", "ReadingCelsius": 32},
    ]}));
    assert_eq!(names(&sensors.temperatures), ["0", "?", "2"]);
}

#[test]
fn a_numeric_string_is_no_reading() {
    // Dart's `_num` read only numbers; "42" is a shape, not a measurement.
    let sensors = legacy(json!({
        "Temperatures": [{"Name": "T", "ReadingCelsius": "42"}],
        "Fans": [{"Name": "F", "Reading": "1200"}],
    }));
    assert!(sensors.is_empty());
}

#[test]
fn entries_that_are_not_objects_are_skipped() {
    let sensors = legacy(json!({
        "Temperatures": [null, 3, "x", {"Name": "T", "ReadingCelsius": 30}],
        "Fans": {"Name": "not a list"},
    }));
    assert_eq!(names(&sensors.temperatures), ["T"]);
    assert!(sensors.fans.is_empty());
}

#[test]
fn the_first_power_control_with_a_reading_is_the_chassis() {
    let sensors = BmcSensors::from_legacy(
        None,
        Some(&json!({"PowerControl": [
            {"PowerConsumedWatts": null},
            {"PowerConsumedWatts": 300},
            {"PowerConsumedWatts": 500},
        ]})),
    );
    assert_eq!(sensors.watts, Some(300.0));
}

// --- the Sensors collection ---

#[test]
fn sorts_members_by_their_reading_type() {
    let sensors = BmcSensors::from_sensors(&[
        json!({"Name": "CPU", "ReadingType": "Temperature", "Reading": 52.0}),
        json!({"Name": "FAN0", "ReadingType": "Rotational", "Reading": 5200, "ReadingUnits": "RPM"}),
        json!({"Name": "Total Power", "ReadingType": "Power", "Reading": 180}),
    ]);
    assert_eq!(names(&sensors.temperatures), ["CPU"]);
    assert_eq!(sensors.temperatures[0].unit.as_deref(), Some("Cel"));
    assert_eq!(sensors.fans[0].value, 5200.0);
    assert_eq!(sensors.watts, Some(180.0));
}

#[test]
fn the_largest_power_reading_is_the_one_about_the_whole_machine() {
    let sensors = BmcSensors::from_sensors(&[
        json!({"Name": "PSU1 Input", "ReadingType": "Power", "Reading": 90}),
        json!({"Name": "Chassis Total", "ReadingType": "Power", "Reading": 175}),
        json!({"Name": "PSU2 Input", "ReadingType": "Power", "Reading": 85}),
    ]);
    assert_eq!(sensors.watts, Some(175.0));
}

#[test]
fn a_fan_reported_as_a_percentage_is_still_a_fan() {
    let sensors = BmcSensors::from_sensors(&[
        json!({"Name": "Fan 1 PWM", "ReadingType": "Percent", "Reading": 42, "ReadingUnits": "Percent"}),
        json!({"Name": "CPU Utilisation", "ReadingType": "Percent", "Reading": 12}),
    ]);
    // The second is a percentage of something else entirely
    assert_eq!(names(&sensors.fans), ["Fan 1 PWM"]);
    assert_eq!(sensors.fans[0].unit.as_deref(), Some("Percent"));
}

#[test]
fn a_member_with_no_reading_is_skipped() {
    let sensors = BmcSensors::from_sensors(&[json!({"Name": "CPU", "ReadingType": "Temperature", "Reading": null})]);
    assert!(sensors.is_empty());
}

#[test]
fn an_unfamiliar_reading_type_is_ignored_rather_than_guessed_at() {
    let sensors = BmcSensors::from_sensors(&[json!({"Name": "Airflow", "ReadingType": "AirFlowCFM", "Reading": 30})]);
    assert!(sensors.is_empty());
}

// --- which resources to fetch ---

fn chassis(json: Value) -> RedfishChassis {
    RedfishChassis::from_json(&json)
}

#[test]
fn the_new_model_needs_only_the_sensors_collection() {
    let c = chassis(json!({
        "ThermalSubsystem": {"@odata.id": "/ts"},
        "PowerSubsystem": {"@odata.id": "/ps"},
        "Sensors": {"@odata.id": "/s"},
    }));
    assert_eq!(sensor_paths(&c), ["/s"]);
}

#[test]
fn the_old_model_needs_both_halves() {
    let c = chassis(json!({"Thermal": {"@odata.id": "/t"}, "Power": {"@odata.id": "/p"}}));
    assert_eq!(sensor_paths(&c), ["/t", "/p"]);
}

#[test]
fn a_chassis_with_one_half_of_the_old_model_asks_for_that_half() {
    assert_eq!(sensor_paths(&chassis(json!({"Thermal": {"@odata.id": "/t"}}))), ["/t"]);
}

#[test]
fn both_models_present_means_the_new_one_and_one_request() {
    let c = chassis(json!({
        "Thermal": {"@odata.id": "/t"},
        "Power": {"@odata.id": "/p"},
        "ThermalSubsystem": {"@odata.id": "/ts"},
        "Sensors": {"@odata.id": "/s"},
    }));
    assert_eq!(sensor_paths(&c), ["/s"]);
}

#[test]
fn a_chassis_with_neither_asks_for_nothing() {
    assert!(sensor_paths(&chassis(json!({}))).is_empty());
}

// --- what an H3C R5350 G6 actually sends ---

#[test]
fn ffffffff_is_no_reading_not_four_billion_degrees() {
    let sensors = legacy(fixture("h3c_r5350_g6_thermal"));
    assert_eq!(names(&sensors.temperatures), ["OCP_Temp"], "the sentinel is absence");
    assert_eq!(sensors.temperatures[0].value, 59.0);
    assert_eq!(names(&sensors.fans), ["Fan1"]);
}

#[test]
fn the_other_sentinels_go_the_same_way_and_real_readings_do_not() {
    for sentinel in [4_294_967_295_i64, 65535, 0x7FFF_FFFF] {
        let s = legacy(json!({"Temperatures": [{"Name": "t", "ReadingCelsius": sentinel}]}));
        assert!(s.temperatures.is_empty(), "sentinel {sentinel}");
    }
    // `-1` is a sentinel in some firmware and also what a cold inlet reads, so
    // it is kept: only one of those two mistakes is visible.
    for real in [-40, -1, 0, 4, 59, 105] {
        let s = legacy(json!({"Temperatures": [{"Name": "t", "ReadingCelsius": real}]}));
        assert_eq!(s.temperatures[0].value, real as f64, "real {real}");
    }
}

#[test]
fn the_bounds_themselves_are_readings() {
    // Dart's `value < min || value > max`: inclusive at both ends.
    let s = legacy(json!({
        "Temperatures": [
            {"Name": "zero", "ReadingCelsius": -273.15},
            {"Name": "hot", "ReadingCelsius": 1000},
            {"Name": "below", "ReadingCelsius": -273.16},
            {"Name": "above", "ReadingCelsius": 1000.01},
        ],
        "Fans": [{"Name": "max", "Reading": 100000}, {"Name": "neg", "Reading": -1}],
    }));
    assert_eq!(names(&s.temperatures), ["zero", "hot"]);
    assert_eq!(names(&s.fans), ["max"]);
}

#[test]
fn a_sentinel_wattage_is_not_a_4_gw_chassis() {
    let s = BmcSensors::from_legacy(None, Some(&json!({"PowerControl": [{"PowerConsumedWatts": 4_294_967_295_i64}]})));
    assert_eq!(s.watts, None);
}

#[test]
fn the_modern_model_filters_the_same_way() {
    let s = BmcSensors::from_sensors(&[
        json!({"Name": "a", "ReadingType": "Temperature", "Reading": 4_294_967_295_i64}),
        json!({"Name": "b", "ReadingType": "Temperature", "Reading": 42}),
        json!({"Name": "Fan1", "ReadingType": "Rotational", "Reading": 4_294_967_295_i64}),
        json!({"Name": "Fan2", "ReadingType": "Rotational", "Reading": 900}),
        json!({"Name": "p", "ReadingType": "Power", "Reading": 4_294_967_295_i64}),
    ]);
    assert_eq!(names(&s.temperatures), ["b"]);
    assert_eq!(names(&s.fans), ["Fan2"]);
    assert_eq!(s.watts, None);
}

#[test]
fn sensors_serialize_for_the_panel_and_the_app() {
    let s = legacy(fixture("h3c_r5350_g6_thermal"));
    assert_eq!(
        serde_json::to_value(&s).unwrap(),
        json!({
            "temperatures": [{"name": "OCP_Temp", "value": 59.0, "unit": "Cel"}],
            "fans": [{"name": "Fan1", "value": 1050.0, "unit": "RPM"}],
            "watts": null,
        })
    );
}
