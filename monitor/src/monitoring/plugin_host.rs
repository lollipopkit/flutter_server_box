//! What a plugin's `sb.*` reaches on this agent. PLUGINS.md 9.5.1.
//!
//! Five functions, because that is what the agent host has: everything with a
//! person in it — `sb.ui`, `sb.nav`, `sb.clipboard` — is a stub that throws
//! before it gets here, and so is `sb.server.list`, since an agent knows one
//! machine and that machine is itself.
//!
//! `sb.server.exec` is not among them either, and that is not an omission: a
//! status plugin says what to run and the agent runs it (`plugins.rs`), so a
//! plugin never issues the command itself — and there is no server handle here
//! for it to name. What is left is storage, the network, and the log.

use std::sync::{Arc, Mutex};

use sbm_plugin::{BridgeError, CallCtx, HostBridge, HostCall, HostFn, LogLevel, PendingCall};
use serde::Deserialize;
use serde_json::json;
use sqlx::SqlitePool;
use tokio::runtime::{Builder, Handle, Runtime};
use tracing::{error, info, warn};

use super::plugin_http::{self, FetchRequest};

/// The agent's answer to `sb.*`.
pub struct AgentBridge {
    pool: SqlitePool,
    /// Where an async answer is spawned, and **its own**.
    ///
    /// Not the caller's. A plugin asks from a thread of its own and the host
    /// call blocks whichever thread asked for it, which for a status plugin is
    /// the monitoring loop's — and that loop runs on the agent's single
    /// `#[ntex::main]` thread. Spawning the answer there would leave it
    /// waiting for a thread that is waiting for it: the plugin never returns,
    /// the loop never ticks again, and the HTTP server on the same thread
    /// stops with it.
    ///
    /// `Option` only so [`Drop`] can hand it away — see below.
    runtime: Option<Runtime>,
    /// Bounds one answer. A plugin cannot raise it — see [`plugin_http`].
    http_timeout: std::time::Duration,
}

impl AgentBridge {
    /// Two threads, which is what the whole plugin set shares.
    ///
    /// Nothing here is compute: a store call waits on SQLite and a fetch waits
    /// on a socket. The agent's own work is what the machine is for.
    const THREADS: usize = 2;

    pub fn new(pool: SqlitePool) -> std::io::Result<Self> {
        let runtime = Builder::new_multi_thread()
            .worker_threads(Self::THREADS)
            .thread_name("sbm-plugin-host")
            .enable_all()
            .build()?;
        Ok(Self {
            pool,
            runtime: Some(runtime),
            http_timeout: std::time::Duration::from_secs(30),
        })
    }

    fn handle(&self) -> &Handle {
        self.runtime.as_ref().expect("taken only by Drop").handle()
    }
}

/// Dropping a [`Runtime`] blocks until its threads are done, and doing that
/// from inside another runtime's thread panics. This is held by the monitoring
/// loop, which is exactly such a thread, so shutdown is handed to the runtime
/// itself rather than waited for.
impl Drop for AgentBridge {
    fn drop(&mut self) {
        if let Some(runtime) = self.runtime.take() {
            runtime.shutdown_background();
        }
    }
}

impl HostBridge for AgentBridge {
    fn call(&self, ctx: CallCtx<'_>, func: HostFn, request: &[u8]) -> HostCall {
        let plugin_id = ctx.plugin_id.to_string();
        match func {
            HostFn::StoreGet | HostFn::StoreSet | HostFn::StoreList => {
                let pool = self.pool.clone();
                let body = request.to_vec();
                spawn(self.handle(), async move {
                    store_call(&pool, &plugin_id, func, &body).await
                })
            }
            HostFn::HttpFetch => {
                let body = request.to_vec();
                let timeout = self.http_timeout;
                spawn(self.handle(), async move {
                    let req: FetchRequest = serde_json::from_slice(&body).map_err(|e| {
                        BridgeError::failed("bad_request", format!("sb.http.fetch: {e}"))
                    })?;
                    plugin_http::fetch(req, timeout).await
                })
            }
            HostFn::DiagCrumb => {
                match serde_json::from_slice::<Crumb>(request) {
                    // The name and the level, never anything a plugin put
                    // around them: a crumb says that something happened, and
                    // what happened is the plugin's own business.
                    Ok(crumb) if !crumb.name.is_empty() => {
                        let id = ctx.plugin_id;
                        match crumb.level.as_str() {
                            "error" => error!("plugin {id}: {}", crumb.name),
                            "warn" => warn!("plugin {id}: {}", crumb.name),
                            _ => info!("plugin {id}: {}", crumb.name),
                        }
                        HostCall::Ready(Ok(b"null".to_vec()))
                    }
                    _ => HostCall::err(BridgeError::failed(
                        "bad_request",
                        "sb.diag.crumb: no `name`",
                    )),
                }
            }
            // Everything else is a stub that throws before reaching a bridge,
            // so arriving here at all means the two lists have drifted.
            other => HostCall::err(BridgeError::failed(
                "unsupported",
                format!("{} is not on the agent host", other.path()),
            )),
        }
    }

    fn log(&self, ctx: CallCtx<'_>, level: LogLevel, message: &str) {
        // The plugin's id, never the message's contents beyond what it wrote:
        // a plugin's log line is its own, and this is where it goes.
        match level {
            LogLevel::Error => error!("plugin {}: {message}", ctx.plugin_id),
            LogLevel::Warn => warn!("plugin {}: {message}", ctx.plugin_id),
            _ => info!("plugin {}: {message}", ctx.plugin_id),
        }
    }
}

/// Runs [`work`] on the runtime and hands back something the plugin's thread
/// can poll.
///
/// `poll` rather than a channel receive, because the plugin thread is inside a
/// synchronous host call and must not block a tokio worker by waiting on one.
fn spawn<F>(runtime: &Handle, work: F) -> HostCall
where
    F: std::future::Future<Output = Result<Vec<u8>, BridgeError>> + Send + 'static,
{
    let slot: Arc<Mutex<Option<Result<Vec<u8>, BridgeError>>>> = Arc::new(Mutex::new(None));
    let write = Arc::clone(&slot);
    let task = runtime.spawn(async move {
        let answer = work.await;
        *write.lock().expect("poisoned") = Some(answer);
    });
    HostCall::Pending(Box::new(Spawned { slot, task: Some(task) }))
}

struct Spawned {
    slot: Arc<Mutex<Option<Result<Vec<u8>, BridgeError>>>>,
    task: Option<tokio::task::JoinHandle<()>>,
}

impl PendingCall for Spawned {
    fn poll(&mut self) -> Option<Result<Vec<u8>, BridgeError>> {
        self.slot.lock().expect("poisoned").take()
    }

    /// The instance is going away, so the answer is not wanted — and an HTTP
    /// request left to finish into nothing holds a connection open for its
    /// whole timeout.
    fn cancel(&mut self) {
        if let Some(task) = self.task.take() {
            task.abort();
        }
    }
}

/// `{name, level?}`, as `sb.diag.crumb` sends it.
#[derive(Deserialize)]
struct Crumb {
    #[serde(default)]
    name: String,
    #[serde(default = "info")]
    level: String,
}

fn info() -> String {
    "info".to_string()
}

#[derive(Deserialize)]
struct StoreRequest {
    scope: String,
    #[serde(default)]
    key: String,
    #[serde(default)]
    prefix: String,
    /// Absent or null deletes, which is what the app's store does too.
    #[serde(default)]
    value: Option<String>,
}

async fn store_call(
    pool: &SqlitePool,
    plugin_id: &str,
    func: HostFn,
    body: &[u8],
) -> Result<Vec<u8>, BridgeError> {
    let req: StoreRequest = serde_json::from_slice(body)
        .map_err(|e| BridgeError::failed("bad_request", format!("{}: {e}", func.path())))?;

    // Two scopes, as on the app. `server` means "this machine" in both, and
    // here there is only one — but a plugin writing to `server` in the app and
    // reading it here would otherwise find nothing.
    if req.scope != "global" && req.scope != "server" {
        return Err(BridgeError::failed(
            "bad_request",
            format!("{}: unknown scope `{}`", func.path(), req.scope),
        ));
    }
    // The app refuses one too. A key a plugin forgot to fill in is a bug it
    // should be told about, and finding it here and not there would be worse
    // than either.
    if func != HostFn::StoreList && req.key.is_empty() {
        return Err(BridgeError::failed(
            "bad_request",
            format!("{}: no `key`", func.path()),
        ));
    }
    let failed = |e: sqlx::Error| BridgeError::failed("io", format!("{}: {e}", func.path()));

    match func {
        HostFn::StoreGet => {
            let row: Option<(String,)> = sqlx::query_as(
                "SELECT value FROM plugin_kv WHERE plugin_id = ? AND scope = ? AND key = ?",
            )
            .bind(plugin_id)
            .bind(&req.scope)
            .bind(&req.key)
            .fetch_optional(pool)
            .await
            .map_err(failed)?;
            Ok(json!({ "value": row.map(|r| r.0) }).to_string().into_bytes())
        }
        HostFn::StoreSet => match req.value {
            Some(value) => {
                sqlx::query(
                    "INSERT INTO plugin_kv (plugin_id, scope, key, value, updated_at) \
                     VALUES (?, ?, ?, ?, ?) \
                     ON CONFLICT (plugin_id, scope, key) \
                     DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at",
                )
                .bind(plugin_id)
                .bind(&req.scope)
                .bind(&req.key)
                .bind(&value)
                .bind(chrono::Utc::now().timestamp())
                .execute(pool)
                .await
                .map_err(failed)?;
                Ok(b"null".to_vec())
            }
            None => {
                sqlx::query(
                    "DELETE FROM plugin_kv WHERE plugin_id = ? AND scope = ? AND key = ?",
                )
                .bind(plugin_id)
                .bind(&req.scope)
                .bind(&req.key)
                .execute(pool)
                .await
                .map_err(failed)?;
                Ok(b"null".to_vec())
            }
        },
        HostFn::StoreList => {
            // `LIKE` with the prefix escaped, so a key containing `%` or `_`
            // does not match more than it should — a plugin's keys are its
            // own strings and may contain anything.
            let pattern = format!("{}%", escape_like(&req.prefix));
            let rows: Vec<(String,)> = sqlx::query_as(
                "SELECT key FROM plugin_kv \
                 WHERE plugin_id = ? AND scope = ? AND key LIKE ? ESCAPE '\\' \
                 ORDER BY key",
            )
            .bind(plugin_id)
            .bind(&req.scope)
            .bind(&pattern)
            .fetch_all(pool)
            .await
            .map_err(failed)?;
            let keys: Vec<String> = rows.into_iter().map(|r| r.0).collect();
            Ok(json!({ "keys": keys }).to_string().into_bytes())
        }
        _ => unreachable!("store_call is only given store functions"),
    }
}

fn escape_like(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for c in s.chars() {
        if c == '%' || c == '_' || c == '\\' {
            out.push('\\');
        }
        out.push(c);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use sqlx::sqlite::SqlitePoolOptions;

    /// One connection, because `sqlite::memory:` gives each its own database
    /// and a pool of several would be several stores.
    async fn pool() -> SqlitePool {
        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect("sqlite::memory:")
            .await
            .unwrap();
        sqlx::migrate!("./migrations").run(&pool).await.unwrap();
        pool
    }

    async fn call(pool: &SqlitePool, id: &str, func: HostFn, body: serde_json::Value) -> String {
        let out = store_call(pool, id, func, body.to_string().as_bytes())
            .await
            .expect("the call answered an error");
        String::from_utf8(out).unwrap()
    }

    async fn set(pool: &SqlitePool, id: &str, key: &str, value: Option<&str>) {
        call(
            pool,
            id,
            HostFn::StoreSet,
            json!({ "scope": "global", "key": key, "value": value }),
        )
        .await;
    }

    async fn get(pool: &SqlitePool, id: &str, key: &str) -> String {
        call(pool, id, HostFn::StoreGet, json!({ "scope": "global", "key": key })).await
    }

    #[tokio::test]
    async fn what_a_plugin_wrote_is_what_it_reads_back() {
        let pool = pool().await;

        assert_eq!(get(&pool, "p", "k").await, r#"{"value":null}"#);

        set(&pool, "p", "k", Some("one")).await;
        assert_eq!(get(&pool, "p", "k").await, r#"{"value":"one"}"#);

        // A second write replaces rather than conflicting: the key is the
        // identity, and a plugin storing a cursor writes the same one forever.
        set(&pool, "p", "k", Some("two")).await;
        assert_eq!(get(&pool, "p", "k").await, r#"{"value":"two"}"#);
    }

    /// Null is how a plugin deletes — there is no `sb.store.remove` — so it
    /// has to mean removal rather than storing the string `null`.
    #[tokio::test]
    async fn no_value_deletes() {
        let pool = pool().await;
        set(&pool, "p", "k", Some("one")).await;

        set(&pool, "p", "k", None).await;

        assert_eq!(get(&pool, "p", "k").await, r#"{"value":null}"#);
    }

    /// The whole point of keying by plugin. An agent runs whatever the
    /// operator put in the directory, and one plugin's cursor, token or
    /// address list is not another's to read.
    #[tokio::test]
    async fn one_plugin_cannot_read_another() {
        let pool = pool().await;
        set(&pool, "a", "k", Some("a's")).await;
        set(&pool, "b", "k", Some("b's")).await;

        assert_eq!(get(&pool, "a", "k").await, r#"{"value":"a's"}"#);
        assert_eq!(
            call(&pool, "b", HostFn::StoreList, json!({ "scope": "global", "prefix": "" })).await,
            r#"{"keys":["k"]}"#,
        );
    }

    /// `server` and `global` are separate spaces on the app, and a plugin
    /// written there and moved here must not find them merged.
    #[tokio::test]
    async fn the_two_scopes_are_two_spaces() {
        let pool = pool().await;
        set(&pool, "p", "k", Some("global")).await;

        call(
            &pool,
            "p",
            HostFn::StoreSet,
            json!({ "scope": "server", "key": "k", "value": "server" }),
        )
        .await;

        assert_eq!(get(&pool, "p", "k").await, r#"{"value":"global"}"#);
        assert_eq!(
            call(&pool, "p", HostFn::StoreGet, json!({ "scope": "server", "key": "k" })).await,
            r#"{"value":"server"}"#,
        );
    }

    #[tokio::test]
    async fn a_scope_that_is_neither_is_refused() {
        let pool = pool().await;

        let e = store_call(
            &pool,
            "p",
            HostFn::StoreGet,
            br#"{"scope":"machine","key":"k"}"#,
        )
        .await
        .unwrap_err();

        match e {
            BridgeError::Failed { kind, .. } => assert_eq!(kind, "bad_request"),
            other => panic!("{other:?}"),
        }
    }

    /// A plugin's keys are its own strings, so a prefix containing `%` or `_`
    /// has to match those characters rather than whatever `LIKE` reads them as.
    #[tokio::test]
    async fn a_key_a_plugin_forgot_to_fill_in_is_refused() {
        let pool = pool().await;

        let e = store_call(&pool, "p", HostFn::StoreGet, br#"{"scope":"global"}"#)
            .await
            .unwrap_err();

        match e {
            BridgeError::Failed { kind, .. } => assert_eq!(kind, "bad_request"),
            other => panic!("{other:?}"),
        }
    }

    #[tokio::test]
    async fn a_prefix_is_matched_literally() {
        let pool = pool().await;
        set(&pool, "p", "a%b", Some("1")).await;
        set(&pool, "p", "axb", Some("2")).await;
        set(&pool, "p", "a_c", Some("3")).await;
        set(&pool, "p", "abc", Some("4")).await;

        let listed = |prefix: &'static str| {
            let pool = pool.clone();
            async move {
                call(&pool, "p", HostFn::StoreList, json!({ "scope": "global", "prefix": prefix }))
                    .await
            }
        };

        assert_eq!(listed("a%").await, r#"{"keys":["a%b"]}"#);
        assert_eq!(listed("a_").await, r#"{"keys":["a_c"]}"#);
        assert_eq!(listed("").await, r#"{"keys":["a%b","a_c","abc","axb"]}"#);
    }
}
