//! The plugin interface, end to end on QuickJS.
//!
//! What is asserted is the parts a broken host would get subtly wrong: state
//! that must survive between calls, values that must cross unchanged, the two
//! ways a plugin reports a failure, and the resource limits.

mod support;

use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::Duration;

use sbm_plugin::{
    BridgeError, Grants, HostFn, Instance, InstanceOptions, LogLevel, Permission, PluginError,
};
use support::{ScriptedBridge, SilentBridge};

fn opts() -> InstanceOptions {
    InstanceOptions::new("test.plugin", "inst-1")
}

fn load(src: &str, options: InstanceOptions, bridge: Arc<ScriptedBridge>) -> Instance {
    Instance::new(src, options, bridge).expect("plugin did not load")
}

// ------------------------------------------------------------------ module

#[test]
fn input_reaches_the_plugin_and_the_answer_comes_back() {
    let mut p = load("export function echo(x) { return x; }", opts(), ScriptedBridge::new());
    assert_eq!(p.call("echo", br#"{"hello":1}"#).unwrap(), br#"{"hello":1}"#);
    // Twice, because an instance is reused and a host that reset something
    // between calls would only show it on the second.
    assert_eq!(p.call("echo", br#"[1,2]"#).unwrap(), b"[1,2]");
}

#[test]
fn an_export_that_answers_nothing_answers_nothing() {
    let mut p = load("export function go() {}", opts(), ScriptedBridge::new());
    assert_eq!(p.call("go", b"").unwrap(), b"");
    // And `null` is not the same as nothing.
    let mut p = load("export function go() { return null; }", opts(), ScriptedBridge::new());
    assert_eq!(p.call("go", b"").unwrap(), b"null");
}

#[test]
fn only_function_exports_are_listed() {
    let p = load(
        "export const version = 3; export function open() {} export function tick() {}",
        opts(),
        ScriptedBridge::new(),
    );
    assert_eq!(p.exports(), ["open", "tick"]);
    assert!(!p.has_export("version"));
}

#[test]
fn a_missing_export_is_named() {
    let mut p = load("export function open() {}", opts(), ScriptedBridge::new());
    let e = p.call("tick", b"").unwrap_err();
    assert!(matches!(e, PluginError::NoSuchExport(ref n) if n == "tick"), "{e}");
}

#[test]
fn a_plugin_that_does_not_parse_fails_at_load() {
    let Err(e) = Instance::new("export function (", opts(), ScriptedBridge::new()) else {
        panic!("a plugin that does not parse was accepted");
    };
    assert!(matches!(e, PluginError::Module(_)), "{e}");
}

/// Top-level state is what a plugin keeps between calls; there is no other
/// place for it.
#[test]
fn module_state_survives_between_calls_and_dies_with_the_instance() {
    let src = "let n = 0; export function bump() { return ++n; }";
    let mut p = load(src, opts(), ScriptedBridge::new());
    assert_eq!(p.call("bump", b"").unwrap(), b"1");
    assert_eq!(p.call("bump", b"").unwrap(), b"2");

    let mut other = load(src, opts(), ScriptedBridge::new());
    assert_eq!(other.call("bump", b"").unwrap(), b"1");
}

// ----------------------------------------------------------------- sandbox

/// The context is not a browser and not Node. Anything that could reach the
/// network or the filesystem without going through `sb` would make the manifest
/// a description of nothing.
#[test]
fn the_context_has_no_way_out() {
    let src = r#"
      export function probe() {
        return [
          "fetch", "require", "process", "XMLHttpRequest", "WebSocket",
          "importScripts", "Deno", "Bun",
        ].filter((n) => typeof globalThis[n] !== "undefined");
      }
    "#;
    let mut p = load(src, opts(), ScriptedBridge::new());
    assert_eq!(p.call("probe", b"").unwrap(), b"[]");
}

/// What a plugin *does* get: the language, and a clock. The clock is the one
/// the WebAssembly design had to add a host function for.
#[test]
fn the_language_and_a_clock_are_available() {
    let src = r#"
      export function probe() {
        return {
          now: typeof Date.now() === "number" && Date.now() > 0,
          json: JSON.parse('{"a":1}').a === 1,
          regexp: "2026-09".match(/(?<y>\d{4})/).groups.y === "2026",
          bigint: (2n ** 70n) > 0n,
        };
      }
    "#;
    let mut p = load(src, opts(), ScriptedBridge::new());
    let v: serde_json::Value = serde_json::from_slice(&p.call("probe", b"").unwrap()).unwrap();
    assert_eq!(v, serde_json::json!({"now": true, "json": true, "regexp": true, "bigint": true}));
}

#[test]
fn every_namespace_exists_even_when_nothing_in_it_is_granted() {
    let src = r#"
      export function probe() {
        return ["server","http","ui","store","diag","nav","clipboard","config","log"]
          .filter((n) => typeof sb[n] !== "object");
      }
    "#;
    let mut p = load(src, opts(), ScriptedBridge::new());
    assert_eq!(p.call("probe", b"").unwrap(), b"[]");
}

// -------------------------------------------------------------- host calls

#[test]
fn a_host_call_carries_the_request_and_the_answer_comes_back_as_a_value() {
    let bridge = ScriptedBridge::new();
    bridge.answer(HostFn::StoreGet, r#"{"value":"42"}"#);
    let src = r#"
      export async function go() {
        const r = await sb.store.get({ scope: "global", key: "n" });
        return r.value;
      }
    "#;
    let mut p = load(src, opts(), Arc::clone(&bridge));
    assert_eq!(p.call("go", b"").unwrap(), br#""42""#);

    let calls = bridge.recorded();
    assert_eq!(calls.len(), 1);
    assert_eq!(calls[0].func, HostFn::StoreGet);
    assert_eq!(calls[0].request, r#"{"scope":"global","key":"n"}"#);
    assert_eq!(calls[0].plugin_id, "test.plugin");
    assert_eq!(calls[0].instance_id, "inst-1");
}

/// A host that could not do the thing is an answer, not a death: a BMC that did
/// not respond has to become a card that says so.
#[test]
fn a_host_failure_is_a_rejection_the_plugin_can_catch() {
    let bridge = ScriptedBridge::new();
    bridge.answer_err(HostFn::StoreGet, BridgeError::failed("io", "database is locked"));
    let src = r#"
      export async function go() {
        try {
          await sb.store.get({ scope: "global", key: "n" });
          return "no error";
        } catch (e) {
          return { name: e.name, kind: e.kind, message: e.message };
        }
      }
    "#;
    let mut p = load(src, opts(), Arc::clone(&bridge));
    let v: serde_json::Value = serde_json::from_slice(&p.call("go", b"").unwrap()).unwrap();
    assert_eq!(v["name"], "HostError");
    assert_eq!(v["kind"], "io");
    assert_eq!(v["message"], "database is locked");
}

/// The app refusing is the same kind of answer as the permission stub, and must
/// not be something a plugin can catch and carry on from.
#[test]
fn the_app_refusing_is_not_catchable_as_an_ordinary_failure() {
    let bridge = ScriptedBridge::new();
    bridge.answer_err(HostFn::StoreGet, BridgeError::Denied { detail: "unknown scope".into() });
    let src = r#"
      export async function go() {
        try { await sb.store.get({}); return "swallowed"; } catch (e) { throw e; }
      }
    "#;
    let mut p = load(src, opts(), Arc::clone(&bridge));
    let e = p.call("go", b"").unwrap_err();
    let PluginError::Denied(msg) = &e else { panic!("{e}") };
    assert!(msg.contains("unknown scope"), "{msg}");
}

#[test]
fn a_void_argument_reaches_the_bridge_as_json_null() {
    let bridge = ScriptedBridge::new();
    let src = "export async function go() { await sb.clipboard.read(); }";
    let mut o = opts();
    o.grants = Grants::new([Permission::Clipboard]);
    let mut p = load(src, o, Arc::clone(&bridge));
    p.call("go", b"").unwrap();
    assert_eq!(bridge.recorded()[0].request, "null");
}

#[test]
fn config_is_synchronous_and_answers_what_the_host_put_there() {
    let src = r#"
      export function probe() {
        return { addr: sb.config.get("addr"), absent: sb.config.get("nope") ?? null };
      }
    "#;
    let mut o = opts();
    o.config = BTreeMap::from([("addr".into(), "https://10.0.0.9".into())]);
    let mut p = load(src, o, ScriptedBridge::new());
    let v: serde_json::Value = serde_json::from_slice(&p.call("probe", b"").unwrap()).unwrap();
    assert_eq!(v["addr"], "https://10.0.0.9");
    assert_eq!(v["absent"], serde_json::Value::Null);
}

#[test]
fn logs_reach_the_bridge_with_their_level() {
    let bridge = ScriptedBridge::new();
    let src = r#"export function go() { sb.log.warn("discovering"); sb.log.info("done"); }"#;
    let mut p = load(src, opts(), Arc::clone(&bridge));
    p.call("go", b"").unwrap();
    assert_eq!(
        bridge.logged(),
        vec![
            (LogLevel::Warn, "discovering".to_string()),
            (LogLevel::Info, "done".to_string())
        ]
    );
}

// ------------------------------------------------------------------- async

/// The reason for the whole design. While a host call is outstanding the
/// plugin's stack is unwound, so the instance holds nothing but memory.
#[test]
fn a_deferred_answer_resumes_the_plugin_where_it_left_off() {
    let bridge = ScriptedBridge::new();
    bridge.answer(HostFn::StoreGet, r#"{"value":"late"}"#).defer(HostFn::StoreGet, 3);
    let src = r#"
      export async function go() {
        const before = "a";
        const r = await sb.store.get({ scope: "global", key: "n" });
        return before + r.value;
      }
    "#;
    let mut p = load(src, opts(), Arc::clone(&bridge));
    assert_eq!(p.call("go", b"").unwrap(), br#""alate""#);
}

#[test]
fn several_awaits_in_a_row_each_get_their_answer() {
    let bridge = ScriptedBridge::new();
    bridge.answer(HostFn::StoreGet, r#"{"value":"x"}"#).defer(HostFn::StoreGet, 2);
    let src = r#"
      export async function go() {
        let out = "";
        for (let i = 0; i < 3; i++) {
          const r = await sb.store.get({ scope: "global", key: String(i) });
          out += r.value;
        }
        return out;
      }
    "#;
    let mut p = load(src, opts(), Arc::clone(&bridge));
    assert_eq!(p.call("go", b"").unwrap(), br#""xxx""#);
    assert_eq!(bridge.recorded().len(), 3);
}

#[test]
fn promise_all_lets_two_calls_be_outstanding_at_once() {
    let bridge = ScriptedBridge::new();
    bridge
        .answer(HostFn::StoreGet, r#"{"value":"a"}"#)
        .defer(HostFn::StoreGet, 2)
        .answer(HostFn::StoreList, r#"{"keys":["k"]}"#)
        .defer(HostFn::StoreList, 4);
    let src = r#"
      export async function go() {
        const [a, b] = await Promise.all([
          sb.store.get({ scope: "global", key: "n" }),
          sb.store.list({ scope: "global", prefix: "" }),
        ]);
        return a.value + b.keys[0];
      }
    "#;
    let mut p = load(src, opts(), Arc::clone(&bridge));
    assert_eq!(p.call("go", b"").unwrap(), br#""ak""#);
}

/// A plugin awaiting something no host call will settle would otherwise leave
/// the instance waiting forever.
#[test]
fn awaiting_a_promise_nothing_will_settle_is_reported() {
    let src = "export function go() { return new Promise(() => {}); }";
    let mut p = load(src, opts(), ScriptedBridge::new());
    let e = p.call("go", b"").unwrap_err();
    assert!(matches!(e, PluginError::Threw(_)), "{e}");
}

#[test]
fn a_bridge_that_never_answers_gives_up_rather_than_waiting_forever() {
    let src = "export async function go() { await sb.store.get({}); }";
    let mut o = opts();
    o.host_call_timeout = Duration::from_millis(50);
    let mut p =
        Instance::new(src, o, Arc::new(SilentBridge)).expect("plugin did not load");
    let e = p.call("go", b"").unwrap_err();
    assert!(matches!(e, PluginError::Internal(_)), "{e}");
}

/// A dropped instance must tell the app about the calls it is still working on,
/// or a BMC session is opened and never released.
#[test]
fn dropping_an_instance_cancels_its_outstanding_calls() {
    let bridge = ScriptedBridge::new();
    // Deferred far beyond the timeout, so the call is still outstanding when
    // the instance is dropped.
    bridge.defer(HostFn::StoreGet, usize::MAX);
    let src = "export async function go() { await sb.store.get({}); }";
    let mut o = opts();
    o.host_call_timeout = Duration::from_millis(20);
    let mut p = Instance::new(src, o, Arc::clone(&bridge) as Arc<_>).unwrap();
    let _ = p.call("go", b"");
    assert_eq!(bridge.cancels(), 0);
    drop(p);
    // The call the timeout gave up on is still outstanding, and the app is told.
    assert_eq!(bridge.cancels(), 1);
}

// ------------------------------------------------------------- how it fails

#[test]
fn a_plugin_that_throws_is_reported_with_its_message() {
    let src = "export function go() { throw new Error('bmc unreachable'); }";
    let mut p = load(src, opts(), ScriptedBridge::new());
    let e = p.call("go", b"").unwrap_err();
    let PluginError::Threw(msg) = &e else { panic!("{e}") };
    assert!(msg.contains("bmc unreachable"), "{msg}");

    // And the instance is still usable.
    let mut p = load(
        "export function go() { throw new Error('x'); } export function ok() { return 1; }",
        opts(),
        ScriptedBridge::new(),
    );
    assert!(p.call("go", b"").is_err());
    assert_eq!(p.call("ok", b"").unwrap(), b"1");
}

#[test]
fn a_rejected_async_export_is_reported_too() {
    let src = "export async function go() { throw new Error('later'); }";
    let mut p = load(src, opts(), ScriptedBridge::new());
    let e = p.call("go", b"").unwrap_err();
    assert!(format!("{e}").contains("later"), "{e}");
}

// -------------------------------------------------------- resource limits

#[test]
fn a_plugin_that_loops_runs_out_of_time() {
    let src = "export function spin() { for (;;) {} }";
    let mut o = opts();
    o.time_limit = Some(Duration::from_millis(50));
    let mut p = load(src, o, ScriptedBridge::new());
    let e = p.call("spin", b"").unwrap_err();
    assert!(matches!(e, PluginError::Threw(_)), "{e}");
}

#[test]
fn a_plugin_that_allocates_past_the_ceiling_is_stopped() {
    let src = r#"
      export function hog() {
        const a = [];
        for (;;) { a.push(new Uint8Array(1024 * 1024)); }
      }
    "#;
    let mut o = opts();
    o.memory_limit = 8 * 1024 * 1024;
    o.time_limit = Some(Duration::from_secs(10));
    let mut p = load(src, o, ScriptedBridge::new());
    assert!(p.call("hog", b"").is_err());
}

#[test]
fn a_plugin_that_recurses_gets_an_exception_rather_than_a_crash() {
    let src = "export function deep() { return deep(); } ";
    let mut p = load(src, opts(), ScriptedBridge::new());
    let e = p.call("deep", b"").unwrap_err();
    assert!(matches!(e, PluginError::Threw(_)), "{e}");
}

// --------------------------------------------------------- server handles

/// `sb.ui.pickServer` is the only way an instance's reach grows, and it grows
/// only because the user picked something.
#[test]
fn a_picked_server_becomes_usable_and_an_invented_one_does_not() {
    let bridge = ScriptedBridge::new();
    bridge.answer(HostFn::UiPickServer, r#"{"server":"h-7"}"#);
    let src = r#"
      export async function invent() {
        await sb.server.exec({ server: "h-7", script: "uptime" });
      }
      export async function pick() { await sb.ui.pickServer(); }
    "#;
    let mut o = opts();
    o.grants = Grants::new([Permission::ServerExec]);
    let mut p = load(src, o, Arc::clone(&bridge));

    assert!(p.call("invent", b"").is_err(), "an unissued handle was accepted");
    p.call("pick", b"").unwrap();
    p.call("invent", b"").unwrap();
    assert_eq!(bridge.funcs().last(), Some(&HostFn::ServerExec));
}

#[test]
fn the_bound_server_is_usable_from_the_first_call() {
    let bridge = ScriptedBridge::new();
    let src = r#"
      export async function go() {
        await sb.server.exec({ server: "bound", script: "uptime" });
      }
    "#;
    let mut o = opts();
    o.grants = Grants::new([Permission::ServerExec]);
    o.bound_server = Some("bound".into());
    let mut p = load(src, o, Arc::clone(&bridge));
    p.call("go", b"").unwrap();
    assert_eq!(bridge.recorded().len(), 1);
}
