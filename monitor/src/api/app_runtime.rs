//! `POST /api/v1/apps/{id}/call` — a desk app's backend (`kind: wasm`), run
//! by the agent (`docs/dev/desk-sys.md`).
//!
//! The backend is a core WebAssembly module (`backend.wasm` in the package)
//! run by an interpreter (wasmi): no JIT, nothing it can reach but what this
//! module links. One fresh instance per call, so nothing of one account's
//! call is left for the next; what an app keeps between calls goes through
//! `kv` (the calling account's app storage).
//!
//! # ABI
//!
//! The module exports `memory`, `sbm_alloc(len: i32) -> i32` and
//! `sbm_call(ptr: i32, len: i32) -> i64`. A call writes the request
//! `{"method", "params", "caller": {"username", "admin"}}` (JSON) into memory
//! from `sbm_alloc` and calls `sbm_call`, which answers where its JSON reply
//! is: `(ptr << 32) | len`. The reply is `{"ok": value}` or `{"error": code}`.
//!
//! It imports one function, `sbm.host(ptr, len) -> i64`: a request
//! `{"fn", "args"}` answered the same way (the answer written into memory the
//! host asks `sbm_alloc` for). Functions:
//!
//! | `fn` | Needs |
//! |---|---|
//! | `log` `{level, message}` | — |
//! | `kv.get/set/remove/keys` `{key, value}` | — (the caller's app storage) |
//! | `status` | `status` |
//! | `fs.list` `{path}`, `fs.read` `{path, offset, length}` | `files.read` and the caller's `files` grant |
//! | `exec` `{cmd, stdin}` | `exec` and the caller's `shell` grant |
//!
//! # Bounds
//!
//! Fuel per call ([`FUEL`]), 64 MiB of memory, one instance, [`MAX_HOST_CALLS`]
//! host calls, 1 MiB per message each way (4 MiB for the reply). A grant is
//! checked when a host function runs, against the account calling, so an app
//! never does more than the person using it may.

use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock};

use base64::Engine as _;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::{Value, json};
use wasmi::{Caller as WasmCaller, Config, Engine, Extern, Linker, Module, Store, StoreLimits, StoreLimitsBuilder};

use super::authz::{self, Caller};
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::core::permissions::Grant;

pub const MAX_REQUEST: usize = 1 << 20;
const MAX_REPLY: usize = 4 << 20;
const MAX_MEMORY: usize = 64 << 20;
/// Work per call: whichever ends first, the fuel or the clock. Given in
/// slices, so the clock is read between them. A call that needs more is a
/// job for a command it starts, not for the agent's request.
const FUEL: u64 = 2_000_000_000;
const FUEL_SLICE: u64 = 20_000_000;
const WALL: std::time::Duration = std::time::Duration::from_secs(10);
const MAX_HOST_CALLS: u32 = 1000;
const MAX_FS_READ: u64 = 1 << 20;
const MAX_LOG: usize = 1024;
const THREAD_STACK: usize = 16 << 20;

/// Calls running at once, all accounts together, and per account.
const MAX_CALLS: usize = 8;
const MAX_CALLS_PER_ACCOUNT: usize = 2;

/// The calls running on one agent (`AppState::app_calls`).
#[derive(Clone)]
pub struct AppCalls {
    slots: Arc<tokio::sync::Semaphore>,
    running: Arc<Mutex<HashMap<String, usize>>>,
}

impl Default for AppCalls {
    fn default() -> Self {
        Self { slots: Arc::new(tokio::sync::Semaphore::new(MAX_CALLS)), running: Default::default() }
    }
}

/// One of an account's [MAX_CALLS_PER_ACCOUNT] running calls, given back
/// when dropped.
struct AccountSlot(Arc<Mutex<HashMap<String, usize>>>, String);

impl AccountSlot {
    fn take(calls: &AppCalls, account: &str) -> Option<Self> {
        let mut running = calls.running.lock().ok()?;
        let n = running.entry(account.to_string()).or_default();
        if *n >= MAX_CALLS_PER_ACCOUNT {
            return None;
        }
        *n += 1;
        Some(Self(calls.running.clone(), account.to_string()))
    }
}

impl Drop for AccountSlot {
    fn drop(&mut self) {
        if let Ok(mut running) = self.0.lock()
            && let Some(n) = running.get_mut(&self.1)
        {
            *n -= 1;
            if *n == 0 {
                running.remove(&self.1);
            }
        }
    }
}

fn engine() -> &'static Engine {
    static ENGINE: OnceLock<Engine> = OnceLock::new();
    ENGINE.get_or_init(|| {
        let mut config = Config::default();
        config.consume_fuel(true);
        Engine::new(&config)
    })
}

/// Compiled modules by app id and package hash: a new version is a new key.
fn modules() -> &'static Mutex<HashMap<(String, String), Module>> {
    static MODULES: OnceLock<Mutex<HashMap<(String, String), Module>>> = OnceLock::new();
    MODULES.get_or_init(Default::default)
}

/// What a host function may reach: the agent, the account calling and what
/// the admin approved for the app.
pub struct Host {
    pub state: Arc<AppState>,
    pub app: String,
    pub caller: Caller,
    pub user: i64,
    pub secure: bool,
    pub permissions: Vec<String>,
    pub runtime: tokio::runtime::Handle,
    limits: StoreLimits,
    calls: u32,
    /// Inside a host function: the guest's `sbm_alloc` reaching `sbm.host`
    /// again would recurse on the native stack without end.
    in_host: bool,
    started: std::time::Instant,
    /// Stopped by the clock inside a host call, rather than by a trap.
    timed_out: bool,
}

impl Host {
    fn allows(&self, permission: &str) -> bool {
        self.permissions.iter().any(|p| p == permission)
    }

    fn grant(&self, grant: Grant) -> Result<(), String> {
        self.caller.check(grant, &self.state, self.secure).map_err(|why| format!("forbidden: {}", why.as_str()))
    }
}

/// An error a guest sees as `{"error": code}`.
fn host_error(code: impl Into<String>) -> Value {
    json!({ "error": code.into() })
}

/// Runs one host function. Blocking: called on a blocking thread, it waits
/// for the agent's async work with the runtime's handle.
fn host_call(host: &mut Host, request: &[u8]) -> Value {
    #[derive(Deserialize)]
    struct Request {
        #[serde(rename = "fn")]
        name: String,
        #[serde(default)]
        args: Value,
    }
    let Ok(request) = serde_json::from_slice::<Request>(request) else { return host_error("invalidRequest") };
    let args = &request.args;
    let text = |k: &str| args.get(k).and_then(Value::as_str);
    let rt = host.runtime.clone();
    match request.name.as_str() {
        "log" => {
            // One line of the agent's log, never one that passes for another.
            let message: String =
                text("message").unwrap_or_default().chars().filter(|c| !c.is_control()).take(MAX_LOG).collect();
            tracing::info!(app = %host.app, user = %host.caller.username, "app log: {message}");
            json!({ "ok": null })
        }
        "kv.get" | "kv.set" | "kv.remove" | "kv.keys" => {
            let db = host.state.db.clone();
            let (user, app) = (host.user, host.app.clone());
            let key = text("key").unwrap_or_default().to_string();
            if request.name != "kv.keys" && !super::desk_storage::key_ok(&key) {
                return host_error("invalidKey");
            }
            let result = rt.block_on(async {
                match request.name.as_str() {
                    "kv.get" => {
                        super::desk_storage::items(&db, user, &app).await.map(|items| items.get(&key).cloned().unwrap_or(Value::Null))
                    }
                    "kv.keys" => super::desk_storage::items(&db, user, &app).await.map(|items| json!(items.keys().collect::<Vec<_>>())),
                    "kv.remove" => super::desk_storage::remove_key(&db, user, &app, &key).await.map(|_| Value::Null),
                    _ => {
                        let value = args.get("value").cloned().unwrap_or(Value::Null).to_string();
                        super::desk_storage::store(&db, user, &app, &key, &value)
                            .await
                            .map(|kept| if kept { Value::Null } else { json!({ "refused": "tooLarge" }) })
                    }
                }
            });
            match result {
                Ok(v) if v.get("refused").is_some() => host_error("tooLarge"),
                Ok(v) => json!({ "ok": v }),
                Err(e) => {
                    tracing::error!("app kv: {e}");
                    host_error("internal")
                }
            }
        }
        "status" => {
            if !host.allows("status") {
                return host_error("notPermitted");
            }
            let state = host.state.clone();
            let metrics = rt.block_on(async { state.current_metrics.read().await.as_ref().map(serde_json::to_value) });
            match metrics {
                Some(Ok(v)) => json!({ "ok": v }),
                _ => host_error("unavailable"),
            }
        }
        "fs.list" | "fs.read" => {
            if !host.allows("files.read") {
                return host_error("notPermitted");
            }
            if let Err(e) = host.grant(Grant::Files) {
                return host_error(e);
            }
            let roots = &host.state.remote_access.fs.roots;
            let Some(path) = text("path") else { return host_error("invalidArgs") };
            let resolved = match roots.resolve_existing(path) {
                Ok(p) => p,
                Err(_) => return host_error("notFound"),
            };
            if request.name == "fs.list" {
                let entries = rt.block_on(async {
                    let mut out = Vec::new();
                    let mut reader = tokio::fs::read_dir(&resolved).await?;
                    while let Some(entry) = reader.next_entry().await? {
                        if roots.hides(&entry.path()) {
                            continue;
                        }
                        let meta = entry.metadata().await.ok();
                        out.push(json!({
                            "name": entry.file_name().to_string_lossy(),
                            "dir": meta.as_ref().is_some_and(|m| m.is_dir()),
                            "size": meta.as_ref().filter(|m| m.is_file()).map(|m| m.len()),
                        }));
                        if out.len() >= 10_000 {
                            break;
                        }
                    }
                    Ok::<_, std::io::Error>(out)
                });
                match entries {
                    Ok(entries) => json!({ "ok": entries }),
                    Err(_) => host_error("failed"),
                }
            } else {
                let offset = args.get("offset").and_then(Value::as_u64).unwrap_or(0);
                let length = args.get("length").and_then(Value::as_u64).unwrap_or(MAX_FS_READ).min(MAX_FS_READ);
                let bytes = rt.block_on(async {
                    use tokio::io::{AsyncReadExt, AsyncSeekExt};
                    // A regular file only: a FIFO or a device would hold the
                    // call past every bound.
                    if !tokio::fs::metadata(&resolved).await?.is_file() {
                        return Err(std::io::Error::other("not a file"));
                    }
                    let mut file = tokio::fs::File::open(&resolved).await?;
                    file.seek(std::io::SeekFrom::Start(offset)).await?;
                    let mut buf = Vec::new();
                    file.take(length).read_to_end(&mut buf).await?;
                    Ok::<_, std::io::Error>(buf)
                });
                match bytes {
                    Ok(bytes) => match String::from_utf8(bytes) {
                        Ok(text) => json!({ "ok": { "text": text } }),
                        Err(e) => json!({ "ok": { "base64": base64::engine::general_purpose::STANDARD.encode(e.as_bytes()) } }),
                    },
                    Err(_) => host_error("failed"),
                }
            }
        }
        "exec" => {
            if !host.allows("exec") {
                return host_error("notPermitted");
            }
            if let Err(e) = host.grant(Grant::Shell) {
                return host_error(e);
            }
            let Some(cmd) = text("cmd") else { return host_error("invalidArgs") };
            let stdin = text("stdin");
            let state = host.state.clone();
            let (app, user) = (host.app.clone(), host.caller.username.clone());
            let result = rt.block_on(async {
                // As `/exec` records a command: its first line, never input.
                Event::new(Kind::Exec, Action::Open, Outcome::Ok)
                    .subject(&user)
                    .detail(format!("app {app}: {}", cmd.lines().next().unwrap_or("").chars().take(200).collect::<String>()))
                    .record(&state.db)
                    .await;
                super::exec::run(cmd, stdin, None, &state.remote_access.exec).await
            });
            match result {
                Ok(out) => json!({ "ok": out }),
                Err(_) => host_error("failed"),
            }
        }
        _ => host_error("unknownFunction"),
    }
}

/// Writes [bytes] into guest memory from its `sbm_alloc`; answers the packed
/// pointer and length.
fn give(caller: &mut WasmCaller<'_, Host>, bytes: &[u8]) -> Result<i64, wasmi::Error> {
    let alloc = caller
        .get_export("sbm_alloc")
        .and_then(Extern::into_func)
        .ok_or_else(|| wasmi::Error::new("sbm_alloc missing"))?
        .typed::<i32, i32>(&*caller)?;
    let len = i32::try_from(bytes.len()).map_err(|_| wasmi::Error::new("too large"))?;
    let ptr = alloc.call(&mut *caller, len)?;
    let memory = caller
        .get_export("memory")
        .and_then(Extern::into_memory)
        .ok_or_else(|| wasmi::Error::new("memory missing"))?;
    memory.write(&mut *caller, ptr as u32 as usize, bytes).map_err(|_| wasmi::Error::new("bad pointer"))?;
    Ok(((ptr as u32 as i64) << 32) | len as i64)
}

fn read_guest(memory: &wasmi::Memory, store: impl wasmi::AsContext, ptr: u32, len: u32, max: usize) -> Result<Vec<u8>, String> {
    if len as usize > max {
        return Err("tooLarge".into());
    }
    let mut buf = vec![0u8; len as usize];
    memory.read(store, ptr as usize, &mut buf).map_err(|_| "badPointer".to_string())?;
    Ok(buf)
}

/// Runs [method] of [wasm] for [host]. Blocking.
pub fn run(wasm_key: (String, String), wasm: &[u8], host: Host, method: &str, params: Value) -> Result<Value, String> {
    let engine = engine();
    let module = {
        let mut cache = modules().lock().map_err(|_| "internal")?;
        match cache.get(&wasm_key) {
            Some(m) => m.clone(),
            None => {
                let m = Module::new(engine, wasm).map_err(|_| "invalidModule")?;
                // One version per app is enough to keep.
                cache.retain(|(app, _), _| app != &wasm_key.0);
                cache.insert(wasm_key.clone(), m.clone());
                m
            }
        }
    };
    let request = serde_json::to_vec(&json!({
        "method": method,
        "params": params,
        "caller": { "username": host.caller.username, "admin": host.caller.is_admin() },
    }))
    .map_err(|_| "internal")?;
    let mut host = host;
    host.limits = StoreLimitsBuilder::new().memory_size(MAX_MEMORY).instances(1).memories(1).tables(1).table_elements(100_000).build();
    let mut store = Store::new(engine, host);
    store.limiter(|h| &mut h.limits);

    let mut linker = <Linker<Host>>::new(engine);
    linker
        .func_wrap("sbm", "host", |mut caller: WasmCaller<'_, Host>, ptr: i32, len: i32| -> Result<i64, wasmi::Error> {
            let memory = caller
                .get_export("memory")
                .and_then(Extern::into_memory)
                .ok_or_else(|| wasmi::Error::new("memory missing"))?;
            let host = caller.data_mut();
            if host.in_host {
                return Err(wasmi::Error::new("sbm.host called from inside sbm.host"));
            }
            host.calls += 1;
            if host.calls > MAX_HOST_CALLS {
                return Err(wasmi::Error::new("too many host calls"));
            }
            if host.started.elapsed() >= WALL {
                host.timed_out = true;
                return Err(wasmi::Error::new("out of time"));
            }
            let request = read_guest(&memory, &caller, ptr as u32, len as u32, MAX_REQUEST).map_err(wasmi::Error::new)?;
            caller.data_mut().in_host = true;
            let answer = host_call(caller.data_mut(), &request);
            let bytes = serde_json::to_vec(&answer).unwrap_or_default();
            // `give` runs the guest's allocator, still inside this call.
            let given = give(&mut caller, &bytes);
            caller.data_mut().in_host = false;
            given
        })
        .map_err(|_| "internal")?;
    let instance = linker.instantiate_and_start(&mut store, &module).map_err(|e| {
        tracing::debug!("app instantiate: {e}");
        "invalidModule".to_string()
    })?;
    let alloc = instance.get_typed_func::<i32, i32>(&store, "sbm_alloc").map_err(|_| "invalidModule")?;
    let call = instance.get_typed_func::<(i32, i32), i64>(&store, "sbm_call").map_err(|_| "invalidModule")?;
    let memory = instance.get_memory(&store, "memory").ok_or("invalidModule")?;

    let len = i32::try_from(request.len()).map_err(|_| "tooLarge")?;
    let started = store.data().started;
    let mut spent = 0;
    let ptr = bounded(&mut store, &alloc, len, started, &mut spent)?;
    memory.write(&mut store, ptr as u32 as usize, &request).map_err(|_| "badPointer")?;
    let packed = bounded(&mut store, &call, (ptr, len), started, &mut spent)?;
    let reply = read_guest(&memory, &store, (packed >> 32) as u32, packed as u32, MAX_REPLY)?;
    serde_json::from_slice::<Value>(&reply).map_err(|_| "invalidReply".to_string())
}

/// Calls [func] a fuel slice at a time until it ends, the fuel is spent or
/// [WALL] has passed since [started]; `tooLong` for the last two.
fn bounded<P: wasmi::WasmParams, R: wasmi::WasmResults>(
    store: &mut Store<Host>,
    func: &wasmi::TypedFunc<P, R>,
    params: P,
    started: std::time::Instant,
    spent: &mut u64,
) -> Result<R, String> {
    store.set_fuel(FUEL_SLICE).map_err(|_| "internal")?;
    let code = |store: &Store<Host>, e: &wasmi::Error| if store.data().timed_out { "tooLong".to_string() } else { trap_code(e) };
    let mut call = func.call_resumable(&mut *store, params).map_err(|e| code(store, &e))?;
    loop {
        match call {
            wasmi::TypedResumableCall::Finished(results) => return Ok(results),
            // No host function here traps to be resumed.
            wasmi::TypedResumableCall::HostTrap(_) => return Err("trap".into()),
            wasmi::TypedResumableCall::OutOfFuel(invocation) => {
                *spent += FUEL_SLICE;
                if *spent >= FUEL || started.elapsed() >= WALL {
                    return Err("tooLong".into());
                }
                store.set_fuel(FUEL_SLICE.max(invocation.required_fuel())).map_err(|_| "internal")?;
                call = invocation.resume(&mut *store).map_err(|e| code(store, &e))?;
            }
        }
    }
}

fn trap_code(e: &wasmi::Error) -> String {
    tracing::debug!("app trap: {e}");
    "trap".into()
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CallBody {
    method: String,
    #[serde(default)]
    params: Value,
}

pub async fn call(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<CallBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = match authz::jwt_caller(&req, &state).await {
        Ok(c) => c,
        Err(response) => return Ok(response),
    };
    let body = body.into_inner();
    if !(1..=64).contains(&body.method.len()) {
        return Ok(HttpResponse::BadRequest().json(&json!({ "error": "invalidMethod" })));
    }
    // Bounded together and per account: a call holds a thread and up to
    // 64 MiB until its bounds end it.
    let Ok(_global) = state.app_calls.slots.clone().try_acquire_owned() else {
        return Ok(HttpResponse::TooManyRequests().json(&json!({ "error": "busy" })));
    };
    let Some(_mine) = AccountSlot::take(&state.app_calls, &caller.username) else {
        return Ok(HttpResponse::TooManyRequests().json(&json!({ "error": "busy" })));
    };
    let user: Option<i64> = match sqlx::query_scalar("SELECT id FROM users WHERE username = ?").bind(&caller.username).fetch_optional(&state.db).await {
        Ok(u) => u,
        Err(e) => return Ok(super::desk::internal_error(&e)),
    };
    let Some(user) = user else { return Ok(HttpResponse::Unauthorized().finish()) };
    let row: Option<(String, Option<String>, String, Vec<u8>)> = match sqlx::query_as(
        "SELECT p.manifest, p.approved_permissions, p.sha256, f.bytes FROM desk_app_package p \
         JOIN desk_app_file f ON f.app_id = p.app_id AND f.path = 'backend.wasm' WHERE p.app_id = ?",
    )
    .bind(id.as_str())
    .fetch_optional(&state.db)
    .await
    {
        Ok(r) => r,
        Err(e) => return Ok(super::desk::internal_error(&e)),
    };
    let Some((_, Some(approved), sha, wasm)) = row else {
        return Ok(HttpResponse::NotFound().json(&json!({ "error": "notFound" })));
    };
    let permissions: Vec<String> = serde_json::from_str(&approved).unwrap_or_default();
    let host = Host {
        state: state.get_ref().clone(),
        app: id.clone(),
        caller: caller.clone(),
        user,
        secure: authz::is_secure(&req, &state),
        permissions,
        runtime: tokio::runtime::Handle::current(),
        limits: StoreLimits::default(),
        calls: 0,
        in_host: false,
        started: std::time::Instant::now(),
        timed_out: false,
    };
    let key = (id.clone(), sha);
    let method = body.method.clone();
    let params = body.params;
    // A thread of its own with room for the interpreter's stack (a blocking
    // pool thread's 2 MiB is not enough in a debug build), awaited here.
    let (tx, rx) = tokio::sync::oneshot::channel();
    let spawned = std::thread::Builder::new()
        .name("sbm-app".into())
        .stack_size(THREAD_STACK)
        .spawn(move || {
            let _ = tx.send(run(key, &wasm, host, &method, params));
        });
    if spawned.is_err() {
        return Ok(HttpResponse::ServiceUnavailable().json(&json!({ "error": "busy" })));
    }
    // The thread ends by its own bounds; a reply later than that is not
    // waited for.
    let outcome = match tokio::time::timeout(WALL + std::time::Duration::from_secs(30), rx).await {
        Ok(outcome) => outcome,
        Err(_) => return Ok(HttpResponse::GatewayTimeout().json(&json!({ "error": "tooLong" }))),
    };
    tracing::info!(app = %id.as_str(), user = %caller.username, ip = ?peer_ip(&req), "app call {}", body.method);
    match outcome {
        Ok(Ok(reply)) => Ok(HttpResponse::Ok().json(&reply)),
        Ok(Err(code)) => Ok(HttpResponse::UnprocessableEntity().json(&json!({ "error": code }))),
        Err(_) => Ok(HttpResponse::InternalServerError().json(&json!({ "error": "internal" }))),
    }
}
