//! Building the `sb` object, which is where permissions are enforced.
//!
//! Section 6.2. A host function the manifest did not ask for is installed as a
//! stub that throws, so no working implementation contains an `if granted` a
//! future edit could drop. `tests/permission_scope.rs` builds `sb` through this
//! same function — not a hand-written table — and asserts it per manifest.

use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Arc;

use rquickjs::function::{Func, Opt};
use rquickjs::{Ctx, Function, Object, Persistent, Promise, Value};

use crate::bridge::{CallCtx, HostCall, PendingCall};
use crate::error::Refusal;
use crate::hostfn::{HostFn, LogLevel};
use crate::scope::State;

/// A host call the app has not answered yet, and the two functions that will
/// settle the plugin's `Promise` when it does.
pub(crate) struct Outstanding {
    pub func: HostFn,
    pub call: Box<dyn PendingCall>,
    pub resolve: Persistent<Function<'static>>,
    pub reject: Persistent<Function<'static>>,
}

/// Everything the instance's own bookkeeping needs, shared with the closures
/// installed on `sb`.
///
/// `Rc<RefCell<..>>` rather than a lock: a QuickJS runtime is used from one
/// thread, and the closures below only ever run while that thread is inside
/// `Context::with`.
pub(crate) type Outbox = Rc<RefCell<Vec<Outstanding>>>;

/// Installs `sb` on the global object.
pub(crate) fn install(ctx: &Ctx<'_>, state: Arc<State>, outbox: Outbox) -> rquickjs::Result<()> {
    let globals = ctx.globals();
    let sb = Object::new(ctx.clone())?;

    // Created up front so a function can be installed onto its namespace
    // regardless of order.
    for ns in HostFn::NAMESPACES {
        sb.set(*ns, Object::new(ctx.clone())?)?;
    }

    for f in HostFn::ALL {
        // Not on this host at all — the agent has no user, so nothing that
        // asks one a question exists there. Installed as the same throwing
        // stub an ungranted function gets, because that is what "you cannot
        // call this" already looks like from inside a plugin; only the reason
        // differs. See `HostFn::available_in`.
        if !f.available_in(state.profile) {
            let target: Object = sb.get(f.namespace())?;
            let refusal =
                Refusal::Unavailable { function: f.path(), host: state.profile.name() };
            let state = Arc::clone(&state);
            target.set(
                f.method(),
                Func::from(hrtb_value(move |ctx, _| {
                    state.refuse(refusal.clone());
                    Err(throw(&ctx, &refusal))
                })),
            )?;
            continue;
        }

        let target: Object = sb.get(f.namespace())?;
        match f.permission() {
            // Not granted: this name is a function that throws, and no code
            // path in the real implementation is reachable at all.
            Some(p) if !state.grants.allows(p) => {
                let refusal =
                    Refusal::PermissionDenied { function: f.path(), permission: p.name() };
                let state = Arc::clone(&state);
                target.set(
                    f.method(),
                    Func::from(hrtb_value(move |ctx, _| {
                        state.refuse(refusal.clone());
                        Err(throw(&ctx, &refusal))
                    })),
                )?;
            }
            _ => {
                let f = *f;
                let state = Arc::clone(&state);
                let outbox = Rc::clone(&outbox);
                target.set(
                    f.method(),
                    Func::from(hrtb_promise(move |ctx, arg| {
                        dispatch(&ctx, f, arg, &state, &outbox)
                    })),
                )?;
            }
        }
    }

    install_config(ctx, &sb, Arc::clone(&state))?;
    install_log(ctx, &sb, Arc::clone(&state))?;

    globals.set("sb", sb)?;
    Ok(())
}

/// Pins a closure's argument and return lifetimes together.
///
/// A closure with two elided lifetimes in its signature is not inferred as
/// higher-ranked, so `Ctx<'a>` and the returned `Promise<'b>` end up unrelated
/// and the closure will not coerce. Passing it through a function with the
/// bound written out is what ties them.
fn hrtb_promise<F>(f: F) -> F
where
    F: for<'js> Fn(Ctx<'js>, Opt<Value<'js>>) -> rquickjs::Result<Promise<'js>>,
{
    f
}

fn hrtb_value<F>(f: F) -> F
where
    F: for<'js> Fn(Ctx<'js>, Opt<Value<'js>>) -> rquickjs::Result<Value<'js>>,
{
    f
}

/// One call to one host function.
fn dispatch<'js>(
    ctx: &Ctx<'js>,
    func: HostFn,
    arg: Opt<Value<'js>>,
    state: &Arc<State>,
    outbox: &Outbox,
) -> rquickjs::Result<Promise<'js>> {
    // Several of these take nothing — `sb.ui.pickServer()`,
    // `sb.clipboard.read()` — so the argument is optional and a missing one is
    // the same as `undefined`. The bridge is handed JSON either way, so it
    // never has to tell an empty body from an absent one.
    let request = match arg.0.and_then(|v| ctx.json_stringify(v).transpose()).transpose()? {
        Some(s) => s.to_string()?.into_bytes(),
        None => b"null".to_vec(),
    };

    if let Err(refusal) = state.verify_scope(func, &request) {
        state.refuse(refusal.clone());
        return Err(throw(ctx, &refusal));
    }

    let (promise, resolve, reject) = ctx.promise()?;
    let call = state.bridge.call(
        CallCtx { plugin_id: &state.plugin_id, instance_id: &state.instance_id },
        func,
        &request,
    );

    match call {
        HostCall::Ready(Ok(value)) => {
            state.record_response(func, &value);
            resolve.call::<_, ()>((decode(ctx, &value)?,))?;
        }
        HostCall::Ready(Err(crate::bridge::BridgeError::Failed { kind, message })) => {
            reject.call::<_, ()>((failure(ctx, &kind, &message)?,))?;
        }
        // The app refusing is the same kind of answer as the stub above, and
        // must not be catchable as an ordinary failure.
        HostCall::Ready(Err(crate::bridge::BridgeError::Denied { detail })) => {
            let refusal = Refusal::OutOfScope { function: func.path(), detail };
            state.refuse(refusal.clone());
            return Err(throw(ctx, &refusal));
        }
        HostCall::Pending(call) => {
            outbox.borrow_mut().push(Outstanding {
                func,
                call,
                resolve: Persistent::save(ctx, resolve),
                reject: Persistent::save(ctx, reject),
            });
        }
    }
    Ok(promise)
}

/// Settles one outstanding call. Returns the JSON the app answered, so the
/// instance can record a server handle.
pub(crate) fn settle<'js>(
    ctx: &Ctx<'js>,
    state: &Arc<State>,
    outstanding: Outstanding,
    answer: Result<Vec<u8>, crate::bridge::BridgeError>,
) -> rquickjs::Result<Option<(HostFn, Vec<u8>)>> {
    let Outstanding { func, resolve, reject, .. } = outstanding;
    let resolve = resolve.restore(ctx)?;
    let reject = reject.restore(ctx)?;
    match answer {
        Ok(value) => {
            resolve.call::<_, ()>((decode(ctx, &value)?,))?;
            Ok(Some((func, value)))
        }
        Err(crate::bridge::BridgeError::Failed { kind, message }) => {
            reject.call::<_, ()>((failure(ctx, &kind, &message)?,))?;
            Ok(None)
        }
        // Rejected rather than thrown, because by now there is no plugin frame
        // on the stack to throw into. The plugin may catch it; what stops it
        // carrying on is that the refusal is recorded and the host fails the
        // call whatever the plugin answers.
        Err(crate::bridge::BridgeError::Denied { detail }) => {
            let refusal = Refusal::OutOfScope { function: func.path(), detail };
            state.refuse(refusal.clone());
            let err = error_value(ctx, refusal.kind(), &refusal.to_string())?;
            reject.call::<_, ()>((err,))?;
            Ok(None)
        }
    }
}

/// `sb.config.get(key)` — synchronous, because it reads a map this instance was
/// handed and never leaves the thread.
fn install_config(ctx: &Ctx<'_>, sb: &Object<'_>, state: Arc<State>) -> rquickjs::Result<()> {
    let config: Object = sb.get("config")?;
    config.set(
        "get",
        Func::from(move |key: String| state.config.get(&key).cloned()),
    )?;
    let _ = ctx;
    Ok(())
}

/// `sb.log.*` — synchronous and cannot fail. A plugin whose logging throws is a
/// plugin that cannot report why it is failing.
fn install_log(ctx: &Ctx<'_>, sb: &Object<'_>, state: Arc<State>) -> rquickjs::Result<()> {
    let log: Object = sb.get("log")?;
    for level in LogLevel::ALL {
        let level = *level;
        let state = Arc::clone(&state);
        log.set(
            level.name(),
            Func::from(move |message: String| {
                state.bridge.log(
                    CallCtx { plugin_id: &state.plugin_id, instance_id: &state.instance_id },
                    level,
                    &message,
                );
            }),
        )?;
    }
    let _ = ctx;
    Ok(())
}

/// The app's JSON answer as a JavaScript value.
fn decode<'js>(ctx: &Ctx<'js>, value: &[u8]) -> rquickjs::Result<Value<'js>> {
    if value.is_empty() {
        return Ok(Value::new_null(ctx.clone()));
    }
    ctx.json_parse(value.to_vec())
}

/// What a rejected `Promise` carries: an `Error` with `kind` and `message`, so
/// a plugin can branch on `e.kind === "timeout"` without parsing a string.
fn failure<'js>(ctx: &Ctx<'js>, kind: &str, message: &str) -> rquickjs::Result<Value<'js>> {
    let err = error_value(ctx, "HostError", message)?;
    if let Some(obj) = err.as_object() {
        obj.set("kind", kind)?;
    }
    Ok(err)
}

fn error_value<'js>(ctx: &Ctx<'js>, name: &str, message: &str) -> rquickjs::Result<Value<'js>> {
    let err = rquickjs::Exception::from_message(ctx.clone(), message)?;
    let value = err.into_value();
    if let Some(obj) = value.as_object() {
        obj.set("name", name)?;
    }
    Ok(value)
}

/// Raises a refusal as a JavaScript exception.
fn throw(ctx: &Ctx<'_>, refusal: &Refusal) -> rquickjs::Error {
    match error_value(ctx, refusal.kind(), &refusal.to_string()) {
        Ok(v) => ctx.throw(v),
        Err(e) => e,
    }
}
