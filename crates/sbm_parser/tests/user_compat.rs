//! The users module against the app's own cases.
//!
//! `test/unit/server/user_manager_test.dart` asserts the Dart implementation
//! against the outputs below — a real `passwd`/`group` catalog, shadow records
//! and `authorized_keys` files. This asserts the Rust port against the same
//! bytes, so the two agree before the Dart half is deleted.
//!
//! Every case in the Dart suite is here, named the same way. The additions are
//! behaviour the Dart suite does not reach but that the agent rests on: the
//! ordering and primary-group rules of the catalog, an output with no
//! current-user line, the no-op command a password-only edit builds, the
//! refusals a rename and a line break in a field earn, and the quoting of the
//! path the detail script reads.
//!
//! TODO(migration): delete `lib/data/service/user_manager.dart`,
//! `lib/data/model/server/system_user.dart` and their test once this file is
//! the only implementation.

use sbm_parser::users::*;

/// The catalog the Dart suite parses.
const LISTING: &str = "SrvBoxUsers.Current\tadmin\n\
SrvBoxUsers.UidMin\t1000\n\
SrvBoxUsers.Passwd\n\
root:x:0:0:root:/root:/bin/bash\n\
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin\n\
admin:x:1000:1000:Admin User:/home/admin:/bin/bash\n\
deploy:x:1001:1000:Deploy:/srv/deploy:/bin/sh\n\
SrvBoxUsers.Group\n\
root:x:0:\n\
users:x:1000:admin\n\
docker:x:998:admin,deploy\n";

fn user(name: &str, home: &str) -> SystemUser {
    SystemUser {
        name: name.to_string(),
        uid: 1000,
        gid: 1000,
        comment: String::new(),
        home: home.to_string(),
        shell: "/bin/bash".to_string(),
        primary_group: Some("users".to_string()),
        supplementary_groups: Vec::new(),
    }
}

fn draft(name: &str) -> UserDraft {
    UserDraft {
        name: name.to_string(),
        comment: String::new(),
        home: String::new(),
        shell: String::new(),
        primary_group: String::new(),
        supplementary_groups: Vec::new(),
        create_home: true,
        move_home: false,
        system: false,
        password: None,
    }
}

// ---------------------------------------------------------------------------
// The catalog
// ---------------------------------------------------------------------------

#[test]
fn parses_passwd_and_group_catalogs() {
    let catalog = parse_list(LISTING).expect("the listing parses");

    assert_eq!(catalog.current_user, "admin");
    assert_eq!(catalog.uid_min, 1000);
    assert_eq!(catalog.users.len(), 4);
    assert!(catalog.users[0].is_root());
    assert!(catalog.users[1].login_disabled());

    let admin = &catalog.users[2];
    assert_eq!(admin.comment, "Admin User");
    assert_eq!(admin.primary_group.as_deref(), Some("users"));
    assert_eq!(admin.supplementary_groups, ["docker"]);
    assert!(!admin.is_system(catalog.uid_min));
}

#[test]
fn the_listing_is_ordered_by_uid_and_then_by_name() {
    let catalog = parse_list(
        "SrvBoxUsers.Current\tadmin\n\
SrvBoxUsers.UidMin\t1000\n\
SrvBoxUsers.Passwd\n\
b:x:1001:1001::/home/b:/bin/sh\n\
a:x:1001:1001::/home/a:/bin/sh\n\
root:x:0:0::/root:/bin/sh\n\
SrvBoxUsers.Group\n\
users:x:1000:\n",
    )
    .expect("the listing parses");

    let names: Vec<&str> = catalog.users.iter().map(|user| user.name.as_str()).collect();
    assert_eq!(names, ["root", "a", "b"]);
}

/// A group an account is in as its primary one is not also a supplementary one,
/// and `/etc/group` lists it either way.
#[test]
fn the_primary_group_is_not_also_a_supplementary_one() {
    let catalog = parse_list(
        "SrvBoxUsers.Current\tadmin\n\
SrvBoxUsers.Passwd\n\
admin:x:1000:1000::/home/admin:/bin/bash\n\
SrvBoxUsers.Group\n\
users:x:1000:admin\n\
docker:x:998:admin\n",
    )
    .expect("the listing parses");

    assert_eq!(catalog.users[0].primary_group.as_deref(), Some("users"));
    assert_eq!(catalog.users[0].supplementary_groups, ["docker"]);
}

/// Everything below the first line could not be trusted, and an empty list
/// would read as "this machine has no users".
#[test]
fn a_listing_without_the_current_user_is_refused() {
    assert_eq!(parse_list(""), Err(UserError::CurrentUserUnknown));
    assert_eq!(
        parse_list("SrvBoxUsers.Passwd\nroot:x:0:0::/root:/bin/sh\n"),
        Err(UserError::CurrentUserUnknown)
    );
}

/// The uid that a machine without `/etc/login.defs` is read with, and a field
/// that will not parse.
#[test]
fn the_system_threshold_defaults_to_a_thousand() {
    let catalog = parse_list("SrvBoxUsers.Current\tadmin\nSrvBoxUsers.UidMin\tgarbage\n")
        .expect("the listing parses");
    assert_eq!(catalog.uid_min, 1000);
    assert!(catalog.find("admin").is_none());
}

// ---------------------------------------------------------------------------
// The listing script
// ---------------------------------------------------------------------------

/// Handed to `sh`, not run as a command: the login shell of the account may be
/// fish, which stops at `if ...; then`.
#[test]
fn the_catalog_script_is_sh_and_says_which_machine_it_read() {
    assert!(LIST_SCRIPT.contains("if command -v getent"));
    assert!(LIST_SCRIPT.contains("elif [ -r /etc/group ]"));
    assert!(LIST_SCRIPT.starts_with("set -e"));

    // Every marker the parser splits on is one the script prints. The tab the
    // first two end in is the script's own escape — inside the single quotes
    // `printf` reads it as one.
    for marker in [
        CURRENT_MARKER,
        UID_MIN_MARKER,
        PASSWD_MARKER,
        GROUP_MARKER,
    ] {
        let name = marker.trim_end();
        assert!(LIST_SCRIPT.contains(&format!("printf '{name}")), "{name}");
    }
}

// ---------------------------------------------------------------------------
// One account's detail
// ---------------------------------------------------------------------------

/// [keysRead] false leaves the read-marker out, which is what the script does
/// when `authorized_keys` could not be opened.
fn detail_out(shadow: &str, status: &str, keys: &str, sudo: &str, keys_read: bool) -> String {
    [
        DETAIL_SHADOW_MARKER,
        shadow,
        DETAIL_STATUS_MARKER,
        status,
        DETAIL_KEYS_MARKER,
        if keys_read { DETAIL_KEYS_READ_MARKER } else { "" },
        keys,
        DETAIL_SUDO_MARKER,
        sudo,
    ]
    .join("\n")
}

#[test]
fn reads_shadow_rather_than_the_locale_formatted_commands() {
    let detail = parse_detail(&detail_out(
        r"lk:$y$j9T$abc:20355:0:99999:7:::",
        "",
        "",
        "",
        true,
    ));
    assert_eq!(detail.password_state, Some(PasswordState::Set));
    // 20355 days after the epoch, which is 2025-09-24 — the same day the Dart
    // suite asserts, as an instant rather than a local date.
    assert_eq!(detail.password_changed_millis, Some(1_758_672_000_000));
    assert!(detail.never_expires);
    assert_eq!(detail.expires_millis, None);
}

/// `!`, `!!` and `*` all mean "no password login". An empty field means no
/// password at all, which lets anyone in and must not read as locked.
#[test]
fn tells_a_locked_password_from_an_absent_one() {
    for hash in ["!", "!!", "*", "!$y$abc"] {
        let detail = parse_detail(&detail_out(&format!("svc:{hash}:20000:0:99999:7:::"), "", "", "", true));
        assert_eq!(detail.password_state, Some(PasswordState::Locked), "{hash}");
    }
    let none = parse_detail(&detail_out("svc::20000:0:99999:7:::", "", "", "", true));
    assert_eq!(none.password_state, Some(PasswordState::None));
}

#[test]
fn an_expiry_date_is_a_date_an_empty_field_is_never() {
    let expiring = parse_detail(&detail_out("temp:x:20000:0:99999:7::20500:", "", "", "", true));
    assert_eq!(expiring.expires_millis, Some(1_771_200_000_000));
    assert!(!expiring.never_expires);
}

/// Empty is the only thing that means never. Anything that will not parse means
/// the record could not be read, and answering Never there would be a claim
/// about an account's expiry made from no evidence.
#[test]
fn an_unreadable_expiry_field_is_not_never() {
    for field in ["0", "-1", "garbage"] {
        let detail = parse_detail(&detail_out(
            &format!("temp:x:20000:0:99999:7::{field}:"),
            "",
            "",
            "",
            true,
        ));
        assert!(!detail.never_expires, "{field}");
        assert_eq!(detail.expires_millis, None, "{field}");
    }
}

#[test]
fn falls_back_to_passwd_s_when_shadow_is_unreadable() {
    let detail = parse_detail(&detail_out("", "lk L 09/28/2026 0 99999 7 -1", "", "", true));
    assert_eq!(detail.password_state, Some(PasswordState::Locked));
    assert_eq!(detail.password_changed_millis, None);
}

/// The script's awk pass has already reduced each line to its type token, which
/// is what keeps the file's free-form contents off this stream.
#[test]
fn collects_distinct_key_types_in_file_order() {
    let detail = parse_detail(&detail_out(
        "",
        "",
        "ssh-ed25519\nssh-rsa\nssh-ed25519\necdsa-sha2-nistp256\n\n",
        "",
        true,
    ));
    assert_eq!(
        detail.ssh_key_types,
        Some(vec![
            "ed25519".to_string(),
            "rsa".to_string(),
            "ecdsa".to_string()
        ])
    );
}

/// An empty list is "read it, there are none"; `None` is "could not read it".
/// Reporting the second as the first would tell the user that an account with
/// keys has none.
#[test]
fn an_unread_keys_file_is_none_an_empty_one_is_empty() {
    let empty = parse_detail(&detail_out("", "", "", "", true));
    assert_eq!(empty.ssh_key_types, Some(Vec::new()));

    let unread = parse_detail(&detail_out("", "", "", "", false));
    assert_eq!(unread.ssh_key_types, None);

    let nothing = parse_detail(DETAIL_SHADOW_MARKER);
    assert_eq!(nothing.ssh_key_types, None);
}

/// The file belongs to the account being looked at, and the markers travel as
/// plain text on the same stream. Reducing each line to a token that cannot
/// spell one is what stops its owner fabricating the sudo rule this is read
/// beside — so the filter has to be in the script, since the parser cannot tell
/// a marker from a line of the file.
#[test]
fn the_script_never_lets_a_keys_line_reach_the_parser_whole() {
    let script = detail_script(&user("lk", "/home/lk")).expect("a valid name");

    assert!(script.contains(r"if ($i ~ /^(ssh-|ecdsa-|sk-)/)"));
    assert!(script.contains("if [ -r '/home/lk/.ssh/authorized_keys' ]"));
    // The read has to report its own failure rather than be swallowed.
    assert!(!script.contains("authorized_keys' 2>/dev/null || true"));
}

/// A home path with a quote in it, and a name that is not one.
#[test]
fn a_detail_script_quotes_the_path_it_reads() {
    let script = detail_script(&user("lk", "/home/o'brien")).expect("a valid name");
    assert!(script.contains(r"if [ -r '/home/o'\''brien/.ssh/authorized_keys' ]"));

    assert_eq!(
        detail_script(&user("bad;touch /tmp/pwned", "/home/x")),
        Err(UserError::InvalidName)
    );
}

#[test]
fn takes_the_first_sudoers_rule_and_drops_the_host_part() {
    let detail = parse_detail(&detail_out(
        "",
        "",
        "",
        "Matching Defaults entries for lk on box:\n    env_reset, mail_badpass\n\nUser lk may run the following commands on box:\n    (ALL : ALL) NOPASSWD: ALL\n",
        true,
    ));
    assert_eq!(detail.sudo_rule.as_deref(), Some("NOPASSWD: ALL"));
}

#[test]
fn nothing_readable_is_an_empty_detail_not_a_wrong_one() {
    let detail = parse_detail(DETAIL_SHADOW_MARKER);
    assert!(detail.is_empty());
    assert_eq!(detail.password_state, None);
    assert_eq!(detail.sudo_rule, None);
}

// ---------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------

#[test]
fn builds_a_quoted_create_script_and_sets_the_password_through_the_heredoc() {
    let mut draft = draft("deploy");
    draft.comment = "Release operator's account".to_string();
    draft.home = "/srv/deploy".to_string();
    draft.shell = "/bin/bash".to_string();
    draft.primary_group = "users".to_string();
    draft.supplementary_groups = vec!["docker".to_string(), "wheel".to_string()];
    draft.password = Some("correct horse battery staple".to_string());

    let script = create_command(&draft).expect("a valid draft");

    assert!(script.contains(r"-c 'Release operator'\''s account'"));
    assert!(script.starts_with("set -e\nuseradd "));
    assert!(script.contains(r#"-G 'docker,wheel' 'deploy'"#));
    assert!(script.contains("chpasswd <<'SrvBoxUserPassword'"));
    assert!(script.contains("deploy:correct horse battery staple"));
}

#[test]
fn a_draft_without_a_password_builds_one_command() {
    let mut with_home = draft("deploy");
    with_home.home = "/srv/deploy".to_string();
    assert_eq!(
        create_command(&with_home).expect("a valid draft"),
        "useradd -m -d '/srv/deploy' 'deploy'"
    );

    assert_eq!(
        create_command(&draft("deploy")).expect("a valid draft"),
        "useradd -m 'deploy'"
    );

    let mut system = draft("deploy");
    system.system = true;
    system.create_home = false;
    assert_eq!(
        create_command(&system).expect("a valid draft"),
        "useradd -r -M 'deploy'"
    );
}

#[test]
fn edits_only_fields_that_changed() {
    let original = SystemUser {
        name: "deploy".to_string(),
        uid: 1001,
        gid: 1000,
        comment: "Deploy".to_string(),
        home: "/home/deploy".to_string(),
        shell: "/bin/sh".to_string(),
        primary_group: Some("users".to_string()),
        supplementary_groups: vec!["docker".to_string()],
    };
    let mut draft = draft("deploy");
    draft.comment = "Deploy".to_string();
    draft.home = "/srv/deploy".to_string();
    draft.shell = "/bin/bash".to_string();
    draft.primary_group = "users".to_string();
    draft.supplementary_groups = vec!["docker".to_string()];
    draft.move_home = true;

    assert_eq!(
        edit_command(&original, &draft).expect("a valid draft"),
        "usermod -d '/srv/deploy' -m -s '/bin/bash' 'deploy'"
    );
}

/// A password with nothing else changed: `:` keeps the script `set -e` was
/// handed a command to run.
#[test]
fn a_password_alone_is_a_no_op_command_and_the_password() {
    let original = user("deploy", "/home/deploy");
    let mut draft = draft("deploy");
    draft.shell = original.shell.clone();
    draft.primary_group = "users".to_string();
    draft.password = Some("hunter2".to_string());

    let script = edit_command(&original, &draft).expect("a valid draft");
    assert!(script.starts_with("set -e\n:\nchpasswd"));
    assert!(script.contains("deploy:hunter2"));
}

#[test]
fn a_rename_is_refused() {
    let original = user("deploy", "/home/deploy");
    let mut draft = draft("deploy2");
    draft.password = Some("hunter2".to_string());

    assert_eq!(edit_command(&original, &draft), Err(UserError::Renaming));
}

#[test]
fn rejects_unsafe_names_and_root_deletion() {
    let unsafe_draft = draft("bad;touch /tmp/pwned");
    assert_eq!(create_command(&unsafe_draft), Err(UserError::InvalidName));
    assert!(!valid_name("bad;touch /tmp/pwned"));
    assert!(!valid_name(""));
    assert!(!valid_name("Deploy"));
    assert!(valid_name("deploy"));
    assert!(valid_name("_svc"));
    assert!(valid_name("box$"));

    let mut root = user("root", "/root");
    root.uid = 0;
    assert_eq!(
        delete_command(&root, false),
        Err(UserError::RootNotDeletable)
    );

    assert_eq!(
        delete_command(&user("deploy", "/home/deploy"), true).expect("a valid name"),
        "userdel -r 'deploy'"
    );
}

/// A password with a line break in it would be a second `name:password` pair
/// and a second account's password changed.
#[test]
fn a_password_with_a_line_break_is_refused() {
    for password in ["a\nb", "a\rb", "a\0b"] {
        let mut draft = draft("deploy");
        draft.password = Some(password.to_string());
        assert_eq!(
            create_command(&draft),
            Err(UserError::PasswordLineBreak),
            "{password:?}"
        );
    }
}

#[test]
fn a_field_with_a_line_break_is_refused() {
    let mut comment = draft("deploy");
    comment.comment = "a\nb".to_string();
    assert_eq!(create_command(&comment), Err(UserError::LineBreak));

    let mut groups = draft("deploy");
    groups.supplementary_groups = vec!["wheel; rm -rf /".to_string()];
    assert_eq!(
        create_command(&groups),
        Err(UserError::InvalidSupplementaryGroup)
    );

    let mut primary = draft("deploy");
    primary.primary_group = "not a group".to_string();
    assert_eq!(create_command(&primary), Err(UserError::InvalidPrimaryGroup));
}
