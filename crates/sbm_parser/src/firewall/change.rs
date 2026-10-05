//! A change to a firewall, planned before it is made: the commands it runs,
//! what it does to each way the caller reaches the server, and the rules that
//! would keep a way open that it shuts.
//!
//! The app's firewall page and the agent's panel both run a change through a
//! [`Plan`], so what one asks before it shuts a connection is what the other
//! asks. A plan is made from the firewall as just read; the agent makes it
//! again from a fresh read when the change is confirmed, so a plan the client
//! was shown never decides what runs.

use super::firewalld::{self, FirewalldItem, FirewalldInputIssue, FirewalldSnapshot, FirewalldTarget, FirewalldZone};
use super::ufw::{self, UfwChain, UfwDraftIssue, UfwLogLevel, UfwPolicy, UfwRule, UfwRuleDraft, UfwSnapshot};
use super::{FirewallAccess, FirewallReach};

/// A change to ufw.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum UfwChange {
    Enable,
    Disable,
    Reload,
    Policy { chain: UfwChain, policy: UfwPolicy },
    Logging { level: UfwLogLevel },
    AddRule { draft: UfwRuleDraft },
    /// The rule read with these tuple lines.
    DeleteRule { tuples: Vec<String> },
}

/// A change to firewalld. Values are as typed: they are checked here.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum FirewalldChange {
    Start,
    Stop,
    Reload,
    /// The runtime written down as it is.
    RuntimeToPermanent,
    PanicOff,
    DefaultZone { zone: String },
    Target { zone: String, target: FirewalldTarget },
    Masquerade { zone: String, enabled: bool },
    /// A service, port, rich rule, source or forwarded port, into `zone`.
    Add { zone: String, item: FirewalldItem, value: String },
    /// One `zone` has; for a port, as firewalld writes it (`8080/tcp`).
    Remove { zone: String, item: FirewalldItem, value: String },
    /// `iface` into `zone`, out of whichever had it.
    ChangeInterface { zone: String, iface: String },
    RemoveInterface { zone: String, iface: String },
}

/// What a change does to one way in.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct Effect {
    pub access: FirewallAccess,
    pub before: FirewallReach,
    pub after: FirewallReach,
    /// About what is written down rather than what is in force: firewalld's
    /// permanent configuration, which takes over at a reload or a boot.
    pub later: bool,
    /// `after` shuts or narrows the way in: what a confirmation warns of.
    pub worse: bool,
}

/// Something a confirmation says beside the commands.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PlanNote {
    /// The runtime holds changes a reload drops.
    ReloadLoses,
}

/// A change, worked out.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct Plan {
    pub commands: Vec<String>,
    /// Every way in, before and after; [`Plan::warnings`] are the ones that
    /// got worse.
    pub effects: Vec<Effect>,
    pub notes: Vec<PlanNote>,
    /// Asked about with the red button.
    pub destructive: bool,
    /// Whether to ask before running it at all: always for some changes,
    /// otherwise only where a way in gets worse.
    pub confirm: bool,
    /// Commands that keep each way in this change shuts open, run before it
    /// when ticked; empty when it shuts none.
    pub keep_open: Vec<String>,
    /// Whether that is ticked to begin with: where a way in surely closes.
    pub keep_open_default: bool,
    /// A way in surely closes: the button counts down rather than taking a
    /// tap.
    pub countdown: bool,
}

impl Plan {
    pub fn warnings(&self) -> impl Iterator<Item = &Effect> {
        self.effects.iter().filter(|e| e.worse)
    }

    /// What runs when confirmed, with the keep-open rules or without.
    pub fn script_commands(&self, keep_open: bool) -> Vec<String> {
        let mut commands = if keep_open { self.keep_open.clone() } else { Vec::new() };
        commands.extend(self.commands.iter().cloned());
        commands
    }
}

/// Why a change cannot be planned.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(tag = "code", content = "issue", rename_all = "snake_case")]
pub enum ChangeError {
    /// It would change nothing: the policy, the zone already as asked.
    Unchanged,
    Draft(UfwDraftIssue),
    Input(FirewalldInputIssue),
    /// No rule with those tuple lines.
    NoSuchRule,
    NoSuchZone,
}

fn effects(accesses: &[FirewallAccess], before: impl Fn(&FirewallAccess) -> FirewallReach, after: impl Fn(&FirewallAccess) -> FirewallReach, later: bool) -> Vec<Effect> {
    accesses
        .iter()
        .map(|a| {
            let (before, after) = (before(a), after(a));
            Effect { access: a.clone(), before, after, later, worse: after.worse_than(before) }
        })
        .collect()
}

/// The plan for `commands` with `effects`, asked about always or only where
/// something gets worse, the keep-open rules made for the ways it shuts.
fn plan(
    commands: Vec<String>,
    effects: Vec<Effect>,
    notes: Vec<PlanNote>,
    destructive: bool,
    always_confirm: bool,
    keep_open: impl Fn(&[FirewallAccess]) -> Vec<String>,
) -> Plan {
    let worse: Vec<&Effect> = effects.iter().filter(|e| e.worse).collect();
    let mut shut: Vec<FirewallAccess> = Vec::new();
    for e in &worse {
        if !e.after.admits() && !shut.contains(&e.access) {
            shut.push(e.access.clone());
        }
    }
    let rescue = if shut.is_empty() { Vec::new() } else { keep_open(&shut) };
    let countdown = worse.iter().any(|e| e.after == FirewallReach::Blocked);
    let confirm = always_confirm || !worse.is_empty();
    Plan {
        keep_open_default: !rescue.is_empty() && countdown,
        keep_open: rescue,
        countdown,
        confirm,
        destructive: destructive || (!always_confirm && !worse.is_empty()),
        commands,
        effects,
        notes,
    }
}

// --- ufw ---------------------------------------------------------------------

/// Rules that let each of `accesses` in, put before every other rule.
fn ufw_keep_open(accesses: &[FirewallAccess]) -> Vec<String> {
    let mut ports: Vec<u16> = Vec::new();
    for a in accesses {
        if !ports.contains(&a.port) {
            ports.push(a.port);
        }
    }
    ports.into_iter().map(ufw::allow_tcp_command).collect()
}

pub fn ufw_plan(s: &UfwSnapshot, change: &UfwChange, accesses: &[FirewallAccess]) -> Result<Plan, ChangeError> {
    let now = |a: &FirewallAccess| s.reach(a, None, None, None);
    Ok(match change {
        UfwChange::Enable => {
            // Turned on, it may stop taking this caller.
            let e = effects(accesses, |a| s.reach(a, Some(false), None, None), |a| s.reach(a, Some(true), None, None), false);
            plan(vec![ufw::ENABLE_COMMAND.into()], e, vec![], true, true, ufw_keep_open)
        }
        // Turned off, the server takes everything.
        UfwChange::Disable => plan(vec![ufw::DISABLE_COMMAND.into()], vec![], vec![], true, true, ufw_keep_open),
        UfwChange::Reload => plan(vec![ufw::RELOAD_COMMAND.into()], vec![], vec![], false, false, ufw_keep_open),
        UfwChange::Logging { level } => plan(vec![ufw::logging_command(*level)], vec![], vec![], false, false, ufw_keep_open),
        UfwChange::Policy { chain, policy } => {
            if s.policies.get(chain) == Some(policy) {
                return Err(ChangeError::Unchanged);
            }
            let e = if *chain == UfwChain::Incoming {
                effects(accesses, now, |a| s.reach(a, None, None, Some(*policy)), false)
            } else {
                Vec::new()
            };
            plan(vec![ufw::policy_command(*chain, *policy)], e, vec![], *policy != UfwPolicy::Allow, true, ufw_keep_open)
        }
        UfwChange::DeleteRule { tuples } => {
            let rule = s.rules.iter().find(|r| &r.tuples == tuples).ok_or(ChangeError::NoSuchRule)?;
            let rest: Vec<UfwRule> = s.rules.iter().filter(|r| *r != rule).cloned().collect();
            let e = effects(accesses, now, |a| s.reach(a, None, Some(&rest), None), false);
            plan(ufw::delete_commands(rule), e, vec![], true, true, ufw_keep_open)
        }
        UfwChange::AddRule { draft } => {
            let command = ufw::add_command(draft).map_err(ChangeError::Draft)?;
            let rules = s.with_rules(&draft.as_rules(&s.apps), draft.prepend);
            let e = effects(accesses, now, |a| s.reach(a, None, Some(&rules), None), false);
            // One that only lets something in needs no second look.
            plan(vec![command], e, vec![], false, false, ufw_keep_open)
        }
    })
}

// --- firewalld ---------------------------------------------------------------

struct Fwd<'a> {
    s: &'a FirewalldSnapshot,
    accesses: &'a [FirewallAccess],
}

impl Fwd<'_> {
    /// What reaches `a` now, or with `zones` / `default_zone` / `running` in
    /// force instead.
    fn now(&self, a: &FirewallAccess, zones: Option<&[FirewalldZone]>, default_zone: Option<&str>, running: Option<bool>) -> FirewallReach {
        self.s.reach(a, running, None, zones, default_zone)
    }

    /// What will reach `a` once the saved configuration is in force.
    fn saved(&self, a: &FirewallAccess, zones: Option<&[FirewalldZone]>, default_zone: Option<&str>) -> FirewallReach {
        self.s.reach(a, Some(true), None, Some(zones.unwrap_or(&self.s.permanent)), default_zone)
    }

    /// What a change to the zones does to every way in, now and once saved.
    /// `runtime` and `permanent` are the zones after it.
    fn zone_effects(&self, runtime: Option<&[FirewalldZone]>, permanent: &[FirewalldZone], default_zone: Option<&str>) -> Vec<Effect> {
        let mut out = Vec::new();
        if self.s.running {
            out.extend(effects(self.accesses, |a| self.now(a, None, None, None), |a| self.now(a, runtime, default_zone, None), false));
        }
        out.extend(effects(self.accesses, |a| self.saved(a, None, None), |a| self.saved(a, Some(permanent), default_zone), true));
        out
    }

    /// Rules letting each of `shut` in to every zone it may land in among
    /// `zones`, before anything there can refuse it — into both
    /// configurations while running, so a reload keeps them.
    fn keep_open(&self, shut: &[FirewallAccess], zones: Option<&[FirewalldZone]>, default_zone: Option<&str>, running: Option<bool>) -> Vec<String> {
        let mut commands: Vec<String> = Vec::new();
        for a in shut {
            for zone in self.s.zones_for(a, zones, default_zone) {
                for c in firewalld::item_commands(running.unwrap_or(self.s.running), &zone.name, FirewalldItem::RichRule, &firewalld::keep_open_rule(a.port), true) {
                    if !commands.contains(&c) {
                        commands.push(c);
                    }
                }
            }
        }
        commands
    }

    fn reload_notes(&self) -> Vec<PlanNote> {
        if self.s.drifted() { vec![PlanNote::ReloadLoses] } else { Vec::new() }
    }

    /// `zones` with `change` made to the one named `name`.
    fn applied(zones: &[FirewalldZone], name: &str, change: impl Fn(&mut FirewalldZone)) -> Vec<FirewalldZone> {
        zones
            .iter()
            .map(|z| {
                let mut z = z.clone();
                if z.name == name {
                    change(&mut z);
                }
                z
            })
            .collect()
    }

    /// A change to the zones as `change` makes it to each list, asked about
    /// `always` or only where a way in gets worse.
    fn zone_change(&self, commands: Vec<String>, change: impl Fn(&[FirewalldZone]) -> Vec<FirewalldZone>, always: bool) -> Plan {
        let permanent = change(&self.s.permanent);
        let runtime = self.s.runtime.as_deref().map(&change);
        let e = self.zone_effects(runtime.as_deref(), &permanent, None);
        let zones = runtime.as_deref().unwrap_or(&permanent);
        plan(commands, e, vec![], always, always, |shut| self.keep_open(shut, Some(zones), None, None))
    }
}

pub fn firewalld_plan(s: &FirewalldSnapshot, change: &FirewalldChange, accesses: &[FirewallAccess]) -> Result<Plan, ChangeError> {
    let f = Fwd { s, accesses };
    let running = s.running;
    let zone_known = |zone: &str| {
        if s.zone(zone, false).is_some() || s.zone(zone, true).is_some() { Ok(()) } else { Err(ChangeError::NoSuchZone) }
    };
    let quiet = |commands: Vec<String>| plan(commands, Vec::new(), Vec::new(), false, false, |_| Vec::new());
    Ok(match change {
        FirewalldChange::Start => {
            // Started, the saved configuration is what is in force.
            let e = effects(accesses, |_| FirewallReach::Open, |a| f.now(a, Some(&s.permanent), None, Some(true)), false);
            plan(vec![firewalld::START_COMMAND.into()], e, vec![], true, true, |shut| f.keep_open(shut, Some(&s.permanent), None, Some(false)))
        }
        FirewalldChange::Stop => plan(vec![firewalld::STOP_COMMAND.into()], vec![], vec![], true, true, |_| Vec::new()),
        FirewalldChange::PanicOff => quiet(vec![firewalld::PANIC_OFF_COMMAND.into()]),
        FirewalldChange::Reload => {
            let e = f.zone_effects(Some(&s.permanent), &s.permanent, None);
            plan(vec![firewalld::RELOAD_COMMAND.into()], e, f.reload_notes(), s.drifted(), true, |shut| f.keep_open(shut, Some(&s.permanent), None, None))
        }
        FirewalldChange::RuntimeToPermanent => {
            let Some(runtime) = &s.runtime else { return Err(ChangeError::Unchanged) };
            let e = f.zone_effects(Some(runtime), runtime, None);
            plan(vec![firewalld::RUNTIME_TO_PERMANENT_COMMAND.into()], e, vec![], false, true, |_| Vec::new())
        }
        FirewalldChange::DefaultZone { zone } => {
            zone_known(zone)?;
            if s.default_zone.as_deref() == Some(zone) {
                return Err(ChangeError::Unchanged);
            }
            let e = f.zone_effects(s.runtime.as_deref(), &s.permanent, Some(zone));
            plan(vec![firewalld::default_zone(running, zone)], e, vec![], false, true, |shut| f.keep_open(shut, None, Some(zone), None))
        }
        FirewalldChange::Target { zone, target } => {
            zone_known(zone)?;
            // Written down, then reloaded: the runtime becomes the saved
            // configuration, target and all.
            let permanent = Fwd::applied(&s.permanent, zone, |z| z.target = *target);
            let e = f.zone_effects(Some(&permanent), &permanent, None);
            plan(
                firewalld::target(running, zone, *target),
                e,
                f.reload_notes(),
                *target != FirewalldTarget::Accept,
                true,
                |shut| f.keep_open(shut, Some(&permanent), None, None),
            )
        }
        FirewalldChange::Masquerade { zone, enabled } => {
            zone_known(zone)?;
            quiet(firewalld::masquerade(running, zone, *enabled))
        }
        FirewalldChange::Add { zone, item, value } => {
            zone_known(zone)?;
            let value = value.trim();
            match item {
                FirewalldItem::Service => quiet(firewalld::item_commands(running, zone, *item, value, true)),
                FirewalldItem::Port => {
                    let port = firewalld::parse_port(value).ok_or(ChangeError::Input(FirewalldInputIssue::InvalidPort))?;
                    quiet(firewalld::item_commands(running, zone, *item, &port.to_string(), true))
                }
                FirewalldItem::Source => {
                    check(firewalld::check_source(value))?;
                    let v = value.to_owned();
                    f.zone_change(firewalld::item_commands(running, zone, *item, value, true), |zs| Fwd::applied(zs, zone, |z| z.sources.push(v.clone())), false)
                }
                FirewalldItem::RichRule => {
                    check(firewalld::check_rich_rule(value))?;
                    let rule = firewalld::FirewalldRichRule::parse(value);
                    f.zone_change(firewalld::item_commands(running, zone, *item, value, true), |zs| Fwd::applied(zs, zone, |z| z.rich_rules.push(rule.clone())), false)
                }
                FirewalldItem::ForwardPort => {
                    check(firewalld::check_forward_port(value))?;
                    let v = value.to_owned();
                    f.zone_change(firewalld::item_commands(running, zone, *item, value, true), |zs| Fwd::applied(zs, zone, |z| z.forward_ports.push(v.clone())), false)
                }
            }
        }
        FirewalldChange::Remove { zone, item, value } => {
            zone_known(zone)?;
            // As the listing has it: the value is one the zone holds.
            let value = value.as_str();
            let commands = firewalld::item_commands(running, zone, *item, value, false);
            let item = *item;
            f.zone_change(
                commands,
                |zs| {
                    Fwd::applied(zs, zone, |z| match item {
                        FirewalldItem::Service => z.services.retain(|v| v != value),
                        FirewalldItem::Source => z.sources.retain(|v| v != value),
                        FirewalldItem::ForwardPort => z.forward_ports.retain(|v| v != value),
                        FirewalldItem::RichRule => z.rich_rules.retain(|r| r.raw != value),
                        FirewalldItem::Port => z.ports.retain(|p| p.to_string() != value),
                    })
                },
                true,
            )
        }
        FirewalldChange::ChangeInterface { zone, iface } => {
            zone_known(zone)?;
            check(firewalld::check_interface(iface))?;
            let iface = iface.trim();
            f.zone_change(
                firewalld::change_interface(running, zone, iface),
                |zs| {
                    zs.iter()
                        .map(|z| {
                            let mut z = z.clone();
                            z.interfaces.retain(|i| i != iface);
                            if z.name == *zone {
                                z.interfaces.push(iface.to_owned());
                            }
                            z
                        })
                        .collect()
                },
                false,
            )
        }
        FirewalldChange::RemoveInterface { zone, iface } => {
            zone_known(zone)?;
            f.zone_change(firewalld::remove_interface(running, zone, iface), |zs| Fwd::applied(zs, zone, |z| z.interfaces.retain(|i| i != iface)), true)
        }
    })
}

fn check(issue: Option<FirewalldInputIssue>) -> Result<(), ChangeError> {
    issue.map_or(Ok(()), |i| Err(ChangeError::Input(i)))
}
