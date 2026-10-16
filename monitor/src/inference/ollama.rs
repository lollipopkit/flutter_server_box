//! Ollama's models through its API: the deployed engine's (`ollama.ollama`)
//! and an Ollama of the machine's own on its default port. Ollama answers on
//! loopback, asks for no key and is never redirected to.

use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use futures::StreamExt;
use serde::Serialize;
use serde_json::{Value, json};

use crate::api::server::AppState;
use crate::stacks::store::StackRow;
use crate::utils::lock::LockExt;

/// The deployed engine's stack id.
pub const STACK: &str = "ollama.ollama";
/// Where Ollama's own install listens.
const NATIVE: &str = "http://127.0.0.1:11434";

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Pull {
    pub instance: String,
    pub model: String,
    /// Ollama's words for the step (`pulling manifest`, `success`).
    pub status: String,
    pub completed: Option<u64>,
    pub total: Option<u64>,
    pub error: Option<String>,
    pub done: bool,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Instance {
    /// `ollama.ollama` (deployed) or `native`.
    pub id: String,
    pub url: String,
    pub version: Option<String>,
}

pub struct Ollama {
    client: reqwest::Client,
    pulls: Mutex<BTreeMap<String, Pull>>,
}

impl Default for Ollama {
    fn default() -> Self {
        let _ = rustls::crypto::ring::default_provider().install_default();
        Self {
            client: reqwest::Client::builder()
                .no_proxy()
                .redirect(reqwest::redirect::Policy::none())
                .connect_timeout(Duration::from_secs(3))
                .build()
                .expect("a valid HTTP client"),
            pulls: Mutex::default(),
        }
    }
}

impl Ollama {
    async fn get(&self, url: &str) -> Result<Value, String> {
        let res = self.client.get(url).timeout(Duration::from_secs(10)).send().await.map_err(|e| e.to_string())?;
        if !res.status().is_success() {
            return Err(format!("HTTP {}", res.status().as_u16()));
        }
        res.json().await.map_err(|e| e.to_string())
    }

    async fn version(&self, base: &str) -> Option<String> {
        self.get(&format!("{base}/api/version")).await.ok()?["version"].as_str().map(String::from)
    }

    /// The models [base] has, and the ones loaded now.
    pub async fn models(&self, base: &str) -> Result<Value, String> {
        let tags = self.get(&format!("{base}/api/tags")).await?;
        let ps = self.get(&format!("{base}/api/ps")).await.unwrap_or(Value::Null);
        Ok(json!({ "models": tags["models"], "running": ps["models"] }))
    }

    pub async fn delete(&self, base: &str, model: &str) -> Result<(), String> {
        let res = self
            .client
            .delete(format!("{base}/api/delete"))
            .json(&json!({ "model": model }))
            .timeout(Duration::from_secs(30))
            .send()
            .await
            .map_err(|e| e.to_string())?;
        match res.status().as_u16() {
            200 => Ok(()),
            404 => Err("notFound".into()),
            s => Err(format!("HTTP {s}")),
        }
    }

    pub fn pulls(&self) -> Vec<Pull> {
        self.pulls.locked().values().cloned().collect()
    }

    /// Pulls [model] into [instance] at [base], in the background; its
    /// progress is in [Self::pulls] until the next pull of it.
    pub fn pull(self: &Arc<Self>, instance: &str, base: &str, model: &str) -> Result<(), &'static str> {
        let key = format!("{instance} {model}");
        {
            let mut pulls = self.pulls.locked();
            if pulls.get(&key).is_some_and(|p| !p.done) {
                return Err("pulling");
            }
            pulls.insert(
                key.clone(),
                Pull { instance: instance.into(), model: model.into(), status: "starting".into(), completed: None, total: None, error: None, done: false },
            );
        }
        let (this, url, model) = (self.clone(), format!("{base}/api/pull"), model.to_string());
        tokio::spawn(async move {
            let result = this.stream_pull(&key, &url, &model).await;
            let mut pulls = this.pulls.locked();
            if let Some(p) = pulls.get_mut(&key) {
                p.done = true;
                if let Err(e) = result {
                    p.error = Some(e);
                }
            }
        });
        Ok(())
    }

    async fn stream_pull(&self, key: &str, url: &str, model: &str) -> Result<(), String> {
        let res = self.client.post(url).json(&json!({ "model": model, "stream": true })).send().await.map_err(|e| e.to_string())?;
        if !res.status().is_success() {
            return Err(format!("HTTP {}", res.status().as_u16()));
        }
        let mut stream = res.bytes_stream();
        let mut buf = Vec::new();
        while let Some(chunk) = stream.next().await {
            buf.extend_from_slice(&chunk.map_err(|e| e.to_string())?);
            while let Some(end) = buf.iter().position(|b| *b == b'\n') {
                let line: Vec<u8> = buf.drain(..=end).collect();
                let Ok(v) = serde_json::from_slice::<Value>(&line) else { continue };
                if let Some(e) = v["error"].as_str() {
                    return Err(e.to_string());
                }
                let mut pulls = self.pulls.locked();
                if let Some(p) = pulls.get_mut(key) {
                    if let Some(s) = v["status"].as_str() {
                        p.status = s.to_string();
                    }
                    if let Some(total) = v["total"].as_u64() {
                        p.total = Some(total);
                        p.completed = v["completed"].as_u64();
                    }
                }
            }
        }
        let status = self.pulls.locked().get(key).map(|p| p.status.clone()).unwrap_or_default();
        if status == "success" { Ok(()) } else { Err(format!("ended at: {status}")) }
    }
}

/// The deployed engine's address, when it is set up.
fn deployed(state: &AppState, rows: &[StackRow]) -> Option<String> {
    let row = rows.iter().find(|r| r.id == STACK && r.state == "installed")?;
    let package = state.stacks.package(STACK)?;
    let llm = package.manifest.llm.as_ref()?;
    let port = row.settings.get(&llm.port)?.as_u64()?;
    Some(format!("http://127.0.0.1:{port}"))
}

/// An Ollama of the machine's own: on its default port and not the
/// deployed one.
pub async fn native(state: &AppState, rows: &[StackRow]) -> Option<String> {
    if deployed(state, rows).as_deref() == Some(NATIVE) {
        return None;
    }
    state.inference.ollama.version(NATIVE).await.map(|_| NATIVE.to_string())
}

pub async fn instances(state: &AppState) -> Vec<Instance> {
    let rows = crate::stacks::store::all(&state.db).await.unwrap_or_default();
    let mut out = Vec::new();
    if let Some(url) = deployed(state, &rows) {
        let version = state.inference.ollama.version(&url).await;
        out.push(Instance { id: STACK.into(), url, version });
    }
    if let Some(url) = native(state, &rows).await {
        let version = state.inference.ollama.version(&url).await;
        out.push(Instance { id: "native".into(), url, version });
    }
    out
}

/// The address of [instance], when it is one of [instances].
pub async fn base_of(state: &AppState, instance: &str) -> Option<String> {
    let rows = crate::stacks::store::all(&state.db).await.unwrap_or_default();
    match instance {
        STACK => deployed(state, &rows),
        "native" => native(state, &rows).await,
        _ => None,
    }
}
