//! ServerBox plugin host.
//!
//! A plugin is a JavaScript ES module. This crate runs it on quickjs-ng, gives
//! it the `sb` interface described in PLUGINS.md section 4.3, and refuses
//! everything the manifest did not ask for.
//!
//! What is here: the runtime, the interface, the permission checks, the
//! manifest. What is deliberately not: anything that draws. A plugin's UI is a
//! JSON tree this crate carries and Dart renders (section 5), so the widget
//! vocabulary lives in `lib/plugin/` and in the SDK, and never here.

mod bindings;
mod scope;

pub mod bridge;
pub mod channel;
pub mod host;
pub mod error;
pub mod hostfn;
pub mod manifest;
pub mod permission;
pub mod runtime;
pub mod status;

pub use bridge::{BridgeError, CallCtx, HostBridge, HostCall, PendingCall};
pub use channel::{ChannelBridge, HostRequest, LogEvent};
pub use host::{InstanceId, PluginHost};
pub use error::{PluginError, Refusal};
pub use hostfn::{HostFn, LogLevel, exports};
pub use manifest::Manifest;
pub use permission::{Grants, HostPattern, Permission};
pub use status::{StatusCmd, StatusItem, StatusResult};
pub use runtime::{
    ABI_VERSION, DEFAULT_HOST_CALL_TIMEOUT, DEFAULT_MEMORY_LIMIT, DEFAULT_STACK_LIMIT,
    DEFAULT_TIME_LIMIT, Instance, InstanceOptions,
};
