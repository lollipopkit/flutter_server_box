//! The deployed apps' MCP servers (`[[mcp]]` of their manifests), as Agent
//! mode reaches them (`agent_mode::mcp`): on this machine at the port
//! setting's port, with the header their manifest names. Worked out from the
//! deployed app each time, so a new port follows and a removed app is gone.

use std::collections::BTreeMap;

use serde::Serialize;

use super::manifest::{McpAuth, McpPublisher, Text};
use super::{ENV_FILE, read_env, store};
use crate::api::server::AppState;

/// Where an app's MCP server gets its credential.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase", tag = "kind")]
pub enum Credential {
    None,
    /// A `[[secrets]]` entry of the app's: known at deploy.
    Secret,
    /// A token an admin gives once the service is set up.
    Asked { hint: Text, given: bool },
    #[serde(rename = "oauth")]
    OAuth,
}

/// A deployed app's MCP server.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AppMcp {
    pub stack: String,
    pub index: usize,
    /// The app's name, in English (what the model is told).
    pub title: String,
    pub publisher: McpPublisher,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub source: Option<String>,
    pub url: String,
    pub enabled: bool,
    pub credential: Credential,
    /// The header and its value, when one is known now. Never shown.
    #[serde(skip)]
    pub header: Option<(String, String)>,
}

impl AppMcp {
    /// Whether it can be connected to now: on, and its credential known.
    pub fn ready(&self) -> bool {
        self.enabled
            && match &self.credential {
                Credential::None => true,
                Credential::Secret | Credential::Asked { .. } | Credential::OAuth => self.header.is_some(),
            }
    }
}

/// Every MCP server of every app deployed and set up (`installed`).
pub async fn servers(state: &AppState) -> Vec<AppMcp> {
    let rows = store::all(&state.db).await.unwrap_or_default();
    let uses = store::mcp_uses(&state.db, &state.sealer).await.unwrap_or_default();
    let mut out = Vec::new();
    for row in rows.iter().filter(|r| r.state == "installed") {
        let Some(package) = state.stacks.package(&row.id) else { continue };
        let m = &package.manifest;
        if m.mcp.is_empty() {
            continue;
        }
        let secrets: Vec<&str> = m.mcp.iter().filter_map(|s| s.auth.as_ref()?.secret.as_deref()).collect();
        let env = if secrets.is_empty() {
            BTreeMap::new()
        } else {
            let text = tokio::fs::read_to_string(state.stacks.dir(&row.id).join(ENV_FILE)).await.unwrap_or_default();
            read_env(&text, &secrets)
        };
        let title = m.title.get("en").cloned().unwrap_or_else(|| m.project.clone());
        for (index, server) in m.mcp.iter().enumerate() {
            let Some(port) = row.settings.get(&server.port).and_then(|v| v.as_u64()) else { continue };
            let used = uses.get(&(row.id.clone(), index)).cloned().unwrap_or(store::McpUse { enabled: true, token: None });
            let (credential, value) = match &server.auth {
                None => (Credential::None, None),
                Some(McpAuth { secret: Some(env_name), .. }) => (Credential::Secret, env.get(env_name).cloned()),
                Some(McpAuth { asked: Some(hint), .. }) => {
                    (Credential::Asked { hint: hint.clone(), given: used.token.is_some() }, used.token.clone())
                }
                // Its token is `agent_mode::mcp_oauth`'s, added at connect.
                Some(_) => (Credential::OAuth, None),
            };
            let header = server.auth.as_ref().zip(value).map(|(auth, value)| {
                let value = match &auth.scheme {
                    Some(scheme) => format!("{scheme} {value}"),
                    None => value,
                };
                (auth.header.clone(), value)
            });
            out.push(AppMcp {
                stack: row.id.clone(),
                index,
                title: title.clone(),
                publisher: server.publisher,
                source: server.source.clone(),
                url: format!("http://127.0.0.1:{port}{}", server.path),
                enabled: used.enabled,
                credential,
                header,
            });
        }
    }
    out
}
