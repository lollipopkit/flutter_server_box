//! A bridge the app answers asynchronously.
//!
//! The runtime asks for something and carries on; the app answers whenever it
//! can. This is the shape `sbm_ffi` needs, because a host call originates on a
//! plugin's own thread — not one belonging to any async runtime — so it cannot
//! await a Dart future in place. What it can do is hand the request out and
//! look for the answer later, which is what [`PendingCall`] already describes.
//!
//! Everything here is synchronous and needs no executor. `sbm_ffi` supplies an
//! `emit` that pushes onto a Dart stream and calls [`ChannelBridge::answer`]
//! from a plain Dart-to-Rust function, so the whole crossing stays on the shape
//! that crate already uses.

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, Weak};

use crate::bridge::{BridgeError, CallCtx, HostBridge, HostCall, PendingCall};
use crate::hostfn::{HostFn, LogLevel};

/// One thing the runtime wants the app to do.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HostRequest {
    /// What [`ChannelBridge::answer`] must quote back.
    pub call_id: u64,
    pub plugin_id: String,
    pub instance_id: String,
    /// `sb.http.fetch`, and so on.
    pub func: String,
    /// JSON, shaped per [`HostFn`].
    pub request: String,
}

/// A line the plugin wrote. Never answered.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LogEvent {
    pub plugin_id: String,
    pub instance_id: String,
    pub level: LogLevel,
    pub message: String,
}

#[derive(Default)]
struct Slot {
    answer: Mutex<Option<Result<Vec<u8>, BridgeError>>>,
    /// The instance went away. A late answer is then dropped rather than
    /// written into a slot nobody will read.
    cancelled: AtomicBool,
}

/// The bridge.
pub struct ChannelBridge {
    /// So an outstanding request can take itself out of the map when it is
    /// dropped. Weak, or the bridge would keep itself alive.
    me: Weak<ChannelBridge>,
    next_id: AtomicU64,
    outstanding: Mutex<HashMap<u64, Arc<Slot>>>,
    emit: Box<dyn Fn(HostRequest) + Send + Sync>,
    write_log: Box<dyn Fn(LogEvent) + Send + Sync>,
}

impl ChannelBridge {
    pub fn new(
        emit: impl Fn(HostRequest) + Send + Sync + 'static,
        write_log: impl Fn(LogEvent) + Send + Sync + 'static,
    ) -> Arc<Self> {
        Arc::new_cyclic(|me| Self {
            me: me.clone(),
            next_id: AtomicU64::new(1),
            outstanding: Mutex::new(HashMap::new()),
            emit: Box::new(emit),
            write_log: Box::new(write_log),
        })
    }

    /// The app's answer to one request.
    ///
    /// Returns whether anything was waiting for it. `false` for an id that was
    /// never issued, was already answered, or belonged to an instance that has
    /// since gone — all of which happen and none of which is an error: an
    /// answer arriving after the user closed the page is the ordinary case.
    pub fn answer(&self, call_id: u64, answer: Result<Vec<u8>, BridgeError>) -> bool {
        let slot = self.outstanding.lock().expect("poisoned").get(&call_id).cloned();
        let Some(slot) = slot else { return false };
        if slot.cancelled.load(Ordering::Acquire) {
            return false;
        }
        let mut held = slot.answer.lock().expect("poisoned");
        if held.is_some() {
            return false;
        }
        *held = Some(answer);
        true
    }

    /// How many requests the app has not answered.
    pub fn outstanding(&self) -> usize {
        self.outstanding.lock().expect("poisoned").len()
    }

    fn forget(&self, call_id: u64) {
        self.outstanding.lock().expect("poisoned").remove(&call_id);
    }
}

impl HostBridge for ChannelBridge {
    fn call(self: &ChannelBridge, ctx: CallCtx<'_>, func: HostFn, request: &[u8]) -> HostCall {
        let call_id = self.next_id.fetch_add(1, Ordering::Relaxed);
        let slot = Arc::new(Slot::default());
        self.outstanding.lock().expect("poisoned").insert(call_id, Arc::clone(&slot));

        // Handed out after the slot is registered, so an app that answers
        // before this returns still finds somewhere to put it.
        (self.emit)(HostRequest {
            call_id,
            plugin_id: ctx.plugin_id.to_string(),
            instance_id: ctx.instance_id.to_string(),
            func: func.path(),
            request: String::from_utf8_lossy(request).into_owned(),
        });

        HostCall::Pending(Box::new(Waiting { call_id, slot, bridge: self.me.clone() }))
    }

    fn log(&self, ctx: CallCtx<'_>, level: LogLevel, message: &str) {
        (self.write_log)(LogEvent {
            plugin_id: ctx.plugin_id.to_string(),
            instance_id: ctx.instance_id.to_string(),
            level,
            message: message.to_string(),
        });
    }
}

/// One outstanding request, from the runtime's side.
struct Waiting {
    call_id: u64,
    slot: Arc<Slot>,
    bridge: Weak<ChannelBridge>,
}

impl PendingCall for Waiting {
    fn poll(&mut self) -> Option<Result<Vec<u8>, BridgeError>> {
        self.slot.answer.lock().expect("poisoned").take()
    }

    fn cancel(&mut self) {
        self.slot.cancelled.store(true, Ordering::Release);
    }
}

/// Cleaning up is tied to the request's own lifetime rather than to answering
/// it. A call that was answered, one that was cancelled and one that timed out
/// all end here, so there is one place to get right and nothing the app has to
/// remember to call. A bridge is shared by every instance and lives as long as
/// the app does; entries left behind would grow without bound.
impl Drop for Waiting {
    fn drop(&mut self) {
        self.slot.cancelled.store(true, Ordering::Release);
        if let Some(bridge) = self.bridge.upgrade() {
            bridge.forget(self.call_id);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::mpsc::{Receiver, channel};

    fn bridge() -> (Arc<ChannelBridge>, Receiver<HostRequest>, Receiver<LogEvent>) {
        let (req_tx, req_rx) = channel();
        let (log_tx, log_rx) = channel();
        let b = ChannelBridge::new(
            move |r| {
                let _ = req_tx.send(r);
            },
            move |l| {
                let _ = log_tx.send(l);
            },
        );
        (b, req_rx, log_rx)
    }

    fn ctx<'a>() -> CallCtx<'a> {
        CallCtx { plugin_id: "app.serverbox.bmc", instance_id: "inst-1" }
    }

    fn pending(call: HostCall) -> Box<dyn PendingCall> {
        match call {
            HostCall::Pending(p) => p,
            HostCall::Ready(_) => panic!("a channel bridge never answers in place"),
        }
    }

    #[test]
    fn a_call_is_handed_out_with_everything_needed_to_answer_it() {
        let (b, requests, _) = bridge();
        let mut call = pending(b.call(ctx(), HostFn::HttpFetch, br#"{"url":"https://x/"}"#));

        let req = requests.recv().unwrap();
        assert_eq!(req.func, "sb.http.fetch");
        assert_eq!(req.request, r#"{"url":"https://x/"}"#);
        assert_eq!(req.plugin_id, "app.serverbox.bmc");
        assert_eq!(req.instance_id, "inst-1");

        assert!(call.poll().is_none(), "answered before the app said anything");
        assert!(b.answer(req.call_id, Ok(b"{\"status\":200}".to_vec())));
        assert_eq!(call.poll().unwrap().unwrap(), b"{\"status\":200}");
    }

    /// The app may answer before the runtime looks. The slot is registered
    /// before the request is handed out precisely so that works.
    #[test]
    fn an_answer_that_arrives_first_is_not_lost() {
        let (b, requests, _) = bridge();
        let call = b.call(ctx(), HostFn::StoreGet, b"{}");
        let req = requests.recv().unwrap();
        assert!(b.answer(req.call_id, Ok(b"null".to_vec())));

        let mut call = pending(call);
        assert_eq!(call.poll().unwrap().unwrap(), b"null");
    }

    #[test]
    fn a_failure_comes_through_as_one() {
        let (b, requests, _) = bridge();
        let mut call = pending(b.call(ctx(), HostFn::HttpFetch, b"{}"));
        let req = requests.recv().unwrap();
        b.answer(req.call_id, Err(BridgeError::failed("timeout", "no answer")));
        assert_eq!(
            call.poll().unwrap().unwrap_err(),
            BridgeError::failed("timeout", "no answer")
        );
    }

    #[test]
    fn answers_are_routed_by_id_even_when_they_arrive_out_of_order() {
        let (b, requests, _) = bridge();
        let mut first = pending(b.call(ctx(), HostFn::StoreGet, br#"{"key":"a"}"#));
        let mut second = pending(b.call(ctx(), HostFn::StoreGet, br#"{"key":"b"}"#));
        let a = requests.recv().unwrap();
        let c = requests.recv().unwrap();
        assert_ne!(a.call_id, c.call_id);

        b.answer(c.call_id, Ok(b"\"second\"".to_vec()));
        assert!(first.poll().is_none());
        assert_eq!(second.poll().unwrap().unwrap(), b"\"second\"");

        b.answer(a.call_id, Ok(b"\"first\"".to_vec()));
        assert_eq!(first.poll().unwrap().unwrap(), b"\"first\"");
    }

    /// An answer arriving after the user closed the page is the ordinary case,
    /// not an error.
    #[test]
    fn answering_something_nobody_is_waiting_for_is_refused_quietly() {
        let (b, requests, _) = bridge();
        let mut call = pending(b.call(ctx(), HostFn::StoreGet, b"{}"));
        let req = requests.recv().unwrap();

        assert!(!b.answer(9999, Ok(b"null".to_vec())), "an id never issued");
        assert!(b.answer(req.call_id, Ok(b"null".to_vec())));
        assert!(!b.answer(req.call_id, Ok(b"null".to_vec())), "answered twice");
        assert!(call.poll().is_some());
    }

    #[test]
    fn a_cancelled_call_drops_a_late_answer() {
        let (b, requests, _) = bridge();
        let mut call = pending(b.call(ctx(), HostFn::HttpFetch, b"{}"));
        let req = requests.recv().unwrap();

        call.cancel();
        assert!(!b.answer(req.call_id, Ok(b"{}".to_vec())));
        assert!(call.poll().is_none());
    }

    /// A bridge is shared by every instance and lives as long as the app does,
    /// so anything it keeps per call has to go away on its own.
    #[test]
    fn a_dropped_call_takes_itself_out_of_the_map() {
        let (b, requests, _) = bridge();
        let call = pending(b.call(ctx(), HostFn::StoreGet, b"{}"));
        let req = requests.recv().unwrap();
        assert_eq!(b.outstanding(), 1);

        drop(call);
        assert_eq!(b.outstanding(), 0);
        assert!(!b.answer(req.call_id, Ok(b"null".to_vec())));
    }

    #[test]
    fn the_map_does_not_grow_across_answered_calls() {
        let (b, requests, _) = bridge();
        for _ in 0..5 {
            let mut call = pending(b.call(ctx(), HostFn::StoreGet, b"{}"));
            let req = requests.recv().unwrap();
            b.answer(req.call_id, Ok(b"null".to_vec()));
            assert!(call.poll().is_some());
        }
        assert_eq!(b.outstanding(), 0);
    }

    #[test]
    fn logs_carry_their_level_and_are_never_answered() {
        let (b, _, logs) = bridge();
        b.log(ctx(), LogLevel::Warn, "session not released");
        let event = logs.recv().unwrap();
        assert_eq!(event.level, LogLevel::Warn);
        assert_eq!(event.message, "session not released");
        assert_eq!(event.instance_id, "inst-1");
        assert_eq!(b.outstanding(), 0);
    }
}
