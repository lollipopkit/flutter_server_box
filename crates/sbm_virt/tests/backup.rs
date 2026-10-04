//! `sbm_virt::backup`'s rules: which guests a job takes, the schedule's
//! shape against what PVE 9.2.2 answered, and the checks a job and a backup
//! request pass before they are sent.
//!
//! Ported from the app's `test/unit/virt/virt_backup_job_test.dart`.

use sbm_virt::backup::{BackupJob, BackupJobEdit, BackupRequest, Issue, job_issue, request_issue, schedule_issue};
use serde_json::{Value, json};

fn job(v: Value) -> BackupJob {
    serde_json::from_value(v).unwrap()
}

fn edit(v: Value) -> BackupJobEdit {
    serde_json::from_value(v).unwrap()
}

// ---------------------------------------------------------------------------
// Which guests a job takes
// ---------------------------------------------------------------------------

#[test]
fn a_job_that_names_its_guests_takes_those() {
    let j = job(json!({"id": "j", "vmids": [911, 912]}));
    assert!(j.enabled, "a job is enabled unless it says otherwise");
    assert!(j.takes(Some(911), None));
    assert!(j.takes(Some(912), Some("pve")));
    assert!(!j.takes(Some(913), None));
    assert!(!j.takes(None, None), "a guest without a VMID");
}

#[test]
fn a_job_for_every_guest_less_what_it_excludes() {
    let j = job(json!({"id": "j", "all": true, "exclude": [912]}));
    assert!(j.takes(Some(911), None));
    assert!(!j.takes(Some(912), None), "excluded");
    assert!(j.takes(Some(913), None));
}

#[test]
fn a_job_by_pool_claims_none_of_its_guests() {
    // Which guests a pool holds is not in the listing.
    let j = job(json!({"id": "j", "pool": "prod", "all": true, "vmids": [100]}));
    assert!(!j.takes(Some(100), None));
    assert!(!j.takes_only(Some(100)));
}

#[test]
fn a_job_restricted_to_a_node_takes_only_the_guests_there() {
    let j = job(json!({"id": "j", "all": true, "node": "a"}));
    assert!(!j.takes(Some(100), Some("pve")));
    assert!(j.takes(Some(100), Some("a")));
    // The guest's node unknown: the job is not ruled out by it.
    assert!(j.takes(Some(100), None));
    let any = job(json!({"id": "j", "vmids": [100]}));
    assert!(any.takes(Some(100), Some("pve")));
}

#[test]
fn a_guests_own_plan_is_a_job_of_it_alone() {
    assert!(job(json!({"id": "j", "vmids": [100]})).takes_only(Some(100)));
    assert!(!job(json!({"id": "j", "vmids": [100]})).takes_only(Some(101)));
    assert!(!job(json!({"id": "j", "vmids": [100, 101]})).takes_only(Some(100)));
    assert!(!job(json!({"id": "j", "all": true})).takes_only(Some(100)));
    assert!(!job(json!({"id": "j", "vmids": [100], "exclude": [101]})).takes_only(Some(100)));
    assert!(!job(json!({"id": "j", "vmids": [100]})).takes_only(None));
}

// ---------------------------------------------------------------------------
// The schedule
// ---------------------------------------------------------------------------

#[test]
fn what_pve_takes_this_accepts() {
    for ok in [
        "02:30",
        "02:30:15",
        "mon..fri 02:30",
        "mon,wed 03:00",
        "sat 03:00",
        "*-*-* 04:00",
        "daily",
        "hourly",
        "weekly",
        "monthly",
        "yearly",
        "*:0/15",
        "*/5",
        "mon",
        "mon 02:30:15",
        "0/15",
        "mon..sun 02:30",
        // From PVE's documentation (Schedule Format), not put to the host: a
        // weekday, a date and a time together, and ranges in the date and
        // the time.
        "sat *-1..7 15:00",
        "mon..fri 8..17,22:0/15",
        "2015-10-21 01:00",
        "mon *-*-* 02:00",
        // Every shorthand, and surrounding whitespace.
        "minutely",
        "quarterly",
        "semiannually",
        "annually",
        "  daily  ",
    ] {
        assert_eq!(schedule_issue(ok), None, "{ok:?}");
    }
    // PVE's own parser is looser than a range check on the hour (checked
    // with `schedule-analyze` on PVE 9.2.2: `mon 59:59` is taken, `mon
    // 60:59` is not).
    assert_eq!(schedule_issue("mon 25:00"), None);
    assert_eq!(schedule_issue("mon 59:59"), None);
}

#[test]
fn what_pve_refuses_this_refuses_first() {
    assert_eq!(schedule_issue(""), Some(Issue::ScheduleEmpty));
    assert_eq!(schedule_issue("   "), Some(Issue::ScheduleEmpty));
    for bad in [
        "nope",
        "02:30 mon",
        "Mon-Fri 02:30",
        "* 02:30",
        "mon 02:70",
        "mon..xyz 02:30",
        "02:30; rm -rf /",
        "a\nb",
        "daily 02:30",
        "mon 02:30 extra",
        "02:30 *-*-*",
        "mon mon",
        // None of these are a calendar event, and one of them would be an
        // argument to `pvesh` had the value not been refused: the host is
        // never asked with them.
        "--help",
        "$(id)",
        "`id`",
        "mon 60:00",
        "mon 59:60",
        "mon 60:59",
        // A step too long for an integer: invalid, not a panic.
        "*/999999999999999999999999",
        "mon *:0/999999999999999999999999",
        // A step PVE refuses: 0 and 60 and above.
        "*:0/0",
        "*/60",
    ] {
        assert_eq!(schedule_issue(bad), Some(Issue::ScheduleInvalid), "{bad:?}");
    }
}

#[test]
fn every_value_the_host_was_asked_about_and_its_answer() {
    // `GET /cluster/jobs/schedule-analyze` on PVE 9.2.2, one line per value:
    // what the host takes (true) and what it refuses (false). The local check
    // has to agree in both directions — a value it passes on that the host
    // refuses is a round trip, and a value it refuses that the host takes is
    // a schedule the user cannot write.
    let answers = [
        ("02:30", true),
        ("02:30:15", true),
        ("mon..fri 02:30", true),
        ("mon,wed 03:00", true),
        ("sat 03:00", true),
        ("*-*-* 04:00", true),
        ("daily", true),
        ("hourly", true),
        ("weekly", true),
        ("monthly", true),
        ("yearly", true),
        ("*:0/15", true),
        ("*/5", true),
        ("mon", true),
        ("mon 25:00", true),
        ("mon 02:30:15", true),
        ("0/15", true),
        ("mon..sun 02:30", true),
        ("nope", false),
        ("02:30 mon", false),
        ("Mon-Fri 02:30", false),
        ("* 02:30", false),
        ("mon 02:70", false),
        ("mon..xyz 02:30", false),
        ("02:30; rm -rf /", false),
        ("--help", false),
        ("$(id)", false),
        ("`id`", false),
        ("mon 02:30 extra", false),
        ("   ", false),
        ("mon 60:00", false),
        ("mon 59:60", false),
    ];
    assert_eq!(answers.len(), 32, "the 32 values put to the host");
    for (value, host) in answers {
        let issue = schedule_issue(value);
        assert_eq!(issue.is_none(), host, "{value:?}: the host says {host}, this says {issue:?}");
    }
}

// ---------------------------------------------------------------------------
// A job and a backup request, checked before they are sent
// ---------------------------------------------------------------------------

fn storages() -> Vec<String> {
    vec!["local".into(), "nfs".into()]
}

#[test]
fn a_job_edit_takes_pves_defaults() {
    let e = edit(json!({"storage": "local", "schedule": "02:00", "vmids": [100]}));
    assert_eq!((e.mode.as_str(), e.compress.as_str()), ("snapshot", "zstd"));
    assert!(e.enabled);
    assert!(!e.is_new);
    assert_eq!(job_issue(&e, &storages()), None);
}

#[test]
fn a_job_is_refused_for_the_first_issue_it_has() {
    let base = json!({"storage": "local", "schedule": "02:00", "vmids": [100]});
    let with = |k: &str, v: Value| {
        let mut j = base.clone();
        j[k] = v;
        edit(j)
    };
    assert_eq!(job_issue(&with("schedule", json!(" ")), &storages()), Some(Issue::ScheduleEmpty));
    assert_eq!(job_issue(&with("schedule", json!("02:30 mon")), &storages()), Some(Issue::ScheduleInvalid));
    assert_eq!(job_issue(&with("storage", json!("local-lvm")), &storages()), Some(Issue::Storage));
    assert_eq!(job_issue(&with("storage", json!("local")), &[]), Some(Issue::Storage));
    assert_eq!(job_issue(&with("mode", json!("live")), &storages()), Some(Issue::Mode));
    assert_eq!(job_issue(&with("compress", json!("xz")), &storages()), Some(Issue::Compress));
    assert_eq!(job_issue(&with("vmids", json!([])), &storages()), Some(Issue::Guests), "a list that names none");
    // The schedule first: it is what the form shows under its own field.
    let mut both = with("schedule", json!("nope"));
    both.storage = "gone".into();
    assert_eq!(job_issue(&both, &storages()), Some(Issue::ScheduleInvalid));
}

#[test]
fn a_job_takes_a_pool_all_or_a_list() {
    for guests in [json!({"pool": "prod"}), json!({"all": true}), json!({"all": true, "exclude": [101]}), json!({"vmids": [1, 2]})] {
        let mut j = json!({"storage": "nfs", "schedule": "sat 03:00", "compress": "0", "mode": "stop"});
        j.as_object_mut().unwrap().extend(guests.as_object().unwrap().clone());
        assert_eq!(job_issue(&edit(j.clone()), &storages()), None, "{j}");
    }
}

#[test]
fn a_backup_request_names_a_backup_storage_a_mode_and_a_compression() {
    let r = |v: Value| -> BackupRequest { serde_json::from_value(v).unwrap() };
    let ok = r(json!({"storage": "local"}));
    assert_eq!((ok.mode.as_str(), ok.compress.as_str()), ("snapshot", "zstd"));
    assert_eq!(request_issue(&ok, &storages()), None);
    for compress in ["0", "zstd", "lzo", "gzip"] {
        for mode in ["snapshot", "suspend", "stop"] {
            assert_eq!(request_issue(&r(json!({"storage": "nfs", "mode": mode, "compress": compress})), &storages()), None);
        }
    }
    assert_eq!(request_issue(&r(json!({"storage": "local-lvm"})), &storages()), Some(Issue::Storage));
    assert_eq!(request_issue(&r(json!({"storage": "local", "mode": "live"})), &storages()), Some(Issue::Mode));
    assert_eq!(request_issue(&r(json!({"storage": "local", "compress": "xz"})), &storages()), Some(Issue::Compress));
}

#[test]
fn an_issue_is_said_by_its_snake_case_name() {
    assert_eq!(serde_json::to_value(Issue::NotStopped).unwrap(), json!("not_stopped"));
    assert_eq!(serde_json::to_value(Issue::ScheduleInvalid).unwrap(), json!("schedule_invalid"));
    assert_eq!(serde_json::to_value(Issue::NodeOffline).unwrap(), json!("node_offline"));
}
