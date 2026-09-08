//! PLUGINS.md 6.2, held to the letter.
//!
//! A plugin that calls every host function is run under each manifest, and
//! every function the manifest did not ask for must throw. What makes this
//! worth running is that it builds `sb` through the real code —
//! `bindings::install` by way of `Instance::new` — so a hand-written table
//! cannot pass for the shipped one.

mod support;

use std::collections::{BTreeMap, BTreeSet};
use std::sync::Arc;

use sbm_plugin::{
    Grants, HostFn, HostProfile, Instance, InstanceOptions, Manifest, Permission, PluginError,
};
use support::ScriptedBridge;

/// An argument each function accepts, so a refusal is never the argument's
/// fault.
///
/// The handle is `bound`, which the instance below is given, so a throw can
/// only come from the permission and never from the scope check.
fn argument(f: HostFn) -> &'static str {
    match f {
        HostFn::ServerExec => r#"{ server: "bound", script: "uptime" }"#,
        HostFn::HttpFetch => r#"{ url: "https://10.0.0.9/redfish/v1/" }"#,
        HostFn::UiPatch => r#"{ path: "/c/0", node: { t: "text" } }"#,
        HostFn::UiPrompt => r#"{ title: "2fa", fields: [] }"#,
        HostFn::UiPickServer => "undefined",
        HostFn::UiToast => r#"{ text: "hi", kind: "info" }"#,
        HostFn::StoreGet => r#"{ scope: "global", key: "k" }"#,
        HostFn::StoreSet => r#"{ scope: "global", key: "k", value: "v" }"#,
        HostFn::StoreList => r#"{ scope: "global", prefix: "" }"#,
        HostFn::DiagCrumb => r#"{ name: "power" }"#,
        HostFn::ServerList => "undefined",
        HostFn::NavOpenServer => r#"{ server: "bound" }"#,
        HostFn::NavOpenTerminal => r#"{ server: "bound", cmd: "uptime" }"#,
        HostFn::NavGoTab => r#"{ tab: "server" }"#,
        HostFn::ClipboardRead => "undefined",
        HostFn::ClipboardWrite => r#"{ text: "hi" }"#,
    }
}

/// A plugin with one export per host function.
///
/// One each rather than one export trying all fourteen: a refused call fails
/// the whole call it happened in — the host does that on purpose, so a plugin
/// cannot `catch` a refusal and carry on — so a single export would stop at the
/// first denial and say nothing about the rest.
fn probe_source() -> String {
    let mut body = String::new();
    for f in HostFn::ALL {
        body.push_str(&format!(
            "export async function {}() {{ await sb.{}.{}({}); return \"ok\"; }}\n",
            export_for(*f),
            f.namespace(),
            f.method(),
            argument(*f),
        ));
    }
    body
}

fn export_for(f: HostFn) -> String {
    format!("try_{}_{}", f.namespace(), f.method())
}

fn instance(grants: Grants, bridge: Arc<ScriptedBridge>) -> Instance {
    let mut o = InstanceOptions::new("test.plugin", "inst-1");
    o.grants = grants;
    o.bound_server = Some("bound".to_string());
    Instance::new(&probe_source(), o, bridge).expect("probe did not load")
}

/// The whole of the claim: what was granted works, what was not is refused with
/// the permission named, and the bridge never hears about the second kind.
fn assert_scope(grants: Grants, expected_ok: &[HostFn]) {
    let bridge = ScriptedBridge::new();
    // The picker answers with the handle the instance already has, so a
    // successful call cannot widen anything and change a later assertion.
    bridge.answer(HostFn::UiPickServer, r#"{"server":"bound"}"#);
    let mut p = instance(grants, Arc::clone(&bridge));

    for f in HostFn::ALL {
        let result = p.call(&export_for(*f), b"");
        if expected_ok.contains(f) {
            assert!(
                matches!(result, Ok(ref out) if out == br#""ok""#),
                "{} was granted and still failed: {result:?}",
                f.path()
            );
        } else {
            let permission = f.permission().expect("only gated ones are refused").name();
            match result {
                Err(PluginError::Denied(msg)) => {
                    assert!(
                        msg.contains("permission denied"),
                        "{}: refused, but not on the permission: {msg}",
                        f.path()
                    );
                    assert!(
                        msg.contains(permission),
                        "{}: the refusal does not name the permission: {msg}",
                        f.path()
                    );
                }
                other => panic!("{} was not granted and gave {other:?}", f.path()),
            }
        }
    }

    let reached: BTreeSet<HostFn> = bridge.funcs().into_iter().collect();
    let expected: BTreeSet<HostFn> = expected_ok.iter().copied().collect();
    assert_eq!(reached, expected, "the bridge saw a different set than ran");
}

/// A plugin cannot get past a refusal by catching it.
///
/// JavaScript has no uncatchable throw, so this is enforced by the host failing
/// the call whatever the plugin answered. Without it, a plugin denied
/// `ui.dialog` could swallow the error and carry on to the power action the
/// dialog was supposed to confirm.
#[test]
fn catching_a_refusal_does_not_let_the_call_succeed() {
    let src = r#"
      export async function go() {
        try { await sb.ui.prompt({ title: "confirm" }); }
        catch (e) { /* carry on regardless */ }
        return "went ahead";
      }
    "#;
    let mut o = InstanceOptions::new("test.plugin", "inst-1");
    o.grants = Grants::default();
    let mut p = Instance::new(src, o, ScriptedBridge::new()).unwrap();

    let e = p.call("go", b"").unwrap_err();
    let PluginError::Denied(msg) = &e else { panic!("{e:?}") };
    assert!(msg.contains("ui.dialog"), "{msg}");
}

/// And the instance is usable afterwards: one refused call is not a dead
/// plugin.
#[test]
fn a_refusal_does_not_carry_into_the_next_call() {
    let src = r#"
      export async function denied() { await sb.ui.prompt({ title: "x" }); }
      export function fine() { return 1; }
    "#;
    let mut o = InstanceOptions::new("test.plugin", "inst-1");
    o.grants = Grants::default();
    let mut p = Instance::new(src, o, ScriptedBridge::new()).unwrap();

    assert!(p.call("denied", b"").is_err());
    assert_eq!(p.call("fine", b"").unwrap(), b"1");
}

/// What 6.1 calls always granted, and therefore what every manifest gets.
fn always_granted() -> Vec<HostFn> {
    HostFn::ALL.iter().copied().filter(|f| f.permission().is_none()).collect()
}

#[test]
fn a_manifest_that_asks_for_nothing_reaches_only_what_is_always_granted() {
    assert_scope(Grants::default(), &always_granted());
}

/// `server.exec` opens two: running a command, and opening a terminal on the
/// machine so a person runs one. The second is not less than the first — it is
/// the same capability with the user watching — so they are granted together
/// rather than the terminal being free.
#[test]
fn server_exec_is_reachable_only_with_its_permission() {
    let mut expected = always_granted();
    expected.push(HostFn::ServerExec);
    expected.push(HostFn::NavOpenTerminal);
    assert_scope(Grants::new([Permission::ServerExec]), &expected);
}

/// Enumerating every server is its own permission, and deliberately not part
/// of `server.exec`: exec acts on a machine the user pointed at, and this
/// hands over the whole list with nobody choosing.
#[test]
fn server_list_is_its_own_permission() {
    let mut expected = always_granted();
    expected.push(HostFn::ServerList);
    assert_scope(Grants::new([Permission::ServerList]), &expected);
}

/// The pairing that would be easiest to get wrong: a plugin allowed to run
/// commands on the machine in front of it must not thereby learn about every
/// other machine.
#[test]
fn server_exec_does_not_imply_server_list() {
    let mut expected = always_granted();
    expected.push(HostFn::ServerExec);
    expected.push(HostFn::NavOpenTerminal);
    assert_scope(Grants::new([Permission::ServerExec]), &expected);

    let mut listing = always_granted();
    listing.push(HostFn::ServerList);
    assert_scope(Grants::new([Permission::ServerList]), &listing);
}

#[test]
fn ui_dialog_gates_the_prompt_and_nothing_else() {
    let mut expected = always_granted();
    expected.push(HostFn::UiPrompt);
    assert_scope(Grants::new([Permission::UiDialog]), &expected);
}

#[test]
fn clipboard_gates_both_directions_together() {
    let mut expected = always_granted();
    expected.push(HostFn::ClipboardRead);
    expected.push(HostFn::ClipboardWrite);
    assert_scope(Grants::new([Permission::Clipboard]), &expected);
}

/// `net.http` is the permission; the pattern list is what it covers. Granting
/// the permission with a pattern that does not match is not the same as not
/// granting it, and the two failures must stay tellable apart.
#[test]
fn net_http_with_a_matching_pattern_reaches_the_bridge() {
    let mut expected = always_granted();
    expected.push(HostFn::HttpFetch);
    let grants =
        Grants::new([Permission::NetHttp]).with_http_patterns(["10.0.0.9".to_string()]);
    assert_scope(grants, &expected);
}

#[test]
fn net_http_with_a_pattern_that_does_not_match_is_out_of_scope_not_denied() {
    let bridge = ScriptedBridge::new();
    let grants =
        Grants::new([Permission::NetHttp]).with_http_patterns(["10.0.0.10".to_string()]);
    let mut p = instance(grants, Arc::clone(&bridge));

    let e = p.call(&export_for(HostFn::HttpFetch), b"").unwrap_err();
    let PluginError::Denied(msg) = &e else { panic!("{e:?}") };
    assert!(msg.contains("out of scope"), "{msg}");
    assert!(!msg.contains("permission denied"), "{msg}");
    assert!(!bridge.funcs().contains(&HostFn::HttpFetch), "the app was asked anyway");
}

/// The all-permissions case, which is what a hand-built table would most easily
/// get right and everything else wrong.
#[test]
fn everything_granted_reaches_everything() {
    let grants = Grants::new([
        Permission::ServerExec,
        Permission::ServerStream,
        Permission::ServerList,
        Permission::NetHttp,
        Permission::UiDialog,
        Permission::Clipboard,
        Permission::StorageSync,
    ])
    .with_http_patterns(["*".to_string()]);
    assert_scope(grants, HostFn::ALL);
}

/// The claim made in PLUGINS.md 9.5, run rather than asserted about a table:
/// on the agent, a function with a user in it is a name that throws.
#[test]
fn a_ui_call_on_the_agent_throws_and_never_reaches_the_app() {
    let src = r#"
      export async function go() { await sb.ui.toast({ text: "hi", kind: "info" }); }
    "#;
    let bridge = ScriptedBridge::new();
    let mut o = InstanceOptions::new("test.plugin", "inst-1");
    o.profile = HostProfile::Agent;
    // Everything granted, so the refusal can only be the host's.
    o.grants = Grants::new(Permission::ALL.to_vec()).with_http_patterns(["*".to_string()]);
    let mut p = Instance::new(src, o, Arc::clone(&bridge) as _).unwrap();

    let e = p.call("go", b"").unwrap_err();
    let PluginError::Denied(msg) = &e else { panic!("{e:?}") };
    // Named as what it is. A permission is something the user can grant, and
    // this is not — so the two must not read the same.
    assert!(msg.contains("does not exist on the agent host"), "{msg}");
    assert!(!msg.contains("permission denied"), "{msg}");
    assert!(bridge.funcs().is_empty(), "the app was asked anyway");
}

/// And the same plugin, in the app, works. Both halves, or this proves only
/// that something threw.
#[test]
fn the_same_call_in_the_app_reaches_the_app() {
    let src = r#"
      export async function go() { await sb.ui.toast({ text: "hi", kind: "info" }); }
    "#;
    let bridge = ScriptedBridge::new();
    let mut o = InstanceOptions::new("test.plugin", "inst-1");
    o.profile = HostProfile::App;
    o.grants = Grants::default();
    let mut p = Instance::new(src, o, Arc::clone(&bridge) as _).unwrap();

    p.call("go", b"").unwrap();
    assert!(bridge.funcs().contains(&HostFn::UiToast));
}

/// What the agent *does* have still works there, and still obeys its
/// permission — the subset narrows the host, it does not widen the grants.
#[test]
fn the_agent_still_enforces_permissions_on_what_it_has() {
    let src = r#"
      export async function go() {
        await sb.http.fetch({ url: "https://10.0.0.1/redfish/v1" });
      }
    "#;
    let bridge = ScriptedBridge::new();
    let mut o = InstanceOptions::new("test.plugin", "inst-1");
    o.profile = HostProfile::Agent;
    o.grants = Grants::default();
    o.bound_server = Some("bound".to_string());
    let mut p = Instance::new(src, o, Arc::clone(&bridge) as _).unwrap();

    let e = p.call("go", b"").unwrap_err();
    let PluginError::Denied(msg) = &e else { panic!("{e:?}") };
    assert!(msg.contains("permission denied"), "{msg}");
    assert!(msg.contains("net.http"), "{msg}");
}

/// The agent has no user, so nothing that asks one a question exists there.
///
/// Asserted as a *subset* rather than as a list, so a host function added
/// later has to be thought about once — it is in the app's set by default, and
/// saying it belongs on a headless daemon is a decision somebody makes.
#[test]
fn the_agent_host_is_a_subset_of_the_app_host() {
    let agent: BTreeSet<HostFn> = HostFn::ALL
        .iter()
        .copied()
        .filter(|f| f.available_in(HostProfile::Agent))
        .collect();

    for f in HostFn::ALL {
        assert!(
            f.available_in(HostProfile::App),
            "{} is missing from the app, which has every one",
            f.path()
        );
    }

    // What it has: the network, its own storage, and its log. Not
    // `sb.server.exec` — see below.
    let names: Vec<String> = agent.iter().map(|f| f.path()).collect();
    assert_eq!(
        names,
        [
            "sb.http.fetch",
            "sb.store.get",
            "sb.store.set",
            "sb.store.list",
            "sb.diag.crumb",
        ]
        .iter()
        .map(|s| s.to_string())
        .collect::<Vec<_>>()
    );
}

/// Every namespace with a person in it is gone, and `sb.server.list` with it —
/// an agent knows one machine and that machine is itself.
///
/// `sb.server.exec` is absent for the neighbouring reason: it names a server
/// by a handle, and the agent issues none. A status plugin says what to run in
/// `statusCmd` and the agent runs it, which is the same power under the name
/// that fits.
#[test]
fn nothing_that_needs_a_user_or_a_server_handle_reaches_the_agent() {
    for f in HostFn::ALL {
        let path = f.path();
        let absent = f.namespace() == "ui"
            || f.namespace() == "nav"
            || f.namespace() == "clipboard"
            || path == "sb.server.list"
            || path == "sb.server.exec";
        assert_eq!(
            !f.available_in(HostProfile::Agent),
            absent,
            "{path} is on the wrong side of the agent's line"
        );
    }
}

/// `storage.sync` grants no host function at all — it is read by the storage
/// layer. If it ever starts gating one, this fails and the change is
/// deliberate.
#[test]
fn storage_sync_opens_no_host_function() {
    assert_scope(Grants::new([Permission::StorageSync]), &always_granted());
}

/// The table in 4.3 and what is installed are the same list.
#[test]
fn every_gated_function_is_gated_by_a_permission_that_exists() {
    for f in HostFn::ALL {
        if let Some(p) = f.permission() {
            assert!(
                Permission::ALL.contains(&p),
                "{} is gated by a permission not in the list",
                f.path()
            );
        }
    }
    for p in Permission::ALL {
        if *p == Permission::StorageSync || *p == Permission::ServerStream {
            // Neither opens a function of its own: `storage.sync` is read by
            // the storage layer, and `server.stream` widens `sb.http.fetch`.
            continue;
        }
        assert!(
            HostFn::ALL.iter().any(|f| f.permission() == Some(*p)),
            "nothing is gated by `{}`, so consenting to it means nothing",
            p.name()
        );
    }
}

/// Nothing on `sb` outside the declared namespaces, so a function cannot be
/// reachable without appearing in the table above.
#[test]
fn sb_carries_nothing_the_table_does_not_name() {
    let src = r#"
      export function names() {
        const out = [];
        for (const ns of Object.keys(sb)) {
          for (const m of Object.keys(sb[ns])) out.push("sb." + ns + "." + m);
        }
        return out.sort();
      }
    "#;
    let mut o = InstanceOptions::new("test.plugin", "inst-1");
    o.grants = Grants::new(Permission::ALL.iter().copied());
    let mut p = Instance::new(src, o, ScriptedBridge::new()).unwrap();

    let found: BTreeSet<String> =
        serde_json::from_slice(&p.call("names", b"").unwrap()).unwrap();

    let mut expected: BTreeSet<String> = HostFn::ALL.iter().map(|f| f.path()).collect();
    expected.insert("sb.config.get".into());
    for level in sbm_plugin::LogLevel::ALL {
        expected.insert(format!("sb.log.{}", level.name()));
    }
    assert_eq!(found, expected);
}

/// The path a real install takes: manifest → consent → grants → bindings.
/// Asserted here rather than only in the manifest's own tests, because this is
/// the point where getting the intersection backwards would stop being visible.
#[test]
fn a_manifest_the_user_only_partly_agreed_to() {
    let manifest = Manifest::parse(
        br#"{
          "id": "app.serverbox.bmc", "version": "1.0.0", "abi": 1, "name": "BMC",
          "permissions": { "net.http": ["$config.addr"], "ui.dialog": true },
          "config": { "fields": [
            {"key":"addr","type":"text","label":"l10n.addr","role":"address"}
          ]}
        }"#,
    )
    .unwrap();

    let config = BTreeMap::from([("addr".to_string(), "https://10.0.0.9".to_string())]);
    let consented: BTreeSet<Permission> = [Permission::NetHttp].into_iter().collect();
    let grants = manifest.resolve_grants(&consented, &config);

    let mut expected = always_granted();
    expected.push(HostFn::HttpFetch);
    assert_scope(grants, &expected);
}

/// A plugin has no way to change a server.
///
/// Not a rule the app has to remember: nothing on `sb` writes to the server
/// record. `sb.store.set` writes the plugin's own key-value namespace, and the
/// server's configuration for a plugin is written by the editor, from the form
/// the manifest declares — the plugin only reads it, through `sb.config.get`.
///
/// Stated as a test because the way it would be lost is a host function added
/// later for a good local reason. Adding one that writes to a server means
/// deleting this, which is a thing to argue about rather than a thing to
/// overlook.
#[test]
fn nothing_on_sb_can_change_a_server() {
    for f in HostFn::ALL {
        let path = f.path();
        assert!(
            !path.starts_with("sb.config.set") && !path.starts_with("sb.server.set"),
            "{path} writes to a server"
        );
    }
    // The four that touch a server at all, none of which changes the record:
    // one runs a command, one lists what exists, one opens a server's page and
    // one opens a terminal on it. Adding a fifth means changing this line,
    // which is the argument this test exists to force.
    let touching: Vec<String> = HostFn::ALL
        .iter()
        .filter(|f| {
            f.namespace() == "server"
                || f.path() == "sb.nav.openServer"
                || f.path() == "sb.nav.openTerminal"
        })
        .map(|f| f.path())
        .collect();
    assert_eq!(
        touching,
        [
            "sb.server.exec",
            "sb.server.list",
            "sb.nav.openServer",
            "sb.nav.openTerminal",
        ]
    );

    // And `sb.config` is read-only: one method, and it reads.
    let config: Vec<String> = HostFn::ALL
        .iter()
        .filter(|f| f.namespace() == "config")
        .map(|f| f.path())
        .collect();
    assert!(config.is_empty(), "config is installed directly and only as `get`");
}
