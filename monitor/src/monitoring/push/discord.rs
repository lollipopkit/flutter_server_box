//! Discord: an incoming webhook. Its URL is the credential (anyone holding it
//! can post), so it is withheld like a key and has no separate destination.

use serde_json::{Map, Value, json};
use tracing::info;

use super::{deliver, http_client, push_error, render, text};
use crate::{
    core::config::{Config, PushConfig},
    utils::error::Result,
};

const DEFAULT_CONTENT: &str = "{{name}}: {{message}}";

/// Discord refuses longer content.
const MAX_CONTENT: usize = 2000;

pub(super) async fn send(config: &Config, push: &PushConfig, message: &str) -> Result<()> {
    validate(push).map_err(push_error)?;
    let url = text(push, "webhook_url").ok_or_else(|| push_error("Missing Discord webhook_url"))?;
    let content = render(
        text(push, "content").unwrap_or(DEFAULT_CONTENT),
        message,
        &config.get_server_name(),
        str::to_string,
    );
    let content: String = content.chars().take(MAX_CONTENT).collect();

    let mut body = Map::new();
    body.insert("content".to_string(), Value::String(content));
    for key in ["username", "avatar_url"] {
        if let Some(value) = text(push, key) {
            body.insert(key.to_string(), Value::String(value.to_string()));
        }
    }
    // An alert must not ping anyone because its text contains `@everyone`.
    body.insert("allowed_mentions".to_string(), json!({ "parse": [] }));

    let url = match thread_id(push) {
        Some(thread) => format!("{url}{}thread_id={thread}", if url.contains('?') { '&' } else { '?' }),
        None => url.to_string(),
    };
    deliver(push, http_client().post(url).json(&body)).await?;
    info!("Discord notification sent successfully to {}", push.name);
    Ok(())
}

/// A snowflake, which is past what a JavaScript number holds exactly, so the
/// editors send it as a string; a hand-written file may have a number.
fn thread_id(push: &PushConfig) -> Option<u64> {
    match push.config.get("thread_id")? {
        toml::Value::Integer(id) => u64::try_from(*id).ok(),
        toml::Value::String(id) => id.trim().parse().ok(),
        _ => None,
    }
}

pub(super) fn validate(push: &PushConfig) -> std::result::Result<(), String> {
    if push.config.contains_key("thread_id") && thread_id(push).is_none() {
        return Err("thread_id must be a number".to_string());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::monitoring::push::tests::{config, local_server, request_json};

    #[tokio::test]
    async fn a_message_is_posted_without_mentions() {
        let (url, request) = local_server(204, Vec::new()).await;
        let push = PushConfig {
            name: "dc".to_string(),
            push_type: "discord".to_string(),
            config: toml::from_str(&format!("webhook_url = \"{url}/api/webhooks/1/t\"\nusername = \"SBM\"\nthread_id = \"1234567890123456789\"")).unwrap(),
        };
        send(&config("host"), &push, "@everyone disk full").await.unwrap();
        let (head, body) = request_json(request.await.unwrap());
        assert!(head.starts_with("POST /api/webhooks/1/t?thread_id=1234567890123456789 HTTP/1.1"), "{head}");
        assert_eq!(body["content"], "host: @everyone disk full");
        assert_eq!(body["username"], "SBM");
        assert_eq!(body["allowed_mentions"]["parse"], json!([]));
    }
}
