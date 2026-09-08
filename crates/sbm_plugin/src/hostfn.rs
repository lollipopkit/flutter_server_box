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

    /// null → `{servers: [{server, name}]}`
    ///
    /// Every server the user has, as handles and display names. What a
    /// fleet-wide surface — a tab — is for: it is bound to no one machine, so
    /// it cannot be handed a single handle at load.
    ///
    /// Names and handles, and nothing else. An address is what a plugin would
    /// need to reach a machine behind the app's back, and a handle is
    /// meaningless outside the instance it was issued to.
    ServerList,

    /// `{server}` → null
    NavOpenServer,

    /// `{server, cmd?, run?}` → null
    ///
    /// Opens a terminal on that server with `cmd` typed into it. `run` sends
    /// it; the default does not, so the user reads the line before it runs and
    /// can edit it. A plugin that wants the output rather than the session has
    /// `sb.server.exec`; this is for the commands a person should watch —
    /// anything interactive, anything that asks before it acts.
    NavOpenTerminal,

    /// `{tab}` → null
    NavGoTab,

    /// null → `{text}`
    ClipboardRead,

    /// `{text}` → null
    ClipboardWrite,
}

/// Which host a plugin instance is running in.
///
/// The two differ in one way that matters and nothing else: the agent has no
/// user in front of it, so nothing that asks a person a question or takes them
/// somewhere exists there. PLUGINS.md 9.5.
///
/// **The absence needs no new mechanism.** A function this host does not have
/// is installed as a stub that throws, which is exactly what an ungranted one
/// already is — so "the manifest did not ask for it" and "this host has not
/// got it" arrive at a plugin the same way and differ only in what they say.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum HostProfile {
    /// The app: a person is looking at it.
    #[default]
    App,
    /// The monitor agent: a daemon on the server, on a timer, with nobody
    /// watching.
    Agent,
}

impl HostProfile {
    pub const fn name(self) -> &'static str {
        match self {
            Self::App => "app",
            Self::Agent => "agent",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "app" => Some(Self::App),
            "agent" => Some(Self::Agent),
            _ => None,
        }
    }
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
        Self::ServerList,
        Self::NavOpenServer,
        Self::NavOpenTerminal,
        Self::NavGoTab,
        Self::ClipboardRead,
        Self::ClipboardWrite,
    ];

    /// The object on `sb` this hangs off.
    pub const fn namespace(self) -> &'static str {
        match self {
            Self::ServerExec | Self::ServerList => "server",
            Self::HttpFetch => "http",
            Self::UiPatch | Self::UiPrompt | Self::UiPickServer | Self::UiToast => "ui",
            Self::StoreGet | Self::StoreSet | Self::StoreList => "store",
            Self::DiagCrumb => "diag",
            Self::NavOpenServer | Self::NavOpenTerminal | Self::NavGoTab => "nav",
            Self::ClipboardRead | Self::ClipboardWrite => "clipboard",
        }
    }

    /// The property name within that object.
    pub const fn method(self) -> &'static str {
        match self {
            Self::ServerExec => "exec",
            Self::ServerList => "list",
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
            Self::NavOpenTerminal => "openTerminal",
            Self::NavGoTab => "goTab",
            Self::ClipboardRead => "read",
            Self::ClipboardWrite => "write",
        }
    }

    /// `sb.server.exec`, for error messages and tests.
    pub fn path(self) -> String {
        format!("sb.{}.{}", self.namespace(), self.method())
    }

    /// Whether this function exists at all in [`profile`](HostProfile).
    ///
    /// The app has every one. The agent has the ones that do not involve a
    /// person: running a command on the machine it is *on*, reaching the
    /// network, its own storage, its config and its log. What it has not got
    /// is anything that asks a question, shows something, navigates, or
    /// touches a clipboard — there is nobody there — and `sb.server.list`,
    /// because an agent knows one machine and that machine is itself.
    pub const fn available_in(self, profile: HostProfile) -> bool {
        match profile {
            HostProfile::App => true,
            // `sb.server.exec` is **not** here, and its absence is not about
            // trust: the agent issues no server handle — there is no bound
            // server and no `sb.server.list` to get one from — so a call could
            // only ever name a handle that does not exist. A stub that says
            // "this host does not have that" is a better answer than one that
            // takes the argument and rejects it. A status plugin's `statusCmd`
            // is how it runs a command here, and the agent runs it.
            HostProfile::Agent => matches!(
                self,
                Self::HttpFetch
                    | Self::StoreGet
                    | Self::StoreSet
                    | Self::StoreList
                    | Self::DiagCrumb
            ),
        }
    }

    /// What the manifest must have asked for, or `None` for the ones 6.1 calls
    /// always granted.
    pub const fn permission(self) -> Option<Permission> {
        match self {
            Self::ServerExec => Some(Permission::ServerExec),
            Self::ServerList => Some(Permission::ServerList),
            // Opening a terminal is causing commands to run on that machine,
            // which is what `server.exec` is. That it is the user who types
            // them makes it no less than exec, only more visible.
            Self::NavOpenTerminal => Some(Permission::ServerExec),
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
                | HostFn::ServerList
                | HostFn::NavOpenTerminal
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
        assert_eq!(HostFn::ALL.len(), 16);
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
