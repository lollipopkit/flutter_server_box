//! The `sb` interface. PLUGINS.md section 4.3.
//!
//! Every entry is permanent: a published plugin calls these names, and a name
//! that stops existing is a plugin that stops working. The table only grows,
//! and `abi` in the manifest says which version of it a plugin was built for.
//!
//! Only the functions that go through the app are here. `sb.config.get` and
//! `sb.log.*` read or write instance-local state and never leave the runtime
//! thread, so they are installed directly (see `bindings.rs`) and need no
//! entry.

use crate::permission::Permission;

/// One function on `sb`, reached as `sb.<namespace>.<method>`.
///
/// All of them take one argument and answer a `Promise`. What varies is the
/// JSON.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum HostFn {
    /// `{server, script, timeoutMs?}` → `{code, stdout, stderr}`
    ServerExec,

    /// `{url, method, headers?, body?, bodyEncoding?, via?, server?,
    ///   pinSha256?, probeCert?, timeoutMs?}`
    /// → `{status, headers, body, bodyEncoding, cert?}`
    ///
    /// The only way out. The plugin context has no `fetch`, because a plugin
    /// making its own request could not be held to the manifest's address list
    /// and could not pin a certificate.
    HttpFetch,

    /// `{path, node}` → null
    ///
    /// Replaces the subtree the JSON Pointer names in the surface's last tree,
    /// so a plugin streaming a log does not resend the page per line.
    UiPatch,

    /// `{title, message?, fields?, confirm?}`
    /// → `{cancelled} | {values}`
    UiPrompt,

    /// null → `{server} | {cancelled}`
    UiPickServer,

    /// `{text, kind}` → null
    UiToast,

    /// `{scope, key}` → `{value}`
    StoreGet,

    /// `{scope, key, value}` → null. A null value deletes.
    StoreSet,

    /// `{scope, prefix}` → `{keys}`
    StoreList,

    /// `{name, level?}` → null
    ///
    /// Records that something happened, never what: the host keeps the name
    /// and the level and decides what else is safe to keep.
    DiagCrumb,

    /// `{server}` → null
    NavOpenServer,

    /// `{tab}` → null
    NavGoTab,

    /// null → `{text}`
    ClipboardRead,

    /// `{text}` → null
    ClipboardWrite,
}

impl HostFn {
    /// Every entry, in the order 4.3 lists them.
    ///
    /// `bindings.rs` installs from this list and `permission_scope.rs` asserts
    /// against it, so a case added without a binding fails a test rather than
    /// being missing on a user's device.
    pub const ALL: &'static [HostFn] = &[
        Self::ServerExec,
        Self::HttpFetch,
        Self::UiPatch,
        Self::UiPrompt,
        Self::UiPickServer,
        Self::UiToast,
        Self::StoreGet,
        Self::StoreSet,
        Self::StoreList,
        Self::DiagCrumb,
        Self::NavOpenServer,
        Self::NavGoTab,
        Self::ClipboardRead,
        Self::ClipboardWrite,
    ];

    /// The object on `sb` this hangs off.
    pub const fn namespace(self) -> &'static str {
        match self {
            Self::ServerExec => "server",
            Self::HttpFetch => "http",
            Self::UiPatch | Self::UiPrompt | Self::UiPickServer | Self::UiToast => "ui",
            Self::StoreGet | Self::StoreSet | Self::StoreList => "store",
            Self::DiagCrumb => "diag",
            Self::NavOpenServer | Self::NavGoTab => "nav",
            Self::ClipboardRead | Self::ClipboardWrite => "clipboard",
        }
    }

    /// The property name within that object.
    pub const fn method(self) -> &'static str {
        match self {
            Self::ServerExec => "exec",
            Self::HttpFetch => "fetch",
            Self::UiPatch => "patch",
            Self::UiPrompt => "prompt",
            Self::UiPickServer => "pickServer",
            Self::UiToast => "toast",
            Self::StoreGet => "get",
            Self::StoreSet => "set",
            Self::StoreList => "list",
            Self::DiagCrumb => "crumb",
            Self::NavOpenServer => "openServer",
            Self::NavGoTab => "goTab",
            Self::ClipboardRead => "read",
            Self::ClipboardWrite => "write",
        }
    }

    /// `sb.server.exec`, for error messages and tests.
    pub fn path(self) -> String {
        format!("sb.{}.{}", self.namespace(), self.method())
    }

    /// What the manifest must have asked for, or `None` for the ones 6.1 calls
    /// always granted.
    pub const fn permission(self) -> Option<Permission> {
        match self {
            Self::ServerExec => Some(Permission::ServerExec),
            Self::HttpFetch => Some(Permission::NetHttp),
            Self::UiPrompt => Some(Permission::UiDialog),
            Self::ClipboardRead | Self::ClipboardWrite => Some(Permission::Clipboard),
            Self::UiPatch
            | Self::UiPickServer
            | Self::UiToast
            | Self::StoreGet
            | Self::StoreSet
            | Self::StoreList
            | Self::DiagCrumb
            | Self::NavOpenServer
            | Self::NavGoTab => None,
        }
    }

    /// Every namespace that appears on `sb`, including the two installed
    /// directly.
    pub const NAMESPACES: &'static [&'static str] = &[
        "server", "http", "ui", "store", "diag", "nav", "clipboard", "config", "log",
    ];

    pub fn parse(path: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|f| f.path() == path)
    }
}

/// How loud a plugin's logs are.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum LogLevel {
    Trace,
    Debug,
    Info,
    Warn,
    Error,
}

impl LogLevel {
    pub const ALL: &'static [LogLevel] =
        &[Self::Trace, Self::Debug, Self::Info, Self::Warn, Self::Error];

    /// The method name on `sb.log`.
    pub const fn name(self) -> &'static str {
        match self {
            Self::Trace => "trace",
            Self::Debug => "debug",
            Self::Info => "info",
            Self::Warn => "warn",
            Self::Error => "error",
        }
    }

    pub fn parse(name: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|l| l.name() == name)
    }
}

/// Section 4.2's exports, by the name a plugin must give them.
pub mod exports {
    /// Once, after the instance is created.
    pub const INIT: &str = "init";
    /// A surface is being shown. Answers `{ui}`.
    pub const OPEN: &str = "open";
    /// The user did something. Answers `{ui}`.
    pub const ON_EVENT: &str = "onEvent";
    /// The shared refresh interval, and only while the surface is visible.
    pub const TICK: &str = "tick";
    /// connected / disconnected / deleted.
    pub const ON_SERVER_EVENT: &str = "onServerEvent";
    /// The editor is about to save. Answers `{errors}`.
    pub const VALIDATE_CONFIG: &str = "validateConfig";
    /// A `select` config field whose choices the plugin supplies.
    ///
    /// Takes the field key as an argument. The WebAssembly design needed one
    /// export per field, because each export is a separate symbol; an ES module
    /// has no such limit.
    pub const CONFIG_OPTIONS: &str = "configOptions";
    /// The AI agent's tools, by name. One export for the same reason.
    pub const TOOL: &str = "tool";
    /// Before the instance goes away.
    pub const DISPOSE: &str = "dispose";

    /// A status-command plugin's two exports (section 9). Neither needs a
    /// surface, a permission or the network.
    pub const STATUS_CMD: &str = "statusCmd";
    pub const PARSE: &str = "parse";

    pub const ALL: &[&str] = &[
        INIT,
        OPEN,
        ON_EVENT,
        TICK,
        ON_SERVER_EVENT,
        VALIDATE_CONFIG,
        CONFIG_OPTIONS,
        TOOL,
        DISPOSE,
        STATUS_CMD,
        PARSE,
    ];
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeSet;

    #[test]
    fn paths_are_unique_and_parse_back() {
        let mut seen = BTreeSet::new();
        for f in HostFn::ALL {
            assert!(seen.insert(f.path()), "duplicate {}", f.path());
            assert_eq!(HostFn::parse(&f.path()), Some(*f));
        }
    }

    /// `ALL` is what the bindings are installed from, so a case missing from it
    /// is a function no plugin can call and nothing else would notice.
    #[test]
    fn all_covers_every_case() {
        for f in HostFn::ALL {
            let _: &'static str = match f {
                HostFn::ServerExec
                | HostFn::HttpFetch
                | HostFn::UiPatch
                | HostFn::UiPrompt
                | HostFn::UiPickServer
                | HostFn::UiToast
                | HostFn::StoreGet
                | HostFn::StoreSet
                | HostFn::StoreList
                | HostFn::DiagCrumb
                | HostFn::NavOpenServer
                | HostFn::NavGoTab
                | HostFn::ClipboardRead
                | HostFn::ClipboardWrite => f.method(),
            };
        }
        assert_eq!(HostFn::ALL.len(), 14);
    }

    /// Every namespace a function hangs off has to be one the bindings create,
    /// or the function is installed onto an object that does not exist.
    #[test]
    fn every_namespace_is_declared() {
        for f in HostFn::ALL {
            assert!(
                HostFn::NAMESPACES.contains(&f.namespace()),
                "{} is not in NAMESPACES",
                f.namespace()
            );
        }
    }

    #[test]
    fn log_levels_round_trip() {
        for l in LogLevel::ALL {
            assert_eq!(LogLevel::parse(l.name()), Some(*l));
        }
    }
}
