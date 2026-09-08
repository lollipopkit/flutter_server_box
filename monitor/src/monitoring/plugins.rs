//! Running plugins on the agent. PLUGINS.md 9.5.
//!
//! An app plugin collects only while somebody has the app open, so a reading
//! it takes never reaches `/metrics/history`, the watch or the home widgets —
//! all three read this agent directly and never speak to the app. Running the
//! same plugin here is what puts it in front of them.
//!
//! **Only status plugins.** A headless daemon has nothing to draw on, and the
//! manifest refuses `runs_in: ["agent"]` beside a UI contribution at parse
//! time. What is left is the shape this agent already deals in: a command, and
//! a reading out of its output.
//!
//! **What a client learns is `/metrics`' `plugin_status`, and nothing else.**
//! Its keys are the plugins that answered this cycle, which is a better answer
//! than a list of what was configured: a plugin named in the file but failing
//! to load would be in the second and not the first, and it is the first that
//! decides whether the app collects the same reading itself.
//!
//! **Off unless the operator says otherwise, and named one at a time.** There
//! is no user here to answer a dialog, so consent is `config.toml` — the same
//! place and the same default as `[remote_access]`. Nothing about a plugin is
//! taken from the app: it cannot install one, and the permissions a plugin
//! gets are the ones written in the file rather than the ones its manifest
//! asks for.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};
use std::sync::Arc;

use sbm_plugin::{
    HostBridge, HostProfile, InstanceId, InstanceOptions, Manifest, Permission, PluginHost,
};
use sbm_plugin::manifest::Platform;
use sbm_plugin::status::StatusResult;
use serde::{Deserialize, Serialize};
use tracing::{error, info, warn};

/// `[plugins]` in `config.toml`.
///
/// Absent means off, which is what every config written before this existed
/// says.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PluginsConfig {
    /// Nothing runs unless this is on *and* an entry below names it.
    #[serde(default)]
    pub enabled: bool,

    /// Where unpacked plugins live: one directory per id, each holding
    /// `manifest.json` and `plugin.js`.
    ///
    /// A directory rather than an archive, and put there by the operator. The
    /// app cannot install one — `full_access` is "run a command I typed and
    /// watch it", and code that runs on a schedule for ever is a different and
    /// larger thing to agree to.
    #[serde(default)]
    pub dir: Option<String>,

    /// Which plugins may run, and what each may do.
    #[serde(default)]
    pub plugin: Vec<PluginEntry>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PluginEntry {
    /// The manifest's id, which is also its directory's name.
    pub id: String,

    /// What this plugin may do, by permission name.
    ///
    /// **Written here, not read from the manifest.** A manifest says what a
    /// plugin wants; on a device the user answers that in a dialog, and here
    /// the operator answers it by typing. A plugin that asks for something not
    /// in this list gets the same throwing stub an app plugin would.
    #[serde(default)]
    pub grant: Vec<String>,

    /// `sb.config.get` on this agent, for the values a plugin needs and a
    /// manifest cannot know — an address, a unit name.
    #[serde(default)]
    pub config: BTreeMap<String, String>,
}

/// One loaded plugin, and what it last reported.
pub struct LoadedPlugin {
    pub id: String,
    pub version: String,
    pub instance: InstanceId,
    /// The platforms its manifest named, so it is not asked about one it has
    /// no command for.
    pub platforms: BTreeSet<String>,
}

/// The plugins this agent has, and the host they run on.
pub struct AgentPlugins {
    /// Shared because a call into it is made from a blocking thread — see
    /// [`AgentPlugins::collect_one`].
    host: Arc<PluginHost>,
    loaded: Vec<LoadedPlugin>,
}

impl AgentPlugins {
    /// Loads what `config.toml` names, and nothing else.
    ///
    /// A plugin that will not load is logged and skipped: the agent's job is
    /// to report the machine, and one bad directory must not stop it doing
    /// that.
    ///
    /// `bridge` is what every loaded plugin's `sb.*` reaches — passed in
    /// rather than built here, because it holds the database handle and the
    /// runtime, and this module has nothing else to do with either.
    pub fn load(config: &PluginsConfig, bridge: Arc<dyn HostBridge>) -> Self {
        let host = Arc::new(PluginHost::new());
        let mut loaded = Vec::new();

        if !config.enabled || config.plugin.is_empty() {
            return Self { host, loaded };
        }
        let Some(dir) = config.dir.as_ref() else {
            warn!("[plugins] is enabled but names no `dir`; nothing will run");
            return Self { host, loaded };
        };
        let root = PathBuf::from(dir);

        for entry in &config.plugin {
            match load_one(&host, &root, entry, Arc::clone(&bridge)) {
                Ok(plugin) => {
                    info!("plugin {} v{} loaded", plugin.id, plugin.version);
                    loaded.push(plugin);
                }
                Err(e) => error!("plugin {} not loaded: {e}", entry.id),
            }
        }
        Self { host, loaded }
    }

    /// No plugins, and no way to get any.
    ///
    /// For the caller that could not build a host to run them in: the agent
    /// carries on reporting what it measures itself.
    pub fn none() -> Self {
        Self { host: Arc::new(PluginHost::new()), loaded: Vec::new() }
    }

    pub fn is_empty(&self) -> bool {
        self.loaded.is_empty()
    }

    /// Asks each plugin what to run, runs it, and hands the output back.
    ///
    /// One command per plugin per extended cycle, in sequence. Not in
    /// parallel: these are arbitrary shell on the machine this agent is
    /// supposed to be measuring, and a burst of them would show up in the
    /// numbers it reports.
    ///
    /// A plugin that fails is dropped from this cycle's answer rather than
    /// remembered as empty — the caller carries the previous reading forward,
    /// which is what every other extended field does.
    pub async fn collect(&self, platform: &str) -> BTreeMap<String, StatusResult> {
        let mut out = BTreeMap::new();
        for plugin in &self.loaded {
            if !plugin.platforms.contains(platform) {
                continue;
            }
            match self.collect_one(plugin, platform).await {
                Ok(result) => {
                    out.insert(plugin.id.clone(), result);
                }
                Err(e) => warn!("plugin {} did not report: {e}", plugin.id),
            }
        }
        out
    }

    async fn collect_one(
        &self,
        plugin: &LoadedPlugin,
        platform: &str,
    ) -> Result<StatusResult, String> {
        let parsed = Platform::parse(platform)
            .ok_or_else(|| format!("unknown platform `{platform}`"))?;

        // Off this thread, both times. A call into a plugin blocks until the
        // plugin answers, and a plugin may `await` — a store read, an HTTP
        // request with the agent's timeout on it. This loop runs on the
        // agent's `#[ntex::main]` thread, so blocking it stops the HTTP server
        // too, for as long as the plugin takes.
        let cmd = {
            let host = Arc::clone(&self.host);
            let id = plugin.instance;
            blocking(move || host.status_cmd(id, parsed).map_err(|e| e.to_string())).await?
        };

        let output = run_locally(&cmd.cmd).await?;

        let host = Arc::clone(&self.host);
        let id = plugin.instance;
        blocking(move || host.status_parse(id, &output).map_err(|e| e.to_string())).await
    }
}

fn load_one(
    host: &PluginHost,
    root: &Path,
    entry: &PluginEntry,
    bridge: Arc<dyn HostBridge>,
) -> Result<LoadedPlugin, String> {
    // The id names the directory, and nothing else may: an id with a separator
    // in it would reach outside the root the operator named.
    if entry.id.is_empty() || entry.id.contains('/') || entry.id.contains('\\') {
        return Err(format!("`{}` is not a plugin id", entry.id));
    }
    let dir = root.join(&entry.id);

    let manifest_bytes = std::fs::read(dir.join("manifest.json"))
        .map_err(|e| format!("manifest.json: {e}"))?;
    let manifest = Manifest::parse(&manifest_bytes).map_err(|e| e.to_string())?;
    if manifest.id != entry.id {
        return Err(format!(
            "the directory is `{}` but the manifest says `{}`",
            entry.id, manifest.id
        ));
    }
    if !manifest.runs_in_host(HostProfile::Agent) {
        return Err("its manifest does not say it runs in the agent".into());
    }
    let Some(status) = manifest.contributes.status.as_ref() else {
        return Err("it contributes no status, which is all an agent can run".into());
    };

    let source = std::fs::read_to_string(dir.join("plugin.js"))
        .map_err(|e| format!("plugin.js: {e}"))?;

    // The operator's list, intersected with what the manifest asks for — the
    // same rule the app applies to what a user consented to, and for the same
    // reason: a plugin updated to want more must not get it because the old
    // line in the file happened to be generous.
    let consented: BTreeSet<Permission> =
        entry.grant.iter().filter_map(|n| Permission::parse(n)).collect();
    for name in &entry.grant {
        if Permission::parse(name).is_none() {
            return Err(format!("unknown permission `{name}` in its `grant`"));
        }
    }
    let grants = manifest.resolve_grants(&consented, &entry.config);

    let mut options = InstanceOptions::new(manifest.id.clone(), format!("agent:{}", manifest.id));
    options.profile = HostProfile::Agent;
    options.grants = grants;
    options.config = entry.config.clone();

    let instance = host
        .load(source, options, bridge)
        .map_err(|e| e.to_string())?;

    Ok(LoadedPlugin {
        id: manifest.id.clone(),
        version: manifest.version.clone(),
        instance,
        platforms: status.platforms.iter().map(|p| p.name().to_string()).collect(),
    })
}

/// Runs `work` where blocking is allowed, and reports a panic in it as an
/// error rather than losing it.
///
/// A plugin that panicked the host would otherwise take this cycle's whole
/// answer with it, and the join failure would be all anyone saw.
async fn blocking<T, F>(work: F) -> Result<T, String>
where
    F: FnOnce() -> Result<T, String> + Send + 'static,
    T: Send + 'static,
{
    match tokio::task::spawn_blocking(work).await {
        Ok(answer) => answer,
        Err(e) => Err(format!("the call did not finish: {e}")),
    }
}

/// Runs a plugin's command on this machine.
///
/// The agent *is* the server, so there is no transport and no credential —
/// which is the whole reason a reading taken here is cheaper than the same one
/// taken over SSH from a phone.
async fn run_locally(script: &str) -> Result<String, String> {
    let mut command = if cfg!(target_os = "windows") {
        let mut c = tokio::process::Command::new("powershell");
        c.args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script]);
        c
    } else {
        let mut c = tokio::process::Command::new("sh");
        c.arg("-c").arg(script);
        c
    };
    let output = command.output().await.map_err(|e| e.to_string())?;
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    /// A plugin directory as the operator would lay one out.
    fn write_plugin(root: &Path, id: &str, manifest: &str, source: &str) {
        let dir = root.join(id);
        fs::create_dir_all(&dir).unwrap();
        fs::write(dir.join("manifest.json"), manifest).unwrap();
        fs::write(dir.join("plugin.js"), source).unwrap();
    }

    const SOURCE: &str = r#"
      export function statusCmd() { return { cmd: "echo hi" }; }
      export function parse() { return { title: "T", items: [] }; }
    "#;

    fn manifest(id: &str, runs_in: &str, extra: &str) -> String {
        format!(
            r#"{{
              "id": "{id}", "version": "1.0.0", "abi": 1, "name": "N",
              "runs_in": {runs_in},
              "permissions": {{ "server.exec": true }},
              "contributes": {{ "status": {{
                "id": "s", "label": "S", "platforms": ["linux"]
              }} }}{extra}
            }}"#
        )
    }

    fn config(root: &Path, entries: Vec<PluginEntry>) -> PluginsConfig {
        PluginsConfig {
            enabled: true,
            dir: Some(root.to_string_lossy().into_owned()),
            plugin: entries,
        }
    }

    /// Loading is what these tests are about, and nothing here calls `sb.*`.
    /// The real one needs a database and a runtime — it is tested where it
    /// lives, in `plugin_host`.
    struct NoBridge;

    impl sbm_plugin::HostBridge for NoBridge {
        fn call(
            &self,
            _ctx: sbm_plugin::CallCtx<'_>,
            func: sbm_plugin::HostFn,
            _request: &[u8],
        ) -> sbm_plugin::HostCall {
            unreachable!("a loading test called {}", func.path())
        }

        fn log(&self, _ctx: sbm_plugin::CallCtx<'_>, _level: sbm_plugin::LogLevel, _m: &str) {}
    }

    fn bridge() -> Arc<dyn HostBridge> {
        Arc::new(NoBridge)
    }

    fn entry(id: &str) -> PluginEntry {
        PluginEntry {
            id: id.to_string(),
            grant: vec!["server.exec".to_string()],
            config: BTreeMap::new(),
        }
    }

    /// The wiring, end to end: a plugin that `await`s reaches the real bridge,
    /// the answer comes back, and the reading is what it wrote.
    ///
    /// Deliberately a **current-thread** runtime, because that is the shape of
    /// the agent — `#[ntex::main]` builds one, and the monitoring loop is a
    /// task on it. A bridge that spawned its answer onto the caller's runtime
    /// would deadlock here and in production: the loop's thread is inside the
    /// plugin call, so the answer it is waiting for never gets a thread.
    #[tokio::test]
    async fn a_plugin_that_awaits_the_store_gets_its_answer() {
        const COUNTING: &str = r#"
          export function statusCmd() { return { cmd: "echo hi" }; }
          export async function parse({ text }) {
            const seen = await sb.store.get({ scope: "global", key: "runs" });
            const n = Number(seen.value ?? 0) + 1;
            await sb.store.set({ scope: "global", key: "runs", value: String(n) });
            return { title: text.trim() + " " + n, items: [] };
          }
        "#;

        let dir = tempfile::tempdir().unwrap();
        write_plugin(dir.path(), "p", &manifest("p", r#"["agent"]"#, ""), COUNTING);

        let pool = sqlx::sqlite::SqlitePoolOptions::new()
            .max_connections(1)
            .connect("sqlite::memory:")
            .await
            .unwrap();
        sqlx::migrate!("./migrations").run(&pool).await.unwrap();

        let plugins = AgentPlugins::load(
            &config(dir.path(), vec![entry("p")]),
            Arc::new(super::super::plugin_host::AgentBridge::new(pool).unwrap()),
        );

        assert_eq!(plugins.collect("linux").await["p"].title, "hi 1");
        // What it stored is still there on the next cycle, which is the whole
        // reason an agent-side plugin has a store at all.
        assert_eq!(plugins.collect("linux").await["p"].title, "hi 2");
    }

    /// An installed function that always refuses is worse than one that is not
    /// installed: the plugin's `catch` runs either way, but only one of the two
    /// is what the host said it had.
    #[tokio::test]
    async fn a_crumb_is_answered_rather_than_refused() {
        const CRUMBS: &str = r#"
          export function statusCmd() { return { cmd: "echo hi" }; }
          export async function parse() {
            await sb.diag.crumb({ name: "probed" });
            return { title: "ok", items: [] };
          }
        "#;

        let dir = tempfile::tempdir().unwrap();
        write_plugin(dir.path(), "p", &manifest("p", r#"["agent"]"#, ""), CRUMBS);

        let pool = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
        let plugins = AgentPlugins::load(
            &config(dir.path(), vec![entry("p")]),
            Arc::new(super::super::plugin_host::AgentBridge::new(pool).unwrap()),
        );

        assert_eq!(plugins.collect("linux").await["p"].title, "ok");
    }

    /// Every agent, until an operator says otherwise. The absent section and
    /// the present-but-off one have to mean the same thing.
    #[test]
    fn nothing_runs_unless_the_operator_turned_it_on() {
        let dir = tempfile::tempdir().unwrap();
        write_plugin(dir.path(), "p", &manifest("p", r#"["agent"]"#, ""), SOURCE);

        assert!(AgentPlugins::load(&PluginsConfig::default(), bridge()).is_empty());

        let mut off = config(dir.path(), vec![entry("p")]);
        off.enabled = false;
        assert!(AgentPlugins::load(&off, bridge()).is_empty());

        // And on, with the same directory, it loads — or the two assertions
        // above would pass for the wrong reason.
        assert!(!AgentPlugins::load(&config(dir.path(), vec![entry("p")]), bridge()).is_empty());
    }

    /// Declaring it is the plugin's half of the bargain. Without it the plugin
    /// has never been looked at for a host with no user in it.
    #[test]
    fn a_plugin_that_does_not_claim_the_agent_is_not_run() {
        let dir = tempfile::tempdir().unwrap();
        write_plugin(dir.path(), "p", &manifest("p", r#"["app"]"#, ""), SOURCE);

        assert!(AgentPlugins::load(&config(dir.path(), vec![entry("p")]), bridge()).is_empty());
    }

    /// The id names a directory under the root the operator chose, so a
    /// separator in it would reach outside.
    #[test]
    fn an_id_cannot_escape_the_directory() {
        let dir = tempfile::tempdir().unwrap();
        let mut e = entry("../elsewhere");
        e.id = "../elsewhere".to_string();
        assert!(AgentPlugins::load(&config(dir.path(), vec![e]), bridge()).is_empty());
    }

    /// A directory named for one plugin holding another's manifest is either a
    /// mistake or an attempt to run something under a name the operator
    /// approved. Refused either way.
    #[test]
    fn the_directory_and_the_manifest_must_agree() {
        let dir = tempfile::tempdir().unwrap();
        write_plugin(dir.path(), "p", &manifest("other", r#"["agent"]"#, ""), SOURCE);

        assert!(AgentPlugins::load(&config(dir.path(), vec![entry("p")]), bridge()).is_empty());
    }

    /// One bad directory must not stop the agent reporting the machine, which
    /// is its actual job.
    #[test]
    fn a_plugin_that_will_not_load_is_skipped_rather_than_fatal() {
        let dir = tempfile::tempdir().unwrap();
        write_plugin(dir.path(), "bad", "{ not json", SOURCE);
        write_plugin(dir.path(), "good", &manifest("good", r#"["agent"]"#, ""), SOURCE);

        let loaded = AgentPlugins::load(
            &config(dir.path(), vec![entry("bad"), entry("good")]),
            bridge(),
        );
        assert_eq!(loaded.loaded.len(), 1);
        assert_eq!(loaded.loaded[0].id, "good");
    }

    /// The operator's list is what grants, and it is intersected with what the
    /// manifest asks for — the same rule the app applies to a user's consent,
    /// so a plugin updated to want more does not get it because the line in
    /// the file was generous.
    #[tokio::test]
    async fn a_plugin_granted_nothing_still_loads_and_reports() {
        let dir = tempfile::tempdir().unwrap();
        write_plugin(dir.path(), "p", &manifest("p", r#"["agent"]"#, ""), SOURCE);

        let mut e = entry("p");
        e.grant.clear();
        let plugins = AgentPlugins::load(&config(dir.path(), vec![e]), bridge());
        assert!(!plugins.is_empty());

        // It never calls `sb.server.exec` itself — the agent runs the command
        // — so a status plugin works with nothing granted at all.
        let out = plugins.collect("linux").await;
        assert_eq!(out.get("p").map(|r| r.title.as_str()), Some("T"));
    }

    /// A plugin that named no such platform is not asked, rather than asked
    /// and answering a command for the wrong system.
    #[tokio::test]
    async fn a_platform_it_did_not_name_is_never_asked() {
        let dir = tempfile::tempdir().unwrap();
        write_plugin(dir.path(), "p", &manifest("p", r#"["agent"]"#, ""), SOURCE);

        let plugins = AgentPlugins::load(&config(dir.path(), vec![entry("p")]), bridge());
        assert!(plugins.collect("windows").await.is_empty());
        assert!(!plugins.collect("linux").await.is_empty());
    }
}
