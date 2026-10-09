//! What Agent mode runs with: the model, the providers an admin added and
//! their credentials (migration 021). Credentials go in and never come back
//! out: a read says whether one is set.

use fl_pi_llm::host::{BoxFuture, Credentials};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::SqlitePool;

/// The APIs a provider an admin adds may speak (pi's custom APIs).
pub const APIS: &[&str] = &["openai-completions", "openai-responses", "anthropic-messages", "google-generative-ai"];
pub const THINKING_LEVELS: &[&str] = &["off", "minimal", "low", "medium", "high"];
pub const MAX_PROVIDERS: usize = 16;
pub const MAX_MODELS: usize = 256;
pub const DEFAULT_MAX_RUNNING: i64 = 3;
const MAX_ID: usize = 64;
const MAX_NAME: usize = 128;
const MAX_URL: usize = 2048;
const MAX_KEY: usize = 8192;

/// pi's model reference.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ModelRef {
    pub provider: String,
    pub id: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ProviderModel {
    pub id: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
}

/// A provider as stored and as a read shows it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Provider {
    pub id: String,
    pub name: String,
    pub api: String,
    pub base_url: String,
    #[serde(default)]
    pub allow_insecure: bool,
    #[serde(default)]
    pub models: Vec<ProviderModel>,
}

impl Provider {
    /// What pi's `providers.setCustom` takes.
    pub fn to_pi(&self) -> Value {
        serde_json::json!({
            "id": self.id, "name": self.name, "api": self.api, "baseUrl": self.base_url, "models": self.models,
        })
    }

    /// Whether the endpoint lists its models (`GET {baseUrl}/models`).
    pub fn lists_models(&self) -> bool {
        matches!(self.api.as_str(), "openai-completions" | "openai-responses")
    }

    /// `http://host:port` when plain HTTP is allowed to it.
    pub fn insecure_origin(&self) -> Option<String> {
        if !self.allow_insecure {
            return None;
        }
        let rest = self.base_url.strip_prefix("http://")?;
        let authority = rest.split(['/', '?', '#']).next()?;
        (!authority.is_empty() && !authority.contains('@')).then(|| format!("http://{}", authority.to_ascii_lowercase()))
    }
}

/// The whole configuration as a read shows it.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Settings {
    /// `None` until an admin picks one: Agent mode is off.
    pub model: Option<ModelRef>,
    pub thinking_level: String,
    pub max_running: i64,
    pub providers: Vec<Provider>,
    /// Providers (built-in or above) that have a credential set.
    pub credentials: Vec<String>,
}

/// A write. `credentials` sets (a string: the API key), removes (`null`) or
/// keeps (absent) each provider's; a removed provider's goes with it.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SettingsWrite {
    pub model: Option<ModelRef>,
    #[serde(default = "off")]
    pub thinking_level: String,
    #[serde(default = "default_max_running")]
    pub max_running: i64,
    #[serde(default)]
    pub providers: Vec<Provider>,
    #[serde(default)]
    pub credentials: std::collections::BTreeMap<String, Option<String>>,
}

fn off() -> String {
    "off".into()
}

fn default_max_running() -> i64 {
    DEFAULT_MAX_RUNNING
}

fn valid_id(id: &str) -> bool {
    (1..=MAX_ID).contains(&id.len()) && id.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.'))
}

/// Why a write is refused: a code the panel words.
pub fn check(w: &SettingsWrite) -> Result<(), &'static str> {
    if !THINKING_LEVELS.contains(&w.thinking_level.as_str()) {
        return Err("invalidThinkingLevel");
    }
    if !(1..=8).contains(&w.max_running) {
        return Err("invalidMaxRunning");
    }
    if w.providers.len() > MAX_PROVIDERS {
        return Err("tooManyProviders");
    }
    let mut seen = std::collections::HashSet::new();
    for p in &w.providers {
        if !valid_id(&p.id) || !seen.insert(p.id.as_str()) {
            return Err("invalidProviderId");
        }
        if p.name.trim().is_empty() || p.name.chars().count() > MAX_NAME || p.name.chars().any(char::is_control) {
            return Err("invalidProviderName");
        }
        check_endpoint(&p.api, &p.base_url, p.allow_insecure)?;
        if p.models.len() > MAX_MODELS || p.models.iter().any(|m| m.id.is_empty() || m.id.len() > 256 || m.id.chars().any(char::is_control)) {
            return Err("invalidModels");
        }
    }
    for (id, key) in &w.credentials {
        if !valid_id(id) {
            return Err("invalidProviderId");
        }
        if let Some(k) = key
            // Empty is a key all the same: an endpoint that takes none (a
            // local server) still needs a credential to be usable to pi.
            && (k.len() > MAX_KEY || k.chars().any(char::is_control))
        {
            return Err("invalidCredential");
        }
    }
    if let Some(m) = &w.model
        && (!valid_id(&m.provider) || m.id.is_empty() || m.id.len() > 256 || m.id.chars().any(char::is_control))
    {
        return Err("invalidModel");
    }
    Ok(())
}

/// Whether an endpoint may be reached: an API pi speaks, and HTTPS, plain
/// HTTP to this machine, or plain HTTP the admin allowed for it.
pub fn check_endpoint(api: &str, base_url: &str, allow_insecure: bool) -> Result<(), &'static str> {
    if !APIS.contains(&api) {
        return Err("invalidApi");
    }
    let url = base_url;
    let host = url.split_once("://").map(|(_, rest)| rest.split(['/', '?', '#']).next().unwrap_or("")).unwrap_or("");
    let scheme_ok = url.starts_with("https://") || (url.starts_with("http://") && allow_insecure) || is_loopback_http(url);
    if url.len() > MAX_URL || host.is_empty() || host.contains('@') || !scheme_ok || url.chars().any(|c| c.is_control() || c.is_whitespace()) {
        return Err("invalidBaseUrl");
    }
    Ok(())
}

fn is_loopback_http(url: &str) -> bool {
    fl_pi_llm::host::fetch_allowed(url, &[]) && url.starts_with("http://")
}

pub async fn load(db: &SqlitePool) -> Result<Settings, sqlx::Error> {
    let row = sqlx::query_as::<_, (String, String, i64)>("SELECT model, thinking_level, max_running FROM agent_settings WHERE id = 1")
        .fetch_optional(db)
        .await?;
    let providers = sqlx::query_as::<_, (String, String, String, String, bool, String)>(
        "SELECT id, name, api, base_url, allow_insecure, models FROM agent_provider ORDER BY position",
    )
    .fetch_all(db)
    .await?
    .into_iter()
    .map(|(id, name, api, base_url, allow_insecure, models)| Provider {
        id,
        name,
        api,
        base_url,
        allow_insecure,
        models: serde_json::from_str(&models).unwrap_or_default(),
    })
    .collect();
    let credentials = sqlx::query_scalar::<_, String>("SELECT provider_id FROM agent_credential ORDER BY provider_id")
        .fetch_all(db)
        .await?;
    let (model, thinking_level, max_running) = match row {
        Some((model, level, max)) => (serde_json::from_str(&model).ok(), level, max),
        None => (None, off(), DEFAULT_MAX_RUNNING),
    };
    Ok(Settings { model, thinking_level, max_running, providers, credentials })
}

/// Replaces the configuration, in one transaction.
pub async fn store(db: &SqlitePool, w: &SettingsWrite) -> Result<(), sqlx::Error> {
    let now = chrono::Utc::now().to_rfc3339();
    let mut tx = db.begin().await?;
    match &w.model {
        Some(m) => {
            sqlx::query(
                "INSERT INTO agent_settings (id, model, thinking_level, max_running, updated_at) VALUES (1, ?, ?, ?, ?) \
                 ON CONFLICT(id) DO UPDATE SET model = excluded.model, thinking_level = excluded.thinking_level, \
                 max_running = excluded.max_running, updated_at = excluded.updated_at",
            )
            .bind(serde_json::to_string(m).expect("a model reference serialises"))
            .bind(&w.thinking_level)
            .bind(w.max_running)
            .bind(&now)
            .execute(&mut *tx)
            .await?;
        }
        None => {
            sqlx::query("DELETE FROM agent_settings").execute(&mut *tx).await?;
        }
    }
    let old: Vec<String> = sqlx::query_scalar("SELECT id FROM agent_provider").fetch_all(&mut *tx).await?;
    sqlx::query("DELETE FROM agent_provider").execute(&mut *tx).await?;
    for (position, p) in w.providers.iter().enumerate() {
        sqlx::query("INSERT INTO agent_provider (id, position, name, api, base_url, allow_insecure, models) VALUES (?, ?, ?, ?, ?, ?, ?)")
            .bind(&p.id)
            .bind(position as i64)
            .bind(p.name.trim())
            .bind(&p.api)
            .bind(p.base_url.trim_end_matches('/'))
            .bind(p.allow_insecure)
            .bind(serde_json::to_string(&p.models).expect("models serialise"))
            .execute(&mut *tx)
            .await?;
    }
    // A provider that went takes its credential with it.
    for id in old.iter().filter(|id| !w.providers.iter().any(|p| &p.id == *id)) {
        sqlx::query("DELETE FROM agent_credential WHERE provider_id = ?").bind(id).execute(&mut *tx).await?;
    }
    for (id, key) in &w.credentials {
        match key {
            Some(k) => {
                let credential = serde_json::json!({ "type": "api_key", "key": k }).to_string();
                sqlx::query(
                    "INSERT INTO agent_credential (provider_id, credential, updated_at) VALUES (?, ?, ?) \
                     ON CONFLICT(provider_id) DO UPDATE SET credential = excluded.credential, updated_at = excluded.updated_at",
                )
                .bind(id)
                .bind(credential)
                .bind(&now)
                .execute(&mut *tx)
                .await?;
            }
            None => {
                sqlx::query("DELETE FROM agent_credential WHERE provider_id = ?").bind(id).execute(&mut *tx).await?;
            }
        }
    }
    tx.commit().await
}

/// pi-ai's credential store over `agent_credential`. pi only reads here:
/// a write from the runtime (an OAuth refresh, which no provider here has)
/// is refused rather than stored behind the admin's back.
pub struct DbCredentials(pub SqlitePool);

impl Credentials for DbCredentials {
    fn read(&self, provider_id: &str) -> BoxFuture<'_, Result<Option<Value>, String>> {
        let id = provider_id.to_string();
        Box::pin(async move {
            let row = sqlx::query_scalar::<_, String>("SELECT credential FROM agent_credential WHERE provider_id = ?")
                .bind(id)
                .fetch_optional(&self.0)
                .await
                .map_err(|e| e.to_string())?;
            Ok(row.and_then(|c| serde_json::from_str(&c).ok()))
        })
    }

    fn list(&self) -> BoxFuture<'_, Result<Vec<String>, String>> {
        Box::pin(async move {
            sqlx::query_scalar("SELECT provider_id FROM agent_credential").fetch_all(&self.0).await.map_err(|e| e.to_string())
        })
    }

    fn write(&self, _: &str, _: Value) -> BoxFuture<'_, Result<(), String>> {
        Box::pin(async { Err("credentials are set by an admin".into()) })
    }

    fn delete(&self, _: &str) -> BoxFuture<'_, Result<(), String>> {
        Box::pin(async { Err("credentials are set by an admin".into()) })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn write(providers: Vec<Provider>) -> SettingsWrite {
        SettingsWrite {
            model: Some(ModelRef { provider: "openai".into(), id: "gpt-4o-mini".into() }),
            thinking_level: "off".into(),
            max_running: 3,
            providers,
            credentials: Default::default(),
        }
    }

    fn provider(base_url: &str, allow_insecure: bool) -> Provider {
        Provider { id: "local".into(), name: "Local".into(), api: "openai-completions".into(), base_url: base_url.into(), allow_insecure, models: vec![] }
    }

    #[test]
    fn plain_http_only_where_allowed() {
        assert!(check(&write(vec![provider("https://api.example.com/v1", false)])).is_ok());
        assert!(check(&write(vec![provider("http://127.0.0.1:11434/v1", false)])).is_ok());
        assert_eq!(check(&write(vec![provider("http://10.0.0.2:8080/v1", false)])), Err("invalidBaseUrl"));
        assert!(check(&write(vec![provider("http://10.0.0.2:8080/v1", true)])).is_ok());
        assert_eq!(check(&write(vec![provider("file:///etc/passwd", true)])), Err("invalidBaseUrl"));
        assert_eq!(check(&write(vec![provider("https://", false)])), Err("invalidBaseUrl"));
        assert_eq!(check(&write(vec![provider("https://user@x/v1", false)])), Err("invalidBaseUrl"));
        assert_eq!(provider("http://10.0.0.2:8080/v1", true).insecure_origin().as_deref(), Some("http://10.0.0.2:8080"));
        assert_eq!(provider("http://10.0.0.2:8080/v1", false).insecure_origin(), None);
    }

    #[test]
    fn a_write_is_checked_whole() {
        let mut w = write(vec![]);
        w.thinking_level = "max".into();
        assert_eq!(check(&w), Err("invalidThinkingLevel"));
        let mut w = write(vec![]);
        w.max_running = 0;
        assert_eq!(check(&w), Err("invalidMaxRunning"));
        let mut w = write(vec![provider("https://x", false), provider("https://y", false)]);
        assert_eq!(check(&w), Err("invalidProviderId"));
        w.providers.pop();
        w.credentials.insert("local".into(), Some("k\n".into()));
        assert_eq!(check(&w), Err("invalidCredential"));
    }
}
