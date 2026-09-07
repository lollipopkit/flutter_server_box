//! Pending package updates, one manager at a time.
//!
//! The bodies are real output from each manager, kept verbatim including the
//! notices and column headers they print around the rows — those are exactly
//! what a parser written against a tidied-up sample gets wrong.

use sbm_parser::pkg::{parse_pkg, PkgUpdates};

fn of(raw: &str) -> PkgUpdates {
    parse_pkg(raw)
}

// ------------------------------------------------------------------- apt

/// Three shapes in one answer: an ordinary upgrade, a security one, and a
/// package being pulled in as a new dependency, which apt prints with no
/// installed version at all.
const APT: &str = r#"mgr=apt
age=93600
NOTE: This is only a simulation!
      apt-get needs root privileges for real execution.
      Keep also in mind that locking is deactivated,
      so don't depend on the relevance to the real current situation!
Reading package lists...
Building dependency tree...
Reading state information...
Calculating upgrade...
The following NEW packages will be installed:
  linux-image-6.1.0-18-amd64
The following packages will be upgraded:
  base-files libssl3 openssl
3 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
Inst base-files [12.4+deb12u5] (12.4+deb12u6 Debian:12.6/stable [amd64])
Conf base-files (12.4+deb12u6 Debian:12.6/stable [amd64])
Inst libssl3 [3.0.11-1~deb12u2] (3.0.13-1~deb12u1 Debian-Security:12/stable-security [amd64])
Inst openssl [3.0.11-1~deb12u2] (3.0.13-1~deb12u1 Debian-Security:12/stable-security [amd64])
Inst linux-image-6.1.0-18-amd64 (6.1.76-1 Debian:12.6/stable [amd64])
Conf libssl3 (3.0.13-1~deb12u1 Debian-Security:12/stable-security [amd64])
"#;

#[test]
fn apt_reads_inst_lines_and_skips_conf() {
    let r = of(APT);

    assert_eq!(r.manager, "apt");
    assert_eq!(r.total(), 4, "Conf lines name the same packages again");
    assert_eq!(r.index_age_secs, Some(93600));

    let names: Vec<&str> = r.items.iter().map(|i| i.name.as_str()).collect();
    assert_eq!(
        names,
        ["base-files", "libssl3", "openssl", "linux-image-6.1.0-18-amd64"]
    );

    let ssl = &r.items[1];
    assert_eq!(ssl.from.as_deref(), Some("3.0.11-1~deb12u2"));
    assert_eq!(ssl.to, "3.0.13-1~deb12u1");
    assert_eq!(ssl.repo.as_deref(), Some("Debian-Security:12/stable-security"));
    assert!(ssl.security);

    assert!(!r.items[0].security, "Debian:12.6/stable is not security");
}

/// A package with no installed version is a new dependency, not a broken line.
#[test]
fn apt_new_dependency_has_no_from() {
    let r = of(APT);
    let new = r.items.iter().find(|i| i.name.starts_with("linux-image")).unwrap();

    assert_eq!(new.from, None);
    assert_eq!(new.to, "6.1.76-1");
}

#[test]
fn apt_counts_security_separately() {
    assert_eq!(of(APT).security, Some(2));
}

/// Nothing to do is an answer, and it has to be told apart from a manager
/// that could not be read.
#[test]
fn apt_with_nothing_pending_is_supported_and_empty() {
    let r = of("mgr=apt\nage=120\n0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.\n");

    assert!(r.supported());
    assert_eq!(r.total(), 0);
    assert_eq!(r.security, Some(0));
}

/// A package present in two archives: apt prints both origins in the
/// parenthesis, and the whole thing is the archive name.
#[test]
fn apt_multiple_origins_are_kept_together() {
    let r = of(
        "mgr=apt\nInst tzdata [2024a-0] (2024b-0 Debian:12.6/stable, Debian-Security:12/stable-security [all])\n",
    );

    assert_eq!(
        r.items[0].repo.as_deref(),
        Some("Debian:12.6/stable, Debian-Security:12/stable-security")
    );
    assert!(r.items[0].security);
}

// ------------------------------------------------------------------- dnf

const DNF: &str = r#"mgr=dnf
age=3600

kernel-core.x86_64                  5.14.0-427.13.1.el9_4       baseos
openssl.x86_64                      1:3.0.7-27.el9_4            baseos
openssl-libs.x86_64                 1:3.0.7-27.el9_4            baseos

Obsoleting Packages
grub2-tools.x86_64                  1:2.06-80.el9               baseos
"#;

#[test]
fn dnf_reads_three_columns_and_stops_at_obsoleting() {
    let r = of(DNF);

    assert_eq!(r.manager, "dnf");
    assert_eq!(r.total(), 3, "the obsoleting section is not an update");

    let k = &r.items[0];
    assert_eq!(k.name, "kernel-core", "the arch suffix is not part of the name");
    assert_eq!(k.to, "5.14.0-427.13.1.el9_4");
    assert_eq!(k.repo.as_deref(), Some("baseos"));
    // dnf's check-update does not print what is installed.
    assert_eq!(k.from, None);
}

/// Saying "0 security updates" here would be a reassurance nothing checked:
/// dnf's repository names do not distinguish one, and the plugin that does
/// needs the network.
#[test]
fn dnf_does_not_claim_to_know_about_security() {
    assert_eq!(of(DNF).security, None);
}

// ---------------------------------------------------------------- zypper

const ZYPPER: &str = r#"mgr=zypper
age=7200
S  | Repository                    | Name     | Current Version | Available Version | Arch
---+-------------------------------+----------+-----------------+-------------------+-------
v  | Update Repository (Non-Oss)   | vim      | 9.0.1234-1.1    | 9.1.0100-1.1      | x86_64
v  | openSUSE-Leap-15.5-Security   | openssl  | 3.0.8-1.1       | 3.0.13-1.1        | x86_64
"#;

#[test]
fn zypper_reads_the_table_under_the_rule() {
    let r = of(ZYPPER);

    assert_eq!(r.total(), 2);
    assert_eq!(r.items[0].name, "vim");
    assert_eq!(r.items[0].from.as_deref(), Some("9.0.1234-1.1"));
    assert_eq!(r.items[0].to, "9.1.0100-1.1");
    assert!(!r.items[0].security);
    assert!(r.items[1].security, "the repository names it");
    assert_eq!(r.security, Some(1));
}

// ---------------------------------------------------------------- pacman

#[test]
fn pacman_reads_the_arrow_form() {
    let r = of("mgr=pacman\nage=600\nlinux 6.7.4.arch1-1 -> 6.7.6.arch1-1\nopenssl 3.2.1-1 -> 3.2.1-2 [ignored]\n");

    assert_eq!(r.total(), 2);
    assert_eq!(r.items[0].from.as_deref(), Some("6.7.4.arch1-1"));
    assert_eq!(r.items[0].to, "6.7.6.arch1-1");
    // Held by IgnorePkg, which is still an available update.
    assert_eq!(r.items[1].name, "openssl");
    assert_eq!(r.security, None);
}

// ------------------------------------------------------------------- apk

/// The whole difficulty is splitting the name from the version: both can
/// contain dashes, and the rule is that the version is the last two
/// dash-separated components.
#[test]
fn apk_splits_a_name_that_contains_dashes() {
    let r = of(
        "mgr=apk\nage=86400\nInstalled:                  Available:\nbusybox-1.36.1-r19        < 1.36.1-r29\nca-certificates-bundle-20240226-r0 < 20241010-r0\n",
    );

    assert_eq!(r.total(), 2);
    assert_eq!(r.items[0].name, "busybox");
    assert_eq!(r.items[0].from.as_deref(), Some("1.36.1-r19"));
    assert_eq!(r.items[0].to, "1.36.1-r29");
    assert_eq!(r.items[1].name, "ca-certificates-bundle");
    assert_eq!(r.items[1].from.as_deref(), Some("20240226-r0"));
}

/// Alpine names no archive, so nothing is marked — and the count is an honest
/// zero rather than a guess.
#[test]
fn apk_reports_zero_security_rather_than_unknown() {
    let r = of("mgr=apk\nbusybox-1.36.1-r19 < 1.36.1-r29\n");
    assert_eq!(r.security, Some(0));
}

// ------------------------------------------------------------- freebsd pkg

#[test]
fn freebsd_pkg_reads_the_index_note() {
    let r = of(
        "mgr=pkg\nage=1800\ncurl-8.4.0                         <   needs updating (index has 8.5.0)\npkg-1.20.8                         <   needs updating (index has 1.21.0)\n",
    );

    assert_eq!(r.total(), 2);
    assert_eq!(r.items[0].name, "curl");
    assert_eq!(r.items[0].from.as_deref(), Some("8.4.0"));
    assert_eq!(r.items[0].to, "8.5.0");
}

// ------------------------------------------------------------------ brew

#[test]
fn brew_takes_the_last_installed_version() {
    let r = of("mgr=brew\nopenssl@3 (3.0.11) < 3.0.13\nnode (20.10.0, 20.11.0) < 21.5.0\n");

    assert_eq!(r.total(), 2);
    assert_eq!(r.items[0].name, "openssl@3");
    assert_eq!(r.items[0].from.as_deref(), Some("3.0.11"));
    // Several installed at once; an upgrade replaces the newest.
    assert_eq!(r.items[1].name, "node");
    assert_eq!(r.items[1].from.as_deref(), Some("20.11.0"));
    assert_eq!(r.items[1].to, "21.5.0");
}

// ------------------------------------------------------------------ shape

/// A server with no manager this build knows is a different thing from one
/// with nothing to upgrade, and the app draws them differently.
#[test]
fn no_manager_is_unsupported_rather_than_empty() {
    let r = of("mgr=none\n");

    assert!(!r.supported());
    assert_eq!(r.total(), 0);
    assert_eq!(r.security, None);
    assert_eq!(r.index_age_secs, None);
}

/// Nothing at all — a command that failed, a segment that did not arrive.
#[test]
fn an_empty_segment_is_unsupported() {
    assert!(!of("").supported());
}

/// A stale index is the answer that matters most: "0 updates" off a cache
/// nobody has refreshed since March is true about what apt knows and false
/// about the machine.
#[test]
fn a_missing_index_age_is_none_not_zero() {
    let r = of("mgr=apt\nInst a [1] (2 Debian:12/stable [amd64])\n");
    assert_eq!(r.index_age_secs, None);
}

/// A clock that moved backwards between the index being written and this
/// being asked. Dropped rather than clamped, which would read as "just
/// refreshed" — the most misleading value available.
#[test]
fn a_negative_index_age_is_dropped() {
    assert_eq!(of("mgr=apt\nage=-500\n").index_age_secs, None);
}

/// Every parser has to survive a manager adding a notice, a warning or a
/// column header in a future release.
#[test]
fn unparseable_lines_cost_a_line_rather_than_the_reading() {
    let r = of("mgr=apt\nage=1\nW: Some warning\nInst a [1] (2 Debian:12/stable [amd64])\n???\n");

    assert_eq!(r.total(), 1);
    assert_eq!(r.items[0].name, "a");
}
