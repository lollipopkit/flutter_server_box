//! A status plugin end to end: manifest, `statusCmd`, `parse`, and the checks
//! around what comes back. PLUGINS.md section 9.
//!
//! Run through [`PluginHost`] rather than an [`Instance`] because that is what
//! the app holds, and because `status_cmd`/`status_parse` are the two calls it
//! makes — a test that assembled the JSON itself would be a second encoder and
//! would not notice the first one changing.

mod support;

use std::collections::{BTreeMap, BTreeSet};

use sbm_plugin::{Manifest, Permission, Platform, PluginHost};
use sbm_plugin::status::Tone;
use support::ScriptedBridge;

/// A plugin of the shape section 9 describes: two exports, no surface.
const ZFS: &str = r#"
export function statusCmd({ platform }) {
  if (platform === 'windows') return { cmd: 'Get-Pool' };
  return { cmd: 'zpool list -Hp' };
}
export function parse({ text }) {
  const items = text.split('\n').filter(Boolean).map((line) => {
    const [name, size, alloc, health] = line.split('\t');
    return {
      label: name,
      value: `${alloc} / ${size}`,
      percent: Number(alloc) / Number(size),
      tone: health === 'ONLINE' ? 'success' : 'danger',
    };
  });
  return { title: 'ZFS', items };
}
"#;

const MANIFEST: &str = r#"{
  "id": "app.serverbox.zfs",
  "version": "1.0.0",
  "abi": 1,
  "name": "ZFS",
  "permissions": { "server.exec": true },
  "contributes": {
    "status": {
      "id": "zfs",
      "label": "ZFS",
      "default_on": true,
      "platforms": ["linux", "bsd"]
    }
  }
}"#;

fn loaded() -> (PluginHost, sbm_plugin::InstanceId) {
    let host = PluginHost::new();
    let id = host
        .load(
            ZFS.to_string(),
            sbm_plugin::InstanceOptions::new("app.serverbox.zfs", "inst-1"),
            ScriptedBridge::new(),
        )
        .expect("plugin did not load");
    (host, id)
}

#[test]
fn the_manifest_says_where_it_appears_and_on_what() {
    let m = Manifest::parse(MANIFEST.as_bytes()).unwrap();
    let status = m.contributes.status.as_ref().expect("a status contribution");
    assert_eq!(status.id, "zfs");
    assert!(status.default_on);
    assert_eq!(status.platforms, vec![Platform::Linux, Platform::Bsd]);
    // Nothing else is contributed, so nothing else is drawn.
    assert!(m.contributes.card.is_none());
    assert!(m.contributes.page.is_none());
}

/// A status plugin runs a command on the user's server. That is what
/// `server.exec` means, and requiring it here is what puts the plugin in front
/// of the user through the install dialog that already lists permissions —
/// rather than through a disclosure someone has to remember to add.
#[test]
fn a_status_contribution_must_ask_for_server_exec() {
    let without = MANIFEST.replace(r#""server.exec": true"#, r#""ui.dialog": true"#);
    let e = Manifest::parse(without.as_bytes()).unwrap_err();
    assert!(e.to_string().contains("server.exec"), "{e}");

    let m = Manifest::parse(MANIFEST.as_bytes()).unwrap();
    assert_eq!(m.requested(), vec![Permission::ServerExec]);
}

#[test]
fn a_status_contribution_must_name_a_platform() {
    let none = MANIFEST.replace(r#"["linux", "bsd"]"#, "[]");
    let e = Manifest::parse(none.as_bytes()).unwrap_err();
    assert!(e.to_string().contains("platform"), "{e}");

    let unknown = MANIFEST.replace(r#""bsd""#, r#""plan9""#);
    assert!(Manifest::parse(unknown.as_bytes()).is_err());
}

#[test]
fn it_answers_a_command_per_platform() {
    let (host, id) = loaded();
    assert_eq!(host.status_cmd(id, Platform::Linux).unwrap().cmd, "zpool list -Hp");
    assert_eq!(host.status_cmd(id, Platform::Bsd).unwrap().cmd, "zpool list -Hp");
    assert_eq!(host.status_cmd(id, Platform::Windows).unwrap().cmd, "Get-Pool");
}

#[test]
fn it_turns_what_the_command_printed_into_readings() {
    let (host, id) = loaded();
    let out = host
        .status_parse(id, "tank\t1000\t330\tONLINE\npool2\t200\t199\tDEGRADED\n")
        .unwrap();

    assert_eq!(out.title, "ZFS");
    assert_eq!(out.items.len(), 2);
    assert_eq!(out.items[0].label, "tank");
    assert_eq!(out.items[0].value, "330 / 1000");
    assert_eq!(out.items[0].percent, Some(0.33));
    assert_eq!(out.items[0].tone, Tone::Success);
    assert_eq!(out.items[1].tone, Tone::Danger);
}

/// The command's stdout is text, and text is what a plugin parses. Anything a
/// command can print has to reach `parse` unchanged, including the characters
/// that would end a JSON string if this went through one written by hand.
#[test]
fn command_output_crosses_unchanged() {
    let host = PluginHost::new();
    let id = host
        .load(
            "export function parse({ text }) { return { items: [{ label: 'raw', value: text }] }; }"
                .to_string(),
            sbm_plugin::InstanceOptions::new("t", "i"),
            ScriptedBridge::new(),
        )
        .unwrap();

    let hostile = "a\"b\\c\nd\te\u{1F600}f";
    let out = host.status_parse(id, hostile).unwrap();
    assert_eq!(out.items[0].value, hostile);
}

/// A plugin's answer is not trusted. What can be trimmed is trimmed, and only
/// a document that is not this shape at all is refused — the whole cost of a
/// bad status plugin should be a wrong row.
#[test]
fn a_plugin_that_answers_nonsense_costs_a_row_not_the_card() {
    let host = PluginHost::new();
    let id = host
        .load(
            r#"
            export function statusCmd() { return { cmd: '  ' }; }
            export function parse() {
              return { items: [
                { label: 'ok', value: 'v', percent: 4 },
                { label: '', value: '' },
                { label: 'x'.repeat(1000), value: 'v' },
              ] };
            }
            "#
            .to_string(),
            sbm_plugin::InstanceOptions::new("t", "i"),
            ScriptedBridge::new(),
        )
        .unwrap();

    // A command with nothing to run is refused: there is no wrong row to
    // salvage, only a round trip to waste on every collection.
    assert!(host.status_cmd(id, Platform::Linux).is_err());

    let out = host.status_parse(id, "").unwrap();
    assert_eq!(out.items.len(), 2, "the empty row goes, the others stay");
    assert_eq!(out.items[0].percent, None, "a percent out of range is dropped");
    assert_eq!(out.items[1].label.chars().count(), 200);
}

#[test]
fn what_it_may_do_is_still_only_what_was_consented_to() {
    let m = Manifest::parse(MANIFEST.as_bytes()).unwrap();
    // Installed, then the user revoked it. A status plugin that can no longer
    // have its command run has no grant to fall back on.
    let g = m.resolve_grants(&BTreeSet::new(), &BTreeMap::new());
    assert!(!g.allows(Permission::ServerExec));

    let consented = BTreeSet::from([Permission::ServerExec]);
    assert!(m.resolve_grants(&consented, &BTreeMap::new()).allows(Permission::ServerExec));
}
