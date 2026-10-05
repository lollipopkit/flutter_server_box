//! Changes to a firewall, planned: what the app's firewall page asked before a
//! change and ran after (`test/widget/firewall_page_test.dart`), now the plan
//! both it and the agent's panel follow.

use sbm_parser::firewall::change::*;
use sbm_parser::firewall::firewalld::{self, FirewalldItem, FirewalldInputIssue, FirewalldTarget};
use sbm_parser::firewall::ufw::{self, UfwAction, UfwChain, UfwDirection, UfwPolicy, UfwRuleDraft};
use sbm_parser::firewall::{FirewallAccess, FirewallAccessVia, FirewallReach};

const FIXTURES: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/");

fn fixture(name: &str) -> String {
    std::fs::read_to_string(format!("{FIXTURES}{name}")).unwrap()
}

/// SSH from 192.0.2.1 to port 22, arriving on eth0.
fn ssh() -> Vec<FirewallAccess> {
    vec![FirewallAccess {
        via: FirewallAccessVia::Ssh,
        port: 22,
        client: Some("192.0.2.1".into()),
        server: Some("198.51.100.2".into()),
        iface: Some("eth0".into()),
    }]
}

mod ufw_plans {
    use super::*;

    fn active() -> ufw::UfwSnapshot {
        ufw::parse(&fixture("ufw/active.txt")).unwrap()
    }

    #[test]
    fn turning_it_on_without_the_ssh_rule_counts_down_and_keeps_ssh_in_first() {
        // Inactive, and with the rule that let 22 in gone.
        let readout: String = fixture("ufw/inactive_no_ipv6.txt").lines().filter(|l| !l.contains(" tcp 22 ")).map(|l| format!("{l}\n")).collect();
        let s = ufw::parse(&readout).unwrap();
        let plan = ufw_plan(&s, &UfwChange::Enable, &ssh()).unwrap();
        assert!(plan.confirm && plan.destructive && plan.countdown);
        assert_eq!(plan.warnings().count(), 1);
        assert_eq!(plan.keep_open, [ufw::allow_tcp_command(22)]);
        assert!(plan.keep_open_default);
        assert_eq!(plan.script_commands(true), [ufw::allow_tcp_command(22), ufw::ENABLE_COMMAND.into()]);
        assert_eq!(plan.script_commands(false), [ufw::ENABLE_COMMAND]);
    }

    #[test]
    fn turning_it_off_asks_and_warns_of_nothing() {
        let plan = ufw_plan(&active(), &UfwChange::Disable, &ssh()).unwrap();
        assert!(plan.confirm && plan.destructive && !plan.countdown);
        assert_eq!(plan.commands, [ufw::DISABLE_COMMAND]);
        assert!(plan.keep_open.is_empty());
    }

    #[test]
    fn deleting_the_rule_that_lets_ssh_in_warns() {
        let s = active();
        let rule = s.rules.iter().find(|r| r.to.port.as_deref() == Some("22")).unwrap();
        let plan = ufw_plan(&s, &UfwChange::DeleteRule { tuples: rule.tuples.clone() }, &ssh()).unwrap();
        assert!(plan.countdown);
        let warning = plan.warnings().next().unwrap();
        assert_eq!((warning.before, warning.after), (FirewallReach::Open, FirewallReach::Blocked));
        assert_eq!(plan.commands, ufw::delete_commands(rule));
    }

    #[test]
    fn deleting_another_rule_asks_but_warns_of_nothing() {
        let s = active();
        let rule = s.rules.iter().find(|r| r.from.address.as_deref() == Some("203.0.113.9")).unwrap();
        let plan = ufw_plan(&s, &UfwChange::DeleteRule { tuples: rule.tuples.clone() }, &ssh()).unwrap();
        assert!(plan.confirm && plan.destructive);
        assert_eq!(plan.warnings().count(), 0);
        assert_eq!(ufw_plan(&s, &UfwChange::DeleteRule { tuples: vec!["gone".into()] }, &ssh()), Err(ChangeError::NoSuchRule));
    }

    #[test]
    fn a_rule_that_only_lets_something_in_is_added_at_once() {
        let draft = UfwRuleDraft { protocol: Some("tcp".into()), port: "8443".into(), ..UfwRuleDraft::new(UfwAction::Allow, UfwDirection::Incoming) };
        let plan = ufw_plan(&active(), &UfwChange::AddRule { draft }, &ssh()).unwrap();
        assert!(!plan.confirm);
        assert_eq!(plan.commands, ["ufw allow in proto tcp from any to any port 8443"]);
    }

    #[test]
    fn a_deny_put_first_on_the_ssh_port_asks() {
        let draft = UfwRuleDraft {
            protocol: Some("tcp".into()),
            port: "20:30".into(),
            prepend: true,
            ..UfwRuleDraft::new(UfwAction::Deny, UfwDirection::Incoming)
        };
        let plan = ufw_plan(&active(), &UfwChange::AddRule { draft: draft.clone() }, &ssh()).unwrap();
        assert!(plan.confirm && plan.destructive && plan.countdown);
        // Put last, it comes after the rule that already lets 22 in.
        let last = UfwRuleDraft { prepend: false, ..draft };
        assert!(!ufw_plan(&active(), &UfwChange::AddRule { draft: last }, &ssh()).unwrap().confirm);
    }

    #[test]
    fn a_draft_ufw_would_refuse_is_refused_before_a_plan() {
        let draft = UfwRuleDraft::new(UfwAction::Allow, UfwDirection::Incoming);
        assert_eq!(ufw_plan(&active(), &UfwChange::AddRule { draft }, &ssh()), Err(ChangeError::Draft(ufw::UfwDraftIssue::NothingMatched)));
    }

    #[test]
    fn a_policy_already_set_changes_nothing() {
        let s = active();
        let same = UfwChange::Policy { chain: UfwChain::Incoming, policy: UfwPolicy::Deny };
        assert_eq!(ufw_plan(&s, &same, &ssh()), Err(ChangeError::Unchanged));
        let allow = ufw_plan(&s, &UfwChange::Policy { chain: UfwChain::Incoming, policy: UfwPolicy::Allow }, &ssh()).unwrap();
        assert!(allow.confirm && !allow.destructive);
        // Only the incoming chain decides what reaches the server.
        let out = ufw_plan(&s, &UfwChange::Policy { chain: UfwChain::Outgoing, policy: UfwPolicy::Deny }, &ssh()).unwrap();
        assert!(out.effects.is_empty() && out.destructive);
    }

    #[test]
    fn reload_and_logging_run_at_once() {
        assert!(!ufw_plan(&active(), &UfwChange::Reload, &ssh()).unwrap().confirm);
        assert!(!ufw_plan(&active(), &UfwChange::Logging { level: ufw::UfwLogLevel::Off }, &ssh()).unwrap().confirm);
    }
}

mod firewalld_plans {
    use super::*;

    fn running() -> firewalld::FirewalldSnapshot {
        firewalld::parse(&fixture("firewalld/running.txt")).unwrap()
    }

    fn remove(zone: &str, item: FirewalldItem, value: &str) -> FirewalldChange {
        FirewalldChange::Remove { zone: zone.into(), item, value: value.into() }
    }

    fn add(zone: &str, item: FirewalldItem, value: &str) -> FirewalldChange {
        FirewalldChange::Add { zone: zone.into(), item, value: value.into() }
    }

    #[test]
    fn removing_ssh_from_this_zone_warns_now_and_after_a_reload_and_keeps_it_in_first() {
        let plan = firewalld_plan(&running(), &remove("internal", FirewalldItem::Service, "ssh"), &ssh()).unwrap();
        assert!(plan.confirm && plan.destructive && plan.countdown);
        let later: Vec<bool> = plan.warnings().map(|e| e.later).collect();
        assert_eq!(later, [false, true]);
        let keep = r#"firewall-cmd --permanent --zone='internal' --add-rich-rule='rule priority="-32768" port port="22" protocol="tcp" accept'"#;
        assert!(plan.keep_open.iter().any(|c| c == keep), "{:?}", plan.keep_open);
        let script = plan.script_commands(true);
        let k = script.iter().position(|c| c == keep).unwrap();
        let r = script.iter().position(|c| c == "firewall-cmd --permanent --zone='internal' --remove-service='ssh'").unwrap();
        assert!(k < r);
    }

    #[test]
    fn a_port_or_a_service_is_added_at_once_to_both_configurations() {
        let plan = firewalld_plan(&running(), &add("internal", FirewalldItem::Port, " 8443/tcp "), &ssh()).unwrap();
        assert!(!plan.confirm);
        assert_eq!(
            plan.commands,
            ["firewall-cmd --zone='internal' --add-port='8443/tcp'", "firewall-cmd --permanent --zone='internal' --add-port='8443/tcp'"]
        );
        assert!(!firewalld_plan(&running(), &add("internal", FirewalldItem::Service, "http"), &ssh()).unwrap().confirm);
    }

    #[test]
    fn what_is_typed_is_checked_and_a_zone_must_exist() {
        let s = running();
        assert_eq!(firewalld_plan(&s, &add("internal", FirewalldItem::Port, "22"), &ssh()), Err(ChangeError::Input(FirewalldInputIssue::InvalidPort)));
        assert_eq!(firewalld_plan(&s, &add("internal", FirewalldItem::Source, "host.example"), &ssh()), Err(ChangeError::Input(FirewalldInputIssue::InvalidSource)));
        assert_eq!(firewalld_plan(&s, &add("internal", FirewalldItem::RichRule, "drop"), &ssh()), Err(ChangeError::Input(FirewalldInputIssue::InvalidRichRule)));
        assert_eq!(
            firewalld_plan(&s, &FirewalldChange::ChangeInterface { zone: "internal".into(), iface: "eth0; reboot".into() }, &ssh()),
            Err(ChangeError::Input(FirewalldInputIssue::InvalidInterface))
        );
        assert_eq!(firewalld_plan(&s, &add("nope", FirewalldItem::Service, "ssh"), &ssh()), Err(ChangeError::NoSuchZone));
    }

    #[test]
    fn moving_this_connections_interface_into_a_refusing_zone_asks() {
        // eth0 into `block`, which rejects everything.
        let plan = firewalld_plan(&running(), &FirewalldChange::ChangeInterface { zone: "block".into(), iface: "eth0".into() }, &ssh()).unwrap();
        assert!(plan.confirm && plan.countdown);
        assert!(plan.keep_open.iter().any(|c| c.contains("--zone='block'")));
        // Into a zone that lets ssh in, nothing to ask.
        let fine = firewalld_plan(&running(), &FirewalldChange::ChangeInterface { zone: "public".into(), iface: "eth0".into() }, &ssh()).unwrap();
        assert!(!fine.confirm);
    }

    #[test]
    fn a_rich_rule_refusing_this_address_asks() {
        let rule = r#"rule family="ipv4" source address="192.0.2.0/24" reject"#;
        let plan = firewalld_plan(&running(), &add("internal", FirewalldItem::RichRule, rule), &ssh()).unwrap();
        assert!(plan.confirm && plan.countdown);
    }

    #[test]
    fn a_reload_of_a_drifted_firewall_says_what_it_loses() {
        let s = running();
        let plan = firewalld_plan(&s, &FirewalldChange::Reload, &ssh()).unwrap();
        assert_eq!(plan.notes, [PlanNote::ReloadLoses]);
        assert!(plan.confirm && plan.destructive);
    }

    #[test]
    fn a_saved_configuration_without_ssh_shuts_it_at_the_next_reload() {
        let mut s = running();
        s.permanent = s.runtime.clone().unwrap();
        let a = &ssh()[0];
        // Not drifted: a reload changes nothing.
        assert!(!s.shut_by_reload(a));
        for z in &mut s.permanent {
            z.services.retain(|v| v != "ssh");
            z.ports.clear();
            z.rich_rules.clear();
            z.target = FirewalldTarget::Reject;
        }
        assert!(s.shut_by_reload(a));
    }

    #[test]
    fn a_target_is_written_down_and_reloaded() {
        let plan = firewalld_plan(&running(), &FirewalldChange::Target { zone: "internal".into(), target: FirewalldTarget::Drop }, &ssh()).unwrap();
        assert_eq!(plan.commands, firewalld::target(true, "internal", FirewalldTarget::Drop));
        assert!(plan.destructive);
        // Drop with ssh still listed lets ssh in: nothing worse.
        assert_eq!(plan.warnings().count(), 0);
    }

    #[test]
    fn the_default_zone_and_saving_the_runtime() {
        let s = running();
        assert_eq!(firewalld_plan(&s, &FirewalldChange::DefaultZone { zone: "public".into() }, &ssh()), Err(ChangeError::Unchanged));
        let plan = firewalld_plan(&s, &FirewalldChange::DefaultZone { zone: "drop".into() }, &ssh()).unwrap();
        assert_eq!(plan.commands, ["firewall-cmd --set-default-zone='drop'"]);
        let save = firewalld_plan(&s, &FirewalldChange::RuntimeToPermanent, &ssh()).unwrap();
        assert!(save.confirm && !save.destructive && save.keep_open.is_empty());
        let stopped = firewalld::parse(&fixture("firewalld/stopped.txt")).unwrap();
        assert_eq!(firewalld_plan(&stopped, &FirewalldChange::RuntimeToPermanent, &ssh()), Err(ChangeError::Unchanged));
    }

    #[test]
    fn starting_it_is_judged_by_what_is_written_down() {
        let stopped = firewalld::parse(&fixture("firewalld/stopped.txt")).unwrap();
        let plan = firewalld_plan(&stopped, &FirewalldChange::Start, &ssh()).unwrap();
        assert_eq!(plan.commands, [firewalld::START_COMMAND]);
        assert!(plan.effects.iter().all(|e| e.before == FirewallReach::Open));
        // Keep-open rules for a firewall that is not running go through the
        // offline tool.
        assert!(plan.keep_open.iter().all(|c| c.starts_with("firewall-offline-cmd ")));
    }
}
