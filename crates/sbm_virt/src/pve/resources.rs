//! Reading PVE API answers into [`crate::model`]. Pure functions, tested
//! against captured payloads.
//!
//! Ported from the app's `lib/data/model/virt/pve_resources.dart`. Lenient: a
//! field missing from one entry (a guest being created has no name yet, an
//! offline node no figures) costs that field, not the whole listing.

use std::collections::{BTreeMap, BTreeSet};

use serde_json::Value;

use crate::model::{Guest, GuestKind, GuestState, Node, PowerAction};
use crate::rates::CounterSample;

/// `/cluster/resources` read: the nodes, the guests (templates included,
/// marked), and each guest's counters.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Resources {
    pub nodes: Vec<Node>,
    pub guests: Vec<Guest>,
    pub samples: BTreeMap<String, CounterSample>,
}

/// `/cluster/resources` at `at` (Unix ms). Storages, SDN zones and anything
/// else that is not a node or a guest are skipped.
pub fn parse(raw: &[Value], at: i64) -> Resources {
    let mut out = Resources::default();
    for e in raw {
        let Some(e) = e.as_object() else { continue };
        match e.get("type").and_then(Value::as_str) {
            Some("node") => {
                let Some(name) = str_of(e.get("node")) else { continue };
                out.nodes.push(Node {
                    name,
                    online: e.get("status").and_then(Value::as_str) == Some("online"),
                    cpu: double(e.get("cpu")),
                    max_cpu: int(e.get("maxcpu")).and_then(|v| u32::try_from(v).ok()),
                    mem_used: uint(e.get("mem")),
                    mem_total: uint(e.get("maxmem")),
                    uptime: duration(e.get("uptime")),
                });
            }
            Some(kind @ ("qemu" | "lxc")) => {
                let vmid = int(e.get("vmid")).and_then(|v| u32::try_from(v).ok());
                let Some(id) = str_of(e.get("id")).or_else(|| vmid.map(|v| format!("{kind}/{v}"))) else {
                    continue;
                };
                let kind = if kind == "lxc" { GuestKind::Lxc } else { GuestKind::Qemu };
                let status = str_of(e.get("status"));
                let lock = str_of(e.get("lock"));
                let template = int(e.get("template")) == Some(1);
                let state = state_of(status.as_deref(), lock.as_deref());
                let state_reason = lock.clone().or_else(|| status.clone().filter(|s| s != state.as_str()));
                out.guests.push(Guest {
                    id: id.clone(),
                    name: str_of(e.get("name")).unwrap_or_else(|| vmid.map_or(id.clone(), |v| v.to_string())),
                    kind,
                    state,
                    state_reason,
                    vmid,
                    node: str_of(e.get("node")),
                    vcpu: int(e.get("maxcpu")).and_then(|v| u32::try_from(v).ok()),
                    mem_bytes: uint(e.get("maxmem")),
                    uptime: duration(e.get("uptime")),
                    tags: tags(e.get("tags")),
                    template,
                    autostart: None,
                    actions: if template {
                        BTreeSet::new()
                    } else {
                        actions_of(status.as_deref(), lock.as_deref(), kind, state)
                    },
                });
                // What runs, whatever holds the lock: a VM being backed up is
                // still running, and its counters still count.
                let active = state_of(status.as_deref(), None).is_active();
                let when_active = |v: Option<u64>| if active { v } else { None };
                let cpu = double(e.get("cpu"));
                out.samples.insert(
                    id,
                    CounterSample {
                        at,
                        cpu_time_ns: None,
                        cpu_percent: if active { cpu.map(|c| c * 100.0) } else { None },
                        vcpus: int(e.get("maxcpu")).and_then(|v| u32::try_from(v).ok()),
                        mem_used: when_active(uint(e.get("mem"))),
                        mem_total: uint(e.get("maxmem")),
                        // QEMU reports 0 used without the guest agent; that is
                        // "not known", not an empty disk.
                        disk_used: positive(uint(e.get("disk"))),
                        disk_total: positive(uint(e.get("maxdisk"))),
                        disk_read: when_active(uint(e.get("diskread"))),
                        disk_write: when_active(uint(e.get("diskwrite"))),
                        net_in: when_active(uint(e.get("netin"))),
                        net_out: when_active(uint(e.get("netout"))),
                    },
                );
            }
            _ => {}
        }
    }
    out
}

/// What a guest with PVE's `status` and `lock` offers, `state` being
/// [`state_of`] the two.
///
/// A lock is an operation in progress (snapshot, clone, rollback, ...) that
/// PVE refuses power actions during, with two exceptions. `suspended` is a
/// hibernated VM, which `start` resumes. `backup` still lets a VM be paused
/// and resumed (`vm_suspend` and `vm_resume` skip the lock check for it, PVE
/// 9.2 `QemuServer/RunState.pm`), which is how a paused VM that a backup job
/// picked up is woken.
pub fn actions_of(status: Option<&str>, lock: Option<&str>, kind: GuestKind, state: GuestState) -> BTreeSet<PowerAction> {
    let qemu = kind == GuestKind::Qemu;
    match lock {
        None | Some("suspended") => PowerAction::offered(state, qemu, true),
        Some("backup") if qemu => match status {
            Some("running") => BTreeSet::from([PowerAction::Suspend]),
            Some("paused") => BTreeSet::from([PowerAction::Resume]),
            _ => BTreeSet::new(),
        },
        _ => BTreeSet::new(),
    }
}

/// PVE's `status` and `lock`, as one state.
///
/// `status` is the QEMU run state where `pvestatd` has one, so beside
/// `running` and `stopped` it can be `paused`, `prelaunch`, `suspended` (S3),
/// `io-error`, `internal-error`, `guest-panicked`, ... A `lock` wins where it
/// names what the guest is busy with.
pub fn state_of(status: Option<&str>, lock: Option<&str>) -> GuestState {
    match lock {
        Some("backup") => return GuestState::Backup,
        Some("migrate") => return GuestState::Migrating,
        Some("suspending") => return GuestState::Stopping,
        _ => {}
    }
    match status {
        Some("running") => GuestState::Running,
        Some("stopped") => GuestState::Stopped,
        Some("paused" | "suspended" | "io-error") => GuestState::Paused,
        Some("prelaunch" | "inmigrate") => GuestState::Starting,
        Some("shutdown") => GuestState::Stopping,
        Some("postmigrate" | "finish-migrate") => GuestState::Migrating,
        _ => GuestState::Unknown,
    }
}

pub(crate) fn tags(v: Option<&Value>) -> Vec<String> {
    let Some(raw) = v.and_then(Value::as_str) else { return Vec::new() };
    raw.split([';', ',', ' ']).map(str::trim).filter(|t| !t.is_empty()).map(str::to_owned).collect()
}

pub(crate) fn str_of(v: Option<&Value>) -> Option<String> {
    v.and_then(Value::as_str).filter(|s| !s.is_empty()).map(str::to_owned)
}

pub(crate) fn int(v: Option<&Value>) -> Option<i64> {
    match v? {
        Value::Number(n) => n.as_i64().or_else(|| n.as_f64().map(|f| f as i64)),
        Value::String(s) => s.parse().ok(),
        _ => None,
    }
}

pub(crate) fn uint(v: Option<&Value>) -> Option<u64> {
    int(v).and_then(|i| u64::try_from(i).ok())
}

pub(crate) fn double(v: Option<&Value>) -> Option<f64> {
    match v? {
        Value::Number(n) => n.as_f64(),
        Value::String(s) => s.parse().ok(),
        _ => None,
    }
}

fn positive(v: Option<u64>) -> Option<u64> {
    v.filter(|v| *v > 0)
}

fn duration(v: Option<&Value>) -> Option<u64> {
    int(v).filter(|s| *s > 0).map(|s| s as u64)
}
