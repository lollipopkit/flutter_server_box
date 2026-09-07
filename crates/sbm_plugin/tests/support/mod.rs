//! A bridge that answers from a script.
//!
//! The "test acts as the shell" arrangement of PLUGINS.md section 12: a plugin
//! runs a whole interaction with no app underneath it, and what it asked the
//! host for is asserted rather than mocked away.

#![allow(dead_code)]

use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};

use sbm_plugin::{BridgeError, CallCtx, HostBridge, HostCall, HostFn, LogLevel, PendingCall};

/// What one host call looked like from the app's side.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Recorded {
    pub func: HostFn,
    pub plugin_id: String,
    pub instance_id: String,
    pub request: String,
}

/// An answer the app has not given yet.
///
/// `after` polls before it answers, so a test can prove the plugin's stack was
/// unwound while it waited rather than blocking the thread.
struct Deferred {
    after: usize,
    polls: usize,
    answer: Option<Result<Vec<u8>, BridgeError>>,
    cancelled: Arc<Mutex<usize>>,
}

impl PendingCall for Deferred {
    fn poll(&mut self) -> Option<Result<Vec<u8>, BridgeError>> {
        if self.polls < self.after {
            self.polls += 1;
            return None;
        }
        self.answer.take()
    }

    fn cancel(&mut self) {
        *self.cancelled.lock().unwrap() += 1;
    }
}

#[derive(Default)]
pub struct ScriptedBridge {
    answers: Mutex<BTreeMap<HostFn, Result<String, BridgeError>>>,
    /// Functions whose answer arrives after this many polls.
    deferred: Mutex<BTreeMap<HostFn, usize>>,
    pub calls: Mutex<Vec<Recorded>>,
    pub logs: Mutex<Vec<(LogLevel, String)>>,
    pub cancelled: Arc<Mutex<usize>>,
}

impl ScriptedBridge {
    pub fn new() -> Arc<Self> {
        Arc::new(Self::default())
    }

    pub fn answer(self: &Arc<Self>, func: HostFn, json: &str) -> Arc<Self> {
        self.answers.lock().unwrap().insert(func, Ok(json.to_string()));
        Arc::clone(self)
    }

    pub fn answer_err(self: &Arc<Self>, func: HostFn, err: BridgeError) -> Arc<Self> {
        self.answers.lock().unwrap().insert(func, Err(err));
        Arc::clone(self)
    }

    /// Answers this function only after `polls` looks, through [`HostCall::Pending`].
    pub fn defer(self: &Arc<Self>, func: HostFn, polls: usize) -> Arc<Self> {
        self.deferred.lock().unwrap().insert(func, polls);
        Arc::clone(self)
    }

    pub fn recorded(&self) -> Vec<Recorded> {
        self.calls.lock().unwrap().clone()
    }

    pub fn funcs(&self) -> Vec<HostFn> {
        self.calls.lock().unwrap().iter().map(|c| c.func).collect()
    }

    pub fn logged(&self) -> Vec<(LogLevel, String)> {
        self.logs.lock().unwrap().clone()
    }

    pub fn cancels(&self) -> usize {
        *self.cancelled.lock().unwrap()
    }
}

impl HostBridge for ScriptedBridge {
    fn call(&self, ctx: CallCtx<'_>, func: HostFn, request: &[u8]) -> HostCall {
        self.calls.lock().unwrap().push(Recorded {
            func,
            plugin_id: ctx.plugin_id.to_string(),
            instance_id: ctx.instance_id.to_string(),
            request: String::from_utf8_lossy(request).into_owned(),
        });

        let answer = match self.answers.lock().unwrap().get(&func) {
            Some(Ok(json)) => Ok(json.clone().into_bytes()),
            Some(Err(e)) => Err(e.clone()),
            None => Ok(b"null".to_vec()),
        };

        match self.deferred.lock().unwrap().get(&func).copied() {
            Some(after) => HostCall::Pending(Box::new(Deferred {
                after,
                polls: 0,
                answer: Some(answer),
                cancelled: Arc::clone(&self.cancelled),
            })),
            None => HostCall::Ready(answer),
        }
    }

    fn log(&self, _: CallCtx<'_>, level: LogLevel, message: &str) {
        self.logs.lock().unwrap().push((level, message.to_string()));
    }
}

/// A bridge that never answers, for the host-call timeout.
pub struct SilentBridge;

struct Never;
impl PendingCall for Never {
    fn poll(&mut self) -> Option<Result<Vec<u8>, BridgeError>> {
        None
    }
}

impl HostBridge for SilentBridge {
    fn call(&self, _: CallCtx<'_>, _: HostFn, _: &[u8]) -> HostCall {
        HostCall::Pending(Box::new(Never))
    }
    fn log(&self, _: CallCtx<'_>, _: LogLevel, _: &str) {}
}
