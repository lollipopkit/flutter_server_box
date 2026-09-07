//! Where instances live.
//!
//! A QuickJS runtime cannot be used from two threads, and `Instance` holds
//! values that are not `Send`, so an instance is created on a thread of its own
//! and never leaves it. Everything above this — the FFI layer, and Dart above
//! that — talks to it over a channel and may call from anywhere.
//!
//! **One thread per instance**, which settles the question PLUGINS.md 4.4 left
//! open. The count is small in practice: an instance exists while a surface is
//! visible, and a detail page shows one server's cards. A parked thread costs a
//! few kilobytes of committed stack, which is less than the machinery a shared
//! pool would need — a call cannot be suspended while a host call is
//! outstanding, because it is inside `Context::with`, so multiplexing would
//! mean restructuring `Instance::call` into a resumable state machine. That is
//! the option to reach for if the count ever becomes a problem.

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc::{Receiver, Sender, channel};
use std::sync::{Arc, Mutex};
use std::thread::JoinHandle;

use crate::bridge::HostBridge;
use crate::error::PluginError;
use crate::runtime::{Instance, InstanceOptions};

/// Names one live instance.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct InstanceId(pub u64);

enum Command {
    Call { export: String, input: Vec<u8>, reply: Sender<Result<Vec<u8>, PluginError>> },
    IssueServerHandle(String),
    Shutdown,
}

struct Worker {
    tx: Sender<Command>,
    join: Option<JoinHandle<()>>,
    exports: Vec<String>,
}

/// Every instance the app has open.
#[derive(Default)]
pub struct PluginHost {
    next: AtomicU64,
    workers: Mutex<HashMap<InstanceId, Worker>>,
}

impl PluginHost {
    pub fn new() -> Self {
        Self::default()
    }

    /// Compiles a plugin and keeps it on a thread of its own.
    ///
    /// Blocks until the module has been evaluated, so a plugin that does not
    /// parse fails here rather than on the first call.
    pub fn load(
        &self,
        source: String,
        options: InstanceOptions,
        bridge: Arc<dyn HostBridge>,
    ) -> Result<InstanceId, PluginError> {
        let id = InstanceId(self.next.fetch_add(1, Ordering::Relaxed));
        let (tx, rx) = channel::<Command>();
        let (ready_tx, ready_rx) = channel::<Result<Vec<String>, PluginError>>();

        let name = format!("sb-plugin-{}", options.plugin_id);
        let join = std::thread::Builder::new()
            .name(name)
            .spawn(move || run(source, options, bridge, rx, ready_tx))
            .map_err(|e| PluginError::Internal(format!("spawn: {e}")))?;

        match ready_rx.recv() {
            Ok(Ok(exports)) => {
                self.workers
                    .lock()
                    .expect("poisoned")
                    .insert(id, Worker { tx, join: Some(join), exports });
                Ok(id)
            }
            Ok(Err(e)) => {
                let _ = join.join();
                Err(e)
            }
            // The thread died before answering, which only a panic does.
            Err(_) => {
                let _ = join.join();
                Err(PluginError::Internal("the plugin thread stopped while loading".into()))
            }
        }
    }

    /// Calls one of section 4.2's exports and waits for the answer.
    ///
    /// Calls to one instance are serialised by its channel, so a tap that
    /// arrives during a poll runs after it rather than alongside — which is
    /// what the plugin's own state assumes.
    pub fn call(
        &self,
        id: InstanceId,
        export: &str,
        input: &[u8],
    ) -> Result<Vec<u8>, PluginError> {
        let (reply, answer) = channel();
        self.send(
            id,
            Command::Call { export: export.to_string(), input: input.to_vec(), reply },
        )?;
        answer.recv().map_err(|_| gone(id))?
    }

    /// The exports this plugin offers, read once at load.
    pub fn exports(&self, id: InstanceId) -> Result<Vec<String>, PluginError> {
        self.workers
            .lock()
            .expect("poisoned")
            .get(&id)
            .map(|w| w.exports.clone())
            .ok_or_else(|| gone(id))
    }

    pub fn has_export(&self, id: InstanceId, export: &str) -> bool {
        self.exports(id).is_ok_and(|e| e.iter().any(|n| n == export))
    }

    /// Adds a server handle the app issued outside a call.
    pub fn issue_server_handle(&self, id: InstanceId, handle: String) -> Result<(), PluginError> {
        self.send(id, Command::IssueServerHandle(handle))
    }

    /// Ends an instance and waits for its thread.
    ///
    /// Waits rather than detaches: dropping the `Instance` is what cancels its
    /// outstanding host calls, and returning before that has happened would let
    /// the app tear down a server whose session is still being released.
    pub fn unload(&self, id: InstanceId) {
        let worker = self.workers.lock().expect("poisoned").remove(&id);
        if let Some(mut worker) = worker {
            let _ = worker.tx.send(Command::Shutdown);
            if let Some(join) = worker.join.take() {
                let _ = join.join();
            }
        }
    }

    pub fn is_loaded(&self, id: InstanceId) -> bool {
        self.workers.lock().expect("poisoned").contains_key(&id)
    }

    pub fn len(&self) -> usize {
        self.workers.lock().expect("poisoned").len()
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    fn send(&self, id: InstanceId, command: Command) -> Result<(), PluginError> {
        let workers = self.workers.lock().expect("poisoned");
        let worker = workers.get(&id).ok_or_else(|| gone(id))?;
        worker.tx.send(command).map_err(|_| gone(id))
    }
}

impl Drop for PluginHost {
    fn drop(&mut self) {
        let ids: Vec<InstanceId> =
            self.workers.lock().expect("poisoned").keys().copied().collect();
        for id in ids {
            self.unload(id);
        }
    }
}

fn gone(id: InstanceId) -> PluginError {
    PluginError::Internal(format!("instance {} is not loaded", id.0))
}

/// The worker thread: build the instance here, then serve commands until told
/// to stop.
fn run(
    source: String,
    options: InstanceOptions,
    bridge: Arc<dyn HostBridge>,
    rx: Receiver<Command>,
    ready: Sender<Result<Vec<String>, PluginError>>,
) {
    let mut instance = match Instance::new(&source, options, bridge) {
        Ok(instance) => {
            if ready.send(Ok(instance.exports().to_vec())).is_err() {
                // Nobody is waiting, so nobody will ever call it.
                return;
            }
            instance
        }
        Err(e) => {
            let _ = ready.send(Err(e));
            return;
        }
    };

    while let Ok(command) = rx.recv() {
        match command {
            Command::Call { export, input, reply } => {
                let _ = reply.send(instance.call(&export, &input));
            }
            Command::IssueServerHandle(handle) => instance.issue_server_handle(handle),
            Command::Shutdown => break,
        }
    }
    // Dropped here, on the thread that made it, which is the only place it may
    // be dropped and the place its outstanding calls are cancelled.
    drop(instance);
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::bridge::{BridgeError, CallCtx, HostCall};
    use crate::hostfn::{HostFn, LogLevel};

    struct Quiet;
    impl HostBridge for Quiet {
        fn call(&self, _: CallCtx<'_>, _: HostFn, _: &[u8]) -> HostCall {
            HostCall::Ready(Ok(b"null".to_vec()))
        }
        fn log(&self, _: CallCtx<'_>, _: LogLevel, _: &str) {}
    }

    fn host() -> PluginHost {
        PluginHost::new()
    }

    fn opts(id: &str) -> InstanceOptions {
        InstanceOptions::new("test.plugin", id)
    }

    #[test]
    fn a_plugin_loads_and_answers() {
        let host = host();
        let id = host
            .load("export function echo(x) { return x; }".into(), opts("i1"), Arc::new(Quiet))
            .unwrap();
        assert_eq!(host.call(id, "echo", b"[1,2]").unwrap(), b"[1,2]");
        assert_eq!(host.exports(id).unwrap(), ["echo"]);
        assert!(host.has_export(id, "echo"));
    }

    #[test]
    fn a_plugin_that_does_not_parse_fails_at_load_and_leaves_nothing_behind() {
        let host = host();
        let e = host.load("export function (".into(), opts("i1"), Arc::new(Quiet)).unwrap_err();
        assert!(matches!(e, PluginError::Module(_)), "{e}");
        assert!(host.is_empty());
    }

    /// Each instance is its own runtime; nothing crosses.
    #[test]
    fn two_instances_do_not_share_state() {
        let host = host();
        let src = "let n = 0; export function bump() { return ++n; }";
        let a = host.load(src.into(), opts("a"), Arc::new(Quiet)).unwrap();
        let b = host.load(src.into(), opts("b"), Arc::new(Quiet)).unwrap();

        assert_eq!(host.call(a, "bump", b"").unwrap(), b"1");
        assert_eq!(host.call(a, "bump", b"").unwrap(), b"2");
        assert_eq!(host.call(b, "bump", b"").unwrap(), b"1");
    }

    /// The instance is built on its own thread and never moves, because the
    /// runtime it holds cannot be used from another one.
    #[test]
    fn every_call_reaches_the_same_thread() {
        let host = host();
        // `Date.now` is not a thread id, so the plugin cannot report one. What
        // it can report is that its state is intact, which is what a runtime
        // used from two threads would not be.
        let src = "const own = []; export function push(x) { own.push(x); return own.length; }";
        let id = host.load(src.into(), opts("i1"), Arc::new(Quiet)).unwrap();

        let host = Arc::new(host);
        let mut seen = Vec::new();
        for i in 0..8 {
            let host = Arc::clone(&host);
            // A different caller thread each time.
            seen.push(
                std::thread::spawn(move || host.call(id, "push", format!("{i}").as_bytes()))
                    .join()
                    .unwrap()
                    .unwrap(),
            );
        }
        let lengths: Vec<i64> = seen
            .iter()
            .map(|v| String::from_utf8_lossy(v).parse().unwrap())
            .collect();
        let mut sorted = lengths.clone();
        sorted.sort_unstable();
        assert_eq!(sorted, (1..=8).collect::<Vec<i64>>());
    }

    /// Calls to one instance are serialised, so a tap arriving during a poll
    /// runs after it. The plugin's own state assumes that.
    #[test]
    fn calls_to_one_instance_do_not_interleave() {
        let host = Arc::new(host());
        let src = r#"
          let inside = false;
          export function slow() {
            if (inside) throw new Error("re-entered");
            inside = true;
            const until = Date.now() + 5;
            while (Date.now() < until) {}
            inside = false;
            return 1;
          }
        "#;
        let id = host.load(src.into(), opts("i1"), Arc::new(Quiet)).unwrap();

        let threads: Vec<_> = (0..4)
            .map(|_| {
                let host = Arc::clone(&host);
                std::thread::spawn(move || host.call(id, "slow", b""))
            })
            .collect();
        for t in threads {
            assert!(t.join().unwrap().is_ok());
        }
    }

    #[test]
    fn calling_an_unloaded_instance_says_so_rather_than_hanging() {
        let host = host();
        let id = host
            .load("export function go() {}".into(), opts("i1"), Arc::new(Quiet))
            .unwrap();
        host.unload(id);

        assert!(!host.is_loaded(id));
        let e = host.call(id, "go", b"").unwrap_err();
        assert!(matches!(e, PluginError::Internal(_)), "{e}");
        assert!(host.exports(id).is_err());
    }

    /// Dropping the `Instance` is what cancels its outstanding host calls, and
    /// that happens on its own thread. `unload` waits for it.
    #[test]
    fn unload_waits_for_the_thread_to_finish() {
        struct Counting(Arc<Mutex<usize>>);
        struct Never(Arc<Mutex<usize>>);
        impl crate::bridge::PendingCall for Never {
            fn poll(&mut self) -> Option<Result<Vec<u8>, BridgeError>> {
                None
            }
            fn cancel(&mut self) {
                *self.0.lock().unwrap() += 1;
            }
        }
        impl HostBridge for Counting {
            fn call(&self, _: CallCtx<'_>, _: HostFn, _: &[u8]) -> HostCall {
                HostCall::Pending(Box::new(Never(Arc::clone(&self.0))))
            }
            fn log(&self, _: CallCtx<'_>, _: LogLevel, _: &str) {}
        }

        let cancels = Arc::new(Mutex::new(0));
        let host = host();
        let mut o = opts("i1");
        o.host_call_timeout = std::time::Duration::from_millis(30);
        let id = host
            .load(
                "export async function go() { await sb.store.get({}); }".into(),
                o,
                Arc::new(Counting(Arc::clone(&cancels))),
            )
            .unwrap();

        let _ = host.call(id, "go", b"");
        assert_eq!(*cancels.lock().unwrap(), 0);
        host.unload(id);
        // Already counted by the time `unload` returns, which is the point.
        assert_eq!(*cancels.lock().unwrap(), 1);
    }

    #[test]
    fn dropping_the_host_unloads_everything() {
        let host = host();
        for i in 0..3 {
            host.load(
                "export function go() {}".into(),
                opts(&format!("i{i}")),
                Arc::new(Quiet),
            )
            .unwrap();
        }
        assert_eq!(host.len(), 3);
        drop(host);
    }

    #[test]
    fn a_server_handle_issued_between_calls_is_usable() {
        let host = host();
        let src = r#"
          export async function go() {
            await sb.server.exec({ server: "later", script: "id" });
            return "ok";
          }
        "#;
        let mut o = opts("i1");
        o.grants = crate::Grants::new([crate::Permission::ServerExec]);
        let id = host.load(src.into(), o, Arc::new(Quiet)).unwrap();

        assert!(host.call(id, "go", b"").is_err());
        host.issue_server_handle(id, "later".into()).unwrap();
        assert_eq!(host.call(id, "go", b"").unwrap(), br#""ok""#);
    }
}
