//! The cron module against the app's Dart fixture tests
//! (`test/unit/server/cron_manager_test.dart`, `cron_schedule_test.dart`),
//! ported before the Dart copy was deleted and the app moved onto
//! `sbm_ffi::api::cron`. The wording of a schedule stays with each client and
//! is not here.

use sbm_parser::cron::*;

const SOURCE: &str = "# Keep this comment
MAILTO=ops@example.com
0 2 * * * /usr/local/bin/backup --quiet
@reboot /usr/local/bin/register
# ServerBox disabled: */5 * * * * /usr/local/bin/health-check
# 0 0 * * * this ordinary comment is not managed
";

fn wall(year: i32, month: u32, day: u32, hour: u32, minute: u32) -> CivilTime {
    CivilTime::new(year, month, day, hour, minute)
}

fn schedule(expression: &str) -> CronSchedule {
    CronSchedule::try_parse(expression).unwrap_or_else(|| panic!("{expression}"))
}

#[test]
fn parses_jobs_while_preserving_comments_and_environment_lines() {
    let document = CronDocument::parse(SOURCE);
    let jobs = document.jobs();
    assert_eq!(jobs.len(), 3);
    assert_eq!(jobs[0].schedule, "0 2 * * *");
    assert_eq!(jobs[0].command, "/usr/local/bin/backup --quiet");
    assert_eq!(jobs[1].schedule, "@reboot");
    assert!(!jobs[2].enabled);
    assert_eq!(document.lines[0], "# Keep this comment");
    assert_eq!(document.lines[1], "MAILTO=ops@example.com");
}

#[test]
fn edits_disables_adds_and_removes_jobs_without_losing_other_lines() {
    let original = CronDocument::parse(SOURCE);
    let edited = original
        .upsert(Some(original.jobs()[0].line_index), "30 3 * * *", "/usr/local/bin/backup", true)
        .unwrap();
    let disabled = edited.set_enabled(edited.jobs()[1].line_index, false).unwrap();
    let added = disabled.upsert(None, "@daily", "/usr/local/bin/report", true).unwrap();
    let removed = added.remove(added.jobs()[2].line_index).unwrap();

    assert_eq!(removed.lines[0], "# Keep this comment");
    assert_eq!(removed.lines[1], "MAILTO=ops@example.com");
    let rendered = removed.render();
    assert!(rendered.contains("30 3 * * * /usr/local/bin/backup\n"));
    assert!(rendered.contains("# ServerBox disabled: @reboot /usr/local/bin/register\n"));
    assert!(rendered.contains("@daily /usr/local/bin/report\n"));
    assert!(!rendered.contains("health-check"));
}

#[test]
fn keeps_every_line_it_does_not_manage_as_a_preserved_one() {
    let document = CronDocument::parse(SOURCE);
    assert_eq!(
        document.preserved(),
        vec![
            "# Keep this comment",
            "MAILTO=ops@example.com",
            "# 0 0 * * * this ordinary comment is not managed",
        ]
    );
    // A disabled task is a task, not a comment.
    assert!(!document.preserved().iter().any(|line| line.contains("health-check")));
}

fn listing(stdout: &str) -> CronCatalog {
    read_listing(stdout, "", Some(0), true).expect("listing")
}

#[test]
fn reads_the_clock_the_listing_reported() {
    let catalog = listing("SrvBoxCron.User\tadmin\nSrvBoxCron.Clock\t1772000000 -0500\nSrvBoxCron.Body\n");
    let clock = catalog.clock.unwrap();
    assert_eq!(clock.offset_minutes, -300);
    assert_eq!(clock.epoch, 1772000000);
}

#[test]
fn treats_a_clock_it_cannot_read_as_one_the_server_did_not_say() {
    assert!(listing("SrvBoxCron.User\tadmin\nSrvBoxCron.Clock\t1772000000 %z\nSrvBoxCron.Body\n").clock.is_none());
    assert!(listing("SrvBoxCron.User\tadmin\nSrvBoxCron.Body\n").clock.is_none());
}

#[test]
fn validates_schedules_and_rejects_line_injection() {
    assert_eq!(validate("* * * *", "echo short"), Some(CronValidation::FieldCount));
    assert_eq!(validate("@reboot", "echo okay"), None);
    assert_eq!(validate("@", "echo okay"), Some(CronValidation::Macro));
    assert_eq!(validate("@daily 0 3 * * *", "echo okay"), Some(CronValidation::Macro));
    assert_eq!(validate("* * * * *", "echo okay\nrm -rf /"), Some(CronValidation::LineBreak));
}

#[test]
fn lists_an_empty_crontab_and_saves_the_complete_document() {
    let catalog = listing("SrvBoxCron.User\tadmin\nSrvBoxCron.Body\n");
    assert_eq!(catalog.user, "admin");
    assert!(catalog.document.jobs().is_empty());
    let document = catalog.document.upsert(None, "0 * * * *", "/usr/local/bin/hourly", true).unwrap();
    assert_eq!(document.render(), "0 * * * * /usr/local/bin/hourly\n");
    assert_eq!(SAVE_COMMAND, "crontab -");
}

#[test]
fn treats_the_no_crontab_messages_as_an_empty_document() {
    for stderr in ["no crontab for admin\n", "crontab: can't open 'admin': No such file or directory\n"] {
        let catalog = read_listing("SrvBoxCron.User\tadmin\nSrvBoxCron.Body\n", stderr, Some(1), false).unwrap();
        assert_eq!(catalog.user, "admin");
        assert!(catalog.document.lines.is_empty(), "{stderr}");
    }
}

#[test]
fn reads_each_implementations_no_crontab_message() {
    assert!(is_no_crontab("no crontab for admin"));
    assert!(is_no_crontab("crontab: no crontab for admin"));
    assert!(is_no_crontab("crontab: can't open 'admin': No such file or directory"));
    assert!(!is_no_crontab(
        "crontab: can't change directory to '/etc/crontabs': No such file or directory"
    ));
    assert!(!is_no_crontab("crontab: can't open 'admin': Permission denied"));
    assert!(!is_no_crontab(""));
}

#[test]
fn does_not_include_successful_crontab_warnings_in_the_document() {
    let catalog = read_listing(
        "SrvBoxCron.User\tadmin\nSrvBoxCron.Body\n0 * * * * echo ok\n",
        "warning: legacy syntax\n",
        Some(0),
        true,
    )
    .unwrap();
    assert_eq!(catalog.document.jobs().len(), 1);
    assert_eq!(catalog.document.render(), "0 * * * * echo ok\n");
}

#[test]
fn reports_a_missing_crontab_implementation() {
    let failure = read_listing("", "crontab is not installed", Some(127), false).unwrap_err();
    assert!(failure.not_installed);
    assert_eq!(failure.detail.as_deref(), Some("crontab is not installed"));

    // An exit of 1 that is not one of the no-crontab messages is a failure,
    // in the machine's words.
    let failure = read_listing("", "crontab: can't open 'admin': Permission denied", Some(1), false).unwrap_err();
    assert!(!failure.not_installed);
    assert_eq!(failure.detail.as_deref(), Some("crontab: can't open 'admin': Permission denied"));

    // Output that is not the script's is not read as a crontab.
    let failure = read_listing("Welcome!\n", "", Some(0), true).unwrap_err();
    assert_eq!(failure.detail.as_deref(), Some("Invalid crontab response"));
}

#[test]
fn a_refused_save_says_why() {
    assert_eq!(check_save("", "", Some(0), true), Ok(()));
    let failure = check_save("", "crontab: bad minute\n", Some(1), false).unwrap_err();
    assert_eq!(failure.detail.as_deref(), Some("crontab: bad minute"));
    assert!(!failure.not_installed);
    assert!(check_save("", "", Some(127), false).unwrap_err().not_installed);
    assert_eq!(check_save("", "", Some(1), false).unwrap_err().detail, None);
}

#[test]
fn expands_every_form_a_field_can_take() {
    let parsed = schedule("0,30 9-17/4 * jan-mar mon-fri");
    assert_eq!(parsed.minutes, vec![0, 30]);
    assert_eq!(parsed.hours, vec![9, 13, 17]);
    assert_eq!(parsed.days_of_month.len(), 31);
    assert_eq!(parsed.months, vec![1, 2, 3]);
    assert_eq!(parsed.days_of_week, vec![1, 2, 3, 4, 5]);
    assert!(!parsed.day_of_month_restricted);
    assert!(parsed.day_of_week_restricted);
}

#[test]
fn folds_sunday_written_as_7_onto_0() {
    assert_eq!(schedule("0 0 * * 7").days_of_week, vec![0]);
    assert_eq!(schedule("0 0 * * 0").days_of_week, vec![0]);
}

#[test]
fn says_nothing_about_a_range_that_descends() {
    assert!(CronSchedule::try_parse("0 22-2 * * *").is_none());
    assert!(CronSchedule::try_parse("0 0 * * fri-mon").is_none());
    assert_eq!(schedule("0 22-23 * * *").hours, vec![22, 23]);
}

#[test]
fn reads_the_macros_as_what_crond_expands_them_to() {
    assert_eq!(schedule("@daily").hours, vec![0]);
    assert_eq!(schedule("@weekly").days_of_week, vec![0]);
    assert_eq!(schedule("@MONTHLY").days_of_month, vec![1]);
    assert!(schedule("@reboot").is_reboot);
}

#[test]
fn refuses_what_it_cannot_read() {
    for expression in [
        "",
        "* * * *",
        "* * * * * *",
        "60 * * * *",
        "* 24 * * *",
        "0 0 0 * *",
        "0 0 * 13 *",
        "*/0 * * * *",
        "0 0 * * mon-",
        "@hourlyish",
        "MAILTO=ops@example.com",
    ] {
        assert!(CronSchedule::try_parse(expression).is_none(), "{expression}");
    }
}

#[test]
fn the_next_run_is_the_next_matching_minute_never_this_one() {
    let every = schedule("*/15 * * * *");
    assert_eq!(every.next_run(wall(2026, 3, 1, 9, 0)), Some(wall(2026, 3, 1, 9, 15)));
    assert_eq!(every.next_run(wall(2026, 3, 1, 9, 14)), Some(wall(2026, 3, 1, 9, 15)));
    assert_eq!(every.next_run(wall(2026, 3, 1, 9, 59)), Some(wall(2026, 3, 1, 10, 0)));
}

#[test]
fn the_next_run_crosses_midnight_and_the_end_of_a_month() {
    let daily = schedule("0 2 * * *");
    assert_eq!(daily.next_run(wall(2026, 3, 31, 3, 0)), Some(wall(2026, 4, 1, 2, 0)));
    assert_eq!(daily.next_run(wall(2026, 3, 31, 1, 0)), Some(wall(2026, 3, 31, 2, 0)));
}

#[test]
fn the_next_run_finds_a_day_of_week() {
    // 2026-03-01 is a Sunday.
    assert_eq!(schedule("30 4 * * 0").next_run(wall(2026, 3, 1, 5, 0)), Some(wall(2026, 3, 8, 4, 30)));
}

#[test]
fn the_next_run_finds_a_date_years_out() {
    assert_eq!(schedule("0 0 29 2 *").next_run(wall(2026, 3, 1, 0, 0)), Some(wall(2028, 2, 29, 0, 0)));
}

#[test]
fn the_next_run_takes_either_day_when_both_day_fields_are_restricted() {
    let either = schedule("0 0 13 * 5");
    // 2026-03-06 is a Friday; the 13th is the Friday after it.
    assert_eq!(either.next_run(wall(2026, 3, 1, 0, 0)), Some(wall(2026, 3, 6, 0, 0)));
    assert_eq!(either.next_run(wall(2026, 3, 7, 0, 0)), Some(wall(2026, 3, 13, 0, 0)));
}

#[test]
fn reboot_has_no_next_run() {
    assert_eq!(schedule("@reboot").next_run(wall(2026, 3, 1, 0, 0)), None);
}

#[test]
fn the_clock_reads_what_date_printed() {
    let clock = CronClock::try_parse("1772000000 +0800").unwrap();
    assert_eq!(clock.offset_minutes, 480);
    let clock = CronClock::try_parse("1772000060 -0330").unwrap();
    assert_eq!(clock.offset_minutes, -210);
    assert_eq!(clock.epoch, 1772000060);
    for unreadable in ["1772000000 %z", "", "1772000000"] {
        assert!(CronClock::try_parse(unreadable).is_none(), "{unreadable}");
    }
}
