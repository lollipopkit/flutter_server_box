use core::fmt;

/// What went wrong before or around a call.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PluginError {
    /// `plugin.js` did not parse, or did not evaluate.
    Module(String),

    /// The manifest could not be read, or asks for something this ABI version
    /// does not have.
    Manifest(String),

    /// The plugin does not export what was called.
    NoSuchExport(String),

    /// The plugin threw, or was stopped by a resource limit.
    ///
    /// The instance is not reusable after this: a plugin that was interrupted
    /// mid-function has left its own state in a shape nothing here can
    /// describe, and the same is true of one that ran out of memory.
    Threw(String),

    /// The plugin's answer was not the JSON the export is supposed to give.
    BadAnswer(String),

    /// A host function was called outside what the manifest asked for.
    ///
    /// Kept apart from [`PluginError::Threw`] because it names a permission,
    /// which is something to show the user rather than a stack trace to log.
    Denied(String),

    /// Something the engine promised did not hold. Not reachable from anything
    /// a plugin can express.
    Internal(String),
}

impl PluginError {
    /// A short machine-readable tag, for a caller that has to branch.
    ///
    /// The one the app acts on differently is `denied`: that names a permission
    /// and belongs in front of the user, while everything else is a log line.
    pub fn kind(&self) -> &'static str {
        match self {
            Self::Module(_) => "module",
            Self::Manifest(_) => "manifest",
            Self::NoSuchExport(_) => "no_such_export",
            Self::Threw(_) => "threw",
            Self::BadAnswer(_) => "bad_answer",
            Self::Denied(_) => "denied",
            Self::Internal(_) => "internal",
        }
    }
}

impl fmt::Display for PluginError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Module(m) => write!(f, "invalid plugin: {m}"),
            Self::Manifest(m) => write!(f, "invalid manifest: {m}"),
            Self::NoSuchExport(m) => write!(f, "no such export: {m}"),
            Self::Threw(m) => write!(f, "plugin threw: {m}"),
            Self::BadAnswer(m) => write!(f, "plugin answered badly: {m}"),
            Self::Denied(m) => write!(f, "{m}"),
            Self::Internal(m) => write!(f, "host failure: {m}"),
        }
    }
}

impl std::error::Error for PluginError {}

/// A refusal raised by the host rather than by the plugin's own code.
///
/// Thrown into JavaScript as an `Error` whose `name` is `PermissionDenied` or
/// `OutOfScope`, so a plugin *can* see it — but there is nothing useful to do
/// with it except report, and the host records it either way.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Refusal {
    /// A host function the manifest did not ask for. Raised by the stub
    /// installed in its place, so it happens on call, never on a check inside a
    /// working implementation.
    PermissionDenied { function: String, permission: &'static str },

    /// A granted function, called with an argument outside what the grant
    /// covers: an `sb.http.fetch` to a host no pattern matches, or
    /// `via: "ssh"` without `server.stream`.
    ///
    /// Separate from the stub above because it cannot be decided when the
    /// bindings are installed — it depends on the argument. Everything that
    /// *can* be decided then still is.
    OutOfScope { function: String, detail: String },

    /// The plugin handed a malformed argument to a host function.
    BadRequest { function: String, detail: String },

    /// A function this *host* does not have, whatever the manifest asked for.
    ///
    /// The monitor agent runs plugins with no user in front of it, so nothing
    /// in `sb.ui`, `sb.nav` or `sb.clipboard` exists there — see PLUGINS.md
    /// 9.5. Told apart from [`PermissionDenied`](Self::PermissionDenied)
    /// because the answers differ: a permission is something the user can
    /// grant, and this is not.
    Unavailable { function: String, host: &'static str },
}

impl Refusal {
    /// The `name` of the JavaScript `Error` this becomes.
    pub fn kind(&self) -> &'static str {
        match self {
            Self::PermissionDenied { .. } => "PermissionDenied",
            Self::OutOfScope { .. } => "OutOfScope",
            Self::BadRequest { .. } => "BadRequest",
            Self::Unavailable { .. } => "Unavailable",
        }
    }
}

impl fmt::Display for Refusal {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::PermissionDenied { function, permission } => {
                write!(f, "permission denied: {function} needs `{permission}`")
            }
            Self::OutOfScope { function, detail } => {
                write!(f, "out of scope: {function}: {detail}")
            }
            Self::BadRequest { function, detail } => {
                write!(f, "bad request to {function}: {detail}")
            }
            Self::Unavailable { function, host } => {
                write!(f, "{function} does not exist on the {host} host")
            }
        }
    }
}

impl std::error::Error for Refusal {}
