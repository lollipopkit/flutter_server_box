//! The seam between the runtime and the app.
//!
//! Everything in section 4.3 that actually touches a server, the network, the
//! screen or the database is behind this trait. `sbm_ffi` will implement it
//! over `DartFnFuture`; the tests implement it with a script. Nothing else in
//! this crate knows which.

use crate::hostfn::{HostFn, LogLevel};

/// Which instance is calling, so one bridge can serve all of them.
#[derive(Debug, Clone, Copy)]
pub struct CallCtx<'a> {
    pub plugin_id: &'a str,
    /// Unique per (plugin, server) pair for the life of the instance.
    pub instance_id: &'a str,
}

/// What the app can answer with when it could not do the thing.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BridgeError {
    /// The host tried and failed. Becomes a rejected `Promise`, so the plugin
    /// can `catch` it — a BMC that did not answer is a card that says so, not
    /// a plugin that dies.
    Failed { kind: String, message: String },

    /// The call was outside what the grant covers, decided by the app rather
    /// than here: a server handle the app no longer recognises, a directory
    /// outside what a file grant named. Thrown rather than rejected, like the
    /// stub installed for an ungranted function.
    Denied { detail: String },
}

impl BridgeError {
    pub fn failed(kind: impl Into<String>, message: impl Into<String>) -> Self {
        Self::Failed { kind: kind.into(), message: message.into() }
    }
}

/// A call the app has not finished yet.
///
/// The reason the plugin's `await` is worth anything: a pending call leaves the
/// runtime thread free, so one thread can carry many instances and a BMC that
/// takes ten seconds does not hold one for ten seconds.
///
/// Polled by the instance while it drains the job queue. Returning `None` means
/// "not yet"; the instance will ask again.
pub trait PendingCall: Send {
    fn poll(&mut self) -> Option<Result<Vec<u8>, BridgeError>>;

    /// The instance is going away and the answer is no longer wanted.
    ///
    /// Called for every outstanding call when an instance is dropped, so the
    /// app can cancel a request rather than leaving it to finish into nothing.
    fn cancel(&mut self) {}
}

/// What a host function call became.
pub enum HostCall {
    /// Answered without leaving the thread. `sb.config.get` and anything the
    /// app can satisfy from memory.
    Ready(Result<Vec<u8>, BridgeError>),

    /// Answered later.
    Pending(Box<dyn PendingCall>),
}

impl HostCall {
    pub fn ok(value: impl Into<Vec<u8>>) -> Self {
        Self::Ready(Ok(value.into()))
    }

    pub fn err(e: BridgeError) -> Self {
        Self::Ready(Err(e))
    }
}

/// Implemented by the app.
pub trait HostBridge: Send + Sync {
    /// One entry point rather than one method per function.
    ///
    /// `request` and the returned bytes are JSON, shaped per [`HostFn`]. An
    /// empty return is the JSON `null` for the functions that answer nothing.
    fn call(&self, ctx: CallCtx<'_>, func: HostFn, request: &[u8]) -> HostCall;

    /// `sb.log.*` from the plugin. Separate from [`HostBridge::call`] because
    /// it cannot fail and must not be able to: a plugin whose logging throws is
    /// a plugin that cannot report why it is failing.
    fn log(&self, ctx: CallCtx<'_>, level: LogLevel, message: &str);
}
