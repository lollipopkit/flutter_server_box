//! Bark (<https://bark.day.app>): JSON to the server's `/push`, the key in the
//! body rather than the path, so it stays out of access logs.
//!
//! With `cipher_key` set the payload is encrypted the way the Bark app's
//! "Push Encryption" decrypts it: AES-CBC, PKCS#7, the key's length picking
//! AES-128/192/256, and a fresh IV per message sent beside the ciphertext.
//! Only `device_key`, `ciphertext` and `iv` then reach the Bark server.

use aes::cipher::{BlockModeEncrypt, KeyIvInit, block_padding::Pkcs7};
use base64::Engine;
use serde_json::{Map, Value};
use toml::Value as TomlValue;
use tracing::info;

use super::{deliver, flag, go_url_encode, http_client, is_legacy_go_push, push_error, render, text, url_encode};
use crate::{
    core::config::{Config, PushConfig},
    utils::error::Result,
};

const DEFAULT_SERVER: &str = "https://api.day.app";
const DEFAULT_TITLE: &str = "ServerBox Monitor";

/// Settings passed to Bark as they are: the config key, then Bark's name.
const PASSED: &[(&str, &str)] = &[
    ("level", "level"),
    ("volume", "volume"),
    ("badge", "badge"),
    ("sound", "sound"),
    ("icon", "icon"),
    ("image", "image"),
    ("group", "group"),
    ("url", "url"),
    ("action", "action"),
    ("ttl", "ttl"),
];

/// Switches Bark takes as the string `"1"`.
const SWITCHES: &[(&str, &str)] = &[("call", "call"), ("auto_copy", "autoCopy")];

const LEVELS: &[&str] = &["active", "timeSensitive", "passive", "critical"];

pub(super) fn validate(push: &PushConfig) -> std::result::Result<(), String> {
    if let Some(level) = text(push, "level")
        && !LEVELS.contains(&level)
    {
        return Err(format!("level must be one of {}", LEVELS.join(", ")));
    }
    if let Some(volume) = push.config.get("volume")
        && !volume.as_integer().is_some_and(|volume| (0..=10).contains(&volume))
    {
        return Err("volume must be a whole number from 0 to 10".to_string());
    }
    if let Some(key) = text(push, "cipher_key")
        && !matches!(key.len(), 16 | 24 | 32)
    {
        return Err("cipher_key must be 16, 24 or 32 characters (AES-128/192/256)".to_string());
    }
    Ok(())
}

pub(super) async fn send(config: &Config, push: &PushConfig, message: &str) -> Result<()> {
    validate(push).map_err(push_error)?;
    let key = text(push, "key").ok_or_else(|| push_error("Missing Bark key"))?;
    let server = text(push, "server").unwrap_or(DEFAULT_SERVER).trim_end_matches('/');
    let name = config.get_server_name();
    let fill = |template: &str| render(template, message, &name, str::to_string);

    let title = fill(text(push, "title").unwrap_or(DEFAULT_TITLE));
    let body = fill(text(push, "body").unwrap_or("{{message}}"));

    let request = if is_legacy_go_push(push) {
        // The Go agent put title and body in the path, and an imported channel
        // keeps that request shape (`legacy_go_format`). TODO: remove with the
        // Go config import.
        let url = format!("{server}/{key}/{}/{}", go_url_encode(&title), go_url_encode(&body));
        let query: Vec<String> = ["level", "group", "sound", "icon", "url"]
            .into_iter()
            .filter_map(|key| text(push, key).map(|value| (key, value)))
            .filter(|(key, value)| !(*key == "level" && *value == "active"))
            .map(|(key, value)| format!("{key}={}", url_encode(value)))
            .collect();
        let url = if query.is_empty() { url } else { format!("{url}?{}", query.join("&")) };
        http_client().get(url)
    } else {
        let payload = payload(push, title, body, &fill);
        let mut request = Map::new();
        request.insert("device_key".to_string(), Value::String(key.to_string()));
        match text(push, "cipher_key") {
            Some(cipher_key) => {
                let iv = random_iv();
                let ciphertext = encrypt(cipher_key.as_bytes(), iv.as_bytes(), &Value::Object(payload).to_string())?;
                request.insert("ciphertext".to_string(), Value::String(ciphertext));
                request.insert("iv".to_string(), Value::String(iv));
            }
            None => request.extend(payload),
        }
        http_client().post(format!("{server}/push")).json(&request)
    };

    deliver(push, request).await?;
    info!("Bark notification sent successfully to {}", push.name);
    Ok(())
}

/// What the notification says, in Bark's parameter names.
fn payload(push: &PushConfig, title: String, body: String, fill: &dyn Fn(&str) -> String) -> Map<String, Value> {
    let mut payload = Map::new();
    payload.insert("title".to_string(), Value::String(title));
    if let Some(subtitle) = text(push, "subtitle") {
        payload.insert("subtitle".to_string(), Value::String(fill(subtitle)));
    }
    // Bark renders `markdown` in place of `body` when it is present.
    let body_key = if flag(push, "markdown") == Some(true) { "markdown" } else { "body" };
    payload.insert(body_key.to_string(), Value::String(body));
    if let Some(copy) = text(push, "copy") {
        payload.insert("copy".to_string(), Value::String(fill(copy)));
    }
    for (key, bark) in PASSED {
        let value = match push.config.get(*key) {
            Some(TomlValue::String(value)) if !value.trim().is_empty() => Value::String(value.clone()),
            Some(TomlValue::Integer(value)) => Value::from(*value),
            _ => continue,
        };
        payload.insert((*bark).to_string(), value);
    }
    for (key, bark) in SWITCHES {
        if flag(push, key) == Some(true) {
            payload.insert((*bark).to_string(), Value::String("1".to_string()));
        }
    }
    // Absent leaves it to the app's setting; false asks not to keep it.
    if let Some(archive) = flag(push, "is_archive") {
        let archive = if archive { "1" } else { "0" };
        payload.insert("isArchive".to_string(), Value::String(archive.to_string()));
    }
    payload
}

/// Sixteen printable characters: the app reads the IV as the bytes of the
/// string it is sent.
fn random_iv() -> String {
    const ALPHABET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    let mut bytes = [0_u8; 16];
    getrandom::fill(&mut bytes).expect("the system random source is available");
    bytes.iter().map(|byte| ALPHABET[*byte as usize % ALPHABET.len()] as char).collect()
}

fn encrypt(key: &[u8], iv: &[u8], plaintext: &str) -> Result<String> {
    fn run<C: KeyIvInit + BlockModeEncrypt>(key: &[u8], iv: &[u8], plaintext: &[u8]) -> Result<Vec<u8>> {
        let cipher = C::new_from_slices(key, iv).map_err(|_| push_error("Invalid Bark cipher key or IV"))?;
        Ok(cipher.encrypt_padded_vec::<Pkcs7>(plaintext))
    }
    let plaintext = plaintext.as_bytes();
    let ciphertext = match key.len() {
        16 => run::<cbc::Encryptor<aes::Aes128>>(key, iv, plaintext)?,
        24 => run::<cbc::Encryptor<aes::Aes192>>(key, iv, plaintext)?,
        32 => run::<cbc::Encryptor<aes::Aes256>>(key, iv, plaintext)?,
        _ => return Err(push_error("cipher_key must be 16, 24 or 32 characters")),
    };
    Ok(base64::engine::general_purpose::STANDARD.encode(ciphertext))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::monitoring::push::tests::{config, local_server, request_json};

    fn bark(server: String, extra: &str) -> PushConfig {
        PushConfig {
            name: "phone".to_string(),
            push_type: "bark".to_string(),
            config: toml::from_str(&format!("server = \"{server}\"\nkey = \"device\"\n{extra}")).unwrap(),
        }
    }

    #[tokio::test]
    async fn a_push_is_json_to_push_with_the_key_in_the_body() {
        let (url, request) = local_server(200, br#"{"code":200}"#.to_vec()).await;
        let push = bark(
            url,
            "subtitle = \"on {{name}}\"\nlevel = \"timeSensitive\"\nbadge = 3\ncall = true\nauto_copy = false\nis_archive = false\nmarkdown = true\ngroup = \"alerts\"",
        );
        send(&config("host-a"), &push, "CPU 91%").await.unwrap();
        let (head, body) = request_json(request.await.unwrap());
        assert!(head.starts_with("POST /push HTTP/1.1"), "{head}");
        assert_eq!(body["device_key"], "device");
        assert_eq!(body["subtitle"], "on host-a");
        assert_eq!(body["markdown"], "CPU 91%");
        assert!(body.get("body").is_none());
        assert_eq!(body["level"], "timeSensitive");
        assert_eq!(body["badge"], 3);
        assert_eq!(body["call"], "1");
        assert!(body.get("autoCopy").is_none());
        assert_eq!(body["isArchive"], "0");
        assert_eq!(body["group"], "alerts");
    }

    #[tokio::test]
    async fn an_encrypted_push_sends_only_the_key_and_the_ciphertext() {
        let (url, request) = local_server(200, br#"{"code":200}"#.to_vec()).await;
        let push = bark(url, "cipher_key = \"1234567890123456\"\nsound = \"minuet\"");
        send(&config("host-a"), &push, "secret text").await.unwrap();
        let (_, body) = request_json(request.await.unwrap());
        let mut fields: Vec<_> = body.as_object().unwrap().keys().cloned().collect();
        fields.sort();
        assert_eq!(fields, ["ciphertext", "device_key", "iv"]);
        assert!(!body.to_string().contains("secret text"));

        // Decrypts back to the payload the app would read.
        use aes::cipher::{BlockModeDecrypt, KeyIvInit};
        let ciphertext = base64::engine::general_purpose::STANDARD
            .decode(body["ciphertext"].as_str().unwrap())
            .unwrap();
        let plain = cbc::Decryptor::<aes::Aes128>::new_from_slices(b"1234567890123456", body["iv"].as_str().unwrap().as_bytes())
            .unwrap()
            .decrypt_padded_vec::<Pkcs7>(&ciphertext)
            .unwrap();
        let payload: Value = serde_json::from_slice(&plain).unwrap();
        assert_eq!(payload["body"], "secret text");
        assert_eq!(payload["sound"], "minuet");
    }

    /// The example in Bark's own encryption docs, so the cipher matches what
    /// the app decrypts rather than only itself.
    #[test]
    fn encryption_matches_barks_documented_example() {
        let ciphertext = encrypt(b"1234567890123456", b"1234567890123456", r#"{"body": "test", "sound": "birdsong"}"#).unwrap();
        assert_eq!(ciphertext, "+aPt5cwN9GbTLLSFri60l3h1X00u/9j1FENfWiTxhNHVLGU+XoJ15JJG5W/d/yf0");
    }

    #[tokio::test]
    async fn a_legacy_push_keeps_title_and_body_in_the_path() {
        let (url, request) = local_server(200, b"ok".to_vec()).await;
        let push = bark(url, "legacy_go_format = true\ntitle = \"T t\"");
        send(&config("host-a"), &push, "b b").await.unwrap();
        let request = String::from_utf8(request.await.unwrap()).unwrap();
        assert!(request.starts_with("GET /device/T+t/b+b HTTP/1.1"), "{request}");
    }

    #[test]
    fn a_key_of_the_wrong_length_is_refused() {
        let push = bark("https://api.day.app".to_string(), "cipher_key = \"short\"");
        assert!(validate(&push).unwrap_err().contains("16, 24 or 32"));
    }
}
