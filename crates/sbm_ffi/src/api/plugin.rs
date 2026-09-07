//! Loading and calling plugins from Dart.
//!
//! The crossing has two directions and they are shaped differently on purpose.
//!
//! Dart to Rust is ordinary function calls. Rust to Dart is a `StreamSink`:
//! when a plugin calls something on `sb`, a [`PluginRequest`] appears on the
//! stream, Dart does the work, and Dart calls [`PluginRuntime::answer`] quoting
//! the `callId`. Nothing here awaits a Dart future, because a host call
//! originates on a plugin's own thread — one that belongs to no async runtime,
//! where `tokio::spawn` would panic.
//!
//! **`call` and `load` must not be `frb(sync)`.** Both wait for the plugin,
//! which waits for Dart to answer; running them on the Dart isolate would stop
//! the isolate that has to do the answering, and neither side would ever
//! proceed. `answer` and the small accessors are sync because they only touch a
//! map.

use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use flutter_rust_bridge::frb;

// The codec-bound alias the generated code defines, which is what a stream
// argument must be written as.
use crate::frb_generated::StreamSink;
use sbm_plugin::{
    BridgeError, ChannelBridge, Grants, InstanceId, InstanceOptions, LogLevel, Manifest,
    Permission, Platform, PluginError, PluginHost,
};

/// Why a plugin call did not answer.
///
/// A local type rather than the runtime's own enum: the app branches on one
/// thing — whether this was a refusal to put in front of the user or a fault to
/// log — and a string pair crosses the boundary without the generated code
/// needing to know the runtime's shape.
#[derive(Debug, Clone)]
pub struct PluginFailure {
    /// `module`, `manifest`, `no_such_export`, `threw`, `bad_answer`,
    /// `denied` or `internal`. `denied` names a permission and is the one to
    /// show; the rest belong in a log.
    pub kind: String,
    pub message: String,
}

impl From<PluginError> for PluginFailure {
    fn from(e: PluginError) -> Self {
        Self { kind: e.kind().to_string(), message: e.to_string() }
    }
}

/// Something a plugin asked the app to do.
///
/// Answer it with [`PluginRuntime::answer`], quoting `call_id`. An answer that
/// never comes stalls that plugin until its own timeout, so answer every one —
/// including with a failure.
#[derive(Debug, Clone)]
pub struct PluginRequest {
    pub call_id: u64,
    /// Which plugin, as its manifest `id`.
    pub plugin_id: String,
    /// Which instance, as the app named it when loading.
    pub instance_id: String,
    /// `sb.http.fetch`, and so on. The full list is PLUGINS.md 4.3.
    pub func: String,
    /// The argument, as JSON.
    pub request: String,
}

/// A line a plugin wrote through `sb.log.*`. Nothing answers it.
#[derive(Debug, Clone)]
pub struct PluginLog {
    pub plugin_id: String,
    pub instance_id: String,
    /// `trace`, `debug`, `info`, `warn` or `error`.
    pub level: String,
    pub message: String,
}

/// Everything an instance needs beyond its source.
#[derive(Debug, Clone)]
pub struct PluginSpec {
    /// The manifest, verbatim. Parsed here so there is one parser.
    pub manifest_json: String,
    /// `plugin.js`.
    pub source: String,
    /// Unique per surface for as long as it is open.
    pub instance_id: String,
    /// Permissions the user agreed to, by name. Intersected with what the
    /// manifest asks for.
    pub granted: Vec<String>,
    /// This server's configuration for this plugin.
    pub config: Vec<(String, String)>,
    /// The opaque handle for the bound server, or absent for a global surface.
    pub bound_server: Option<String>,
}

/// The plugin runtime, one per app.
///
/// Create it once, keep it, and read `requests` and `logs` for as long as it
/// lives.
pub struct PluginRuntime {
    host: PluginHost,
    bridge: Arc<ChannelBridge>,
    /// The manifest each instance was loaded with, so the app does not have to
    /// carry it back for every question.
    manifests: Mutex<BTreeMap<u64, Manifest>>,
}

impl PluginRuntime {
    /// Starts the runtime.
    ///
    /// Both sinks stay open for the runtime's life. A plugin blocks until its
    /// request is answered, so whatever reads `requests` must keep reading.
    pub fn new(
        requests: StreamSink<PluginRequest>,
        logs: StreamSink<PluginLog>,
    ) -> Self {
        let bridge = ChannelBridge::new(
            move |r| {
                // A closed stream means Dart has gone away; the plugin's own
                // timeout is what notices.
                let _ = requests.add(PluginRequest {
                    call_id: r.call_id,
                    plugin_id: r.plugin_id,
                    instance_id: r.instance_id,
                    func: r.func,
                    request: r.request,
                });
            },
            move |l| {
                let _ = logs.add(PluginLog {
                    plugin_id: l.plugin_id,
                    instance_id: l.instance_id,
                    level: l.level.name().to_string(),
                    message: l.message,
                });
            },
        );
        Self { host: PluginHost::new(), bridge, manifests: Mutex::new(BTreeMap::new()) }
    }

    /// Compiles a plugin and keeps it on a thread of its own.
    ///
    /// Not `sync`: a module may await a host call while it loads, and that
    /// answer has to come from the Dart isolate.
    pub fn load(&self, spec: PluginSpec) -> Result<u64, PluginFailure> {
        let manifest = Manifest::parse(spec.manifest_json.as_bytes())?;

        let consented = spec
            .granted
            .iter()
            .filter_map(|name| Permission::parse(name))
            .collect();
        let config: BTreeMap<String, String> = spec.config.into_iter().collect();
        let grants = manifest.resolve_grants(&consented, &config);

        let mut options = InstanceOptions::new(manifest.id.clone(), spec.instance_id);
        options.grants = grants;
        options.config = config;
        options.bound_server = spec.bound_server;

        let id = self.host.load(spec.source, options, Arc::clone(&self.bridge) as Arc<_>)?;
        self.manifests.lock().expect("poisoned").insert(id.0, manifest);
        Ok(id.0)
    }

    /// Calls one of PLUGINS.md 4.2's exports.
    ///
    /// Not `sync`, and this is the one that would deadlock: it waits for the
    /// plugin, which waits for Dart to answer its host calls.
    pub fn call(&self, instance: u64, export: String, input: String) -> Result<String, PluginFailure> {
        let out = self.host.call(InstanceId(instance), &export, input.as_bytes())?;
        Ok(String::from_utf8_lossy(&out).into_owned())
    }

    /// The app's answer to one [`PluginRequest`].
    ///
    /// Exactly one of the three outcomes:
    ///
    /// - `ok` — the JSON the function answers with. `null` for the ones that
    ///   answer nothing.
    /// - `error_kind` plus `error_message` — the app tried and could not. The
    ///   plugin sees a rejected promise it can catch.
    /// - `denied` — the app refuses. The plugin cannot catch it, and the call
    ///   ends the way an ungranted function would.
    ///
    /// Answers whether anything was still waiting. `false` is ordinary: a page
    /// closed while a request was in flight.
    #[frb(sync)]
    pub fn answer(
        &self,
        call_id: u64,
        ok: Option<String>,
        error_kind: Option<String>,
        error_message: Option<String>,
        denied: Option<String>,
    ) -> bool {
        let answer = if let Some(detail) = denied {
            Err(BridgeError::Denied { detail })
        } else if let Some(kind) = error_kind {
            Err(BridgeError::failed(kind, error_message.unwrap_or_default()))
        } else {
            Ok(ok.unwrap_or_else(|| "null".to_string()).into_bytes())
        };
        self.bridge.answer(call_id, answer)
    }

    /// Ends an instance and waits for its thread, so its outstanding requests
    /// are cancelled before this returns.
    pub fn unload(&self, instance: u64) {
        self.host.unload(InstanceId(instance));
        self.manifests.lock().expect("poisoned").remove(&instance);
    }

    /// What the plugin exports, so the app can tell a card from a status plugin
    /// without calling anything.
    #[frb(sync)]
    pub fn exports(&self, instance: u64) -> Result<Vec<String>, PluginFailure> {
        Ok(self.host.exports(InstanceId(instance))?)
    }

    #[frb(sync)]
    pub fn has_export(&self, instance: u64, export: String) -> bool {
        self.host.has_export(InstanceId(instance), &export)
    }

    /// Adds a server handle the app issued outside a call — after a picker, or
    /// when a surface is rebound.
    #[frb(sync)]
    pub fn issue_server_handle(&self, instance: u64, handle: String) -> Result<(), PluginFailure> {
        Ok(self.host.issue_server_handle(InstanceId(instance), handle)?)
    }

    /// How many requests the app has not answered. For diagnostics.
    #[frb(sync)]
    pub fn outstanding(&self) -> u32 {
        self.bridge.outstanding() as u32
    }

    /// What a status plugin wants run on `platform`. PLUGINS.md 9.
    ///
    /// Not `sync`, for [`PluginRuntime::call`]'s reason: a plugin may await a
    /// host call while answering.
    ///
    /// The same call the install page makes to show what the plugin will run,
    /// so what the user was shown and what the app runs cannot differ for want
    /// of asking twice.
    pub async fn status_cmd(
        &self,
        instance: u64,
        platform: String,
    ) -> Result<PluginStatusCmd, PluginFailure> {
        let platform = Platform::parse(&platform)
            .ok_or_else(|| PluginError::BadAnswer(format!("unknown platform `{platform}`")))?;
        let cmd = self.host.status_cmd(InstanceId(instance), platform)?;
        Ok(PluginStatusCmd { cmd: cmd.cmd })
    }

    /// Hands a status plugin what its command printed, and takes back the
    /// readings.
    ///
    /// Checked by `sbm_plugin::status` before it gets here: a label longer
    /// than a label is cut, a `percent` outside 0..1 is dropped rather than
    /// clamped, and only a document that is not this shape at all is refused.
    /// A bad status plugin costs a row, not a card.
    pub async fn status_parse(
        &self,
        instance: u64,
        text: String,
    ) -> Result<PluginStatusResult, PluginFailure> {
        let out = self.host.status_parse(InstanceId(instance), &text)?;
        Ok(PluginStatusResult {
            title: out.title,
            note: out.note,
            items: out
                .items
                .into_iter()
                .map(|i| PluginStatusItem {
                    label: i.label,
                    value: i.value,
                    percent: i.percent,
                    tone: format!("{:?}", i.tone).to_lowercase(),
                })
                .collect(),
        })
    }
}

/// What a status plugin says to run.
#[derive(Debug, Clone)]
pub struct PluginStatusCmd {
    pub cmd: String,
}

/// One reading.
#[derive(Debug, Clone)]
pub struct PluginStatusItem {
    pub label: String,
    pub value: String,
    /// 0..1, drawn as a bar beside the value. Absent where the reading is not
    /// a proportion.
    pub percent: Option<f64>,
    /// `normal`, `muted`, `success`, `warning` or `danger` — a name rather
    /// than a colour, so a plugin's row looks like the app's own in both
    /// themes and cannot ship an unreadable one.
    pub tone: String,
}

/// A status plugin's readings for one collection.
#[derive(Debug, Clone)]
pub struct PluginStatusResult {
    /// Falls back to the plugin's name when empty.
    pub title: String,
    pub items: Vec<PluginStatusItem>,
    /// Shown under the readings, for what a row cannot say.
    pub note: Option<String>,
}

/// Reads a manifest without loading anything.
///
/// What the install page needs: the name, the version, and the permissions to
/// put in front of the user. Refuses a manifest asking for an ABI this build
/// does not implement, which is the check that keeps a newer plugin from
/// half-working.
#[frb(sync)]
pub fn plugin_read_manifest(manifest_json: String) -> Result<PluginManifestInfo, PluginFailure> {
    let m = Manifest::parse(manifest_json.as_bytes())?;
    Ok(PluginManifestInfo {
        id: m.id.clone(),
        version: m.version.clone(),
        abi: m.abi,
        name: m.name.clone(),
        description: m.description.clone(),
        permissions: m.requested().iter().map(|p| p.name().to_string()).collect(),
        card: m.contributes.card.as_ref().map(|c| PluginCardInfo {
            id: c.id.clone(),
            label: c.label.clone(),
            icon: c.icon.clone(),
            default_on: c.default_on,
            requires_config: c.requires_config,
        }),
        status: m.contributes.status.as_ref().map(|s| PluginStatusInfo {
            id: s.id.clone(),
            label: s.label.clone(),
            icon: s.icon.clone(),
            default_on: s.default_on,
            requires_config: s.requires_config,
            platforms: s.platforms.iter().map(|p| p.name().to_string()).collect(),
        }),
        license: m.license.clone(),
        source_url: m.source_url.clone(),
    })
}

/// What the install page shows.
#[derive(Debug, Clone)]
pub struct PluginManifestInfo {
    pub id: String,
    pub version: String,
    pub abi: u32,
    pub name: String,
    pub description: String,
    /// Permission names, for the dialog. PLUGINS.md 6.1.
    pub permissions: Vec<String>,
    /// Present when this plugin draws a card on the server detail page.
    pub card: Option<PluginCardInfo>,
    /// Present when this plugin contributes readings to the status page.
    pub status: Option<PluginStatusInfo>,
    pub license: Option<String>,
    pub source_url: Option<String>,
}

/// A card on the server detail page, drawn from the widget tree the plugin
/// answers `open` with. PLUGINS.md 5.3.
///
/// Unlike a status contribution this has a surface: the plugin holds state,
/// answers events, and is ticked while it is on screen.
#[derive(Debug, Clone)]
pub struct PluginCardInfo {
    /// Stable within the plugin; the stored id is `<plugin id>:<this>`.
    pub id: String,
    pub label: String,
    pub icon: Option<String>,
    pub default_on: bool,
    /// Show this only on a server that has configuration for the plugin.
    ///
    /// Not a nicety. A card that appeared on every server to say "not
    /// configured" would be a row of noise on the machines that have no BMC,
    /// which is most of them — and the plugin cannot decide it for itself,
    /// because deciding means being instantiated and instantiated is already
    /// the cost.
    pub requires_config: bool,
}

/// A status contribution, as the app needs it to decide what to collect.
///
/// PLUGINS.md 9. There is no surface: the app asks the plugin what to run,
/// runs it, hands back what it printed, and draws the readings with the
/// widgets it draws its own with.
#[derive(Debug, Clone)]
pub struct PluginStatusInfo {
    /// Stable within the plugin; the stored id is `<plugin id>:<this>`.
    pub id: String,
    pub label: String,
    pub icon: Option<String>,
    pub default_on: bool,
    pub requires_config: bool,
    /// `linux`, `bsd`, `windows`. A plugin is not asked about a platform it
    /// did not name — the answer would be nothing, once per collection, or a
    /// command for the wrong system.
    pub platforms: Vec<String>,
}

/// The ABI this build implements. A plugin whose manifest asks for more is
/// refused.
#[frb(sync)]
pub fn plugin_abi_version() -> u32 {
    sbm_plugin::runtime::ABI_VERSION
}

/// Every permission a manifest may ask for, so the app's dialog and this build
/// cannot disagree about the list.
#[frb(sync)]
pub fn plugin_permissions() -> Vec<String> {
    Permission::ALL.iter().map(|p| p.name().to_string()).collect()
}

/// Every function a plugin may call, as `sb.http.fetch` and so on.
///
/// The app implements these; reading the list from here is what keeps the two
/// from drifting.
#[frb(sync)]
pub fn plugin_host_functions() -> Vec<String> {
    sbm_plugin::HostFn::ALL.iter().map(|f| f.path()).collect()
}

// Kept so a rename in `sbm_plugin` shows up here as an error rather than as a
// level string the app does not recognise.
const _: fn(LogLevel) -> &'static str = |l| l.name();
const _: Duration = sbm_plugin::DEFAULT_HOST_CALL_TIMEOUT;
const _: fn(&Grants, Permission) -> bool = |g, p| g.allows(p);
