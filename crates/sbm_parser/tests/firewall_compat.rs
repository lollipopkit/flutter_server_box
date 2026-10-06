//! Firewalls, ported with the app's Dart fixtures
//! (`test/unit/server/firewall_test.dart`, `ufw_manager_test.dart`,
//! `firewalld_manager_test.dart`) before the Dart copy went. The captures are
//! `tests/fixtures/{ufw,firewalld}/`.

use std::net::IpAddr;

use sbm_parser::firewall::firewalld::{self, *};
use sbm_parser::firewall::ufw::{self, *};
use sbm_parser::firewall::*;

const FIXTURES: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/");

fn fixture(name: &str) -> String {
    std::fs::read_to_string(format!("{FIXTURES}{name}")).unwrap()
}

fn ip(s: &str) -> IpAddr {
    s.parse().unwrap()
}

fn access(port: u16, client: Option<&str>) -> FirewallAccess {
    FirewallAccess { via: FirewallAccessVia::Ssh, port, client: client.map(str::to_owned), server: None, iface: None }
}

mod common {
    use super::*;

    #[test]
    fn ssh_connection_reads_the_server_port_not_the_one_dialled() {
        let a = FirewallAccess::from_ssh_connection("203.0.113.5 51234 10.0.0.2 22").unwrap();
        assert_eq!(a.via, FirewallAccessVia::Ssh);
        assert_eq!(a.port, 22);
        assert_eq!(a.client.as_deref(), Some("203.0.113.5"));
        assert_eq!(a.server.as_deref(), Some("10.0.0.2"));
    }

    #[test]
    fn ssh_connection_takes_ipv6_with_a_zone() {
        let a = FirewallAccess::from_ssh_connection("fe80::1%eth0 51234 fe80::2%eth0 2222").unwrap();
        assert_eq!(a.port, 2222);
        assert!(ip(a.client.as_deref().unwrap()).is_ipv6());
    }

    #[test]
    fn ssh_connection_is_nothing_for_what_is_not_one() {
        for v in ["", "a b c d", "1.1.1.1 1 2.2.2.2 0", "1.1.1.1 1 2.2.2.2 70000"] {
            assert_eq!(FirewallAccess::from_ssh_connection(v), None, "{v}");
        }
    }

    #[test]
    fn network_contains_networks_and_single_addresses() {
        let v4 = ip("192.168.1.77");
        let v6 = ip("2001:db8::5");
        for (net, a, want) in [
            ("192.168.1.0/24", v4, true),
            ("192.168.0.0/23", v4, true),
            ("192.168.2.0/24", v4, false),
            ("192.168.1.77", v4, true),
            ("0.0.0.0/0", v4, true),
            ("192.168.1.64/27", v4, true),
            ("192.168.1.96/27", v4, false),
            ("2001:db8::/32", v6, true),
            ("2001:db9::/32", v6, false),
            // Never across families.
            ("0.0.0.0/0", v6, false),
            ("::/0", v4, false),
        ] {
            assert_eq!(network_contains(net, a), Some(want), "{net} {a}");
        }
        for net in ["example.com", "10.0.0.0/40", "ipset:foo"] {
            assert_eq!(network_contains(net, v4), None, "{net}");
        }
    }

    #[test]
    fn port_spec_covers_reads_both_ufw_and_firewalld_ranges() {
        assert!(port_spec_covers(None, 22));
        assert!(port_spec_covers(Some("22"), 22));
        assert!(port_spec_covers(Some("80,443"), 443));
        assert!(port_spec_covers(Some("6000:6010"), 6005));
        assert!(port_spec_covers(Some("6000-6010"), 6010));
        assert!(!port_spec_covers(Some("6000-6010"), 6011));
    }

    #[test]
    fn worst_change_says_only_what_got_worse() {
        use FirewallReach::*;
        assert_eq!(worst_change(&[(Open, Open)]), None);
        assert_eq!(worst_change(&[(Blocked, Blocked)]), None);
        assert_eq!(worst_change(&[(Open, Unknown), (Open, Blocked)]), Some(Blocked));
        assert_eq!(worst_change(&[(Open, Limited)]), Some(Limited));
    }

    #[test]
    fn probe_reads_what_is_installed_what_is_on_and_the_connection() {
        let r = parse_probe(&format!("{PROBE_UFW}yes\n{PROBE_FIREWALLD}inactive\n{PROBE_UID}1000\n{PROBE_SSH}10.9.9.9 51000 192.168.215.3 22\n{PROBE_IFACE}eth0\n"));
        assert_eq!((r.ufw, r.firewalld), (Some(true), Some(false)));
        assert!(!r.root);
        assert_eq!(r.ssh.as_ref().unwrap().port, 22);
        assert_eq!(r.ssh.as_ref().unwrap().iface.as_deref(), Some("eth0"));
        assert_eq!(parse_probe(&format!("{PROBE_UFW}yes\n{PROBE_FIREWALLD}inactive\n")).preferred(), Some(FirewallKind::Ufw));
    }

    #[test]
    fn probe_firewalld_without_systemd_answers_from_the_daemon() {
        let r = parse_probe(&format!("{PROBE_FIREWALLD}running\n{PROBE_UID}0\n{PROBE_SSH}\n"));
        assert_eq!((r.ufw, r.firewalld), (None, Some(true)));
        assert!(r.root);
        assert_eq!(r.ssh, None);
    }

    #[test]
    fn probe_prefers_the_one_that_is_on_firewalld_when_both_are() {
        let preferred = |ufw: &str, fwd: &str| parse_probe(&format!("{PROBE_UFW}{ufw}\n{PROBE_FIREWALLD}{fwd}\n")).preferred();
        assert_eq!(preferred("no", "active"), Some(FirewallKind::Firewalld));
        assert_eq!(preferred("yes", "inactive"), Some(FirewallKind::Ufw));
        assert_eq!(preferred("no", "not running"), Some(FirewallKind::Ufw));
        assert_eq!(preferred("yes", "active"), Some(FirewallKind::Firewalld));
        assert_eq!(parse_probe(&format!("{PROBE_UFW}\"yes\"\n")).ufw, Some(true));
        assert_eq!(parse_probe("").preferred(), None);
    }

    #[test]
    fn the_probe_script_never_asks_for_root() {
        assert!(PROBE_SCRIPT.starts_with(ENV));
        assert!(!PROBE_SCRIPT.contains("sudo"));
        assert!(PROBE_SCRIPT.contains(r"'SrvBoxFw.Ufw\t%s\n'"));
    }

    #[cfg(unix)]
    #[test]
    fn script_stops_at_the_first_failure_and_never_exits_2() {
        let exit = |commands: &[&str]| std::process::Command::new("sh").arg("-c").arg(script(commands)).status().unwrap().code();
        assert_eq!(exit(&["true", "exit 7", "exit 0"]), Some(7));
        assert_eq!(exit(&["true", "true"]), Some(0));
        // 2 reads as a refused sudo password.
        assert_eq!(exit(&["exit 2"]), Some(1));
    }
}

mod ufw_tests {
    use super::*;

    fn snapshot(name: &str) -> UfwSnapshot {
        ufw::parse(&fixture(&format!("ufw/{name}"))).unwrap()
    }

    fn rule<'a>(s: &'a UfwSnapshot, port: &str) -> &'a UfwRule {
        s.rules.iter().find(|r| r.to.port.as_deref() == Some(port)).unwrap()
    }

    fn draft(action: UfwAction, direction: UfwDirection) -> UfwRuleDraft {
        UfwRuleDraft::new(action, direction)
    }

    #[test]
    fn reads_status_version_policies_and_logging() {
        let s = snapshot("active.txt");
        assert_eq!(s.active, Some(true));
        assert_eq!(s.version.as_deref(), Some("0.36.2"));
        assert_eq!(s.log_level, Some(UfwLogLevel::Low));
        assert!(s.ipv6);
        assert_eq!(s.policies.get(&UfwChain::Incoming), Some(&UfwPolicy::Deny));
        assert_eq!(s.policies.get(&UfwChain::Outgoing), Some(&UfwPolicy::Allow));
        assert_eq!(s.policies.get(&UfwChain::Routed), Some(&UfwPolicy::Deny));
        assert_eq!(s.apps.iter().map(|a| a.name.as_str()).collect::<Vec<_>>(), ["My App", "OpenSSH"]);
        assert_eq!(s.apps[0].ports, [UfwAppPort { port: "8000,8001".into(), protocol: Some("tcp".into()) }]);
        assert_eq!(s.apps[1].ports[0].port, "22");
    }

    #[test]
    fn lists_a_rule_added_to_both_families_once_in_ufw_order() {
        let s = snapshot("active.txt");
        // 11 v4 tuples and 6 v6 ones, five of which repeat a v4 rule.
        assert_eq!(s.rules.len(), 12);
        assert_eq!(s.rules[0].from.address.as_deref(), Some("203.0.113.9"));
        let last = s.rules.last().unwrap();
        assert_eq!(last.from.address.as_deref(), Some("2001:db8::/32"));
        assert_eq!(last.ip_version, UfwIpVersion::V6);

        let ssh = rule(&s, "22");
        assert_eq!(ssh.ip_version, UfwIpVersion::Both);
        assert_eq!(
            ssh.tuples,
            [
                "### tuple ### allow tcp 22 0.0.0.0/0 any 0.0.0.0/0 in comment=73736820616363657373",
                "### tuple ### allow tcp 22 ::/0 any ::/0 in comment=73736820616363657373",
            ]
        );
        assert_eq!(ssh.comment.as_deref(), Some("ssh access"));
        assert_eq!(ssh.protocol.as_deref(), Some("tcp"));
        assert_eq!(ssh.to.address, None);
        assert_eq!(ssh.from, UfwEndpoint::default());
    }

    #[test]
    fn keeps_a_rule_with_an_address_in_its_own_family() {
        let s = snapshot("active.txt");
        let web = rule(&s, "80,443");
        assert_eq!(web.ip_version, UfwIpVersion::V4);
        assert_eq!(web.from.address.as_deref(), Some("192.168.1.0/24"));
        assert_eq!(web.tuples.len(), 1);
    }

    #[test]
    fn reads_direction_interfaces_logging_and_routing() {
        let s = snapshot("active.txt");
        let out = s.rules.iter().find(|r| r.direction == UfwDirection::Outgoing && r.log.is_none()).unwrap();
        assert_eq!(out.action, UfwAction::Deny);
        assert_eq!(out.to.port.as_deref(), Some("25"));
        assert_eq!(out.protocol, None);

        let reject = s.rules.iter().find(|r| r.action == UfwAction::Reject).unwrap();
        assert_eq!(reject.interface_in.as_deref(), Some("eth0"));
        assert_eq!(reject.to.port, None);

        assert_eq!(rule(&s, "53").log, Some(UfwLog::Log));
        assert_eq!(rule(&s, "22").log, None);
        assert_eq!(rule(&s, "99").log, Some(UfwLog::LogAll));
        assert_eq!(rule(&s, "99").from.port.as_deref(), Some("1234"));
        assert_eq!(rule(&s, "99").to.address.as_deref(), Some("10.0.0.1"));

        let routed = rule(&s, "8080");
        assert!(routed.routed);
        assert_eq!(routed.action, UfwAction::Allow);
        assert_eq!(routed.direction, UfwDirection::Incoming);
        assert_eq!(routed.interface_in.as_deref(), Some("eth0"));
        assert_eq!(routed.interface_out.as_deref(), Some("eth1"));
        assert_eq!(routed.to.address.as_deref(), Some("10.1.0.0/16"));
    }

    #[test]
    fn splits_an_interface_name_at_its_first_underscore_only() {
        let s = snapshot("active.txt");
        let dns = s.rules.iter().find(|r| r.to.address.as_deref() == Some("1.1.1.1")).unwrap();
        assert_eq!(dns.direction, UfwDirection::Outgoing);
        assert_eq!(dns.interface_out.as_deref(), Some("br_lan"));
        assert_eq!(dns.comment.as_deref(), Some("dns: 中文"));
    }

    #[test]
    fn reads_an_application_profile_with_its_resolved_ports() {
        let s = snapshot("active.txt");
        let app = rule(&s, "8000,8001");
        assert_eq!(app.to.app.as_deref(), Some("My App"));
        assert_eq!(app.from.app, None);
        assert_eq!(app.ip_version, UfwIpVersion::Both);
        assert_eq!(rule(&s, "2222").action, UfwAction::Limit);
    }

    #[test]
    fn lists_no_v6_rule_with_ipv6_off_and_reads_inactive() {
        let off = snapshot("inactive_no_ipv6.txt");
        assert_eq!(off.active, Some(false));
        assert!(!off.ipv6);
        assert_eq!(off.rules.len(), 11);
        assert!(off.rules.iter().all(|r| r.ip_version == UfwIpVersion::V4));
    }

    #[test]
    fn keeps_a_status_it_does_not_recognise_rather_than_guessing() {
        let odd = ufw::parse(&format!("{STATUS_MARKER}ERROR: problem running iptables\n")).unwrap();
        assert_eq!(odd.active, None);
        assert_eq!(odd.status_line.as_deref(), Some("ERROR: problem running iptables"));
        assert!(odd.rules.is_empty());
    }

    #[test]
    fn refuses_output_without_a_status_line() {
        assert!(ufw::parse("Cannot read /etc/ufw/user.rules\n").is_err());
    }

    #[test]
    fn an_unreadable_v6_file_is_an_error_while_ipv6_is_on() {
        let on = fixture("ufw/active.txt").replace("SrvBoxUfw.V6\n", "SrvBoxUfw.V6\nSrvBoxUfw.V6Unreadable\n");
        assert_eq!(ufw::parse(&on).unwrap_err(), "Cannot read /etc/ufw/user6.rules");
        // With IPv6 off ufw does not load the file, so it is not needed.
        let off = fixture("ufw/inactive_no_ipv6.txt").replace("SrvBoxUfw.V6\n", "SrvBoxUfw.V6\nSrvBoxUfw.V6Unreadable\n");
        assert_eq!(ufw::parse(&off).unwrap().rules.len(), 11);
    }

    #[cfg(unix)]
    #[test]
    fn the_status_line_skips_warnings() {
        // `ufw status` prints `WARN:` lines before the status on some hosts.
        let script = ufw::read_script().replace("ufw status 2>&1", "printf 'WARN: x\\nStatus: active\\n'");
        let out = std::process::Command::new("sh").arg("-c").arg(script.replace("[ -r /etc/ufw/user.rules ] || { echo 'Cannot read /etc/ufw/user.rules' >&2; exit 1; }", "")).output().unwrap();
        let stdout = String::from_utf8_lossy(&out.stdout);
        assert!(stdout.contains("SrvBoxUfw.Status\tStatus: active\n"), "{stdout}");
    }

    #[test]
    fn skips_a_tuple_it_cannot_read() {
        let none: [&str; 0] = [];
        assert!(merge_rules(&["### tuple ### allow tcp 22 in"], &none).is_empty());
        assert!(merge_rules(&["### tuple ### frobnicate tcp 22 0.0.0.0/0 any 0.0.0.0/0 in"], &none).is_empty());
        // Nor one whose logging is not `log` or `log-all`.
        assert!(merge_rules(&["### tuple ### allow_log-custom tcp 22 0.0.0.0/0 any 0.0.0.0/0 in"], &none).is_empty());
    }

    #[test]
    fn the_read_script_matches_what_the_fixtures_were_captured_with() {
        let script = ufw::read_script();
        assert!(script.starts_with(ENV));
        assert!(script.contains("printf 'SrvBoxUfw.Version\t%s\\n' \"$v\""));
        assert!(script.contains("grep '^### tuple ### ' /etc/ufw/user6.rules 2>/dev/null"));
        assert!(script.ends_with("exit 0\n"));
    }

    mod reach {
        use super::*;
        use FirewallReach::*;

        fn at(port: u16, client: Option<&str>) -> FirewallAccess {
            access(port, client)
        }

        #[test]
        fn the_first_rule_that_matches_decides() {
            let s = snapshot("active.txt");
            let r = |p, c| s.reach(&at(p, c), None, None, None);
            assert_eq!(r(22, Some("192.0.2.1")), Open);
            assert_eq!(r(2222, Some("192.0.2.1")), Limited);
            // Rule 1 denies 203.0.113.9 everything, before 22 is allowed.
            assert_eq!(r(22, Some("203.0.113.9")), Blocked);
            assert_eq!(r(3770, Some("192.0.2.1")), Blocked);
            // An app profile's ports, as ufw resolved them.
            assert_eq!(r(8001, Some("192.0.2.1")), Open);
        }

        #[test]
        fn an_address_bound_rule_decides_only_for_its_address() {
            let s = snapshot("active.txt");
            let r = |p, c| s.reach(&at(p, c), None, None, None);
            assert_eq!(r(443, Some("192.168.1.20")), Open);
            assert_eq!(r(443, Some("192.0.2.1")), Blocked);
            // Unknown where it is from: the rule may or may not be for it.
            assert_eq!(r(443, None), Unknown);
            // A v6 rule says nothing of a v4 connection.
            assert_eq!(r(5000, Some("192.0.2.1")), Blocked);
            assert_eq!(r(5000, Some("2001:db8::9")), Open);
        }

        #[test]
        fn rule_1_may_be_the_one_for_an_address_not_known() {
            let s = snapshot("active.txt");
            assert_eq!(s.reach(&at(22, None), None, None, None), Unknown);
        }

        #[test]
        fn an_interface_that_cannot_be_seen_makes_it_unknown() {
            let s = snapshot("active.txt");
            // 22 is allowed before `reject in on eth0 from 10.0.0.5` is
            // reached; 2222's limit comes after it, and eth0 may or may not
            // be the way in.
            assert_eq!(s.reach(&at(22, Some("10.0.0.5")), None, None, None), Open);
            assert_eq!(s.reach(&at(2222, Some("10.0.0.5")), None, None, None), Unknown);
        }

        #[test]
        fn outgoing_routed_and_udp_rules_do_not_count() {
            let s = snapshot("active.txt");
            for port in [25, 8080, 53] {
                assert_eq!(s.reach(&at(port, Some("192.0.2.1")), None, None, None), Blocked, "{port}");
            }
        }

        #[test]
        fn a_change_is_judged_before_it_is_made() {
            let s = snapshot("active.txt");
            let a = at(22, Some("192.0.2.1"));
            let rules: Vec<UfwRule> = s.rules.iter().filter(|r| r.to.port.as_deref() != Some("22")).cloned().collect();
            assert_eq!(s.reach(&a, None, Some(&rules), None), Blocked);
            assert_eq!(s.reach(&a, None, Some(&rules), Some(UfwPolicy::Allow)), Open);
            let off = snapshot("inactive_no_ipv6.txt");
            assert_eq!(off.reach(&a, None, None, None), Open);
            assert_eq!(off.reach(&a, Some(true), None, None), Open);
            assert_eq!(off.reach(&a, Some(true), Some(&[]), None), Blocked);
        }

        #[test]
        fn what_could_not_be_read_is_not_taken_as_open() {
            let mut s = snapshot("active.txt");
            let a = at(3770, Some("192.0.2.1"));
            // A status other than active or inactive: the rules still decide.
            s.active = None;
            assert_eq!(s.reach(&a, None, None, None), Blocked);
            // No incoming policy read: neither way.
            s.policies.clear();
            assert_eq!(s.reach(&a, None, None, None), Unknown);
        }

        #[test]
        fn ufw_leaves_ipv6_alone_with_it_off() {
            let off = snapshot("inactive_no_ipv6.txt");
            assert_eq!(off.reach(&at(3770, Some("2001:db8::9")), Some(true), None, None), Open);
        }

        #[test]
        fn a_draft_becomes_the_rules_ufw_would_add() {
            let s = snapshot("active.txt");
            let a = at(22, Some("192.0.2.1"));
            let reach = |d: &UfwRuleDraft, prepend: bool, a: &FirewallAccess| s.reach(a, None, Some(&s.with_rules(&d.as_rules(&s.apps), prepend)), None);
            let deny = UfwRuleDraft { protocol: Some("tcp".into()), port: "20:30".into(), ..draft(UfwAction::Deny, UfwDirection::Incoming) };
            assert_eq!(reach(&deny, true, &a), Blocked);
            // Last, it comes after the rule that already let 22 in.
            assert_eq!(reach(&deny, false, &a), Open);
            let app = UfwRuleDraft { app: Some("OpenSSH".into()), ..draft(UfwAction::Reject, UfwDirection::Incoming) };
            assert_eq!(reach(&app, true, &a), Blocked);
            // From one network only: blocked if it is this one.
            let from_one = UfwRuleDraft { from: "192.0.2.0/24".into(), prepend: true, ..draft(UfwAction::Deny, UfwDirection::Incoming) };
            assert_eq!(reach(&from_one, true, &a), Blocked);
            assert_eq!(reach(&from_one, true, &at(22, Some("198.51.100.1"))), Open);
        }
    }

    mod commands {
        use super::*;

        #[test]
        fn add_quotes_what_was_typed_and_puts_proto_before_from() {
            let d = UfwRuleDraft {
                protocol: Some("tcp".into()),
                port: "80,443".into(),
                from: "192.168.1.0/24".into(),
                interface_in: "br_lan".into(),
                comment: r#"web $(id) "x""#.into(),
                prepend: true,
                ..draft(UfwAction::Allow, UfwDirection::Incoming)
            };
            assert_eq!(
                add_command(&d).unwrap(),
                r#"ufw prepend allow in on 'br_lan' proto tcp from '192.168.1.0/24' to any port 80,443 comment 'web $(id) "x"'"#
            );
        }

        #[test]
        fn add_names_an_application_profile_without_a_protocol() {
            let d = UfwRuleDraft { protocol: Some("tcp".into()), app: Some("My App".into()), ..draft(UfwAction::Limit, UfwDirection::Incoming) };
            assert_eq!(add_command(&d).unwrap(), "ufw limit in from any to any app 'My App'");
        }

        #[test]
        fn add_refuses_what_validation_refuses_a_protocol_ufw_does_not_take_included() {
            assert_eq!(add_command(&draft(UfwAction::Allow, UfwDirection::Incoming)), Err(UfwDraftIssue::NothingMatched));
            let d = UfwRuleDraft { protocol: Some("tcp; reboot".into()), port: "22".into(), ..draft(UfwAction::Allow, UfwDirection::Incoming) };
            assert_eq!(add_command(&d), Err(UfwDraftIssue::InvalidProtocol));
            let gre = UfwRuleDraft { protocol: Some("gre".into()), from: "10.0.0.0/8".into(), ..draft(UfwAction::Allow, UfwDirection::Incoming) };
            assert_eq!(add_command(&gre).unwrap(), "ufw allow in proto gre from '10.0.0.0/8' to any");
        }

        #[test]
        fn delete_finds_every_tuple_of_the_rule_by_its_text() {
            let s = snapshot("active.txt");
            let ssh = rule(&s, "22");
            let commands = delete_commands(ssh);
            let assigns: Vec<&String> = commands.iter().filter(|c| c.starts_with("t=")).collect();
            assert_eq!(assigns, [&format!("t='{}'", ssh.tuples[0]), &format!("t='{}'", ssh.tuples[1])]);
            assert_eq!(commands.iter().filter(|c| *c == r#"ufw --force delete "$n""#).count(), 2);
            // Never 2, which reads as sudo refusing the password.
            assert!(commands.join("\n").contains("exit 3"));
        }

        #[test]
        fn a_routed_rule_names_each_interface_it_has_and_none_it_lacks() {
            let both = UfwRuleDraft {
                routed: true,
                protocol: Some("tcp".into()),
                port: "8080".into(),
                to: "10.1.0.0/16".into(),
                interface_in: "eth0".into(),
                interface_out: "eth1".into(),
                prepend: true,
                ..draft(UfwAction::Allow, UfwDirection::Incoming)
            };
            assert_eq!(add_command(&both).unwrap(), "ufw route prepend allow in on 'eth0' out on 'eth1' proto tcp from any to '10.1.0.0/16' port 8080");
            let out = UfwRuleDraft { routed: true, from: "10.0.0.0/8".into(), interface_out: "eth1".into(), ..draft(UfwAction::Deny, UfwDirection::Incoming) };
            assert_eq!(add_command(&out).unwrap(), "ufw route deny out on 'eth1' from '10.0.0.0/8' to any");
        }

        #[test]
        fn an_outgoing_rule_reads_its_outgoing_interface_only() {
            let d = UfwRuleDraft {
                protocol: Some("udp".into()),
                port: "53".into(),
                source_port: "1024:65535".into(),
                interface_in: "eth0".into(),
                interface_out: "wg0".into(),
                log: Some(UfwLog::LogAll),
                ..draft(UfwAction::Allow, UfwDirection::Outgoing)
            };
            assert_eq!(add_command(&d).unwrap(), "ufw allow out on 'wg0' log-all proto udp from any port 1024:65535 to any port 53");
        }

        #[test]
        fn policy_and_logging_use_ufw_words() {
            assert_eq!(policy_command(UfwChain::Incoming, UfwPolicy::Deny), "ufw default deny incoming");
            assert_eq!(policy_command(UfwChain::Routed, UfwPolicy::Reject), "ufw default reject routed");
            assert_eq!(logging_command(UfwLogLevel::Off), "ufw logging off");
        }

        #[test]
        fn the_rule_that_keeps_this_app_in_goes_first() {
            assert_eq!(allow_tcp_command(22), "ufw prepend allow in proto tcp from any to any port 22");
        }
    }

    mod validate {
        use super::*;
        use UfwDraftIssue::*;

        #[derive(Default)]
        struct Check {
            port: &'static str,
            protocol: Option<&'static str>,
            app: Option<&'static str>,
            from: &'static str,
            to: &'static str,
            source_port: &'static str,
            interface: &'static str,
            comment: &'static str,
            routed: bool,
        }

        fn check(c: Check) -> Option<UfwDraftIssue> {
            validate_draft(&UfwRuleDraft {
                port: c.port.into(),
                protocol: c.protocol.map(Into::into),
                app: c.app.map(Into::into),
                from: c.from.into(),
                to: c.to.into(),
                source_port: c.source_port.into(),
                interface_in: c.interface.into(),
                interface_out: c.interface.into(),
                routed: c.routed,
                comment: c.comment.into(),
                ..draft(UfwAction::Allow, UfwDirection::Incoming)
            })
        }

        #[test]
        fn accepts_what_ufw_accepts() {
            assert_eq!(check(Check { port: "22", ..Default::default() }), None);
            assert_eq!(check(Check { port: "22", protocol: Some("udp"), ..Default::default() }), None);
            assert_eq!(check(Check { port: "1,2,3:5", protocol: Some("tcp"), ..Default::default() }), None);
            assert_eq!(check(Check { app: Some("OpenSSH"), ..Default::default() }), None);
            assert_eq!(check(Check { from: "10.0.0.0/8", ..Default::default() }), None);
            assert_eq!(check(Check { from: "2001:db8::/32", to: "2001:db8::1", ..Default::default() }), None);
            assert_eq!(check(Check { port: "22", interface: "br_lan", comment: "é \"x\"", ..Default::default() }), None);
        }

        #[test]
        fn a_rule_must_match_something() {
            assert_eq!(check(Check::default()), Some(NothingMatched));
            assert_eq!(check(Check { routed: true, ..Default::default() }), Some(NothingMatched));
            // All of an interface's traffic is something.
            assert_eq!(check(Check { interface: "eth0", ..Default::default() }), None);
            assert_eq!(check(Check { interface: "eth0", routed: true, ..Default::default() }), None);
        }

        #[test]
        fn a_source_port_is_checked_as_a_port() {
            assert_eq!(check(Check { source_port: "53", ..Default::default() }), None);
            assert_eq!(check(Check { source_port: "53,54", ..Default::default() }), Some(PortsNeedProtocol));
            assert_eq!(check(Check { source_port: "70000", ..Default::default() }), Some(InvalidPort));
            // No protocol is written beside a profile, so none makes a list
            // valid.
            assert_eq!(check(Check { app: Some("My App"), source_port: "53,54", protocol: Some("tcp"), ..Default::default() }), Some(PortsNeedProtocol));
            assert_eq!(check(Check { app: Some("My App"), source_port: "53", protocol: Some("tcp"), ..Default::default() }), None);
        }

        #[test]
        fn ports() {
            let tcp = Some("tcp");
            assert_eq!(check(Check { port: "0", ..Default::default() }), Some(InvalidPort));
            assert_eq!(check(Check { port: "65536", ..Default::default() }), Some(InvalidPort));
            assert_eq!(check(Check { port: "30:20", protocol: tcp, ..Default::default() }), Some(InvalidPort));
            assert_eq!(check(Check { port: "22,", protocol: tcp, ..Default::default() }), Some(InvalidPort));
            assert_eq!(check(Check { port: "ssh", ..Default::default() }), Some(InvalidPort));
            // Digits of another script are not ports.
            assert_eq!(check(Check { port: "٢٢", ..Default::default() }), Some(InvalidPort));
            assert_eq!(check(Check { port: "22:30", ..Default::default() }), Some(PortsNeedProtocol));
            assert_eq!(check(Check { port: "80,443", ..Default::default() }), Some(PortsNeedProtocol));
            // A range counts as two of iptables' fifteen.
            let fifteen: &'static str = Box::leak(format!("{},20:30", (1..=13).map(|i| i.to_string()).collect::<Vec<_>>().join(",")).into_boxed_str());
            assert_eq!(check(Check { port: fifteen, protocol: tcp, ..Default::default() }), None);
            let sixteen: &'static str = Box::leak(format!("{},14,20:30", (1..=13).map(|i| i.to_string()).collect::<Vec<_>>().join(",")).into_boxed_str());
            assert_eq!(check(Check { port: sixteen, protocol: tcp, ..Default::default() }), Some(TooManyPorts));
        }

        #[test]
        fn addresses() {
            assert_eq!(check(Check { from: "example.com", ..Default::default() }), Some(InvalidAddress));
            assert_eq!(check(Check { from: "10.0.0.0/33", ..Default::default() }), Some(InvalidAddress));
            assert_eq!(check(Check { from: "10.0.0.0/8", to: "2001:db8::1", ..Default::default() }), Some(MixedIpVersions));
        }

        #[test]
        fn interface_and_comment() {
            assert_eq!(check(Check { port: "22", interface: "eth0; reboot", ..Default::default() }), Some(InvalidInterface));
            assert_eq!(check(Check { port: "22", comment: "it's", ..Default::default() }), Some(InvalidComment));
            assert_eq!(check(Check { port: "22", comment: "a\nb", ..Default::default() }), Some(InvalidComment));
        }
    }
}

mod firewalld_tests {
    use super::*;
    use FirewallReach::*;

    fn running() -> FirewalldSnapshot {
        firewalld::parse(&fixture("firewalld/running.txt")).unwrap()
    }

    fn port(p: &str, proto: &str) -> FirewalldPort {
        FirewalldPort { port: p.into(), protocol: proto.into() }
    }

    fn ports(zone: &FirewalldZone) -> Vec<String> {
        zone.ports.iter().map(|p| p.to_string()).collect()
    }

    fn ssh(client: Option<&str>, p: u16) -> FirewallAccess {
        access(p, client)
    }

    /// `access` arriving on `iface`.
    fn on(access: FirewallAccess, iface: Option<&str>) -> FirewallAccess {
        FirewallAccess { iface: iface.map(str::to_owned), ..access }
    }

    #[test]
    fn reads_the_daemon_both_configurations_and_the_policies() {
        let r = running();
        assert!(r.running);
        assert_eq!(r.version.as_deref(), Some("1.3.4"));
        assert_eq!(r.default_zone.as_deref(), Some("public"));
        assert!(!r.panic);
        assert!(r.runtime.is_some());
        let names: Vec<&str> = r.zones().iter().map(|z| z.name.as_str()).collect();
        for zone in ["block", "drop", "internal", "public", "trusted"] {
            assert!(names.contains(&zone), "{zone}");
        }
        assert_eq!(r.policies.len(), 1);
        assert_eq!(r.policies[0].name, "allow-host-ipv6");
        // ICMPv6 only: it decides nothing about a TCP connection.
        assert!(!r.policies[0].decides);
    }

    #[test]
    fn reads_a_zone_whole() {
        let r = running();
        let public = r.zone("public", false).unwrap();
        assert_eq!(public.target, FirewalldTarget::DefaultTarget);
        assert!(!public.active);
        assert_eq!(public.services, ["cockpit", "dhcpv6-client", "http", "ssh"]);
        for p in ["8080/tcp", "6000-6010/udp", "7777/tcp"] {
            assert!(ports(public).contains(&p.to_owned()), "{p}");
        }
        assert!(public.masquerade);
        assert_eq!(public.forward_ports, ["port=80:proto=tcp:toport=8080:toaddr="]);
        assert_eq!(public.rich_rules.len(), 2);

        let internal = r.zone("internal", false).unwrap();
        assert!(internal.active);
        assert_eq!(internal.interfaces, ["eth0"]);
        assert_eq!(r.zone("trusted", false).unwrap().target, FirewalldTarget::Accept);
        assert_eq!(r.zone("trusted", false).unwrap().sources, ["10.8.0.0/24"]);
        assert_eq!(r.zone("block", false).unwrap().target, FirewalldTarget::Reject);
    }

    #[test]
    fn runtime_and_permanent_are_read_apart_and_differ() {
        let r = running();
        // 7777 was added to the runtime only, 5555 written down only.
        let runtime = ports(r.zone("public", false).unwrap());
        let saved = ports(r.zone("public", true).unwrap());
        assert!(runtime.contains(&"7777/tcp".into()) && !runtime.contains(&"5555/tcp".into()));
        assert!(saved.contains(&"5555/tcp".into()) && !saved.contains(&"7777/tcp".into()));
        assert!(r.drifted());
    }

    #[test]
    fn reads_rich_rules_as_far_as_they_decide_anything() {
        let r = running();
        let [drop, reject] = &r.zone("public", false).unwrap().rich_rules[..] else { panic!() };
        assert_eq!(drop.priority, -10);
        assert_eq!(drop.family.as_deref(), Some("ipv4"));
        assert_eq!(drop.source.as_deref(), Some("198.51.100.7"));
        assert_eq!(drop.element, None);
        assert_eq!(drop.action.as_deref(), Some("drop"));
        assert_eq!(reject.priority, 0);
        assert_eq!(reject.source.as_deref(), Some("203.0.113.0/24"));
        assert_eq!(reject.element.as_deref(), Some("service"));
        assert_eq!(reject.service.as_deref(), Some("ssh"));
        assert_eq!(reject.action.as_deref(), Some("reject"));

        let odd = FirewalldRichRule::parse(
            r#"rule family="ipv4" source not address="10.0.0.0/8" port port="22" protocol="tcp" log prefix="ssh in" level="info" accept limit value="3/m""#,
        );
        assert!(odd.source_not);
        assert_eq!(odd.port.as_deref(), Some("22"));
        assert_eq!(odd.protocol.as_deref(), Some("tcp"));
        assert_eq!(odd.action.as_deref(), Some("accept"));
        assert!(odd.limited);
    }

    #[test]
    fn services_carry_their_ports_etc_over_usr_lib_with_includes() {
        let r = running();
        assert_eq!(r.services["ssh"], [port("22", "tcp")]);
        assert_eq!(r.services["myapp"], [port("9000", "tcp"), port("9001-9002", "udp")]);
        // Its own port, and RH-Satellite-6's, and foreman's through that.
        let capsule = &r.services["RH-Satellite-6-capsule"];
        assert!(capsule.contains(&port("8443", "tcp")));
        assert!(capsule.contains(&port("5000", "tcp")));
        for name in ["ssh", "http", "myapp"] {
            assert!(r.service_names.contains(&name.to_owned()), "{name}");
        }
    }

    #[test]
    fn a_later_file_of_the_same_name_replaces_the_earlier() {
        let services = parse_services(&[
            r#"/etc/firewalld/services/ssh.xml:<port protocol="tcp" port="2222"/>"#,
            r#"/usr/lib/firewalld/services/ssh.xml:<port protocol="tcp" port="22"/>"#,
        ]);
        assert_eq!(services["ssh"], [port("2222", "tcp")]);
    }

    #[test]
    fn stopped_only_what_is_written_down_through_the_offline_tool() {
        let stopped = firewalld::parse(&fixture("firewalld/stopped.txt")).unwrap();
        assert!(!stopped.running);
        assert_eq!(stopped.runtime, None);
        assert!(!stopped.drifted());
        // A zone written down and not loaded yet is drift too.
        let mut r = running();
        let runtime = r.zone("public", true).cloned().map(|z| vec![z]).unwrap();
        r.permanent = runtime.clone();
        r.runtime = Some(runtime);
        r.runtime.as_mut().unwrap()[0].ports = r.permanent[0].ports.clone();
        assert!(!r.drifted());
        let mut extra = r.permanent[0].clone();
        extra.name = "added".into();
        r.permanent.push(extra);
        assert!(r.drifted());
        assert!(ports(stopped.zone("public", false).unwrap()).contains(&"5555/tcp".into()));
        assert_eq!(stopped.reach(&on(ssh(Some("203.0.113.5"), 22), None), None, None, None, None), Open);
    }

    #[test]
    fn a_zone_is_active_by_its_flags_never_by_its_name() {
        let zones = parse_zones(&[
            "inactive",
            "  target: default",
            "myactive",
            "  target: default",
            "public (default, active)",
            "  target: default",
            "internal (active)",
            "  target: default",
        ]);
        let active: Vec<(&str, bool)> = zones.iter().map(|z| (z.name.as_str(), z.active)).collect();
        assert_eq!(active, [("inactive", false), ("myactive", false), ("public", true), ("internal", true)]);
    }

    #[test]
    fn refuses_output_with_no_zones_section() {
        assert!(firewalld::parse("SrvBoxFwd.Version\t1\n").is_err());
    }

    #[test]
    fn a_listing_that_failed_is_an_error_not_an_empty_one() {
        let out = fixture("firewalld/running.txt").replace("SrvBoxFwd.Policies\n", "SrvBoxFwd.Policies\nSrvBoxFwd.Incomplete\n");
        assert!(firewalld::parse(&out).is_err());
        // Listings that exited 0 and named no zone were cut short.
        assert!(firewalld::parse("SrvBoxFwd.Permanent\n").is_err());
        assert!(firewalld::parse("SrvBoxFwd.Running\nSrvBoxFwd.Runtime\nSrvBoxFwd.Permanent\npublic\n  target: default\n").is_err());
        assert!(firewalld::read_script().contains("firewall-cmd --list-all-policies 2>/dev/null || echo SrvBoxFwd.Incomplete\n"));
    }

    #[test]
    fn a_source_zone_wins_over_the_interface() {
        // trusted (ACCEPT) holds 10.8.0.0/24.
        assert_eq!(running().reach(&on(ssh(Some("10.8.0.5"), 3770), Some("eth0")), None, None, None, None), Open);
    }

    #[test]
    fn the_interfaces_zone_and_its_services() {
        // internal has eth0 and ssh.
        let r = running();
        assert_eq!(r.reach(&on(ssh(Some("192.0.2.1"), 22), Some("eth0")), None, None, None, None), Open);
        assert_eq!(r.reach(&on(ssh(Some("192.0.2.1"), 3770), Some("eth0")), None, None, None, None), Blocked);
    }

    #[test]
    fn the_default_zone_and_its_rich_rules_in_priority_order() {
        // public: priority -10 drops 198.51.100.7; 203.0.113.0/24 is refused
        // ssh at 0, before the ssh service lets anyone else in.
        let r = running();
        let reach = |c, p| r.reach(&on(ssh(Some(c), p), Some("eth9")), None, None, None, None);
        assert_eq!(reach("192.0.2.1", 22), Open);
        assert_eq!(reach("203.0.113.5", 22), Blocked);
        assert_eq!(reach("198.51.100.7", 8080), Blocked);
        assert_eq!(reach("192.0.2.1", 7777), Open);
    }

    #[test]
    fn what_cannot_be_known_is_said_to_be_unknown() {
        // No address, no interface: public's address-bound refusals may apply.
        assert_eq!(running().reach(&on(ssh(None, 22), None), None, None, None, None), Unknown);
    }

    #[test]
    fn a_change_is_judged_before_it_is_made() {
        let r = running();
        let a = ssh(Some("192.0.2.1"), 22);
        let zones: Vec<FirewalldZone> = r
            .zones()
            .iter()
            .map(|z| {
                let mut z = z.clone();
                if z.name == "internal" {
                    z.services.retain(|s| s != "ssh");
                }
                z
            })
            .collect();
        assert_eq!(r.reach(&on(a.clone(), Some("eth0")), None, None, Some(&zones), None), Blocked);
        assert_eq!(r.reach(&on(a.clone(), Some("eth0")), None, Some(true), None, None), Blocked);
        assert_eq!(r.reach(&on(a.clone(), Some("eth0")), Some(false), None, None, None), Open);
    }

    #[test]
    fn a_forwarded_port_sends_the_connection_elsewhere() {
        let r = running();
        let mut zone = r.zone("public", false).unwrap().clone();
        zone.forward_ports = vec!["port=22:proto=tcp:toport=2222:toaddr=".into()];
        assert_eq!(zone.reach(&ssh(Some("192.0.2.1"), 22), &r.services), Unknown);
    }

    #[test]
    fn a_policy_for_the_host_may_decide_what_a_zone_let_in() {
        let mut r = running();
        r.policies = vec![FirewalldPolicy { name: "p".into(), target: "REJECT".into(), egress_host: true, decides: true }];
        assert_eq!(r.reach(&on(ssh(Some("192.0.2.1"), 22), Some("eth0")), None, None, None, None), Unknown);
    }

    #[test]
    fn the_zones_a_connection_may_be_in() {
        let r = running();
        let names = |a: &FirewallAccess, i: Option<&str>| r.zones_for(&on(a.clone(), i), None, None).into_iter().map(|z| z.name).collect::<Vec<_>>();
        assert_eq!(names(&ssh(Some("10.8.0.5"), 22), Some("eth0")), ["trusted"]);
        assert_eq!(names(&ssh(Some("192.0.2.1"), 22), Some("eth0")), ["internal"]);
        assert_eq!(names(&ssh(Some("192.0.2.1"), 22), Some("eth9")), ["public"]);
        // Not knowing the address: the source zone may be the one too.
        assert!(names(&ssh(None, 22), Some("eth0")).contains(&"trusted".to_owned()));
    }

    #[test]
    fn a_change_goes_to_both_configurations_while_running() {
        assert_eq!(
            item_commands(true, "public", FirewalldItem::Port, &port("22", "tcp").to_string(), true),
            ["firewall-cmd --zone='public' --add-port='22/tcp'", "firewall-cmd --permanent --zone='public' --add-port='22/tcp'"]
        );
        assert_eq!(item_commands(false, "public", FirewalldItem::Service, "ssh", false), ["firewall-offline-cmd --zone='public' --remove-service='ssh'"]);
    }

    #[test]
    fn a_rich_rule_is_one_quoted_word() {
        assert_eq!(
            item_commands(true, "public", FirewalldItem::RichRule, r#"rule family="ipv4" source address="1.2.3.4" drop"#, false)[0],
            r#"firewall-cmd --zone='public' --remove-rich-rule='rule family="ipv4" source address="1.2.3.4" drop'"#
        );
    }

    #[test]
    fn a_target_is_written_down_and_reloaded() {
        assert_eq!(
            target(true, "work", FirewalldTarget::Reject),
            ["firewall-cmd --permanent --zone='work' --set-target='%%REJECT%%'", firewalld::RELOAD_COMMAND]
        );
        assert_eq!(target(false, "work", FirewalldTarget::Accept), ["firewall-offline-cmd --zone='work' --set-target='ACCEPT'"]);
    }

    #[test]
    fn the_rest_of_the_commands() {
        assert_eq!(keep_open_rule(22), r#"rule priority="-32768" port port="22" protocol="tcp" accept"#);
        assert_eq!(change_interface(false, "internal", "eth0"), ["firewall-offline-cmd --zone='internal' --change-interface='eth0'"]);
        assert_eq!(remove_interface(false, "internal", "eth0"), ["firewall-offline-cmd --zone='internal' --remove-interface='eth0'"]);
        assert_eq!(masquerade(false, "public", true), ["firewall-offline-cmd --zone='public' --add-masquerade"]);
        assert_eq!(default_zone(true, "home"), "firewall-cmd --set-default-zone='home'");
    }

    #[test]
    fn the_read_script_matches_what_the_fixtures_were_captured_with() {
        let script = firewalld::read_script();
        assert!(script.starts_with(ENV));
        assert!(script.contains("  printf 'SrvBoxFwd.Version\t%s\\n' \"$(firewall-cmd --version 2>/dev/null)\"\n"));
        assert!(script.contains(
            "grep -H -o -E '<(port|include) [^>]*>' $(for d in /usr/lib/firewalld/services /etc/firewalld/services; do ls -d \"$d\"/*.xml 2>/dev/null; done) 2>/dev/null\n"
        ));
        assert!(script.ends_with("exit 0\n"));
    }

    #[test]
    fn input_ports() {
        assert_eq!(parse_port("22/tcp"), Some(port("22", "tcp")));
        assert_eq!(parse_port(" 6000-6010/udp "), Some(port("6000-6010", "udp")));
        for bad in ["22", "0/tcp", "20-10/tcp", "22/icmp"] {
            assert_eq!(parse_port(bad), None, "{bad}");
        }
    }

    #[test]
    fn input_sources() {
        for ok in ["10.0.0.0/8", "2001:db8::/32", "ipset:blocklist", "00:11:22:33:44:55"] {
            assert_eq!(check_source(ok), None, "{ok}");
        }
        for bad in ["10.0.0.0/33", "host.example"] {
            assert_eq!(check_source(bad), Some(FirewalldInputIssue::InvalidSource), "{bad}");
        }
    }

    #[test]
    fn input_interfaces_rich_rules_and_forwarded_ports() {
        assert_eq!(check_interface("br_lan"), None);
        assert_eq!(check_interface("eth0; reboot"), Some(FirewalldInputIssue::InvalidInterface));
        assert_eq!(check_rich_rule("rule drop"), None);
        assert_eq!(check_rich_rule("drop"), Some(FirewalldInputIssue::InvalidRichRule));
        assert_eq!(check_rich_rule("rule drop\nreboot"), Some(FirewalldInputIssue::InvalidRichRule));
        assert_eq!(check_forward_port("port=80:proto=tcp:toport=8080"), None);
        assert_eq!(check_forward_port("port=80:proto=tcp:toaddr=192.168.1.2"), None);
        assert_eq!(check_forward_port("port=80:proto=tcp"), Some(FirewalldInputIssue::InvalidForwardPort));
    }
}
