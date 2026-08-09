use crate::core::remote_access::RemoteAccessConfig;
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::Path;

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

    // Go-compatible fields (for compatibility)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub interval: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rate: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rules: Option<Vec<GoRule>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pushes: Option<Vec<GoPush>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub tls: Option<TlsConfig>,
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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MonitoringConfig {
    pub interval_seconds: u64,
    pub rules: Vec<MonitoringRule>,
    pub data_retention: Option<DataRetentionConfig>,
    /// How often to run the extended status script, which collects
    /// battery/sensors/SMART/AMD-GPU data — the only fields still bound to
    /// CLI tools after monitor's native collection cutover. `None` (the
    /// default, and what an unset/absent config value resolves to) does
    /// *not* mean "same as `interval_seconds`" — resolve via
    /// `effective_extended_interval_secs`, which defaults to a much slower
    /// cadence. Running `smartctl`/`sensors`/`amd-smi` every core cycle (e.g.
    /// every few seconds) is real, avoidable CPU/power/battery-drain cost
    /// for data that essentially never changes that fast; SMART reads
    /// themselves are negligible flash wear (a diagnostic log read, not a
    /// write), so the slower default here is about host resource use, not
    /// disk lifespan.
    #[serde(default)]
    pub extended_interval_secs: Option<u64>,
    /// Skip the extended cycle (see `extended_interval_secs`) while no
    /// authenticated client has polled `/metrics` or `/status` recently —
    /// core metrics and alert rule checks are unaffected either way, this
    /// only pauses the CLI-tool-bound fields (battery/sensors/SMART/AMD).
    /// Approximates "nobody has the panel open," not a real browser
    /// visibility signal — see `AppState.last_viewer_seen`.
    #[serde(default = "default_idle_pause_enabled")]
    pub idle_pause_enabled: bool,
    /// How long without a poll before the extended cycle is considered
    /// idle. `None` (default) resolves to `interval_seconds * 4` — long
    /// enough to tolerate a couple of missed/slow polls without flapping.
    #[serde(default)]
    pub idle_pause_threshold_secs: Option<u64>,
}

fn default_idle_pause_enabled() -> bool {
    true
}

impl MonitoringConfig {
    /// Unset defaults to 10x the core interval, floored at 120s — running
    /// smartctl/sensors/amd-smi on every core cycle (previously: literally
    /// every cycle, since this defaulted to `interval_seconds` itself) burns
    /// CPU/power for data that doesn't change meaningfully faster than a
    /// couple of minutes. Explicit `extended_interval_secs` in config.toml
    /// (or the settings page) always overrides this.
    pub fn effective_extended_interval_secs(&self) -> u64 {
        self.extended_interval_secs
            .unwrap_or_else(|| self.interval_seconds.saturating_mul(10).max(120))
    }

    pub fn effective_idle_pause_threshold_secs(&self) -> u64 {
        self.idle_pause_threshold_secs.unwrap_or(self.interval_seconds.saturating_mul(4))
    }
}

fn default_max_db_size_mb() -> u64 {
    256
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
            return Ok(config);
        } else if Path::new("config.json").exists() {
            let content =
                fs::read_to_string("config.json").context("Failed to read config.json")?;
            let mut config: Self = serde_json::from_str(&content).context("Failed to parse config.json")?;

            // Convert from Go format if needed
            config.normalize()?;
            config.apply_env_overrides();

            // One-way migration to config.toml so subsequent starts take the
            // config.toml branch above instead of re-parsing JSON every time.
            // The original file is renamed (kept, not deleted) as a safety
            // net rather than silently discarded — if the TOML write fails,
            // config.json is left untouched and this run still succeeds off
            // the in-memory config.
            let toml_content =
                toml::to_string_pretty(&config).context("Failed to serialize migrated config")?;
            fs::write("config.toml", toml_content).context("Failed to write migrated config.toml")?;
            match fs::rename("config.json", "config.json.migrated") {
                Ok(()) => tracing::info!(
                    "Migrated config.json to config.toml (old file kept as config.json.migrated)"
                ),
                Err(e) => tracing::warn!(
                    "Migrated config.json to config.toml but couldn't rename the old file: {e}"
                ),
            }

            return Ok(config);
        }

        // Create default config
        let mut config = Self::default();
        config.apply_env_overrides();

        // Save default config as TOML
        let content =
            toml::to_string_pretty(&config).context("Failed to serialize default config")?;
        fs::write("config.toml", content).context("Failed to write default config.toml")?;

        Ok(config)
    }

    // Normalize the config by converting Go format to Rust format if needed
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
                cors_allowed_origins: Vec::new(),
                card_order: Vec::new(),
            };

            let interval_seconds = if let Some(interval_str) = &self.interval {
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
                rules: self.rules.as_ref().map(|go_rules| {
                    go_rules.iter().map(|gr| MonitoringRule {
                        name: format!("{} {}", gr.monitor_type, gr.threshold),
                        monitor_type: gr.monitor_type.clone(),
                        threshold: gr.threshold.clone(),
                        matcher: gr.matcher.clone(),
                    }).collect()
                }).unwrap_or_else(|| vec![]),
                data_retention: Some(DataRetentionConfig {
                    metrics_days: 30,
                    alerts_days: 90,
                    cleanup_interval_hours: 24,
                    max_db_size_mb: default_max_db_size_mb(),
                }),
                extended_interval_secs: None,
                idle_pause_enabled: default_idle_pause_enabled(),
                idle_pause_threshold_secs: None,
            };

            let push = self.pushes.as_ref().map(|go_pushes| {
                go_pushes.iter().map(|gp| PushConfig {
                    name: gp.name.clone(),
                    push_type: gp.push_type.clone(),
                    config: match gp.iface {
                        serde_json::Value::Object(ref obj) => {
                            obj.iter().map(|(k, v)| {
                                (k.clone(), toml::Value::try_from(v.clone()).unwrap_or(toml::Value::String(v.to_string())))
                            }).collect()
                        }
                        _ => toml::Table::new(),
                    },
                }).collect()
            }).unwrap_or_else(|| vec![]);

            self.server = Some(server);
            self.monitoring = Some(monitoring);
            self.database_url = Some(env::var("DATABASE_URL")
                .unwrap_or_else(|_| "sqlite:serverbox_monitor.db".to_string()));
            self.jwt_secret = env::var("JWT_SECRET").ok().filter(|s| !s.is_empty());
            self.push = Some(push);
        }

        Ok(())
    }

    // Accessors to get the values whether they're in Rust or Go format
    pub fn get_server(&self) -> ServerConfig {
        self.server.clone().unwrap_or_else(|| ServerConfig {
            host: "0.0.0.0".to_string(),
            port: 3770,
            tls: None,
            cors_allowed_origins: Vec::new(),
                card_order: Vec::new(),
        })
    }

    pub fn get_monitoring(&self) -> MonitoringConfig {
        self.monitoring.clone().unwrap_or_else(|| MonitoringConfig {
            interval_seconds: 7,
            rules: vec![],
            data_retention: Some(DataRetentionConfig {
                metrics_days: 30,
                alerts_days: 90,
                cleanup_interval_hours: 24,
                max_db_size_mb: default_max_db_size_mb(),
            }),
            extended_interval_secs: None,
                idle_pause_enabled: default_idle_pause_enabled(),
                idle_pause_threshold_secs: None,
        })
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
        self.push.clone().unwrap_or_else(|| vec![])
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
    /// installs) -> a generic label as the last resort. `name` defaults to
    /// None everywhere (see all `Config` construction sites).
    pub fn get_server_name(&self) -> String {
        self.name.clone().unwrap_or_else(|| {
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

    /// Push rate limit, formatted "N/duration" (e.g. "1/1m"), default once per minute
    pub fn get_push_rate(&self) -> (usize, std::time::Duration) {
        const DEFAULT: (usize, std::time::Duration) = (1, std::time::Duration::from_secs(60));
        let Some(rate) = &self.rate else { return DEFAULT };
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

/// Parse Go-style durations, e.g. "10s", "1m", "1h"
fn parse_go_duration(s: &str) -> Option<std::time::Duration> {
    let s = s.trim();
    let (num, unit) = s.split_at(s.len().checked_sub(1)?);
    let num: u64 = num.parse().ok()?;
    let secs = match unit {
        "s" => num,
        "m" => num * 60,
        "h" => num * 3600,
        _ => return None,
    };
    Some(std::time::Duration::from_secs(secs))
}

impl Default for Config {
    fn default() -> Self {
        Self {
            server: Some(ServerConfig {
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
                cors_allowed_origins: Vec::new(),
                card_order: Vec::new(),
            }),
            monitoring: Some(MonitoringConfig {
                interval_seconds: 7,
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
                data_retention: Some(DataRetentionConfig {
                    metrics_days: 30,
                    alerts_days: 90,
                    cleanup_interval_hours: 24,
                    max_db_size_mb: default_max_db_size_mb(),
                }),
                extended_interval_secs: None,
                idle_pause_enabled: default_idle_pause_enabled(),
                idle_pause_threshold_secs: None,
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
            // Go-compatible fields
            version: None,
            interval: None,
            rate: None,
            name: None,
            rules: None,
            pushes: None,
        }
    }
}
