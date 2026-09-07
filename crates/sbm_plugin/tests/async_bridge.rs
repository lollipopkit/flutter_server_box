//! The whole asynchronous path, with an app that answers on its own schedule.
//!
//! PLUGINS.md 4.4. A plugin awaits, its JavaScript stack unwinds, another
//! thread answers whenever it likes, and the plugin resumes where it left off.
//! Everything here is what `sbm_ffi` will do, minus the FFI: the `emit` pushes
//! onto a channel instead of a Dart stream, and the answering thread calls
//! `ChannelBridge::answer` instead of a Dart-to-Rust function.

use std::collections::BTreeMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{Receiver, channel};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use sbm_plugin::{
    BridgeError, ChannelBridge, Grants, HostRequest, InstanceOptions, LogEvent, Permission,
    PluginHost,
};

/// The app: answers requests off a channel, in its own time.
struct App {
    bridge: Arc<ChannelBridge>,
    stop: Arc<AtomicBool>,
    seen: Arc<Mutex<Vec<HostRequest>>>,
    join: Option<std::thread::JoinHandle<()>>,
}

impl App {
    /// `answer` decides what each request gets, by function path.
    fn start(
        delay: Duration,
        answer: impl Fn(&HostRequest) -> Result<Vec<u8>, BridgeError> + Send + 'static,
    ) -> (Self, Receiver<LogEvent>) {
        let (req_tx, req_rx) = channel::<HostRequest>();
        let (log_tx, log_rx) = channel::<LogEvent>();
        let bridge = ChannelBridge::new(
            move |r| {
                let _ = req_tx.send(r);
            },
            move |l| {
                let _ = log_tx.send(l);
            },
        );

        let stop = Arc::new(AtomicBool::new(false));
        let seen = Arc::new(Mutex::new(Vec::new()));
        let join = {
            let bridge = Arc::clone(&bridge);
            let stop = Arc::clone(&stop);
            let seen = Arc::clone(&seen);
            std::thread::spawn(move || {
                while !stop.load(Ordering::Acquire) {
                    match req_rx.recv_timeout(Duration::from_millis(10)) {
                        Ok(req) => {
                            // The delay is the point: the plugin must be
                            // waiting, not spinning inside a host call.
                            std::thread::sleep(delay);
                            seen.lock().unwrap().push(req.clone());
                            bridge.answer(req.call_id, answer(&req));
                        }
                        Err(_) => continue,
                    }
                }
            })
        };

        (Self { bridge, stop, seen, join: Some(join) }, log_rx)
    }

    fn requests(&self) -> Vec<HostRequest> {
        self.seen.lock().unwrap().clone()
    }
}

impl Drop for App {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Release);
        if let Some(join) = self.join.take() {
            let _ = join.join();
        }
    }
}

fn opts() -> InstanceOptions {
    let mut o = InstanceOptions::new("app.serverbox.test", "inst-1");
    o.grants = Grants::new([Permission::ServerExec, Permission::NetHttp])
        .with_http_patterns(["10.0.0.9".to_string()]);
    o.bound_server = Some("bound".into());
    o.config = BTreeMap::from([("addr".into(), "https://10.0.0.9".into())]);
    o
}

fn json(v: serde_json::Value) -> Result<Vec<u8>, BridgeError> {
    Ok(v.to_string().into_bytes())
}

#[test]
fn a_plugin_awaits_and_the_app_answers_later() {
    let (app, _logs) = App::start(Duration::from_millis(5), |req| match req.func.as_str() {
        "sb.server.exec" => json(serde_json::json!({"code": 0, "stdout": "up 3 days", "stderr": ""})),
        _ => json(serde_json::Value::Null),
    });

    let host = PluginHost::new();
    let id = host
        .load(
            r#"
              export async function go() {
                const r = await sb.server.exec({ server: "bound", script: "uptime -p" });
                return r.stdout;
              }
            "#
            .into(),
            opts(),
            Arc::clone(&app.bridge) as Arc<_>,
        )
        .unwrap();

    assert_eq!(host.call(id, "go", b"").unwrap(), br#""up 3 days""#);
    assert_eq!(app.requests().len(), 1);
    assert_eq!(app.requests()[0].func, "sb.server.exec");
}

/// A plugin doing several things at once. Two requests are outstanding
/// together, which only works because the plugin's stack is unwound while it
/// waits.
#[test]
fn two_requests_can_be_outstanding_at_the_same_time() {
    let (app, _logs) = App::start(Duration::from_millis(5), |req| {
        let body: serde_json::Value = serde_json::from_str(&req.request).unwrap();
        json(serde_json::json!({"code": 0, "stdout": body["script"], "stderr": ""}))
    });

    let host = PluginHost::new();
    let id = host
        .load(
            r#"
              export async function go() {
                const [a, b] = await Promise.all([
                  sb.server.exec({ server: "bound", script: "one" }),
                  sb.server.exec({ server: "bound", script: "two" }),
                ]);
                return a.stdout + "," + b.stdout;
              }
            "#
            .into(),
            opts(),
            Arc::clone(&app.bridge) as Arc<_>,
        )
        .unwrap();

    assert_eq!(host.call(id, "go", b"").unwrap(), br#""one,two""#);
    assert_eq!(app.requests().len(), 2);
}

/// The whole of a poll: several sequential requests, each answered by another
/// thread, with the plugin keeping state across them.
#[test]
fn a_sequence_of_awaits_keeps_the_plugin_state_intact() {
    let (app, _logs) = App::start(Duration::from_millis(2), |req| {
        // Answers with the path it was asked for, so what the plugin
        // accumulates says which requests it made and in what order.
        let body: serde_json::Value = serde_json::from_str(&req.request).unwrap();
        let url = body["url"].as_str().unwrap();
        json(serde_json::json!({
            "status": 200,
            "headers": {},
            "body": url.rsplit('/').next().unwrap(),
            "bodyEncoding": "utf8",
        }))
    });

    let host = PluginHost::new();
    let id = host
        .load(
            r#"
              let seen = "";
              export async function poll() {
                for (const path of ["a", "bb", "ccc"]) {
                  const r = await sb.http.fetch({
                    url: sb.config.get("addr") + "/" + path,
                    pinSha256: "aa",
                  });
                  seen += r.body + ";";
                }
                return seen;
              }
            "#
            .into(),
            opts(),
            Arc::clone(&app.bridge) as Arc<_>,
        )
        .unwrap();

    // Three separate resumptions, in order, accumulated by the plugin.
    assert_eq!(host.call(id, "poll", b"").unwrap(), br#""a;bb;ccc;""#);
    // And the state survives into the next call, as it must for a card that
    // polls.
    assert_eq!(host.call(id, "poll", b"").unwrap(), br#""a;bb;ccc;a;bb;ccc;""#);
    assert_eq!(app.requests().len(), 6);
}

/// A failure the app reports is something the plugin handles, not something
/// that kills the instance.
#[test]
fn an_app_failure_is_caught_by_the_plugin() {
    let (app, _logs) = App::start(Duration::from_millis(2), |_| {
        Err(BridgeError::failed("timeout", "the bmc did not answer"))
    });

    let host = PluginHost::new();
    let id = host
        .load(
            r#"
              export async function go() {
                try {
                  await sb.http.fetch({ url: "https://10.0.0.9/", pinSha256: "aa" });
                  return "unreachable";
                } catch (e) {
                  return e.kind + ": " + e.message;
                }
              }
            "#
            .into(),
            opts(),
            Arc::clone(&app.bridge) as Arc<_>,
        )
        .unwrap();

    assert_eq!(host.call(id, "go", b"").unwrap(), br#""timeout: the bmc did not answer""#);
}

#[test]
fn logs_reach_the_app_without_being_answered() {
    let (app, logs) = App::start(Duration::from_millis(1), |_| json(serde_json::Value::Null));

    let host = PluginHost::new();
    let id = host
        .load(
            r#"export function go() { sb.log.warn("session not released"); }"#.into(),
            opts(),
            Arc::clone(&app.bridge) as Arc<_>,
        )
        .unwrap();

    host.call(id, "go", b"").unwrap();
    let event = logs.recv_timeout(Duration::from_secs(2)).unwrap();
    assert_eq!(event.message, "session not released");
    assert_eq!(event.level, sbm_plugin::LogLevel::Warn);
    assert!(app.requests().is_empty(), "a log was answered");
}

/// Unloading an instance whose request is still in flight must not leave the
/// bridge holding it: the bridge lives as long as the app does.
#[test]
fn unloading_mid_request_leaves_nothing_outstanding() {
    // An app that never answers.
    let (req_tx, req_rx) = channel::<HostRequest>();
    let bridge = ChannelBridge::new(
        move |r| {
            let _ = req_tx.send(r);
        },
        |_| {},
    );

    let host = PluginHost::new();
    let mut o = opts();
    o.host_call_timeout = Duration::from_millis(30);
    let id = host
        .load(
            r#"export async function go() { await sb.server.exec({ server: "bound", script: "x" }); }"#
                .into(),
            o,
            Arc::clone(&bridge) as Arc<_>,
        )
        .unwrap();

    assert!(host.call(id, "go", b"").is_err(), "the app never answered");
    assert!(req_rx.try_recv().is_ok());
    host.unload(id);
    assert_eq!(bridge.outstanding(), 0);
}

/// Two instances on one bridge. Answers are routed by call id, and neither
/// plugin sees the other's.
#[test]
fn two_instances_share_a_bridge_without_crossing() {
    let (app, _logs) = App::start(Duration::from_millis(2), |req| {
        let body: serde_json::Value = serde_json::from_str(&req.request).unwrap();
        json(serde_json::json!({
            "code": 0,
            "stdout": format!("{}:{}", req.instance_id, body["script"].as_str().unwrap()),
            "stderr": "",
        }))
    });

    let host = PluginHost::new();
    let src = r#"
      export async function go(script) {
        const r = await sb.server.exec({ server: "bound", script });
        return r.stdout;
      }
    "#;
    let mut a = opts();
    a.instance_id = "inst-a".into();
    let mut b = opts();
    b.instance_id = "inst-b".into();

    let ia = host.load(src.into(), a, Arc::clone(&app.bridge) as Arc<_>).unwrap();
    let ib = host.load(src.into(), b, Arc::clone(&app.bridge) as Arc<_>).unwrap();

    let host = Arc::new(host);
    let ta = {
        let host = Arc::clone(&host);
        std::thread::spawn(move || host.call(ia, "go", br#""one""#))
    };
    let tb = {
        let host = Arc::clone(&host);
        std::thread::spawn(move || host.call(ib, "go", br#""two""#))
    };

    assert_eq!(ta.join().unwrap().unwrap(), br#""inst-a:one""#);
    assert_eq!(tb.join().unwrap().unwrap(), br#""inst-b:two""#);
}

/// A module that awaits a host call before it exports anything.
///
/// The natural way to write "read my accounts once" is a top-level `await`, and
/// module evaluation has to be driven the same way a call is for that to work.
/// Driving only the job queue answers `WouldBlock`, which reaches the user as a
/// plugin that will not load and no reason why.
#[test]
fn a_module_may_await_a_host_call_while_it_loads() {
    let (app, _logs) = App::start(Duration::from_millis(3), |_| {
        json(serde_json::json!({"code": 0, "stdout": "loaded", "stderr": ""}))
    });

    let host = PluginHost::new();
    let id = host
        .load(
            r#"
              const boot = await sb.server.exec({ server: "bound", script: "id" });
              export function who() { return boot.stdout; }
            "#
            .into(),
            opts(),
            Arc::clone(&app.bridge) as Arc<_>,
        )
        .unwrap();

    assert_eq!(host.call(id, "who", b"").unwrap(), br#""loaded""#);
    assert_eq!(app.requests().len(), 1);
}

/// The same shape, failing. A plugin whose top-level await throws must not load
/// at all, rather than load with half its state built.
#[test]
fn a_module_whose_top_level_await_fails_does_not_load() {
    let (app, _logs) = App::start(Duration::from_millis(1), |_| {
        Err(BridgeError::failed("io", "no such server"))
    });

    let host = PluginHost::new();
    let e = host
        .load(
            r#"
              const boot = await sb.server.exec({ server: "bound", script: "id" });
              export function who() { return boot.stdout; }
            "#
            .into(),
            opts(),
            Arc::clone(&app.bridge) as Arc<_>,
        )
        .unwrap_err();

    assert!(format!("{e}").contains("no such server"), "{e}");
    assert!(host.is_empty());
}
