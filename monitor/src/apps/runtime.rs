//! A desk app's backend: a component (`monitor/wit/app.wit`) run by
//! wasmtime. Compiled once per package (cached as `<sha256>.cwasm` in a
//! directory only the agent writes), a fresh instance per call or job, so
//! nothing of one is left for the next; what an app keeps goes through `kv`.
//!
//! An app exports `api` (unary calls) and `jobs`; each function returns
//! `result<T, error>` with `sbm:app/types.error`. The frame calls one by name
//! with its parameters as JSON (`apps::value`).
//!
//! Bounds per instance: linear memory ([`MAX_MEMORY`]); CPU by epoch
//! interruption every [`TICK`], yielding to the executor at each tick so one
//! app never holds a thread, and a trap after [`MAX_CPU_TICKS`] of the
//! guest's own work (time in host calls, a script's, is not counted); a call
//! ends after [`CALL_WALL`].

use std::collections::BTreeMap;
use std::path::Path;
use std::sync::{Arc, OnceLock};
use std::time::Duration;

use serde_json::Value;
use tokio::sync::mpsc;
use wasmtime::component::types::ComponentItem;
use wasmtime::component::{Component, ComponentExportIndex, HasSelf, InstancePre, Linker, ResourceTable, Type, Val};
use wasmtime::{Config, Engine, Store, StoreLimits, StoreLimitsBuilder, UpdateDeadline};
use wasmtime_wasi::{WasiCtx, WasiCtxView, WasiView};
use zeroize::Zeroizing;

use super::value;
use crate::agent_mode::command::{self, Spec, Stream};
use crate::api::server::AppState;
use crate::stacks::job::Job;

wasmtime::component::bindgen!({
    path: "wit",
    world: "sbm:app/imports",
    imports: { default: async },
});

pub use sbm::app::types::Error as AppError;
use sbm::app::types::Output;

pub const MAX_MEMORY: usize = 64 << 20;
/// Core instances in one component (the app, the WASI adapter, shims).
const MAX_CORE_INSTANCES: usize = 16;
const TICK: Duration = Duration::from_millis(10);
/// 10 s of the guest's own work.
const MAX_CPU_TICKS: u64 = 1000;
/// A unary call's longest, a script it runs as root included.
pub const CALL_WALL: Duration = Duration::from_secs(60);
/// A job's script's longest run: an install over a slow line.
const JOB_SCRIPT_TIMEOUT: Duration = Duration::from_secs(3 * 3600);
/// What a script's output may hold, each stream.
const MAX_OUTPUT: usize = 8 << 20;
/// A log line from an app.
const MAX_LOG: usize = 1024;
/// A private file's contents, and how many a job may hold.
const MAX_PRIVATE_FILE: usize = 64 << 10;
#[cfg(unix)]
const MAX_PRIVATE_FILES: usize = 8;
/// A JSON text an app keeps under one key (the app's whole storage is
/// bounded by `desk_storage`).
const MAX_KV_VALUE: usize = 256 << 10;

/// The service an app offers: its functions by kind.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Kind {
    Call,
    Job,
}

/// Why a call did not answer with the app's own value or error.
#[derive(Debug)]
pub enum Failure {
    /// No such function in the app's `api` or `jobs`.
    Unknown,
    /// The parameters do not fit its types.
    Arguments(String),
    /// Its own `error`.
    App(AppError),
    /// Out of CPU or memory, or a trap.
    Trap(String),
    Deadline,
    Cancelled,
}

struct Method {
    index: ComponentExportIndex,
    params: Vec<(String, Type)>,
}

/// A package's backend, compiled and linked, and the functions it offers.
pub struct Backend {
    pre: InstancePre<Ctx>,
    methods: BTreeMap<(Kind, String), Method>,
}

fn engine() -> &'static Engine {
    static ENGINE: OnceLock<Engine> = OnceLock::new();
    ENGINE.get_or_init(|| {
        let mut config = Config::new();
        config.wasm_component_model(true).epoch_interruption(true);
        let engine = Engine::new(&config).expect("wasmtime engine");
        let ticker = engine.weak();
        std::thread::Builder::new()
            .name("wasm-epoch".into())
            .spawn(move || {
                while let Some(engine) = ticker.upgrade() {
                    engine.increment_epoch();
                    drop(engine);
                    std::thread::sleep(TICK);
                }
            })
            .expect("epoch thread");
        engine
    })
}

fn linker() -> &'static Linker<Ctx> {
    static LINKER: OnceLock<Linker<Ctx>> = OnceLock::new();
    LINKER.get_or_init(|| {
        let mut linker = Linker::new(engine());
        wasmtime_wasi::p2::add_to_linker_async(&mut linker).expect("wasi");
        Imports::add_to_linker::<_, HasSelf<_>>(&mut linker, |c| c).expect("sbm:app");
        linker
    })
}

/// Whether [ty] is `result<T, error>` with this world's `error`.
fn answers_app_result(ty: &Type) -> bool {
    let Type::Result(r) = ty else { return false };
    let Some(Type::Variant(v)) = r.err() else { return false };
    let cases: Vec<&str> = v.cases().map(|c| c.name).collect();
    cases
        == [
            "invalid-argument",
            "not-found",
            "already-exists",
            "permission-denied",
            "failed-precondition",
            "unavailable",
            "deadline-exceeded",
            "cancelled",
            "internal",
        ]
}

impl Backend {
    /// From the component's bytes ([sha256] their digest), through [cache]:
    /// a directory only this agent writes, `<sha256>.cwasm` made on first
    /// use. Refused when it is not a component of this world, or a function
    /// takes or answers what JSON cannot carry.
    pub fn load(bytes: &[u8], sha256: &str, cache: &Path) -> Result<Self, String> {
        let engine = engine();
        let cached = cache.join(format!("{sha256}.cwasm"));
        // SAFETY: the file is this agent's own compilation (a protected
        // directory, named by the source's digest); one from another
        // wasmtime build is refused by deserialize and compiled again.
        let component = match unsafe { Component::deserialize_file(engine, &cached) } {
            Ok(c) => c,
            Err(_) => {
                let c = Component::from_binary(engine, bytes).map_err(|e| format!("not a component: {e}"))?;
                if let Ok(serialized) = c.serialize() {
                    let _ = std::fs::create_dir_all(cache);
                    let tmp = cached.with_extension("part");
                    if std::fs::write(&tmp, serialized).is_ok() {
                        let _ = std::fs::rename(&tmp, &cached);
                    }
                }
                c
            }
        };
        let pre = linker().instantiate_pre(&component).map_err(|e| format!("imports: {e}"))?;
        let mut methods = BTreeMap::new();
        for (name, item) in component.component_type().exports(engine) {
            let kind = match name.split('@').next().unwrap_or(name).rsplit_once('/') {
                Some((_, "api")) => Kind::Call,
                Some((_, "jobs")) => Kind::Job,
                _ => continue,
            };
            let ComponentItem::ComponentInstance(instance) = item.ty else { continue };
            let instance_index = component.get_export_index(None, name).ok_or("export index")?;
            for (fname, item) in instance.exports(engine) {
                let ComponentItem::ComponentFunc(func) = item.ty else { continue };
                let params: Vec<(String, Type)> = func.params().map(|(n, t)| (n.to_string(), t)).collect();
                let results: Vec<Type> = func.results().collect();
                if results.len() != 1 || !answers_app_result(&results[0]) {
                    return Err(format!("{fname}: does not answer result<_, error>"));
                }
                for (_, t) in &params {
                    value::check(t).map_err(|e| format!("{fname}: {e}"))?;
                }
                value::check(&results[0]).map_err(|e| format!("{fname}: {e}"))?;
                let index = component.get_export_index(Some(&instance_index), fname).ok_or("export index")?;
                methods.insert((kind, value::camel(fname)), Method { index, params });
            }
        }
        Ok(Self { pre, methods })
    }

    /// The function names of [kind].
    pub fn names(&self, kind: Kind) -> Vec<&str> {
        self.methods.keys().filter(|(k, _)| *k == kind).map(|(_, n)| n.as_str()).collect()
    }

    /// Runs [name] of [kind] with [args] (an object by parameter name, in
    /// camelCase) as [ctx] allows; its value as JSON. A job's runs until it
    /// returns or its job is cancelled; a call's for [`CALL_WALL`] at most.
    pub async fn invoke(&self, kind: Kind, name: &str, args: &Value, ctx: Ctx) -> Result<Value, Failure> {
        let method = self.methods.get(&(kind, name.to_string())).ok_or(Failure::Unknown)?;
        let empty = serde_json::Map::new();
        let obj = match args {
            Value::Null => &empty,
            Value::Object(o) => o,
            _ => return Err(Failure::Arguments("$: expected an object".into())),
        };
        if let Some(extra) = obj.keys().find(|k| !method.params.iter().any(|(n, _)| value::camel(n) == **k)) {
            return Err(Failure::Arguments(format!("$: unknown parameter {extra}")));
        }
        let params: Vec<Val> = method
            .params
            .iter()
            .map(|(n, t)| {
                let key = value::camel(n);
                value::from_json_at_param(t, obj.get(&key).unwrap_or(&Value::Null), &key)
            })
            .collect::<Result<_, _>>()
            .map_err(Failure::Arguments)?;
        let cancel = ctx.job.as_ref().map(|j| j.cancel_token());
        let run = async {
            let mut store = Store::new(engine(), ctx);
            store.limiter(|c| &mut c.limits);
            store.set_epoch_deadline(1);
            store.epoch_deadline_callback(|mut s| {
                let c = s.data_mut();
                c.cpu_ticks += 1;
                if c.cpu_ticks > MAX_CPU_TICKS {
                    return Ok(UpdateDeadline::Interrupt);
                }
                Ok(UpdateDeadline::Yield(1))
            });
            let instance = self.pre.instantiate_async(&mut store).await.map_err(|e| Failure::Trap(format!("{e:#}")))?;
            let func = instance.get_func(&mut store, method.index).ok_or(Failure::Unknown)?;
            let mut results = [Val::Bool(false)];
            func.call_async(&mut store, &params, &mut results).await.map_err(|e| Failure::Trap(format!("{e:#}")))?;
            let [answer] = results;
            Ok::<_, Failure>(answer)
        };
        let answer = match (kind, cancel) {
            (Kind::Job, Some(cancel)) => tokio::select! {
                answer = run => answer?,
                () = cancel.cancelled() => return Err(Failure::Cancelled),
            },
            _ => tokio::time::timeout(CALL_WALL, run).await.map_err(|_| Failure::Deadline)??,
        };
        match answer {
            Val::Result(Ok(v)) => Ok(v.as_deref().map_or(Value::Null, value::to_json)),
            Val::Result(Err(Some(e))) => Err(Failure::App(app_error(&e))),
            _ => Err(Failure::Trap("not a result".into())),
        }
    }
}

/// The guest's `error` variant back as the host's type.
fn app_error(v: &Val) -> AppError {
    let Val::Variant(case, payload) = v else { return AppError::Internal("malformed error".into()) };
    let text = match payload.as_deref() {
        Some(Val::String(s)) => s.chars().take(MAX_LOG).collect(),
        _ => String::new(),
    };
    match case.as_str() {
        "invalid-argument" => AppError::InvalidArgument(text),
        "not-found" => AppError::NotFound(text),
        "already-exists" => AppError::AlreadyExists(text),
        "permission-denied" => AppError::PermissionDenied(text),
        "failed-precondition" => AppError::FailedPrecondition(text),
        "unavailable" => AppError::Unavailable(text),
        "deadline-exceeded" => AppError::DeadlineExceeded,
        "cancelled" => AppError::Cancelled,
        _ => AppError::Internal(text),
    }
}

/// [e]'s code and message, as the frame gets them.
pub fn error_code(e: &AppError) -> (&'static str, String) {
    match e {
        AppError::InvalidArgument(m) => ("invalidArgument", m.clone()),
        AppError::NotFound(m) => ("notFound", m.clone()),
        AppError::AlreadyExists(m) => ("alreadyExists", m.clone()),
        AppError::PermissionDenied(m) => ("permissionDenied", m.clone()),
        AppError::FailedPrecondition(m) => ("failedPrecondition", m.clone()),
        AppError::Unavailable(m) => ("unavailable", m.clone()),
        AppError::DeadlineExceeded => ("deadlineExceeded", String::new()),
        AppError::Cancelled => ("cancelled", String::new()),
        AppError::Internal(m) => ("internal", m.clone()),
    }
}

/// Who a call is for and what it may reach.
pub struct Grant {
    pub state: Arc<AppState>,
    pub app: String,
    /// The calling account (`users.id`): whose app storage.
    pub user: i64,
    /// What the admin approved for the app.
    pub permissions: Vec<String>,
    /// Whether the machine may be acted on over the link the call came by
    /// (`Caller::check`), and why not.
    pub reach: Result<(), String>,
}

impl Grant {
    fn may(&self, permission: &str) -> Result<(), AppError> {
        if !self.permissions.iter().any(|p| p == permission) {
            return Err(AppError::PermissionDenied(permission.into()));
        }
        self.reach.clone().map_err(AppError::PermissionDenied)
    }
}

pub struct Ctx {
    wasi: WasiCtx,
    table: ResourceTable,
    limits: StoreLimits,
    cpu_ticks: u64,
    grant: Grant,
    password: Option<Zeroizing<String>>,
    job: Option<Arc<Job>>,
    /// The job's private files, removed with it.
    #[cfg(unix)]
    private: Vec<crate::api::machine::PrivateScript>,
}

impl Ctx {
    /// For a call ([job] none) or a job; [password] is sudo's, when the
    /// caller gave one.
    pub fn new(grant: Grant, password: Option<Zeroizing<String>>, job: Option<Arc<Job>>) -> Self {
        Self {
            // Nothing of the host: no preopens, environment, arguments or
            // network; stdio discarded.
            wasi: WasiCtx::builder().build(),
            table: ResourceTable::new(),
            limits: StoreLimitsBuilder::new().memory_size(MAX_MEMORY).instances(MAX_CORE_INSTANCES).build(),
            cpu_ticks: 0,
            grant,
            password,
            job,
            #[cfg(unix)]
            private: Vec::new(),
        }
    }

    /// The same, for [job]: its lines, its cancel.
    pub fn with_job(mut self, job: Arc<Job>) -> Self {
        self.job = Some(job);
        self
    }

    fn script_timeout(&self) -> Duration {
        if self.job.is_some() { JOB_SCRIPT_TIMEOUT } else { CALL_WALL }
    }

    fn cancel(&self) -> fl_pi_llm::host::Cancel {
        self.job.as_ref().map(|j| j.cancel_token()).unwrap_or_default()
    }
}

/// Runs [script] as root (`sudo -S` with [password], an empty one for root
/// and `NOPASSWD`); each line to [on_line].
async fn root(
    password: Zeroizing<String>,
    script: &str,
    timeout: Duration,
    cancel: fl_pi_llm::host::Cancel,
    mut on_line: impl FnMut(Stream, String) + Send,
) -> Result<i32, AppError> {
    let (tx, mut rx) = mpsc::unbounded_channel::<(Stream, String)>();
    let run = command::run(Spec { command: script, sudo_password: Some(&password), timeout }, tx, &cancel);
    let drain = async {
        while let Some((stream, line)) = rx.recv().await {
            on_line(stream, line);
        }
    };
    let (finished, ()) = tokio::join!(run, drain);
    let f = finished.map_err(|e| AppError::Internal(e.to_string()))?;
    if f.cancelled {
        return Err(AppError::Cancelled);
    }
    if f.timed_out {
        return Err(AppError::DeadlineExceeded);
    }
    Ok(f.exit_code.unwrap_or(-1))
}

impl WasiView for Ctx {
    fn ctx(&mut self) -> WasiCtxView<'_> {
        WasiCtxView { ctx: &mut self.wasi, table: &mut self.table }
    }
}

impl sbm::app::types::Host for Ctx {}

impl sbm::app::host::Host for Ctx {
    async fn log(&mut self, level: sbm::app::host::Level, message: String) {
        use sbm::app::host::Level;
        // One line of the agent's log, never one that passes for another.
        let message: String = message.chars().filter(|c| !c.is_control()).take(MAX_LOG).collect();
        let app = &self.grant.app;
        match level {
            Level::Debug => tracing::debug!(app = %app, "app log: {message}"),
            Level::Info => tracing::info!(app = %app, "app log: {message}"),
            Level::Warn => tracing::warn!(app = %app, "app log: {message}"),
            Level::Error => tracing::error!(app = %app, "app log: {message}"),
        }
    }

    async fn exec(&mut self, script: String, stdin: Option<Vec<u8>>) -> Result<Output, AppError> {
        self.grant.may("process")?;
        let stdin = stdin.map(|b| String::from_utf8_lossy(&b).into_owned());
        let state = self.grant.state.clone();
        // A listing (packages, kernels) is longer than `/exec`'s own cap.
        let limits = crate::api::machine::at_least(&state.remote_access.exec, MAX_OUTPUT);
        let out = crate::api::exec::run(&script, stdin.as_deref(), None, &limits)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;
        if out.timed_out {
            return Err(AppError::DeadlineExceeded);
        }
        Ok(Output { status: out.exit_code.unwrap_or(-1), stdout: out.stdout.into_bytes(), stderr: out.stderr.into_bytes() })
    }

    async fn exec_root(&mut self, script: String) -> Result<Output, AppError> {
        self.grant.may("root")?;
        let password = self.password.clone().ok_or_else(|| AppError::PermissionDenied("sudo".into()))?;
        let (mut stdout, mut stderr) = (Vec::new(), Vec::new());
        let status = root(password, &script, self.script_timeout(), self.cancel(), |stream, line| {
            let buf = if stream == Stream::Out { &mut stdout } else { &mut stderr };
            if buf.len() + line.len() < MAX_OUTPUT {
                buf.extend_from_slice(line.as_bytes());
                buf.push(b'\n');
            }
        })
        .await?;
        Ok(Output { status, stdout, stderr })
    }

    async fn kv_get(&mut self, key: String) -> Option<String> {
        if !crate::api::desk_storage::key_ok(&key) {
            return None;
        }
        let items = crate::api::desk_storage::items(&self.grant.state.db, self.grant.user, &self.grant.app).await.ok()?;
        items.get(&key).map(Value::to_string)
    }

    async fn kv_set(&mut self, key: String, value: String) -> Result<(), AppError> {
        if !crate::api::desk_storage::key_ok(&key) {
            return Err(AppError::InvalidArgument("key".into()));
        }
        if value.len() > MAX_KV_VALUE || serde_json::from_str::<Value>(&value).is_err() {
            return Err(AppError::InvalidArgument("value: a JSON text".into()));
        }
        match crate::api::desk_storage::store(&self.grant.state.db, self.grant.user, &self.grant.app, &key, &value).await {
            Ok(true) => Ok(()),
            Ok(false) => Err(AppError::Unavailable("storageFull".into())),
            Err(e) => {
                tracing::error!("app kv: {e}");
                Err(AppError::Internal("storage".into()))
            }
        }
    }

    async fn kv_remove(&mut self, key: String) {
        if crate::api::desk_storage::key_ok(&key) {
            let _ = crate::api::desk_storage::remove_key(&self.grant.state.db, self.grant.user, &self.grant.app, &key).await;
        }
    }

    async fn home(&mut self) -> Option<String> {
        std::env::var("HOME").ok()
    }

    async fn status(&mut self) -> Result<String, AppError> {
        self.grant.may("status")?;
        let metrics = self.grant.state.current_metrics.read().await;
        let m = metrics.as_ref().ok_or_else(|| AppError::Unavailable("noSample".into()))?;
        serde_json::to_string(m).map_err(|e| AppError::Internal(e.to_string()))
    }
}

impl sbm::app::agent::Host for Ctx {
    async fn holds_state(&mut self, path: String) -> bool {
        let canonical = std::fs::canonicalize(&path).unwrap_or_else(|_| Path::new(&path).to_path_buf());
        self.grant.state.remote_access.fs.roots.check_mutable(&canonical).is_err()
    }

    async fn stack_leftovers(&mut self) -> Vec<(String, String)> {
        let state = self.grant.state.clone();
        let installed: Vec<String> = crate::stacks::store::all(&state.db).await.map(|rows| rows.into_iter().map(|r| r.id).collect()).unwrap_or_default();
        state.stacks.leftovers(&installed).into_iter().map(|(id, path)| (id, path.to_string_lossy().into_owned())).collect()
    }
}

impl sbm::app::job::Host for Ctx {
    async fn line(&mut self, text: String) {
        if let Some(job) = &self.job {
            job.push(text.chars().take(4 * MAX_LOG).collect::<String>());
        }
    }

    async fn run_root(&mut self, script: String) -> Result<i32, AppError> {
        let job = self.job.clone().ok_or_else(|| AppError::FailedPrecondition("notAJob".into()))?;
        self.grant.may("root")?;
        let password = self.password.clone().ok_or_else(|| AppError::PermissionDenied("sudo".into()))?;
        job.push(format!("# {script}"));
        root(password, &script, JOB_SCRIPT_TIMEOUT, job.cancel_token(), |_, line| job.push(line)).await
    }

    async fn private_file(&mut self, contents: Vec<u8>) -> Result<String, AppError> {
        if self.job.is_none() {
            return Err(AppError::FailedPrecondition("notAJob".into()));
        }
        if contents.len() > MAX_PRIVATE_FILE {
            return Err(AppError::InvalidArgument("tooLarge".into()));
        }
        #[cfg(unix)]
        {
            if self.private.len() >= MAX_PRIVATE_FILES {
                return Err(AppError::Unavailable("tooMany".into()));
            }
            let text = String::from_utf8(contents).map_err(|_| AppError::InvalidArgument("utf8".into()))?;
            let file = crate::api::machine::PrivateScript::write(&text).map_err(|e| AppError::Internal(e.to_string()))?;
            let path = file.path().to_string_lossy().into_owned();
            self.private.push(file);
            Ok(path)
        }
        #[cfg(not(unix))]
        {
            let _ = contents;
            Err(AppError::Unavailable("notUnix".into()))
        }
    }
}
