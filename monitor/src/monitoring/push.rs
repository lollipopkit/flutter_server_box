use crate::{core::config::PushConfig, utils::error::Result};
use futures::StreamExt;
use reqwest::Client;
use serde_json::Value;
use std::collections::{HashMap, VecDeque};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};
use tokio::sync::Semaphore;
use toml::Value as TomlValue;
use tracing::{info, warn};

const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);
const REQUEST_TIMEOUT: Duration = Duration::from_secs(20);
const MAX_RESPONSE_BYTES: usize = 64 * 1024;
const MAX_CONCURRENT_PUSHES: usize = 4;

fn http_client() -> &'static Client {
    static CLIENT: OnceLock<Client> = OnceLock::new();
    CLIENT.get_or_init(|| {
        Client::builder()
            .connect_timeout(CONNECT_TIMEOUT)
            .timeout(REQUEST_TIMEOUT)
            .pool_idle_timeout(Duration::from_secs(60))
            .build()
            .expect("valid push HTTP client configuration")
    })
}

fn push_limit() -> &'static Arc<Semaphore> {
    static LIMIT: OnceLock<Arc<Semaphore>> = OnceLock::new();
    LIMIT.get_or_init(|| Arc::new(Semaphore::new(MAX_CONCURRENT_PUSHES)))
}

async fn response_text_limited(response: reqwest::Response) -> Result<String> {
    let mut stream = response.bytes_stream();
    let mut body = Vec::new();
    while let Some(chunk) = stream.next().await {
        let chunk = chunk?;
        if body.len().saturating_add(chunk.len()) > MAX_RESPONSE_BYTES {
            return Err(crate::utils::error::MonitorError::Push(format!(
                "Push response exceeded {MAX_RESPONSE_BYTES} bytes"
            )));
        }
        body.extend_from_slice(&chunk);
    }
    Ok(String::from_utf8_lossy(&body).into_owned())
}

/// Rate limit per push name: at most `times` within `window`
pub struct PushRateLimiter {
    records: Mutex<HashMap<String, VecDeque<Instant>>>,
}

impl Default for PushRateLimiter {
    fn default() -> Self {
        Self::new()
    }
}

impl PushRateLimiter {
    pub fn new() -> Self {
        Self {
            records: Mutex::new(HashMap::new()),
        }
    }

    pub fn global() -> &'static Self {
        static LIMITER: OnceLock<PushRateLimiter> = OnceLock::new();
        LIMITER.get_or_init(Self::new)
    }

    /// Whether a push is allowed (does not consume quota)
    pub fn check(&self, name: &str, times: usize, window: Duration) -> bool {
        let mut records = self.records.lock().unwrap();
        let queue = records.entry(name.to_string()).or_default();
        let now = Instant::now();
        while queue.front().is_some_and(|t| now.duration_since(*t) > window) {
            queue.pop_front();
        }
        queue.len() < times
    }

    /// Consume one quota unit after a successful push
    pub fn acquire(&self, name: &str) {
        let mut records = self.records.lock().unwrap();
        records
            .entry(name.to_string())
            .or_default()
            .push_back(Instant::now());
    }
}

pub async fn send_notification(config: &PushConfig, message: &str) -> Result<()> {
    let _permit = push_limit()
        .clone()
        .acquire_owned()
        .await
        .map_err(|_| crate::utils::error::MonitorError::Push("Push queue is unavailable".to_string()))?;
    match config.push_type.as_str() {
        "webhook" => send_webhook_notification(config, message).await,
        "serverchan" => send_serverchan_notification(config, message).await,
        "server_chan" => send_serverchan_notification(config, message).await, // Go compatibility
        "bark" => send_bark_notification(config, message).await,
        "ios" => send_ios_notification(config, message).await,
        _ => {
            warn!("Unknown push type: {}", config.push_type);
            Ok(())
        }
    }
}

async fn send_webhook_notification(config: &PushConfig, message: &str) -> Result<()> {
    let client = http_client();
    
    // Extract webhook configuration
    let url = config.config.get("url")
        .and_then(|v| v.as_str())
        .ok_or_else(|| crate::utils::error::MonitorError::Push("Missing webhook URL".to_string()))?;
    
    let method = config.config.get("method")
        .and_then(|v| v.as_str())
        .unwrap_or("POST");
    
    let headers = config.config.get("headers")
        .and_then(|v| v.as_table())
        .cloned()
        .unwrap_or_default();
    
    // Build request body from template
    let body_template = config.config.get("body_template")
        .and_then(|v| v.as_table())
        .cloned()
        .unwrap_or_default();
    
    let mut body = serde_json::Map::new();
    for (key, toml_val) in body_template.iter() {
        let json_val = toml_value_to_json(toml_val);
        body.insert(key.clone(), json_val);
    }
    
    // Replace template variables in the body
    let mut body_value = Value::Object(body);
    replace_template_variables(&mut body_value, message);
    
    // Build request
    let mut request = match method.to_uppercase().as_str() {
        "GET" => client.get(url),
        "POST" => client.post(url),
        "PUT" => client.put(url),
        "PATCH" => client.patch(url),
        _ => client.post(url),
    };
    
    // Add headers
    for (key, toml_val) in headers.iter() {
        if let Some(value_str) = toml_val.as_str() {
            request = request.header(key, value_str);
        }
    }
    
    // Add body for non-GET requests
    if method.to_uppercase() != "GET" {
        request = request.json(&body_value);
    }
    
    let response = request.send().await?;
    let status = response.status();
    let response_text = response_text_limited(response).await?;
    
    if status.is_success() {
        info!("Webhook notification sent successfully to {}", config.name);
    } else {
        return Err(crate::utils::error::MonitorError::Push(format!(
            "Webhook notification failed: {status} {response_text}"
        )));
    }
    
    Ok(())
}

async fn send_serverchan_notification(config: &PushConfig, message: &str) -> Result<()> {
    let client = http_client();
    
    // Extract ServerChan configuration
    let sc_key = config.config.get("sc_key")
        .and_then(|v| v.as_str())
        .ok_or_else(|| crate::utils::error::MonitorError::Push("Missing ServerChan SCKey".to_string()))?;
    
    let title = config.config.get("title")
        .and_then(|v| v.as_str())
        .unwrap_or("ServerBox Monitor");
    let desp = config.config.get("desp")
        .and_then(|v| v.as_str())
        .unwrap_or(message);
    
    // Build URL with parameters
    let url = format!("https://sctapi.ftqq.com/{}.send", sc_key);
    
    // Build request body
    let mut body = serde_json::Map::new();
    body.insert("title".to_string(), Value::String(replace_template_string(title, message)));
    body.insert("desp".to_string(), Value::String(replace_template_string(desp, message)));
    
    let response = client.post(&url)
        .json(&body)
        .send()
        .await?;
    
    let status = response.status();
    let response_text = response_text_limited(response).await?;
    if !status.is_success() {
        return Err(crate::utils::error::MonitorError::Push(format!(
            "ServerChan notification failed: {status} {response_text}"
        )));
    }
    
    // Validate response
    if let Ok(parsed) = serde_json::from_str::<Value>(&response_text) {
        if let Some(code) = parsed.get("code").and_then(|c| c.as_i64()) {
            if code == 0 {
                info!("ServerChan notification sent successfully to {}", config.name);
            } else {
                return Err(crate::utils::error::MonitorError::Push(format!(
                    "ServerChan notification failed: {code} - {response_text}"
                )));
            }
        } else {
            return Err(crate::utils::error::MonitorError::Push(format!(
                "ServerChan response missing code field: {response_text}"
            )));
        }
    } else {
        return Err(crate::utils::error::MonitorError::Push(format!(
            "Failed to parse ServerChan response: {response_text}"
        )));
    }
    
    Ok(())
}

async fn send_bark_notification(config: &PushConfig, message: &str) -> Result<()> {
    let client = http_client();
    
    // Extract Bark configuration
    let server = config.config.get("server")
        .and_then(|v| v.as_str())
        .unwrap_or("https://api.day.app");
    let key = config.config.get("key")
        .and_then(|v| v.as_str())
        .ok_or_else(|| crate::utils::error::MonitorError::Push("Missing Bark key".to_string()))?;
    
    let title = config.config.get("title")
        .and_then(|v| v.as_str())
        .unwrap_or("ServerBox Monitor");
    let body = config.config.get("body")
        .and_then(|v| v.as_str())
        .unwrap_or(message);
    let level = config.config.get("level")
        .and_then(|v| v.as_str())
        .unwrap_or("active");
    
    // Build URL
    let url = format!("{}/{}/{}", server, key, url_encode(&replace_template_string(body, message)));
    
    // Build query parameters
    let mut query_params = Vec::new();
    query_params.push(format!("title={}", url_encode(&replace_template_string(title, message))));
    
    // Add level if not default
    if level != "active" {
        query_params.push(format!("level={}", level));
    }
    
    // Add optional parameters
    if let Some(group) = config.config.get("group").and_then(|v| v.as_str()) {
        query_params.push(format!("group={}", url_encode(group)));
    }
    
    if let Some(sound) = config.config.get("sound").and_then(|v| v.as_str()) {
        query_params.push(format!("sound={}", url_encode(sound)));
    }
    
    if let Some(icon) = config.config.get("icon").and_then(|v| v.as_str()) {
        query_params.push(format!("icon={}", url_encode(icon)));
    }
    
    if let Some(url_param) = config.config.get("url").and_then(|v| v.as_str()) {
        query_params.push(format!("url={}", url_encode(url_param)));
    }
    
    // Build final URL with query parameters
    let final_url = if !query_params.is_empty() {
        format!("{}?{}", url, query_params.join("&"))
    } else {
        url
    };
    
    let response = client.get(&final_url).send().await?;
    let status = response.status();
    let response_text = response_text_limited(response).await?;
    
    if status.is_success() {
        info!("Bark notification sent successfully to {}", config.name);
    } else {
        return Err(crate::utils::error::MonitorError::Push(format!(
            "Bark notification failed: {status} {response_text}"
        )));
    }
    
    Ok(())
}

async fn send_ios_notification(config: &PushConfig, message: &str) -> Result<()> {
    let client = http_client();
    
    // Extract iOS configuration
    let token = config.config.get("token")
        .and_then(|v| v.as_str())
        .ok_or_else(|| crate::utils::error::MonitorError::Push("Missing iOS token".to_string()))?;
    
    let title = config.config.get("title")
        .and_then(|v| v.as_str())
        .unwrap_or("ServerBox Monitor");
    let content = config.config.get("content")
        .and_then(|v| v.as_str())
        .unwrap_or(message);
    
    // Build request body
    let body = serde_json::json!({
        "token": token,
        "title": replace_template_string(title, message),
        "content": replace_template_string(content, message)
    });
    
    let response = client.post("https://push.lolli.tech/v1/ios")
        .json(&body)
        .header("AppID", "com.lollipopkit.toolbox")
        .header("Content-Type", "application/json")
        .header("Env", "prod")
        .send()
        .await?;
    
    let status_code = response.status();
    let response_text = response_text_limited(response).await?;

    if !status_code.is_success() {
        warn!("iOS notification failed: {} - {}", status_code, response_text);
        return Err(crate::utils::error::MonitorError::Push(format!(
            "Unexpected status code: {}",
            status_code
        )));
    }
    
    // Check if there's an expected response code
    if let Some(expected_code) = config.config.get("code").and_then(|v| v.as_integer())
        && status_code.as_u16() != expected_code as u16
    {
        warn!("iOS notification failed: {} - {}", status_code, response_text);
        return Err(crate::utils::error::MonitorError::Push(format!("Unexpected status code: {}", status_code)));
    }
    
    // Check if there's a specific expected response pattern
    if let Some(body_regex) = config.config.get("body_regex").and_then(|v| v.as_str()) {
        let re = regex::Regex::new(body_regex)
            .map_err(|e| crate::utils::error::MonitorError::Push(format!("Invalid regex pattern: {}", e)))?;
        
        if !re.is_match(&response_text) {
            warn!("iOS notification response didn't match expected pattern: {}", response_text);
            return Err(crate::utils::error::MonitorError::Push(format!("Response validation failed: {}", response_text)));
        }
    }
    
    info!("iOS notification sent successfully to {}", config.name);
    Ok(())
}

fn toml_value_to_json(toml_val: &TomlValue) -> Value {
    match toml_val {
        TomlValue::String(s) => Value::String(s.clone()),
        TomlValue::Integer(i) => Value::Number(serde_json::Number::from(*i)),
        TomlValue::Float(f) => Value::Number(serde_json::Number::from_f64(*f).unwrap_or(serde_json::Number::from(0))),
        TomlValue::Boolean(b) => Value::Bool(*b),
        TomlValue::Array(arr) => Value::Array(arr.iter().map(toml_value_to_json).collect()),
        TomlValue::Table(table) => {
            let mut map = serde_json::Map::new();
            for (key, val) in table.iter() {
                map.insert(key.clone(), toml_value_to_json(val));
            }
            Value::Object(map)
        }
        TomlValue::Datetime(dt) => Value::String(dt.to_string()),
    }
}

fn replace_template_variables(value: &mut Value, message: &str) {
    match value {
        Value::String(s) => {
            *s = s.replace("{{message}}", message)
                 .replace("{{name}}", "ServerBox Monitor");
        }
        Value::Object(obj) => {
            for (_, v) in obj.iter_mut() {
                replace_template_variables(v, message);
            }
        }
        Value::Array(arr) => {
            for v in arr.iter_mut() {
                replace_template_variables(v, message);
            }
        }
        _ => {}
    }
}

fn replace_template_string(template: &str, message: &str) -> String {
    template.replace("{{message}}", message)
             .replace("{{name}}", "ServerBox Monitor")
}

fn url_encode(input: &str) -> String {
    use percent_encoding::{utf8_percent_encode, NON_ALPHANUMERIC};
    utf8_percent_encode(input, NON_ALPHANUMERIC).to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::TcpListener;

    async fn local_response(status: u16, body: Vec<u8>) -> String {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move {
            let (mut socket, _) = listener.accept().await.unwrap();
            let mut request = [0_u8; 4096];
            let _ = socket.read(&mut request).await;
            let reason = if status == 200 { "OK" } else { "Error" };
            let head = format!(
                "HTTP/1.1 {status} {reason}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                body.len()
            );
            socket.write_all(head.as_bytes()).await.unwrap();
            socket.write_all(&body).await.unwrap();
        });
        format!("http://{addr}")
    }

    fn webhook(url: String) -> PushConfig {
        let mut config = toml::Table::new();
        config.insert("url".to_string(), toml::Value::String(url));
        PushConfig {
            name: "test_webhook".to_string(),
            push_type: "webhook".to_string(),
            config,
        }
    }

    #[test]
    fn test_replace_template_string() {
        let result = replace_template_string("Hello {{name}}, message: {{message}}", "Test message");
        assert_eq!(result, "Hello ServerBox Monitor, message: Test message");
    }

    #[test]
    fn test_url_encode() {
        let result = url_encode("hello world");
        assert_eq!(result, "hello%20world");
    }

    #[tokio::test]
    async fn webhook_accepts_a_small_success_response() {
        let config = webhook(local_response(200, b"ok".to_vec()).await);
        assert!(send_notification(&config, "Test Message").await.is_ok());
    }

    #[tokio::test]
    async fn webhook_reports_an_http_failure() {
        let config = webhook(local_response(500, b"failed".to_vec()).await);
        let error = send_notification(&config, "Test Message").await.unwrap_err();
        assert!(error.to_string().contains("500"));
    }

    #[tokio::test]
    async fn webhook_refuses_an_oversized_response() {
        let config = webhook(local_response(200, vec![b'x'; MAX_RESPONSE_BYTES + 1]).await);
        let error = send_notification(&config, "Test Message").await.unwrap_err();
        assert!(error.to_string().contains("exceeded"));
    }

    #[tokio::test]
    async fn test_send_notification_unknown_type() {
        let config = crate::core::config::PushConfig {
            name: "test_unknown".to_string(),
            push_type: "unknown".to_string(),
            config: toml::Table::new(),
        };

        let result = send_notification(&config, "Test Message").await;
        assert!(result.is_ok()); // Should handle unknown type gracefully
    }

}
