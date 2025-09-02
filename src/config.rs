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
    pub config: serde_json::Value,
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
        // Try to load from config file first
        if Path::new("config.json").exists() {
            let content =
                fs::read_to_string("config.json").context("Failed to read config.json")?;
            let mut config: Self = serde_json::from_str(&content).context("Failed to parse config.json")?;
            
            // Convert from Go format if needed
            config.normalize()?;
            return Ok(config);
        }

        // Create default config
        let config = Self::default();

        // Save default config
        let content =
            serde_json::to_string_pretty(&config).context("Failed to serialize default config")?;
        fs::write("config.json", content).context("Failed to write default config.json")?;

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
            };

            let push = self.pushes.as_ref().map(|go_pushes| {
                go_pushes.iter().map(|gp| PushConfig {
                    name: gp.name.clone(),
                    push_type: gp.push_type.clone(),
                    config: gp.iface.clone(),
                }).collect()
            }).unwrap_or_else(|| vec![]);

            self.server = Some(server);
            self.monitoring = Some(monitoring);
            self.database_url = Some(env::var("DATABASE_URL")
                .unwrap_or_else(|_| "sqlite:serverbox_monitor.db".to_string()));
            self.jwt_secret = Some(env::var("JWT_SECRET")
                .unwrap_or_else(|_| "your-secret-key-change-this".to_string()));
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
        })
    }

    pub fn get_monitoring(&self) -> MonitoringConfig {
        self.monitoring.clone().unwrap_or_else(|| MonitoringConfig {
            interval_seconds: 7,
            rules: vec![],
        })
    }

    pub fn get_database_url(&self) -> String {
        self.database_url.clone().unwrap_or_else(|| "sqlite:serverbox_monitor.db".to_string())
    }

    pub fn get_jwt_secret(&self) -> String {
        self.jwt_secret.clone().unwrap_or_else(|| "your-secret-key-change-this".to_string())
    }

    pub fn get_push(&self) -> Vec<PushConfig> {
        self.push.clone().unwrap_or_else(|| vec![])
    }
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
            }),
            database_url: Some(env::var("DATABASE_URL")
                .unwrap_or_else(|_| "sqlite:serverbox_monitor.db".to_string())),
            jwt_secret: Some(env::var("JWT_SECRET")
                .unwrap_or_else(|_| "your-secret-key-change-this".to_string())),
            push: Some(vec![
                PushConfig {
                    name: "webhook".to_string(),
                    push_type: "webhook".to_string(),
                    config: serde_json::json!({
                        "url": "http://localhost:5700",
                        "method": "POST",
                        "headers": {
                            "Content-Type": "application/json"
                        },
                        "body_template": {
                            "message": "Server {{name}}: {{message}}"
                        }
                    }),
                },
                PushConfig {
                    name: "serverchan".to_string(),
                    push_type: "serverchan".to_string(),
                    config: serde_json::json!({
                        "sc_key": "",
                        "title": "ServerBox Monitor",
                        "desp": "{{message}}"
                    }),
                },
                PushConfig {
                    name: "bark".to_string(),
                    push_type: "bark".to_string(),
                    config: serde_json::json!({
                        "server": "https://api.day.app",
                        "key": "",
                        "title": "ServerBox Monitor",
                        "body": "{{message}}",
                        "level": "active"
                    }),
                },
                PushConfig {
                    name: "ios".to_string(),
                    push_type: "ios".to_string(),
                    config: serde_json::json!({
                        "token": "",
                        "title": "ServerBox Monitor",
                        "content": "{{message}}",
                        "body_regex": ".*",
                        "code": 200
                    }),
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
