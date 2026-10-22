//! Telegram: a bot's `sendMessage`. `api_base` points at a self-hosted Bot API
//! server; the token rides in the request path, so it is the destination a
//! withheld token is tied to (`api::push`).

use serde_json::{Map, Value, json};
use tracing::info;

use super::{deliver, flag, http_client, integer, push_error, render, text};
use crate::{
    core::config::{Config, PushConfig},
    utils::error::Result,
};

const DEFAULT_API: &str = "https://api.telegram.org";
const DEFAULT_TEXT: &str = "{{name}}: {{message}}";
const PARSE_MODES: &[&str] = &["HTML", "MarkdownV2", "Markdown"];

pub(super) fn validate(push: &PushConfig) -> std::result::Result<(), String> {
    if let Some(mode) = text(push, "parse_mode")
        && !PARSE_MODES.contains(&mode)
    {
        return Err(format!("parse_mode must be one of {}", PARSE_MODES.join(", ")));
    }
    if chat_id(push).is_none() {
        return Err("chat_id must be a number or an @channel name".to_string());
    }
    Ok(())
}

fn chat_id(push: &PushConfig) -> Option<Value> {
    match push.config.get("chat_id")? {
        toml::Value::Integer(id) => Some(Value::from(*id)),
        toml::Value::String(id) => {
            let id = id.trim();
            if let Ok(number) = id.parse::<i64>() {
                Some(Value::from(number))
            } else if id.starts_with('@') && id.len() > 1 {
                Some(Value::String(id.to_string()))
            } else {
                None
            }
        }
        _ => None,
    }
}

pub(super) async fn send(config: &Config, push: &PushConfig, message: &str) -> Result<()> {
    validate(push).map_err(push_error)?;
    let token = text(push, "bot_token").ok_or_else(|| push_error("Missing Telegram bot_token"))?;
    let api = text(push, "api_base").unwrap_or(DEFAULT_API).trim_end_matches('/');
    let mode = text(push, "parse_mode");
    let escape = |value: &str| escape(mode, value);
    let text_value = render(
        text(push, "text").unwrap_or(DEFAULT_TEXT),
        message,
        &config.get_server_name(),
        escape,
    );

    let mut body = Map::new();
    body.insert("chat_id".to_string(), chat_id(push).unwrap_or(Value::Null));
    body.insert("text".to_string(), Value::String(text_value));
    if let Some(mode) = mode {
        body.insert("parse_mode".to_string(), Value::String(mode.to_string()));
    }
    if let Some(thread) = integer(push, "message_thread_id") {
        body.insert("message_thread_id".to_string(), Value::from(thread));
    }
    if flag(push, "disable_notification") == Some(true) {
        body.insert("disable_notification".to_string(), Value::Bool(true));
    }
    if flag(push, "disable_link_preview") == Some(true) {
        body.insert("link_preview_options".to_string(), json!({ "is_disabled": true }));
    }

    let response = deliver(push, http_client().post(format!("{api}/bot{token}/sendMessage")).json(&body)).await?;
    match serde_json::from_str::<Value>(&response) {
        Ok(answer) if answer["ok"] == true => {
            info!("Telegram notification sent successfully to {}", push.name);
            Ok(())
        }
        Ok(answer) => Err(push_error(format!(
            "Telegram refused it: {}",
            answer["description"].as_str().unwrap_or("no description")
        ))),
        Err(_) => Err(push_error("Telegram answered something that is not JSON")),
    }
}

/// The message and the server name are plain text; with a `parse_mode` they
/// are escaped so a `_` or a `<` in them is not read as markup (which
/// Telegram refuses outright for MarkdownV2).
fn escape(mode: Option<&str>, value: &str) -> String {
    let special: &[char] = match mode {
        Some("HTML") => {
            return value.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;");
        }
        Some("MarkdownV2") => &[
            '_', '*', '[', ']', '(', ')', '~', '`', '>', '#', '+', '-', '=', '|', '{', '}', '.', '!', '\\',
        ],
        Some("Markdown") => &['_', '*', '`', '['],
        _ => return value.to_string(),
    };
    let mut out = String::with_capacity(value.len());
    for c in value.chars() {
        if special.contains(&c) {
            out.push('\\');
        }
        out.push(c);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::monitoring::push::tests::{config, local_server, request_json};

    fn telegram(api: String, extra: &str) -> PushConfig {
        PushConfig {
            name: "tg".to_string(),
            push_type: "telegram".to_string(),
            config: toml::from_str(&format!("api_base = \"{api}\"\nbot_token = \"123:abc\"\n{extra}")).unwrap(),
        }
    }

    #[tokio::test]
    async fn a_message_goes_to_send_message_with_its_values_escaped() {
        let (url, request) = local_server(200, br#"{"ok":true}"#.to_vec()).await;
        let push = telegram(url, "chat_id = \"-100123\"\nparse_mode = \"HTML\"\ntext = \"<b>{{name}}</b> {{message}}\"\nmessage_thread_id = 7");
        send(&config("a<b"), &push, "x > 1 & y").await.unwrap();
        let (head, body) = request_json(request.await.unwrap());
        assert!(head.starts_with("POST /bot123:abc/sendMessage HTTP/1.1"), "{head}");
        assert_eq!(body["chat_id"], -100123);
        assert_eq!(body["text"], "<b>a&lt;b</b> x &gt; 1 &amp; y");
        assert_eq!(body["message_thread_id"], 7);
    }

    #[tokio::test]
    async fn a_refusal_carries_telegrams_description() {
        let (url, _) = local_server(200, br#"{"ok":false,"description":"chat not found"}"#.to_vec()).await;
        let push = telegram(url, "chat_id = 1");
        let error = send(&config("h"), &push, "m").await.unwrap_err();
        assert!(error.to_string().contains("chat not found"), "{error}");
    }

    #[test]
    fn markdown_v2_escapes_its_reserved_characters() {
        assert_eq!(escape(Some("MarkdownV2"), "cpu_load 9.5!"), "cpu\\_load 9\\.5\\!");
    }

    #[test]
    fn a_chat_id_that_is_neither_a_number_nor_a_channel_is_refused() {
        let push = telegram("https://api.telegram.org".to_string(), "chat_id = \"someone\"");
        assert!(validate(&push).is_err());
    }
}
