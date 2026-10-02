//! The service module against the app's own fixtures.
//!
//! `test/fixtures/systemd/` holds what `systemctl` and `journalctl` printed on
//! a real machine, and `test/unit/server/service_manager_test.dart` asserts the
//! Dart implementation against them. This asserts the Rust port against the
//! same bytes, so the two agree before the Dart half is deleted.
//!
//! Read at runtime rather than `include_str!`: `monitor/Dockerfile` builds this
//! crate with `crates/` copied into the image and `monitor/` as the workspace
//! root, where `../../test/` is not there.
//!
//! TODO(migration): move `test/fixtures/systemd/` into this crate when the Dart
//! test is deleted, and read it with `include_str!`.

use std::collections::HashMap;

use sbm_parser::output::CommandOutput;
use sbm_parser::service::*;

const FIXTURES: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../../test/fixtures/systemd/");

fn fixture(name: &str) -> String {
    let path = format!("{FIXTURES}{name}");
    std::fs::read_to_string(&path).unwrap_or_else(|error| panic!("{path}: {error}"))
}

/// The systemd fixture's listing and details, as the agent would have them.
fn systemd_outputs(list: &str, details: &str) -> (CommandOutput, CommandOutput) {
    (
        CommandOutput::ok(list),
        CommandOutput::ok(details),
    )
}

fn listing_of(
    system_list: &CommandOutput,
    system_details: &CommandOutput,
    user_list: &CommandOutput,
    user_details: &CommandOutput,
) -> Result<ServiceListing, ServiceLoadError> {
    parse_systemd_listing(&SystemdOutputs {
        system_list,
        system_details,
        user_list,
        user_details,
    })
}

#[test]
fn the_systemd_fixture_reads_as_one_listing() {
    let (list, details) = systemd_outputs(&fixture("list_units.txt"), &fixture("show.txt"));
    // The user scope on the machine this was captured from has nothing in it.
    let empty = CommandOutput::ok("");
    let listing = listing_of(&list, &details, &empty, &empty).expect("listed");

    assert!(listing.notice.is_none(), "{:?}", listing.notice);
    assert_eq!(listing.detail, None);
    assert_eq!(listing.units.len(), 11);

    // Running first, then by name; the two scopes are the same here.
    let names: Vec<&str> = listing.units.iter().map(|unit| unit.name.as_str()).collect();
    assert_eq!(
        names,
        [
            "dbus",
            "dbus",
            "nscd",
            "sbrun",
            "sbtimer",
            "systemd-journald",
            "systemd-journald",
            "systemd-tmpfiles-clean",
            "sbfail",
            "sbtimer",
            "systemd-tmpfiles-clean",
        ]
    );

    let by_key: HashMap<String, &ServiceUnit> = listing
        .units
        .iter()
        .map(|unit| (unit.key(), unit))
        .collect();

    // A transient unit that exited 3: every field the details sweep fills.
    let failed = by_key["system:sbfail.service"];
    assert_eq!(failed.unit_type, ServiceUnitType::Service);
    assert_eq!(failed.state, ServiceState::Failed);
    assert_eq!(failed.scope, ServiceScope::System);
    assert_eq!(failed.description.as_deref(), Some("Fails on purpose"));
    assert_eq!(failed.sub_state.as_deref(), Some("failed"));
    assert_eq!(failed.result.as_deref(), Some("exit-code"));
    assert_eq!(failed.exit_status, Some(3));
    assert_eq!(failed.unit_file_state.as_deref(), Some("transient"));
    // `transient` is neither enabled nor disabled, so neither is offered.
    assert_eq!(failed.enabled, None);
    assert_eq!(failed.startup(), Some("transient"));
    assert_eq!(failed.actions, [ServiceAction::Restart]);
    assert_eq!(failed.memory_bytes, None);
    // The instant as the machine printed it, with no shift: the Dart port moves
    // it onto the device's clock, and the fixture test asserts that shifted
    // value. 2026-09-16 17:12:26 UTC.
    assert_eq!(failed.since_millis, Some(1_789_578_746_000));

    let journald = by_key["system:systemd-journald.service"];
    assert_eq!(journald.state, ServiceState::Running);
    assert_eq!(journald.memory_bytes, Some(12_386_304));
    // `success` explains nothing, so it is not kept.
    assert_eq!(journald.result, None);
    assert_eq!(journald.exit_status, None);
    assert_eq!(journald.enabled, Some(true));
    assert_eq!(journald.startup(), Some("enabled"));
    assert_eq!(
        journald.actions,
        [ServiceAction::Stop, ServiceAction::Restart, ServiceAction::Disable]
    );

    // `[not set]` is not zero bytes.
    assert_eq!(by_key["system:dbus.socket"].memory_bytes, None);
    assert_eq!(by_key["system:dbus.socket"].unit_type, ServiceUnitType::Socket);
    assert_eq!(by_key["system:dbus.socket"].enabled, None);
    assert_eq!(by_key["system:dbus.socket"].startup(), Some("linked"));

    // A timer, with no next elapse: the fixture's is monotonic, which systemd
    // prints as an empty value.
    let timer = by_key["system:sbtimer.timer"];
    assert_eq!(timer.unit_type, ServiceUnitType::Timer);
    assert_eq!(timer.state, ServiceState::Running);
    assert_eq!(timer.sub_state.as_deref(), Some("waiting"));
    assert_eq!(timer.next_elapse_millis, None);
    // Not a timer, so the column is not read for it at all.
    assert_eq!(by_key["system:sbrun.service"].next_elapse_millis, None);
    assert_eq!(by_key["system:sbrun.service"].memory_bytes, Some(950_272));

    let stopped = by_key["system:sbtimer.service"];
    assert_eq!(stopped.state, ServiceState::Stopped);
    assert_eq!(stopped.since_millis, None);
}

#[test]
fn the_details_sweep_reports_the_server_clock_it_was_taken_on() {
    let details = parse_details(&fixture("show.txt"));
    assert_eq!(details.sampled_at_millis, Some(1_789_578_763_000));
    assert_eq!(details.units.len(), 9);
    // The fixture's own timestamps are 17 s behind the clock line above, which
    // is what a caller differences against.
    assert_eq!(
        details.sampled_at_millis.unwrap() - details.units["sbfail.service"].active_enter_millis.unwrap(),
        17_000
    );

    // Without the clock line the properties are taken as they are, and there is
    // nothing to anchor a duration to.
    let without_clock = parse_details(
        "Id=nginx.service\nSubState=running\nActiveEnterTimestamp=Wed 2026-09-16 17:12:26 UTC\n\n",
    );
    assert_eq!(without_clock.sampled_at_millis, None);
    assert_eq!(
        without_clock.units["nginx.service"].active_enter_millis,
        Some(1_789_578_746_000)
    );
}

#[test]
fn a_unit_file_state_is_not_the_only_word_for_enabled() {
    let output = "Id=a.service\nUnitFileState=enabled-runtime\n\nId=b.service\nUnitFileState=disabled\n\nId=c.service\nUnitFileState=masked\n\nId=d.service\nUnitFileState=static\n\n";
    let details = parse_details(output);
    let running = |name: &str| {
        let mut unit = ServiceUnit::new(
            name,
            ServiceUnitType::Service,
            ServiceScope::System,
            ServiceState::Running,
        );
        unit.full_name = format!("{name}.service");
        with_details(&unit, details.units.get(&format!("{name}.service")))
    };

    assert_eq!(running("a").enabled, Some(true));
    assert_eq!(running("b").enabled, Some(false));
    assert_eq!(running("b").startup(), Some("disabled"));
    // `masked` and `static` are neither, and offering to enable either would
    // fail on the machine.
    assert_eq!(running("c").enabled, None);
    assert_eq!(running("c").startup(), Some("masked"));
    assert_eq!(running("d").enabled, None);
    assert_eq!(running("d").startup(), Some("static"));
    assert!(!running("c").actions.contains(&ServiceAction::Enable));
    assert!(!running("c").actions.contains(&ServiceAction::Disable));
}

#[test]
fn the_fixture_journal_reads_line_by_line() {
    let log = parse_journal(&fixture("journal.txt"), "");
    assert_eq!(log.lines.len(), 4);
    assert!(!log.unreadable);
    assert_eq!(log.lines[0].time.as_deref(), Some("01:12:26"));
    assert_eq!(log.lines[0].text, "systemd[1]: Started Fails on purpose.");
    assert_eq!(log.lines[1].text, "sh[373]: bind failed");
    assert_eq!(
        log.lines[3].text,
        "systemd[1]: sbfail.service: Failed with result 'exit-code'."
    );
}

#[test]
fn an_empty_log_is_not_an_unreadable_one() {
    // What journald prints when this account may not read the unit's log.
    let unreadable = parse_journal(
        "-- No entries --\n",
        "Hint: You are currently not seeing messages from other users and the system.\n",
    );
    assert!(unreadable.lines.is_empty());
    assert!(unreadable.unreadable);

    // And a unit that has simply never written anything.
    let empty = parse_journal("-- No entries --\n", "");
    assert!(empty.lines.is_empty());
    assert!(!empty.unreadable);
}

#[test]
fn a_carriage_return_does_not_end_up_in_the_message() {
    let log = parse_journal(
        "2026-09-17T01:12:26+08:00 host sh[373]: bind failed\r\n",
        "",
    );
    assert_eq!(log.lines.len(), 1);
    assert_eq!(log.lines[0].text, "sh[373]: bind failed");

    let logread = parse_logread(
        "Wed Sep 16 21:09:58 2026 daemon.err dnsmasq[1234]: failed to bind\r\n",
    );
    assert_eq!(logread.len(), 1);
    assert_eq!(logread[0].text, "dnsmasq[1234]: failed to bind");
}

#[test]
fn a_listing_that_failed_is_a_failure_and_a_details_sweep_that_failed_is_a_notice() {
    let (list, details) = systemd_outputs(&fixture("list_units.txt"), &fixture("show.txt"));
    let empty = CommandOutput::ok("");

    // The user scope is a notice: the machine has no user session, and every
    // system unit is still there.
    let user_failed = CommandOutput::new("", "channel closed\n", false);
    let listing = listing_of(&list, &details, &user_failed, &empty).expect("listed");
    assert_eq!(listing.units.len(), 11);
    assert_eq!(listing.notice, Some(ServiceListingNotice::UserScopeUnavailable));
    assert_eq!(listing.detail.as_deref(), Some("channel closed"));

    // The details sweep is a notice too: the units are listed but not
    // described.
    let details_failed = CommandOutput::new("", "no such property\n", false);
    let listing = listing_of(&list, &details_failed, &empty, &empty).expect("listed");
    assert_eq!(listing.units.len(), 11);
    assert_eq!(listing.notice, Some(ServiceListingNotice::DetailsUnavailable));
    // Nothing was read about them, so nothing is invented about them.
    let sshd = &listing.units[0];
    assert_eq!(sshd.enabled, None);
    assert_eq!(sshd.memory_bytes, None);

    // The system listing is the page: without it there is nothing to show.
    let system_failed = CommandOutput::new("", "systemctl: command not found\n", false);
    let error = listing_of(&system_failed, &details, &empty, &empty).expect_err("failed");
    assert!(error.detail.contains("systemctl: command not found"));
}

#[test]
fn only_the_managers_own_words_for_a_state_are_read() {
    // A row systemd printed for something this model does not carry, and one
    // whose state it does not name: both are dropped rather than guessed at.
    let units = parse_list_units(
        "unsupported.target loaded active active A target\n\
         odd.service loaded reloading reload A state no client draws\n\
         short.service loaded active\n\
         \n",
        ServiceScope::System,
    );
    assert!(units.is_empty());
}

#[test]
fn the_commands_are_the_ones_the_app_runs() {
    let system = ServiceManagerType::Systemd;
    assert_eq!(
        system.list_command(ServiceScope::System).unwrap(),
        "systemctl list-units --all --no-legend --no-pager --plain --type=service,socket,mount,timer"
    );
    assert_eq!(
        system.list_command(ServiceScope::User).unwrap(),
        "systemctl --user list-units --all --no-legend --no-pager --plain --type=service,socket,mount,timer"
    );
    let details = system.details_command(ServiceScope::System).unwrap();
    assert!(details.starts_with("date +%s; env TZ=UTC LC_ALL=C systemctl show --no-pager"));
    assert!(details.ends_with("-- '*.service' '*.socket' '*.mount' '*.timer'"));
    assert!(details.contains("--property=Id,UnitFileState,SubState"));
    assert!(
        system
            .details_command(ServiceScope::User)
            .unwrap()
            .contains("systemctl --user show")
    );
    // Not a systemd question at all.
    assert!(ServiceManagerType::Procd.list_command(ServiceScope::System).is_none());

    // A system unit, and the user unit beside it: the second is the one that
    // must not be wrapped in sudo.
    let unit = ServiceUnit::new(
        "sshd",
        ServiceUnitType::Service,
        ServiceScope::System,
        ServiceState::Running,
    );
    assert_eq!(
        system.command_for(&unit, ServiceAction::Restart),
        "systemctl restart 'sshd.service'"
    );
    assert!(system.needs_root(&unit));
    assert_eq!(
        terminal_command(
            &system.command_for(&unit, ServiceAction::Restart),
            system.needs_root(&unit),
            false
        ),
        "sudo systemctl restart 'sshd.service'"
    );
    assert_eq!(
        terminal_command(
            &system.command_for(&unit, ServiceAction::Restart),
            system.needs_root(&unit),
            true
        ),
        "systemctl restart 'sshd.service'"
    );
    assert_eq!(
        system.unit_status_command(&unit),
        "systemctl status --no-pager --full 'sshd.service'"
    );
    assert_eq!(
        system.recent_log_command(&unit, 20).unwrap(),
        "journalctl --no-pager --output=short-iso -n 20 -u 'sshd.service'"
    );
    assert_eq!(
        system.log_command(&unit).unwrap(),
        "journalctl -e -u 'sshd.service'"
    );

    let mut user_unit = ServiceUnit::new(
        "gpg-agent",
        ServiceUnitType::Socket,
        ServiceScope::User,
        ServiceState::Running,
    );
    assert_eq!(user_unit.full_name, "gpg-agent.socket");
    assert_eq!(
        system.command_for(&user_unit, ServiceAction::Restart),
        "systemctl --user restart 'gpg-agent.socket'"
    );
    assert!(!system.needs_root(&user_unit));
    assert_eq!(
        system.definition_command(&user_unit),
        "systemctl --user cat 'gpg-agent.socket'"
    );
    assert_eq!(
        system.log_command(&user_unit).unwrap(),
        "journalctl --user -e -u 'gpg-agent.socket'"
    );

    // Procd and OpenRC name their own scripts, and both need root.
    user_unit.scope = ServiceScope::System;
    user_unit.name = "nginx".to_string();
    user_unit.full_name = "nginx.service".to_string();
    assert_eq!(
        ServiceManagerType::Procd.command_for(&user_unit, ServiceAction::Restart),
        "'/etc/init.d/nginx' restart"
    );
    assert!(ServiceManagerType::Procd.needs_root(&user_unit));
    assert_eq!(
        ServiceManagerType::Procd.unit_status_command(&user_unit),
        "'/etc/init.d/nginx' status"
    );
    assert_eq!(
        ServiceManagerType::Procd.definition_command(&user_unit),
        "cat '/etc/init.d/nginx'"
    );

    assert_eq!(
        ServiceManagerType::Openrc.command_for(&user_unit, ServiceAction::Start),
        "rc-service 'nginx' start"
    );
    assert_eq!(
        ServiceManagerType::Openrc.command_for(&user_unit, ServiceAction::Stop),
        "rc-service 'nginx' stop"
    );
    assert_eq!(
        ServiceManagerType::Openrc.command_for(&user_unit, ServiceAction::Enable),
        "rc-update add 'nginx' default"
    );
    assert_eq!(
        ServiceManagerType::Openrc.command_for(&user_unit, ServiceAction::Disable),
        "rc-update --all delete 'nginx'"
    );
    assert_eq!(
        ServiceManagerType::Openrc.unit_status_command(&user_unit),
        "rc-service 'nginx' status"
    );
    // OpenRC keeps no per-service log, so both commands are absent rather than
    // answering with another service's output.
    assert!(ServiceManagerType::Openrc.log_command(&user_unit).is_none());
    assert!(
        ServiceManagerType::Openrc
            .recent_log_command(&user_unit, 20)
            .is_none()
    );
}

#[test]
fn procd_merges_a_script_walk_with_what_ubus_knows() {
    let catalog = "dnsmasq\t1\ndropbear\t1\nrpcd\t1\nuhttpd\t0\n";
    let status = r#"{
  "dnsmasq": {"instances": {"cfg01411c": {"running": true}}},
  "uhttpd": {"instances": {"instance1": {"running": false}}},
  "rpcd": {"instances": {}},
  "../../tmp/not-an-init-script": {"instances": {"x": {"running": true}}}
}"#;
    let listing = parse_procd_listing(&ProcdOutputs {
        catalog: &CommandOutput::ok(catalog),
        status: &CommandOutput::ok(status),
    })
    .expect("listed");

    assert_eq!(listing.notice, None);
    let names: Vec<&str> = listing.units.iter().map(|unit| unit.name.as_str()).collect();
    // Sorted with the running one first. `../../tmp/not-an-init-script` is not
    // here: it has no `/etc/init.d` entry, and an action for it would
    // manufacture a path from remote JSON that does not exist.
    assert_eq!(names, ["dnsmasq", "dropbear", "rpcd", "uhttpd"]);

    let by_name: HashMap<&str, &ServiceUnit> = listing
        .units
        .iter()
        .map(|unit| (unit.name.as_str(), unit))
        .collect();
    assert_eq!(by_name["dnsmasq"].state, ServiceState::Running);
    assert_eq!(by_name["dnsmasq"].enabled, Some(true));
    assert!(by_name["dnsmasq"].actions.contains(&ServiceAction::Disable));
    // `ubus` printed no object for `dropbear` at all, which is unknown rather
    // than stopped: the script is there and its state was not reported.
    assert_eq!(by_name["dropbear"].state, ServiceState::Unknown);
    assert_eq!(by_name["dropbear"].enabled, Some(true));
    // An instance that exists and is not running is stopped.
    assert_eq!(by_name["uhttpd"].state, ServiceState::Stopped);
    assert_eq!(by_name["uhttpd"].enabled, Some(false));
    assert!(by_name["uhttpd"].actions.contains(&ServiceAction::Enable));
    // An empty instance object is stopped too, not unknown.
    assert_eq!(by_name["rpcd"].state, ServiceState::Stopped);
}

#[test]
fn a_procd_machine_whose_ubus_failed_still_has_its_scripts() {
    let catalog = "dnsmasq\t1\ndropbear\t1\n";
    let listing = parse_procd_listing(&ProcdOutputs {
        catalog: &CommandOutput::ok(catalog),
        status: &CommandOutput::failed("ubus: not found\n"),
    })
    .expect("listed");

    assert_eq!(listing.units.len(), 2);
    assert_eq!(listing.notice, Some(ServiceListingNotice::DetailsUnavailable));
    assert_eq!(listing.detail.as_deref(), Some("ubus: not found"));
    assert!(listing.units.iter().all(|unit| unit.state == ServiceState::Unknown));
    // The startup registration came from the walk, not from `ubus`, so it is
    // still there.
    assert!(listing.units.iter().all(|unit| unit.enabled.is_some()));

    // A `ubus` that answered something this parser does not read is the same:
    // the scripts are there and only the states are missing.
    let garbage = parse_procd_listing(&ProcdOutputs {
        catalog: &CommandOutput::ok(catalog),
        status: &CommandOutput::ok("not json at all"),
    })
    .expect("listed");
    assert_eq!(garbage.notice, Some(ServiceListingNotice::DetailsUnavailable));
    assert!(garbage.detail.is_some());

    // Without the walk there is no page.
    let error = parse_procd_listing(&ProcdOutputs {
        catalog: &CommandOutput::failed("no /etc/init.d\n"),
        status: &CommandOutput::ok("{}"),
    })
    .expect_err("failed");
    assert!(error.detail.contains("no /etc/init.d"));
}

#[test]
fn the_procd_logread_format_is_read_by_its_own_date() {
    let lines = parse_logread(
        "Wed Sep 16 21:09:58 2026 daemon.err dnsmasq[1234]: failed to bind\ngarbage\n",
    );
    assert_eq!(lines.len(), 2);
    assert_eq!(lines[0].time.as_deref(), Some("21:09:58"));
    assert_eq!(lines[0].text, "dnsmasq[1234]: failed to bind");
    // A line that is not in that format is shown as written rather than
    // dropped.
    assert_eq!(lines[1].time, None);
    assert_eq!(lines[1].text, "garbage");
}

#[test]
fn openrc_merges_its_catalog_its_statuses_and_its_runlevels() {
    let catalog = "acpid\nchronyd\nlocalmount\nnetworking\nsshd\n";
    let status = "\
 acpid                  [  started  ]
 chronyd                [  stopped  ]
 localmount             [  crashed  ]
 networking             [  starting ]
";
    let startup = "\
             acpid | default
        localmount | boot
";
    let listing = parse_openrc_listing(&OpenRcOutputs {
        catalog: &CommandOutput::ok(catalog),
        status: &CommandOutput::ok(status),
        startup: &CommandOutput::ok(startup),
    })
    .expect("listed");

    assert_eq!(listing.notice, None);
    let names: Vec<&str> = listing.units.iter().map(|unit| unit.name.as_str()).collect();
    // Every name either source knows, running first. `sshd` is in the catalog
    // with no state, which is unknown rather than absent.
    assert_eq!(
        names,
        ["acpid", "chronyd", "localmount", "networking", "sshd"]
    );

    let by_name: HashMap<&str, &ServiceUnit> = listing
        .units
        .iter()
        .map(|unit| (unit.name.as_str(), unit))
        .collect();
    assert_eq!(by_name["acpid"].state, ServiceState::Running);
    assert_eq!(by_name["chronyd"].state, ServiceState::Stopped);
    assert_eq!(by_name["localmount"].state, ServiceState::Failed);
    assert_eq!(by_name["networking"].state, ServiceState::Starting);
    assert_eq!(by_name["sshd"].state, ServiceState::Unknown);
    assert_eq!(by_name["acpid"].enabled, Some(true));
    assert_eq!(by_name["localmount"].enabled, Some(true));
    // `rc-update show` answered and did not name it.
    assert_eq!(by_name["chronyd"].enabled, Some(false));
    assert_eq!(by_name["sshd"].enabled, Some(false));
}

#[test]
fn openrc_does_not_read_its_own_table_header_as_a_service() {
    let startup = "\
          service |     runlevels
                  |
            acpid |     default
";
    let enabled = parse_openrc_enabled(startup);
    assert_eq!(enabled.len(), 1);
    assert!(enabled.contains("acpid"));

    // A row with no runlevel names nothing to register.
    let empty_runlevel = parse_openrc_enabled("    acpid |     \n");
    assert!(empty_runlevel.is_empty());
}

#[test]
fn a_machine_that_cannot_report_its_runlevels_offers_no_switch() {
    let listing = parse_openrc_listing(&OpenRcOutputs {
        catalog: &CommandOutput::ok("/etc/init.d/sshd\n"),
        status: &CommandOutput::ok("sshd [ started ]\n"),
        startup: &CommandOutput::failed("rc-update: not found\n"),
    })
    .expect("listed");

    assert_eq!(listing.notice, Some(ServiceListingNotice::DetailsUnavailable));
    // Not `Some(false)`: "could not read it" is not "not registered", and a
    // false would offer to enable what may already be enabled.
    assert_eq!(listing.units[0].enabled, None);
    assert_eq!(listing.units[0].actions, [ServiceAction::Stop, ServiceAction::Restart]);
    assert!(listing.detail.unwrap().contains("rc-update: not found"));

    // The statuses are the page, as systemd's listing is.
    let error = parse_openrc_listing(&OpenRcOutputs {
        catalog: &CommandOutput::ok("/etc/init.d/sshd\n"),
        status: &CommandOutput::failed("rc-status: not found\n"),
        startup: &CommandOutput::ok(""),
    })
    .expect_err("failed");
    assert!(error.detail.contains("rc-status: not found"));
}

#[test]
fn the_probe_reads_a_manager_and_the_detection_order_puts_procd_first() {
    let probe = parse_probe("systemd\tDebian GNU/Linux");
    assert_eq!(probe.manager_type, Some(ServiceManagerType::Systemd));
    assert_eq!(probe.description(), "systemd (Debian GNU/Linux)");

    let unsupported = parse_probe("runit\tVoid Linux\n");
    assert_eq!(unsupported.manager_type, None);
    assert_eq!(unsupported.description(), "runit (Void Linux)");
    // The raw answer is kept, so a page can say what it found.
    assert_eq!(unsupported.raw, "runit\tVoid Linux\n");

    // OpenWrt has `/etc/init.d` too, so Procd must be recognised before the
    // generic fallback or every such box reads as sysvinit.
    let procd = DETECT_SCRIPT.find("manager=procd").expect("procd branch");
    let sysvinit = DETECT_SCRIPT.find("manager=sysvinit").expect("sysvinit branch");
    assert!(procd < sysvinit);
}

#[test]
fn the_timestamp_and_memory_parsers_refuse_what_they_cannot_read() {
    for value in ["", "n/a", "[not set]", "Wed 2026-09-16 12:04:31 CST"] {
        assert_eq!(parse_timestamp(value), None, "{value}");
    }
    assert_eq!(
        parse_timestamp("Wed 2026-09-16 17:12:26 UTC"),
        Some(1_789_578_746_000)
    );

    // What older systemd prints when there is no memory accounting at all.
    // The value is what a signed parse rejects, and the type is the check.
    for value in ["[not set]", "18446744073709551615", ""] {
        assert_eq!(parse_memory(value), None, "{value}");
    }
    assert_eq!(parse_memory(" 950272 "), Some(950_272));
}
