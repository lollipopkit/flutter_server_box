//! The engine, and one instance of one plugin.
//!
//! An [`Instance`] is a (plugin, server) pair — or (plugin, null) for a global
//! surface such as a tab. A QuickJS runtime cannot be used from two threads, so
//! an instance stays on the one it was created on for its whole life.

use std::cell::RefCell;
use std::collections::{BTreeMap, BTreeSet};
use std::rc::Rc;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use rquickjs::promise::{MaybePromise, PromiseState};
use rquickjs::CaughtError;
use rquickjs::{
    CatchResultExt, Context, Ctx, Function, Module, Object, Persistent, Runtime as QjsRuntime,
    Value,
};

use crate::hostfn::HostProfile;
use crate::bindings::{self, Outbox, Outstanding};
use crate::bridge::{BridgeError, HostBridge};
use crate::error::PluginError;
use crate::permission::Grants;
use crate::scope::State;

/// The ABI a plugin's `abi` field names.
pub const ABI_VERSION: u32 = 1;

/// How long one call may run JavaScript before it is stopped.
///
/// Wall clock rather than an instruction count: what this bounds is a plugin
/// that loops, and the interrupt handler QuickJS offers is a periodic callback
/// rather than a budget. Time spent waiting for the app does not count against
/// it — that happens with the plugin's stack unwound, and is bounded separately
/// by [`InstanceOptions::host_call_timeout`].
pub const DEFAULT_TIME_LIMIT: Duration = Duration::from_secs(5);

/// Section 4.4's ceiling, applied to the instance's own runtime.
pub const DEFAULT_MEMORY_LIMIT: usize = 64 * 1024 * 1024;

/// A plugin that recurses should get an exception rather than reaching the host
/// stack guard.
pub const DEFAULT_STACK_LIMIT: usize = 512 * 1024;

/// How long the instance waits for the app to answer one host call.
///
/// A ceiling above whatever the app applies: a bridge that never answers would
/// otherwise leave a call waiting forever.
pub const DEFAULT_HOST_CALL_TIMEOUT: Duration = Duration::from_secs(120);

/// How long to wait between polls of the outstanding host calls, at first.
///
/// Backed off from here — see [`poll_interval`].
const POLL_INTERVAL: Duration = Duration::from_millis(1);

/// How long to wait once the app has been thinking for a while.
const POLL_INTERVAL_MAX: Duration = Duration::from_millis(25);

/// After this much waiting, answers are not about to arrive.
const POLL_BACKOFF_AFTER: Duration = Duration::from_millis(50);

/// A millisecond while an answer might be imminent, then twenty-five.
///
/// A fixed millisecond would wake this thread thirty thousand times across one
/// slow BMC request, which on a phone is battery spent on finding out that
/// nothing has happened. The cost is up to 25 ms added to a call that already
/// took seconds.
fn poll_interval(waiting: Duration) -> Duration {
    if waiting < POLL_BACKOFF_AFTER { POLL_INTERVAL } else { POLL_INTERVAL_MAX }
}

/// Everything an instance needs that is not the source.
pub struct InstanceOptions {
    pub plugin_id: String,
    pub instance_id: String,
    pub grants: Grants,
    pub config: BTreeMap<String, String>,

    /// Which host this is running in, which decides what `sb` has on it.
    ///
    /// Defaults to the app. The monitor agent sets [`HostProfile::Agent`],
    /// and everything that involves a person is then a stub that throws —
    /// see PLUGINS.md 9.5.
    pub profile: HostProfile,

    /// The server this instance is bound to, as the opaque handle the app
    /// minted for it. `None` for a global surface.
    ///
    /// The plugin never sees a server id and never sees a credential: what it
    /// gets is this string, and the app maps it back.
    pub bound_server: Option<String>,

    /// `None` runs unbounded, which is for the desktop dev-plugin path only.
    pub time_limit: Option<Duration>,
    pub memory_limit: usize,
    pub stack_limit: usize,
    pub host_call_timeout: Duration,
}

impl InstanceOptions {
    pub fn new(plugin_id: impl Into<String>, instance_id: impl Into<String>) -> Self {
        Self {
            profile: HostProfile::default(),
            plugin_id: plugin_id.into(),
            instance_id: instance_id.into(),
            grants: Grants::default(),
            config: BTreeMap::new(),
            bound_server: None,
            time_limit: Some(DEFAULT_TIME_LIMIT),
            memory_limit: DEFAULT_MEMORY_LIMIT,
            stack_limit: DEFAULT_STACK_LIMIT,
            host_call_timeout: DEFAULT_HOST_CALL_TIMEOUT,
        }
    }
}

/// One live plugin.
///
/// **Field order is load-bearing.** A `Persistent` is a JavaScript value plus a
/// runtime pointer, and freeing the runtime while one is alive aborts the
/// process — quickjs asserts `list_empty(&rt->gc_obj_list)` in `JS_FreeRuntime`.
/// Fields drop in declaration order, so everything holding a value is declared
/// above `ctx` and `rt`.
pub struct Instance {
    /// The module's exports, kept so a call does not re-evaluate anything.
    namespace: Persistent<Object<'static>>,

    /// Host calls the app has not answered. Each holds the two functions that
    /// will settle the plugin's promise, so these are values too.
    outbox: Outbox,

    exports: Vec<String>,
    state: Arc<State>,

    /// Read by the interrupt handler, written before and after each call.
    deadline: Arc<Mutex<Option<Instant>>>,
    time_limit: Option<Duration>,
    host_call_timeout: Duration,

    ctx: Context,
    #[allow(dead_code)]
    rt: QjsRuntime,
}

impl Instance {
    /// Compiles `source` as an ES module and evaluates it.
    ///
    /// Both happen here rather than lazily: a plugin that does not parse should
    /// fail while the user is watching an install, not the first time they open
    /// a card.
    pub fn new(
        source: &str,
        options: InstanceOptions,
        bridge: Arc<dyn HostBridge>,
    ) -> Result<Self, PluginError> {
        let rt = QjsRuntime::new().map_err(|e| PluginError::Internal(format!("runtime: {e}")))?;
        rt.set_memory_limit(options.memory_limit);
        rt.set_max_stack_size(options.stack_limit);

        // Shared with the interrupt handler rather than captured by value: the
        // deadline moves with each call, and the handler is installed once.
        let deadline: Arc<Mutex<Option<Instant>>> = Arc::new(Mutex::new(None));
        let handler_deadline = Arc::clone(&deadline);
        rt.set_interrupt_handler(Some(Box::new(move || {
            matches!(*handler_deadline.lock().expect("poisoned"), Some(d) if Instant::now() > d)
        })));

        let ctx = Context::full(&rt).map_err(|e| PluginError::Internal(format!("context: {e}")))?;

        let mut server_handles = BTreeSet::new();
        if let Some(handle) = options.bound_server.clone() {
            server_handles.insert(handle);
        }

        let state = Arc::new(State {
            profile: options.profile,
            plugin_id: options.plugin_id,
            instance_id: options.instance_id,
            bridge,
            grants: options.grants,
            config: options.config,
            refusal: Mutex::new(None),
            server_handles: Mutex::new(server_handles),
        });
        let outbox: Outbox = Rc::new(RefCell::new(Vec::new()));

        *deadline.lock().expect("poisoned") = options.time_limit.map(|d| Instant::now() + d);
        let loaded = {
            let state = Arc::clone(&state);
            let outbox = Rc::clone(&outbox);
            ctx.with(|ctx| -> Result<(Persistent<Object<'static>>, Vec<String>), PluginError> {
                bindings::install(&ctx, Arc::clone(&state), Rc::clone(&outbox))
                    .map_err(|e| PluginError::Internal(format!("install sb: {e}")))?;

                let declared = Module::declare(ctx.clone(), "plugin", source)
                    .catch(&ctx)
                    .map_err(|e| PluginError::Module(e.to_string()))?;
                let (module, pending) = declared
                    .eval()
                    .catch(&ctx)
                    .map_err(|e| PluginError::Module(e.to_string()))?;

                // Driven the same way a call is, rather than with
                // `Promise::finish`. A module that awaits a host function at
                // top level — `const accounts = await sb.store.list(...)` is
                // the natural way to write it — leaves a promise nothing in the
                // job queue can settle, and `finish` answers `WouldBlock`,
                // which reaches the user as a plugin that will not load for no
                // stated reason.
                let arm = || {
                    *deadline.lock().expect("poisoned") =
                        options.time_limit.map(|d| Instant::now() + d)
                };
                drive(
                    &ctx,
                    MaybePromise::from_value(pending.into_value()),
                    &outbox,
                    &state,
                    options.host_call_timeout,
                    &arm,
                )
                .map_err(|e| PluginError::Module(e.to_string()))?;

                let ns = module
                    .namespace()
                    .map_err(|e| PluginError::Module(format!("exports: {e}")))?;
                let mut exports = Vec::new();
                for entry in ns.props::<String, Value>() {
                    let (name, value) =
                        entry.map_err(|e| PluginError::Module(format!("exports: {e}")))?;
                    if value.is_function() {
                        exports.push(name);
                    }
                }
                exports.sort();
                Ok((Persistent::save(&ctx, ns), exports))
            })?
        };
        *deadline.lock().expect("poisoned") = None;
        let (namespace, exports) = loaded;

        Ok(Self {
            ctx,
            rt,
            namespace,
            exports,
            state,
            outbox,
            deadline,
            time_limit: options.time_limit,
            host_call_timeout: options.host_call_timeout,
        })
    }

    /// The exports this plugin offers, so the host can tell a plugin with a
    /// `card` surface from one without calling it.
    pub fn exports(&self) -> &[String] {
        &self.exports
    }

    pub fn has_export(&self, name: &str) -> bool {
        self.exports.iter().any(|e| e == name)
    }

    /// Adds a server handle the app issued outside a call.
    ///
    /// Used when a surface is rebound — the same instance, a different server —
    /// rather than to widen an instance's reach mid-call.
    pub fn issue_server_handle(&self, handle: impl Into<String>) {
        self.state.issue_handle(handle);
    }

    /// Calls one of section 4.2's exports.
    ///
    /// `input` and the answer are JSON. An export that answers `undefined`
    /// answers an empty slice, so a caller can tell "returned nothing" from
    /// "returned the JSON null" without parsing.
    pub fn call(&mut self, name: &str, input: &[u8]) -> Result<Vec<u8>, PluginError> {
        if !self.has_export(name) {
            return Err(PluginError::NoSuchExport(name.to_string()));
        }

        let namespace = self.namespace.clone();
        let outbox = Rc::clone(&self.outbox);
        let state = Arc::clone(&self.state);
        let host_call_timeout = self.host_call_timeout;
        let deadline = Arc::clone(&self.deadline);
        let time_limit = self.time_limit;

        // Armed around the whole call, including the waits between host
        // answers. Those are bounded separately, so the JavaScript deadline is
        // refreshed each time the plugin is resumed.
        let arm = || *deadline.lock().expect("poisoned") = time_limit.map(|d| Instant::now() + d);
        arm();

        let result = self.ctx.with(|ctx| -> Result<Vec<u8>, PluginError> {
            let ns = namespace
                .restore(&ctx)
                .map_err(|e| PluginError::Internal(format!("exports: {e}")))?;
            let func: Function = ns
                .get(name)
                .map_err(|_| PluginError::NoSuchExport(name.to_string()))?;

            let arg = if input.is_empty() {
                Value::new_undefined(ctx.clone())
            } else {
                ctx.json_parse(input.to_vec())
                    .map_err(|e| PluginError::BadAnswer(format!("input is not JSON: {e}")))?
            };

            let pending: MaybePromise = func
                .call((arg,))
                .catch(&ctx)
                .map_err(from_caught)?;

            let settled = drive(&ctx, pending, &outbox, &state, host_call_timeout, &arm);

            // Checked whether the call succeeded or not, and before the answer
            // is read. A plugin can `catch` a refusal — JavaScript has no
            // uncatchable throw — so what stops it carrying on is that the host
            // fails the call regardless of what it answered.
            if let Some(refusal) = state.take_refusal() {
                return Err(PluginError::Denied(refusal.to_string()));
            }
            encode(&ctx, settled?)
        });

        *self.deadline.lock().expect("poisoned") = None;
        result
    }
}

impl Drop for Instance {
    /// Tells the app about every call it is still working on.
    ///
    /// Without this a dropped instance leaves the app finishing requests whose
    /// answers nothing will read — which for a BMC means a session opened and
    /// never released.
    fn drop(&mut self) {
        for mut outstanding in self.outbox.borrow_mut().drain(..) {
            outstanding.call.cancel();
        }
    }
}

/// Runs the job queue and answers outstanding host calls until the value
/// settles.
///
/// This is what makes `await` in a plugin worth anything: while a host call is
/// outstanding the plugin's own stack is unwound, so the instance is holding
/// nothing but memory, and the thread is free to carry another instance.
fn drive<'js>(
    ctx: &Ctx<'js>,
    pending: MaybePromise<'js>,
    outbox: &Outbox,
    state: &Arc<State>,
    host_call_timeout: Duration,
    arm: &dyn Fn(),
) -> Result<Value<'js>, PluginError> {
    let mut waited_since: Option<Instant> = None;

    loop {
        // Microtasks first: a promise resolved by the last round of answers
        // only reaches the plugin when the queue runs.
        while ctx.execute_pending_job() {}

        match pending.state() {
            PromiseState::Resolved => {
                let value = pending.result::<Value>().transpose().catch(ctx).map_err(from_caught)?;
                return Ok(value.unwrap_or_else(|| Value::new_undefined(ctx.clone())));
            }
            PromiseState::Rejected => return Err(rejection(ctx, &pending)),
            PromiseState::Pending => {}
        }

        // Nothing to run and nothing outstanding: the plugin is waiting on
        // something that will never arrive. Reported rather than waited on,
        // because the alternative is an instance that never answers.
        if outbox.borrow().is_empty() {
            return Err(PluginError::Threw(
                "the plugin is waiting on a promise nothing will settle".into(),
            ));
        }

        let ready = take_ready(outbox);
        if ready.is_empty() {
            let since = *waited_since.get_or_insert_with(Instant::now);
            if since.elapsed() > host_call_timeout {
                return Err(PluginError::Internal(format!(
                    "the app did not answer within {host_call_timeout:?}"
                )));
            }
            std::thread::sleep(poll_interval(since.elapsed()));
            continue;
        }

        waited_since = None;
        // The plugin is about to run again, so it gets a fresh deadline. Time
        // spent waiting for the app is not the plugin's.
        arm();
        for (outstanding, answer) in ready {
            let recorded = bindings::settle(ctx, state, outstanding, answer)
                .map_err(|e| PluginError::Internal(format!("settle: {e}")))?;
            if let Some((func, value)) = recorded {
                state.record_response(func, &value);
            }
        }
    }
}

/// Everything the app has answered since the last look.
///
/// The borrow is dropped before anything runs JavaScript: settling a promise
/// re-enters the plugin, which can call a host function, which pushes onto this
/// same list.
fn take_ready(outbox: &Outbox) -> Vec<(Outstanding, Result<Vec<u8>, BridgeError>)> {
    let mut ready = Vec::new();
    let mut still_waiting = Vec::new();
    for mut outstanding in outbox.borrow_mut().drain(..) {
        match outstanding.call.poll() {
            Some(answer) => ready.push((outstanding, answer)),
            None => still_waiting.push(outstanding),
        }
    }
    outbox.borrow_mut().extend(still_waiting);
    ready
}

/// Turns a caught JavaScript exception into a [`PluginError`].
///
/// The `name` decides which: a refusal this host raised names a permission,
/// which is something to show the user, while anything else is the plugin's own
/// bug and belongs in a log. `name` rather than the message text, so the
/// wording in `error.rs` can change without changing what this classifies.
fn from_caught(caught: CaughtError<'_>) -> PluginError {
    let name = match &caught {
        CaughtError::Exception(e) => e.get::<_, String>("name").ok(),
        _ => None,
    };
    let text = caught.to_string().trim().to_string();
    match name.as_deref() {
        Some("PermissionDenied") | Some("OutOfScope") => PluginError::Denied(text),
        _ => PluginError::Threw(text),
    }
}

/// Why a rejected promise was rejected.
///
/// `Promise::result` throws the reason into the context rather than handing it
/// back, so it has to be caught before it can be read. Without that every
/// rejection reads as "Exception generated by QuickJS", which says nothing
/// about the plugin.
fn rejection<'js>(ctx: &Ctx<'js>, pending: &MaybePromise<'js>) -> PluginError {
    match pending.result::<Value>() {
        Some(Err(e)) => match Err::<(), _>(e).catch(ctx) {
            Err(caught) => from_caught(caught),
            Ok(()) => PluginError::Threw("rejected".into()),
        },
        Some(Ok(value)) => {
            let text = ctx
                .json_stringify(value)
                .ok()
                .flatten()
                .and_then(|s| s.to_string().ok())
                .unwrap_or_else(|| "rejected".into());
            PluginError::Threw(text)
        }
        None => PluginError::Threw("rejected".into()),
    }
}

fn encode<'js>(ctx: &Ctx<'js>, value: Value<'js>) -> Result<Vec<u8>, PluginError> {
    if value.is_undefined() {
        return Ok(Vec::new());
    }
    match ctx
        .json_stringify(value)
        .map_err(|e| PluginError::BadAnswer(format!("answer is not JSON: {e}")))?
    {
        Some(s) => {
            Ok(s.to_string().map_err(|e| PluginError::BadAnswer(e.to_string()))?.into_bytes())
        }
        None => Ok(Vec::new()),
    }
}
