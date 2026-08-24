use crate::core::remote_access::RemoteAccessConfig;
use crate::core::config_file;
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    // Rust-specific fields
    #[serde(skip_serializing_if = "Option::is_none")]
    pub server: Option<ServerConfig>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub monitoring: Option<MonitoringConfig>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub database_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jwt_secret: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub push: Option<Vec<PushConfig>>,
    /// WebSocket access to the local sshd — off unless present and enabled.
    /// Absent in every config written before the feature existed, hence
    /// `Option`; see `core::remote_access`.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub remote_access: Option<RemoteAccessConfig>,

    /// The flat top-level keys the Go agent's `config.json` used.
    ///
    /// Read-only, and never written back: [`Self::normalize`] folds them into
    /// the sections above and then clears them, so the `config.toml` this
    /// agent writes on its first start is in the current shape and the next
    /// start takes the TOML branch of [`Self::load`]. `#[serde(skip)]` on the
    /// serialize side is what guarantees the second half of that.
    ///
    /// Flat on purpose: this is the *other program's* format, and it is only
    /// ever deserialized from a file that program wrote.
    // TODO: drop `legacy` and the `config.json` branch of `load` once no Go
    // agent is left to migrate from.
    #[serde(flatten)]
    pub legacy: LegacyGoConfig,
}

/// The Go agent's flat `config.json` keys — see [`Config::legacy`].
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct LegacyGoConfig {
    #[serde(default, skip_serializing)]
    pub version: Option<i32>,
    /// Go-style duration, e.g. `"7s"`.
    #[serde(default, skip_serializing)]
    pub interval: Option<String>,
    #[serde(default, skip_serializing)]
    pub rate: Option<String>,
    #[serde(default, skip_serializing)]
    pub name: Option<String>,
    #[serde(default, skip_serializing)]
    pub rules: Option<Vec<GoRule>>,
    #[serde(default, skip_serializing)]
    pub pushes: Option<Vec<GoPush>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub tls: Option<TlsConfig>,
    /// What this machine is called in the app and in pushes. `None` = derive
    /// it from the host — see [`Config::get_server_name`].
    ///
    /// Here rather than at the top level, where the Go agent put it: it names
    /// the thing `host`/`port` also describe.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    /// Origins allowed to call the API cross-origin (e.g. a panel hosted on
    /// Cloudflare Pages). Empty = same-origin only (no CORS headers).
    #[serde(default)]
    pub cors_allowed_origins: Vec<String>,
    /// Home-grid card display order (StatCard keys, e.g. "cpu"/"memory"/...),
    /// persisted server-side (not per-browser localStorage) so every client
    /// viewing this agent sees the same arrangement. Empty = default order;
    /// never read by the backend itself, purely a sync point for the panel.
    #[serde(default)]
    pub card_order: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TlsConfig {
    pub cert_path: String,
    pub key_path: String,
}

/// Stated once, here, rather than at each of the places that used to build a
/// `ServerConfig` by hand — they had drifted apart on whether the environment
/// is read at all.
impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            host: env::var("SBM_HOST").unwrap_or_else(|_| "0.0.0.0".to_string()),
            port: env::var("SBM_PORT")
                .unwrap_or_else(|_| "3770".to_string())
                .parse()
                .unwrap_or(3770),
            tls: env::var("SBM_TLS_CERT")
                .ok()
                .zip(env::var("SBM_TLS_KEY").ok())
                .map(|(cert, key)| TlsConfig {
                    cert_path: cert,
                    key_path: key,
                }),
            name: None,
            cors_allowed_origins: Vec::new(),
            card_order: Vec::new(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MonitoringConfig {
    pub interval_seconds: u64,
    pub rules: Vec<MonitoringRule>,
    pub data_retention: Option<DataRetentionConfig>,

    /// Push rate limit for what the rules above trigger, formatted
    /// "N/duration" (e.g. "1/1m"). `None` = once per minute.
    ///
    /// Here rather than next to `[[push]]`: it bounds how often a *rule* may
    /// fire, not how a channel delivers, and a TOML array-of-tables has
    /// nowhere to put a scalar that applies to all of them.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub push_rate: Option<String>,

    #[serde(default)]
    pub extended: ExtendedConfig,
}

/// `[monitoring.extended]` — the slower cycle that collects
/// battery/sensors/SMART/AMD-GPU data, the only fields still bound to CLI
/// tools after monitor's native collection cutover.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ExtendedConfig {
    /// `None` (the default, and what an unset/absent config value resolves
    /// to) does *not* mean "same as `interval_seconds`" — resolve via
    /// [`MonitoringConfig::effective_extended_interval_secs`], which defaults
    /// to a much slower cadence. Running `smartctl`/`sensors`/`amd-smi` every
    /// core cycle (e.g. every few seconds) is real, avoidable
    /// CPU/power/battery-drain cost for data that essentially never changes
    /// that fast; SMART reads themselves are negligible flash wear (a
    /// diagnostic log read, not a write), so the slower default here is about
    /// host resource use, not disk lifespan.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub interval_secs: Option<u64>,

    #[serde(default)]
    pub idle_pause: IdlePauseConfig,
}

/// `[monitoring.extended.idle_pause]` — skipping the extended cycle while
/// nobody is looking.
///
/// A subsection of `extended` rather than of `monitoring`, because that is the
/// only cycle it can pause: core metrics and alert rule checks run either way.
/// Nesting says so; the flat name `monitoring.idle_pause_enabled` read as
/// though monitoring itself stopped.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IdlePauseConfig {
    /// Pause while no authenticated client has polled `/metrics` or `/status`
    /// recently. Approximates "nobody has the panel open," not a real browser
    /// visibility signal — see `AppState.last_viewer_seen`.
    #[serde(default = "default_idle_pause_enabled")]
    pub enabled: bool,

    /// How long without a poll before the extended cycle is considered idle.
    /// `None` (default) resolves to `interval_seconds * 4` — long enough to
    /// tolerate a couple of missed/slow polls without flapping.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub threshold_secs: Option<u64>,
}

impl Default for IdlePauseConfig {
    fn default() -> Self {
        Self {
            enabled: default_idle_pause_enabled(),
            threshold_secs: None,
        }
    }
}

fn default_idle_pause_enabled() -> bool {
    true
}

impl MonitoringConfig {
    /// Unset defaults to 10x the core interval, floored at 120s — running
    /// smartctl/sensors/amd-smi on every core cycle (previously: literally
    /// every cycle, since this defaulted to `interval_seconds` itself) burns
    /// CPU/power for data that doesn't change meaningfully faster than a
    /// couple of minutes. An explicit `[monitoring.extended] interval_secs`
    /// in config.toml (or the settings page) always overrides this.
    pub fn effective_extended_interval_secs(&self) -> u64 {
        self.extended
            .interval_secs
            .unwrap_or_else(|| self.interval_seconds.saturating_mul(10).max(120))
    }

    pub fn effective_idle_pause_threshold_secs(&self) -> u64 {
        self.extended
            .idle_pause
            .threshold_secs
            .unwrap_or(self.interval_seconds.saturating_mul(4))
    }
}

fn default_max_db_size_mb() -> u64 {
    256
}

/// The interval every construction site used to repeat.
const DEFAULT_INTERVAL_SECONDS: u64 = 7;

impl Default for MonitoringConfig {
    fn default() -> Self {
        Self {
            interval_seconds: DEFAULT_INTERVAL_SECONDS,
            rules: Vec::new(),
            data_retention: Some(DataRetentionConfig::default()),
            push_rate: None,
            extended: ExtendedConfig::default(),
        }
    }
}

impl Default for DataRetentionConfig {
    fn default() -> Self {
        Self {
            metrics_days: 30,
            alerts_days: 90,
            cleanup_interval_hours: 24,
            max_db_size_mb: default_max_db_size_mb(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataRetentionConfig {
    pub metrics_days: u32,
    pub alerts_days: u32,
    pub cleanup_interval_hours: u32,
    /// Hard cap on the SQLite file size; oldest time-series rows are dropped
    /// until the database fits (0 disables the cap)
    #[serde(default = "default_max_db_size_mb")]
    pub max_db_size_mb: u64,
}

impl DataRetentionConfig {
    /// A zero duration makes Tokio's interval tick continuously, turning
    /// retention into a database-consuming busy loop.
    pub fn validate(&self) -> std::result::Result<(), String> {
        if self.cleanup_interval_hours < 1 {
            Err("data_retention.cleanup_interval_hours must be at least 1".to_string())
        } else {
            Ok(())
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MonitoringRule {
    pub name: String,
    pub monitor_type: String,
    pub threshold: String,
    pub matcher: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PushConfig {
    pub name: String,
    pub push_type: String,
    #[serde(flatten)]
    pub config: toml::Table,
}

// Go-compatible structures
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GoRule {
    #[serde(rename = "type")]
    pub monitor_type: String,
    pub threshold: String,
    pub matcher: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GoPush {
    #[serde(rename = "type")]
    pub push_type: String,
    pub name: String,
    pub iface: serde_json::Value,
}

impl Config {
    pub async fn load() -> Result<Self> {
        // .env support: environment variables are the primary config channel for Docker/systemd
        dotenvy::dotenv().ok();

        // Try to load from config file first (TOML preferred, JSON fallback)
        if Path::new("config.toml").exists() {
            let content =
                fs::read_to_string("config.toml").context("Failed to read config.toml")?;
            let mut config: Self = toml::from_str(&content).context("Failed to parse config.toml")?;
            
            // Convert from Go format if needed
            config.normalize()?;
            config.apply_env_overrides();
            config.validate()?;
            return Ok(config);
        } else if let Some(json_path) = legacy_json_path() {
            let content = fs::read_to_string(&json_path)
                .with_context(|| format!("Failed to read {}", json_path.display()))?;
            let mut config: Self = serde_json::from_str(&content).context("Failed to parse config.json")?;

            // Convert from Go format if needed
            config.normalize()?;
            config.apply_env_overrides();
            config.validate()?;

            // One-way migration to config.toml so subsequent starts take the
            // config.toml branch above instead of re-parsing JSON every time.
            // The original file is renamed (kept, not deleted) as a safety
            // net rather than silently discarded — if the TOML write fails,
            // config.json is left untouched and this run still succeeds off
            // the in-memory config.
            let toml_content =
                toml::to_string_pretty(&config).context("Failed to serialize migrated config")?;
            config_file::write_atomic(Path::new("config.toml"), toml_content.as_bytes())
                .context("Failed to write migrated config.toml")?;
            let migrated_path = json_path.with_extension("json.migrated");
            match fs::rename(&json_path, &migrated_path) {
                Ok(()) => tracing::info!(
                    "Migrated {} to config.toml (old file kept as {})",
                    json_path.display(),
                    migrated_path.display(),
                ),
                Err(e) => tracing::warn!(
                    "Migrated {} to config.toml but couldn't rename it: {e}",
                    json_path.display(),
                ),
            }

            return Ok(config);
        }

        // Create default config
        let mut config = Self::default();
        config.apply_env_overrides();
        config.validate()?;

        // Save default config as TOML
        let content =
            toml::to_string_pretty(&config).context("Failed to serialize default config")?;
        config_file::write_atomic(Path::new("config.toml"), content.as_bytes())
            .context("Failed to write default config.toml")?;

        Ok(config)
    }

    /// Validates values that would otherwise be accepted by serde but make a
    /// runtime task unsafe or unusable.
    pub fn validate(&self) -> Result<()> {
        if let Some(monitoring) = self.monitoring.as_ref() {
            if monitoring.interval_seconds == 0 {
                anyhow::bail!("monitoring.interval_seconds must be >= 1");
            }
            if let Some(retention) = monitoring.data_retention.as_ref() {
                retention.validate().map_err(anyhow::Error::msg)?;
            }
        }
        Ok(())
    }

    /// Folds the Go agent's flat keys into the sections this agent uses, then
    /// clears them so nothing downstream — including the `config.toml` written
    /// straight after — carries the old shape.
    pub fn normalize(&mut self) -> Result<()> {
        // If we have Go-style config, convert it
        if self.server.is_none() && self.monitoring.is_none() {
            // Convert Go format to Rust format
            let server = ServerConfig {
                host: env::var("SBM_HOST").unwrap_or_else(|_| "0.0.0.0".to_string()),
                port: env::var("SBM_PORT")
                    .unwrap_or_else(|_| "3770".to_string())
                    .parse()
                    .unwrap_or(3770),
                tls: env::var("SBM_TLS_CERT")
                    .ok()
                    .zip(env::var("SBM_TLS_KEY").ok())
                    .map(|(cert, key)| TlsConfig {
                        cert_path: cert,
                        key_path: key,
                    }),
                name: self.legacy.name.clone(),
                cors_allowed_origins: Vec::new(),
                card_order: Vec::new(),
            };

            let interval_seconds = if let Some(interval_str) = &self.legacy.interval {
                // Parse Go-style interval like "7s"
                if interval_str.ends_with('s') {
                    interval_str[..interval_str.len()-1].parse().unwrap_or(7)
                } else {
                    7
                }
            } else {
                7
            };

            let monitoring = MonitoringConfig {
                interval_seconds,
                rules: self.legacy.rules.as_ref().map(|go_rules| {
                    go_rules.iter().map(|gr| MonitoringRule {
                        name: format!("{} {}", gr.monitor_type, gr.threshold),
                        monitor_type: gr.monitor_type.clone(),
                        threshold: gr.threshold.clone(),
                        matcher: gr.matcher.clone(),
                    }).collect()
                }).unwrap_or_default(),
                data_retention: Some(DataRetentionConfig {
                    metrics_days: 30,
                    alerts_days: 90,
                    cleanup_interval_hours: 24,
                    max_db_size_mb: default_max_db_size_mb(),
                }),
                push_rate: self.legacy.rate.clone(),
                extended: ExtendedConfig::default(),
            };

            let push = self
                .legacy
                .pushes
                .as_ref()
                .map(|pushes| pushes.iter().map(normalize_go_push).collect())
                .unwrap_or_default();

            self.server = Some(server);
            self.monitoring = Some(monitoring);
            self.database_url = Some(env::var("DATABASE_URL")
                .unwrap_or_else(|_| "sqlite:serverbox_monitor.db".to_string()));
            self.jwt_secret = env::var("JWT_SECRET").ok().filter(|s| !s.is_empty());
            self.push = Some(push);
        }

        // Everything the Go keys said now lives in a section. Cleared rather
        // than left in place: `skip_serializing` already keeps them out of the
        // file, and leaving them in memory would give every reader two places
        // to look for the same answer.
        self.legacy = LegacyGoConfig::default();

        Ok(())
    }

    /// The `[server]` section, or what an absent one means.
    ///
    /// Absent is not the same as "nothing configured": `SBM_HOST`/`SBM_PORT`/
    /// `SBM_TLS_*` still apply, which is what [`ServerConfig::default`] reads.
    /// This used to hard-code `0.0.0.0:3770` here and read the env only in
    /// [`Config::default`], so a file with a `[monitoring]` section and no
    /// `[server]` one silently ignored `SBM_HOST`.
    pub fn get_server(&self) -> ServerConfig {
        self.server.clone().unwrap_or_default()
    }

    pub fn get_monitoring(&self) -> MonitoringConfig {
        self.monitoring.clone().unwrap_or_default()
    }

    pub fn get_database_url(&self) -> String {
        self.database_url.clone().unwrap_or_else(|| "sqlite:serverbox_monitor.db".to_string())
    }

    /// Environment variable overrides (take precedence over config files); empty values count as unset
    fn apply_env_overrides(&mut self) {
        if let Some(secret) = env::var("JWT_SECRET").ok().filter(|s| !s.is_empty()) {
            self.jwt_secret = Some(secret);
        }
        if let Some(origins) = env::var("SBM_CORS_ORIGINS").ok().filter(|s| !s.is_empty()) {
            let mut server = self.get_server();
            server.cors_allowed_origins = origins
                .split(',')
                .map(|o| o.trim().trim_end_matches('/').to_string())
                .filter(|o| !o.is_empty())
                .collect();
            self.server = Some(server);
        }
    }

    /// JWT secret resolution; must be called once at serve startup:
    /// - explicitly configured (env/config file): example values and short keys rejected
    /// - unset: a randomly generated secret is persisted next to the database (0600)
    pub fn resolve_jwt_secret(&mut self) -> Result<()> {
        const MIN_LEN: usize = 32;
        const KNOWN_DEFAULTS: &[&str] = &[
            "your-secret-key-change-this",
            "your-secret-key-change-this-in-production",
        ];

        if let Some(secret) = &self.jwt_secret {
            if KNOWN_DEFAULTS.contains(&secret.as_str()) {
                anyhow::bail!(
                    "JWT_SECRET is set to a publicly known example value; remove it to auto-generate a random secret, or set a unique one"
                );
            }
            if secret.len() < MIN_LEN {
                anyhow::bail!("JWT_SECRET must be at least {MIN_LEN} characters");
            }
            return Ok(());
        }

        let path = self.jwt_secret_path();
        if path.exists() {
            let secret = fs::read_to_string(&path)
                .with_context(|| format!("Failed to read {}", path.display()))?
                .trim()
                .to_string();
            if secret.len() < MIN_LEN {
                anyhow::bail!(
                    "Persisted JWT secret at {} is invalid; delete it to regenerate",
                    path.display()
                );
            }
            self.jwt_secret = Some(secret);
            return Ok(());
        }

        let secret = crate::utils::secrets::random_hex(48)
            .map_err(|e| anyhow::anyhow!("Failed to generate JWT secret: {e}"))?;
        if let Some(dir) = path.parent().filter(|d| !d.as_os_str().is_empty()) {
            fs::create_dir_all(dir)
                .with_context(|| format!("Failed to create {}", dir.display()))?;
        }
        fs::write(&path, &secret)
            .with_context(|| format!("Failed to write {}", path.display()))?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(&path, fs::Permissions::from_mode(0o600))
                .with_context(|| format!("Failed to chmod {}", path.display()))?;
        }
        tracing::info!("Generated new JWT secret at {}", path.display());
        self.jwt_secret = Some(secret);
        Ok(())
    }

    /// The secret file lives next to the SQLite database (persisted with the data under Docker volume mounts)
    fn jwt_secret_path(&self) -> std::path::PathBuf {
        let db = self.get_database_url();
        let db_path = db
            .trim_start_matches("sqlite://")
            .trim_start_matches("sqlite:");
        let dir = Path::new(db_path).parent().unwrap_or_else(|| Path::new("."));
        dir.join("jwt.secret")
    }

    pub fn get_jwt_secret(&self) -> String {
        self.jwt_secret
            .clone()
            .expect("JWT secret not resolved; call resolve_jwt_secret at startup")
    }

    pub fn get_push(&self) -> Vec<PushConfig> {
        self.push.clone().unwrap_or_default()
    }

    /// The raw section as written (or its all-off defaults when absent).
    /// Call `.resolve(..)` on it to fill in the memory-derived capacities.
    pub fn get_remote_access(&self) -> RemoteAccessConfig {
        self.remote_access.clone().unwrap_or_default()
    }

    /// CLI/env overrides of the serve subcommand (--addr/--cert/--key), taking precedence over config files
    pub fn apply_cli_overrides(
        &mut self,
        addr: Option<&str>,
        cert: Option<&str>,
        key: Option<&str>,
    ) -> Result<()> {
        let mut server = self.get_server();
        if let Some(addr) = addr {
            let (host, port) = addr
                .rsplit_once(':')
                .ok_or_else(|| anyhow::anyhow!("Invalid --addr '{addr}', expected host:port"))?;
            server.host = host.to_string();
            server.port = port
                .parse()
                .with_context(|| format!("Invalid port in --addr '{addr}'"))?;
        }
        match (cert, key) {
            (Some(cert), Some(key)) => {
                server.tls = Some(TlsConfig {
                    cert_path: cert.to_string(),
                    key_path: key.to_string(),
                });
            }
            (None, None) => {}
            _ => anyhow::bail!("--cert and --key must be provided together"),
        }
        self.server = Some(server);
        Ok(())
    }

    /// Falls back, in order, to: `SBM_HOSTNAME` env (explicit override) ->
    /// `/etc/host_hostname` (the host's real /etc/hostname, bind-mounted
    /// read-only by docker-compose — inside a container, `hostname::get()`
    /// would otherwise return the container's own random hostname, not the
    /// machine actually being monitored) -> the local OS hostname (bare-metal
    /// installs) -> a generic label as the last resort. `[server] name`
    /// defaults to None everywhere (see all `Config` construction sites).
    pub fn get_server_name(&self) -> String {
        self.get_server().name.unwrap_or_else(|| {
            env::var("SBM_HOSTNAME")
                .ok()
                .filter(|h| !h.is_empty())
                .or_else(|| {
                    fs::read_to_string("/etc/host_hostname")
                        .ok()
                        .map(|h| h.trim().to_string())
                        .filter(|h| !h.is_empty())
                })
                .or_else(|| {
                    hostname::get()
                        .ok()
                        .and_then(|h| h.into_string().ok())
                        .filter(|h| !h.is_empty())
                })
                .unwrap_or_else(|| "Server 1".to_string())
        })
    }

    /// Push rate limit, formatted "N/duration" (e.g. "1/1m"), default once per
    /// minute. See `[monitoring] push_rate`.
    pub fn get_push_rate(&self) -> (usize, std::time::Duration) {
        const DEFAULT: (usize, std::time::Duration) = (1, std::time::Duration::from_secs(60));
        let Some(rate) = self.get_monitoring().push_rate else { return DEFAULT };
        let rate = rate.as_str();
        let Some((times, duration)) = rate.split_once('/') else {
            tracing::warn!("Invalid rate format: {}", rate);
            return DEFAULT;
        };
        let Ok(times) = times.parse::<usize>() else {
            tracing::warn!("Invalid rate times: {}", rate);
            return DEFAULT;
        };
        match parse_go_duration(duration) {
            Some(d) => (times, d),
            None => {
                tracing::warn!("Invalid rate duration: {}", rate);
                DEFAULT
            }
        }
    }
}

/// Finds the JSON source from a pre-Rust monitor installation. The current
/// directory wins for the short-lived Rust JSON format; Go wrote exclusively
/// to `$HOME/.config/server_box/config.json`, while the current installer runs
/// from a different application directory.
fn legacy_json_path() -> Option<PathBuf> {
    let local = PathBuf::from("config.json");
    if local.is_file() {
        return Some(local);
    }

    let go = env::var_os("HOME")
        .map(PathBuf::from)?
        .join(".config")
        .join("server_box")
        .join("config.json");
    go.is_file().then_some(go)
}

/// Maps Go's per-channel JSON shape to the current flattened TOML table.
/// Keep the fields the old implementations actually consumed rather than
/// dropping them on import: an upgrade gets one chance to carry notification
/// credentials and templates forward.
fn normalize_go_push(push: &GoPush) -> PushConfig {
    let mut config = match &push.iface {
        serde_json::Value::Object(object) => object
            .iter()
            .map(|(key, value)| {
                (
                    key.clone(),
                    toml::Value::try_from(value.clone())
                        .unwrap_or_else(|_| toml::Value::String(value.to_string())),
                )
            })
            .collect(),
        _ => toml::Table::new(),
    };
    let push_type = match push.push_type.as_str() {
        "server_chan" => "serverchan".to_string(),
        other => other.to_string(),
    };
    // The current ServerChan/Bark encodings differ from the Go agent's. Keep
    // this marker in the migrated file so each channel can preserve its old
    // request shape instead of accepting the credentials then notifying a
    // different endpoint format.
    config.insert("legacy_go_format".to_string(), toml::Value::Boolean(true));

    if push_type == "serverchan"
        && let Some(key) = config.remove("sckey")
    {
        config.insert("sc_key".to_string(), key);
    }
    // Go's `code` was the expected HTTP status for these three channels.
    // `code` means the same thing for iOS in the current format, so leave it
    // there for that channel.
    if matches!(push_type.as_str(), "webhook" | "serverchan" | "bark")
        && let Some(code) = config.remove("code").filter(|code| code.as_integer() != Some(0))
    {
        config.insert("expected_http_status".to_string(), code);
    }
    if push_type == "ios" && config.get("code").and_then(|code| code.as_integer()) == Some(0) {
        config.remove("code");
    }

    PushConfig {
        name: push.name.clone(),
        push_type,
        config,
    }
}

/// Parse Go-style durations, e.g. "10s", "1m", "1h"
fn parse_go_duration(s: &str) -> Option<std::time::Duration> {
    let s = s.trim();
    let (num, unit) = s.split_at(s.len().checked_sub(1)?);
    let num: u64 = num.parse().ok()?;
    let secs = match unit {
        "s" => num,
        "m" => num.checked_mul(60)?,
        "h" => num.checked_mul(3600)?,
        _ => return None,
    };
    Some(std::time::Duration::from_secs(secs))
}

impl Default for Config {
    fn default() -> Self {
        Self {
            server: Some(ServerConfig::default()),
            monitoring: Some(MonitoringConfig {
                rules: vec![
                    MonitoringRule {
                        name: "High CPU Usage".to_string(),
                        monitor_type: "cpu".to_string(),
                        threshold: ">=77%".to_string(),
                        matcher: "cpu".to_string(),
                    },
                    MonitoringRule {
                        name: "High Memory Usage".to_string(),
                        monitor_type: "memory".to_string(),
                        threshold: ">=85%".to_string(),
                        matcher: "memory".to_string(),
                    },
                    MonitoringRule {
                        name: "High Disk Usage".to_string(),
                        monitor_type: "disk".to_string(),
                        threshold: ">=90%".to_string(),
                        matcher: "disk".to_string(),
                    },
                ],
                // The rules are the only thing a first run wants that the
                // defaults can't state: everything else here is what
                // `MonitoringConfig::default` already says.
                ..MonitoringConfig::default()
            }),
            database_url: Some(env::var("DATABASE_URL")
                .unwrap_or_else(|_| "sqlite:serverbox_monitor.db".to_string())),
            jwt_secret: None, // auto-generated on first start when unset, see resolve_jwt_secret
            // Written out so a generated config.toml shows the section and
            // its switches; every switch in it defaults to off
            remote_access: Some(RemoteAccessConfig::default()),
            push: Some(vec![
                PushConfig {
                    name: "webhook".to_string(),
                    push_type: "webhook".to_string(),
                    config: {
                        let mut table = toml::Table::new();
                        table.insert("url".to_string(), toml::Value::String("http://localhost:5700".to_string()));
                        table.insert("method".to_string(), toml::Value::String("POST".to_string()));
                        
                        let mut headers = toml::Table::new();
                        headers.insert("Content-Type".to_string(), toml::Value::String("application/json".to_string()));
                        table.insert("headers".to_string(), toml::Value::Table(headers));
                        
                        let mut body_template = toml::Table::new();
                        body_template.insert("message".to_string(), toml::Value::String("Server {{name}}: {{message}}".to_string()));
                        table.insert("body_template".to_string(), toml::Value::Table(body_template));
                        
                        table
                    },
                },
                PushConfig {
                    name: "serverchan".to_string(),
                    push_type: "serverchan".to_string(),
                    config: {
                        let mut table = toml::Table::new();
                        table.insert("sc_key".to_string(), toml::Value::String("".to_string()));
                        table.insert("title".to_string(), toml::Value::String("ServerBox Monitor".to_string()));
                        table.insert("desp".to_string(), toml::Value::String("{{message}}".to_string()));
                        table
                    },
                },
                PushConfig {
                    name: "bark".to_string(),
                    push_type: "bark".to_string(),
                    config: {
                        let mut table = toml::Table::new();
                        table.insert("server".to_string(), toml::Value::String("https://api.day.app".to_string()));
                        table.insert("key".to_string(), toml::Value::String("".to_string()));
                        table.insert("title".to_string(), toml::Value::String("ServerBox Monitor".to_string()));
                        table.insert("body".to_string(), toml::Value::String("{{message}}".to_string()));
                        table.insert("level".to_string(), toml::Value::String("active".to_string()));
                        table
                    },
                },
                PushConfig {
                    name: "ios".to_string(),
                    push_type: "ios".to_string(),
                    config: {
                        let mut table = toml::Table::new();
                        table.insert("token".to_string(), toml::Value::String("".to_string()));
                        table.insert("title".to_string(), toml::Value::String("ServerBox Monitor".to_string()));
                        table.insert("content".to_string(), toml::Value::String("{{message}}".to_string()));
                        table.insert("body_regex".to_string(), toml::Value::String(".*".to_string()));
                        table.insert("code".to_string(), toml::Value::Integer(200));
                        table
                    },
                },
            ]),
            legacy: LegacyGoConfig::default(),
        }
    }
}
