//! ntfy (<https://ntfy.sh>): a JSON publish to the server's root. An access
//! `token` or a `username`/`password` pair goes to `server`, the destination
//! a withheld one is tied to (`api::push`).

use serde_json::{Map, Value};
use tracing::info;

use super::{deliver, flag, http_client, list, push_error, render, text};
use crate::{
    core::config::{Config, PushConfig},
    utils::error::Result,
};

const DEFAULT_SERVER: &str = "https://ntfy.sh";
const DEFAULT_TITLE: &str = "{{name}}";
const PRIORITIES: &[&str] = &["min", "low", "default", "high", "max", "urgent"];

pub(super) fn validate(push: &PushConfig) -> std::result::Result<(), String> {
    if let Some(topic) = text(push, "topic")
        && !(topic.len() <= 64 && topic.chars().all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_'))
    {
        return Err("topic may hold only letters, digits, - and _, at most 64".to_string());
    }
    if push.config.contains_key("priority") && priority(push).is_none() {
        return Err(format!("priority must be 1 to 5 or one of {}", PRIORITIES.join(", ")));
    }
    if text(push, "password").is_some() && text(push, "username").is_none() {
        return Err("password needs a username".to_string());
    }
    Ok(())
}

/// ntfy's JSON publish takes the priority as a number only.
fn priority(push: &PushConfig) -> Option<i64> {
    match push.config.get("priority")? {
        toml::Value::Integer(level) => (1..=5).contains(level).then_some(*level),
        toml::Value::String(name) => match name.trim() {
            "min" => Some(1),
            "low" => Some(2),
            "default" => Some(3),
            "high" => Some(4),
            "max" | "urgent" => Some(5),
            other => other.parse().ok().filter(|level| (1..=5).contains(level)),
        },
        _ => None,
    }
}

pub(super) async fn send(config: &Config, push: &PushConfig, message: &str) -> Result<()> {
    validate(push).map_err(push_error)?;
    let topic = text(push, "topic").ok_or_else(|| push_error("Missing ntfy topic"))?;
    let server = text(push, "server").unwrap_or(DEFAULT_SERVER).trim_end_matches('/');
    let name = config.get_server_name();
    let fill = |template: &str| render(template, message, &name, str::to_string);

    let mut body = Map::new();
    body.insert("topic".to_string(), Value::String(topic.to_string()));
    body.insert("title".to_string(), Value::String(fill(text(push, "title").unwrap_or(DEFAULT_TITLE))));
    body.insert("message".to_string(), Value::String(fill(text(push, "message").unwrap_or("{{message}}"))));
    if let Some(priority) = priority(push) {
        body.insert("priority".to_string(), Value::from(priority));
    }
    let tags = list(push, "tags");
    if !tags.is_empty() {
        body.insert("tags".to_string(), Value::from(tags));
    }
    for key in ["click", "icon", "attach", "delay", "email"] {
        if let Some(value) = text(push, key) {
            body.insert(key.to_string(), Value::String(value.to_string()));
        }
    }
    if flag(push, "markdown") == Some(true) {
        body.insert("markdown".to_string(), Value::Bool(true));
    }

    let mut request = http_client().post(format!("{server}/")).json(&body);
    if let Some(token) = text(push, "token") {
        request = request.bearer_auth(token);
    } else if let Some(username) = text(push, "username") {
        request = request.basic_auth(username, text(push, "password"));
    }
    deliver(push, request).await?;
    info!("ntfy notification sent successfully to {}", push.name);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::monitoring::push::tests::{config, local_server, request_json};

    #[tokio::test]
    async fn a_message_is_published_as_json_with_the_token() {
        let (url, request) = local_server(200, b"{}".to_vec()).await;
        let push = PushConfig {
            name: "ntfy".to_string(),
            push_type: "ntfy".to_string(),
            config: toml::from_str(&format!(
                "server = \"{url}\"\ntopic = \"alerts\"\ntoken = \"tk_x\"\npriority = \"high\"\ntags = \"warning, computer\"\nmarkdown = true"
            ))
            .unwrap(),
        };
        send(&config("host"), &push, "load 9").await.unwrap();
        let (head, body) = request_json(request.await.unwrap());
        assert!(head.starts_with("POST / HTTP/1.1"), "{head}");
        assert!(head.to_ascii_lowercase().contains("authorization: bearer tk_x"), "{head}");
        assert_eq!(body["topic"], "alerts");
        assert_eq!(body["title"], "host");
        assert_eq!(body["message"], "load 9");
        assert_eq!(body["priority"], 4);
        assert_eq!(body["tags"], serde_json::json!(["warning", "computer"]));
        assert_eq!(body["markdown"], true);
    }

    #[test]
    fn a_bad_priority_is_refused() {
        let push = PushConfig {
            name: "ntfy".to_string(),
            push_type: "ntfy".to_string(),
            config: toml::from_str("topic = \"alerts\"\npriority = 9").unwrap(),
        };
        assert!(validate(&push).unwrap_err().contains("priority"));
    }
}
