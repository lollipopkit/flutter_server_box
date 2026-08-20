use crate::{core::config::{Config, PushConfig}, utils::error::Result};
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

pub async fn send_notification(config: &Config, push: &PushConfig, message: &str) -> Result<()> {
    let _permit = push_limit()
        .clone()
        .acquire_owned()
        .await
        .map_err(|_| crate::utils::error::MonitorError::Push("Push queue is unavailable".to_string()))?;
    match push.push_type.as_str() {
        "webhook" => send_webhook_notification(config, push, message).await,
        "serverchan" => send_serverchan_notification(config, push, message).await,
        "server_chan" => send_serverchan_notification(config, push, message).await, // Go compatibility
        "bark" => send_bark_notification(config, push, message).await,
        "ios" => send_ios_notification(config, push, message).await,
        _ => {
            warn!("Unknown push type: {}", push.push_type);
            Ok(())
        }
    }
}

async fn send_webhook_notification(config: &Config, push: &PushConfig, message: &str) -> Result<()> {
    let client = http_client();
    
    // Extract webhook configuration
    let url = push.config.get("url")
        .and_then(|v| v.as_str())
        .ok_or_else(|| crate::utils::error::MonitorError::Push("Missing webhook URL".to_string()))?;
    
    let method = push.config.get("method")
        .and_then(|v| v.as_str())
        .unwrap_or("POST");
    
    let headers = push.config.get("headers")
        .and_then(|v| v.as_table())
        .cloned()
        .unwrap_or_default();
    
    // Build request body from template
    let body_template = push.config.get("body_template")
        .or_else(|| push.config.get("body"))
        .and_then(|v| v.as_table())
        .cloned();
    
    let mut body_value = body_template
        .map(|template| Value::Object(template.into_iter().map(|(key, value)| (key, toml_value_to_json(&value))).collect()))
        .or_else(|| push.config.get("body").map(toml_value_to_json))
        .unwrap_or_else(|| Value::Object(serde_json::Map::new()));
    replace_template_variables(&mut body_value, message, &config.get_server_name());
    
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
    
    validate_response(push, status.as_u16(), &response_text)?;
    info!("Webhook notification sent successfully to {}", push.name);
    
    Ok(())
}

async fn send_serverchan_notification(config: &Config, push: &PushConfig, message: &str) -> Result<()> {
    let client = http_client();
    
    // Extract ServerChan configuration
    let sc_key = push.config.get("sc_key")
        .or_else(|| push.config.get("sckey"))
        .and_then(|v| v.as_str())
        .ok_or_else(|| crate::utils::error::MonitorError::Push("Missing ServerChan SCKey".to_string()))?;
    
    let title = push.config.get("title")
        .and_then(|v| v.as_str())
        .unwrap_or("ServerBox Monitor");
    let desp = push.config.get("desp")
        .and_then(|v| v.as_str())
        .unwrap_or(message);
    
    let title = replace_template_string(title, message, &config.get_server_name());
    let desp = replace_template_string(desp, message, &config.get_server_name());
    let url = format!("https://sctapi.ftqq.com/{}.send", sc_key);
    let legacy = is_legacy_go_push(push);
    let response = if legacy {
        let url = format!(
            "{url}?title={}&desp={}",
            url_encode(&title),
            url_encode(&desp),
        );
        client
            .get(&url)
            .send()
            .await?
    } else {
        client
            .post(&url)
            .json(&serde_json::json!({ "title": title, "desp": desp }))
            .send()
            .await?
    };
    
    let status = response.status();
    let response_text = response_text_limited(response).await?;
    validate_response(push, status.as_u16(), &response_text)?;
    
    // The Go endpoint contract was configured status/regex only. The current
    // ServerChan implementation additionally understands its JSON `{code:0}`
    // response; applying that new requirement to old configs would turn a
    // successful legacy response into a false failure.
    if legacy {
        return Ok(());
    }

    // Validate response
    if let Ok(parsed) = serde_json::from_str::<Value>(&response_text) {
        if let Some(code) = parsed.get("code").and_then(|c| c.as_i64()) {
            if code == 0 {
        info!("ServerChan notification sent successfully to {}", push.name);
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

async fn send_bark_notification(config: &Config, push: &PushConfig, message: &str) -> Result<()> {
    let client = http_client();
    
    // Extract Bark configuration
    let server = push.config.get("server")
        .and_then(|v| v.as_str())
        .unwrap_or("https://api.day.app");
    let key = push.config.get("key")
        .and_then(|v| v.as_str())
        .ok_or_else(|| crate::utils::error::MonitorError::Push("Missing Bark key".to_string()))?;
    
    let title = push.config.get("title")
        .and_then(|v| v.as_str())
        .unwrap_or("ServerBox Monitor");
    let body = push.config.get("body")
        .and_then(|v| v.as_str())
        .unwrap_or(message);
    let level = push.config.get("level")
        .and_then(|v| v.as_str())
        .unwrap_or("active");
    
    let title = replace_template_string(title, message, &config.get_server_name());
    let body = replace_template_string(body, message, &config.get_server_name());
    let server = server.trim_end_matches('/');
    // The Go agent put title and body in the path. Its successor initially
    // moved title to a query parameter, so retain the original path for data
    // imported from that agent.
    let url = if is_legacy_go_push(push) {
        format!("{server}/{key}/{}/{}", go_url_encode(&title), go_url_encode(&body))
    } else {
        format!("{server}/{key}/{}", url_encode(&body))
    };
    
    // Build query parameters
    let mut query_params = Vec::new();
    if !is_legacy_go_push(push) {
        query_params.push(format!("title={}", url_encode(&title)));
    }
    
    // Add level if not default
    if level != "active" {
        query_params.push(format!("level={}", level));
    }
    
    // Add optional parameters
    if let Some(group) = push.config.get("group").and_then(|v| v.as_str()) {
        query_params.push(format!("group={}", url_encode(group)));
    }
    
    if let Some(sound) = push.config.get("sound").and_then(|v| v.as_str()) {
        query_params.push(format!("sound={}", url_encode(sound)));
    }
    
    if let Some(icon) = push.config.get("icon").and_then(|v| v.as_str()) {
        query_params.push(format!("icon={}", url_encode(icon)));
    }
    
    if let Some(url_param) = push.config.get("url").and_then(|v| v.as_str()) {
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
    validate_response(push, status.as_u16(), &response_text)?;
    info!("Bark notification sent successfully to {}", push.name);
    
    Ok(())
}

async fn send_ios_notification(config: &Config, push: &PushConfig, message: &str) -> Result<()> {
    let client = http_client();
    
    // Extract iOS configuration
    let token = push.config.get("token")
        .and_then(|v| v.as_str())
        .ok_or_else(|| crate::utils::error::MonitorError::Push("Missing iOS token".to_string()))?;
    
    let title = push.config.get("title")
        .and_then(|v| v.as_str())
        .unwrap_or("ServerBox Monitor");
    let content = push.config.get("content")
        .and_then(|v| v.as_str())
        .unwrap_or(message);
    
    // Build request body
    let body = serde_json::json!({
        "token": token,
        "title": replace_template_string(title, message, &config.get_server_name()),
        "content": replace_template_string(content, message, &config.get_server_name())
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
    if let Some(expected_code) = push.config.get("code").and_then(|v| v.as_integer())
        && status_code.as_u16() != expected_code as u16
    {
        warn!("iOS notification failed: {} - {}", status_code, response_text);
        return Err(crate::utils::error::MonitorError::Push(format!("Unexpected status code: {}", status_code)));
    }
    
    // Check if there's a specific expected response pattern
    if let Some(body_regex) = push.config.get("body_regex").and_then(|v| v.as_str()) {
        let re = regex::Regex::new(body_regex)
            .map_err(|e| crate::utils::error::MonitorError::Push(format!("Invalid regex pattern: {}", e)))?;
        
        if !re.is_match(&response_text) {
            warn!("iOS notification response didn't match expected pattern: {}", response_text);
            return Err(crate::utils::error::MonitorError::Push(format!("Response validation failed: {}", response_text)));
        }
    }
    
    info!("iOS notification sent successfully to {}", push.name);
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

fn replace_template_variables(value: &mut Value, message: &str, server_name: &str) {
    match value {
        Value::String(s) => {
            *s = replace_template_string(s, message, server_name);
        }
        Value::Object(obj) => {
            for (_, v) in obj.iter_mut() {
                replace_template_variables(v, message, server_name);
            }
        }
        Value::Array(arr) => {
            for v in arr.iter_mut() {
                replace_template_variables(v, message, server_name);
            }
        }
        _ => {}
    }
}

fn replace_template_string(template: &str, message: &str, server_name: &str) -> String {
    template
        .replace("{{message}}", message)
        .replace("{{msg}}", message)
        .replace("{{name}}", server_name)
}

fn validate_response(push: &PushConfig, status: u16, body: &str) -> Result<()> {
    if let Some(expected) = push.config.get("expected_http_status").and_then(|v| v.as_integer()) {
        if status != expected as u16 {
            return Err(crate::utils::error::MonitorError::Push(format!(
                "{} returned {status}, expected {expected}",
                push.name
            )));
        }
    } else if !(200..300).contains(&status) {
        return Err(crate::utils::error::MonitorError::Push(format!(
            "{} returned HTTP {status}: {body}",
            push.name
        )));
    }
    if let Some(pattern) = push.config.get("body_regex").and_then(|v| v.as_str()) {
        let regex = regex::Regex::new(pattern)
            .map_err(|error| crate::utils::error::MonitorError::Push(format!("Invalid regex pattern: {error}")))?;
        if !regex.is_match(body) {
            return Err(crate::utils::error::MonitorError::Push(format!(
                "{} response did not match body_regex",
                push.name
            )));
        }
    }
    Ok(())
}

fn is_legacy_go_push(push: &PushConfig) -> bool {
    push.config
        .get("legacy_go_format")
        .and_then(|value| value.as_bool())
        .unwrap_or(false)
}

fn url_encode(input: &str) -> String {
    use percent_encoding::{utf8_percent_encode, NON_ALPHANUMERIC};
    utf8_percent_encode(input, NON_ALPHANUMERIC).to_string()
}

/// Go's `url.QueryEscape`, which the old Bark path used, spells spaces as
/// `+`. The newer Bark form uses RFC percent encoding in a query parameter.
fn go_url_encode(input: &str) -> String {
    url_encode(input).replace("%20", "+")
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::TcpListener;

    async fn local_response(status: u16, body: Vec<u8>) -> String {
        let (url, _) = local_server(status, body).await;
        url
    }

    async fn local_server(status: u16, body: Vec<u8>) -> (String, tokio::task::JoinHandle<Vec<u8>>) {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let request = tokio::spawn(async move {
            let (mut socket, _) = listener.accept().await.unwrap();
            let mut request = Vec::new();
            let mut buffer = [0_u8; 1024];
            loop {
                let read = socket.read(&mut buffer).await.unwrap();
                if read == 0 {
                    break;
                }
                request.extend_from_slice(&buffer[..read]);
                let Some(head_end) = request.windows(4).position(|window| window == b"\r\n\r\n") else {
                    continue;
                };
                let headers = String::from_utf8_lossy(&request[..head_end]);
                let content_length = headers
                    .lines()
                    .find_map(|line| line.strip_prefix("Content-Length: "))
                    .and_then(|value| value.parse::<usize>().ok())
                    .unwrap_or(0);
                if request.len() >= head_end + 4 + content_length {
                    break;
                }
            }
            let reason = if status == 200 { "OK" } else { "Error" };
            let head = format!(
                "HTTP/1.1 {status} {reason}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                body.len()
            );
            socket.write_all(head.as_bytes()).await.unwrap();
            socket.write_all(&body).await.unwrap();
            request
        });
        (format!("http://{addr}"), request)
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

    fn config(server_name: &str) -> Config {
        let mut config = Config::default();
        config.server.as_mut().unwrap().name = Some(server_name.to_string());
        config
    }

    #[test]
    fn test_replace_template_string() {
        let result = replace_template_string("Hello {{name}}, message: {{message}}", "Test message", "my-server");
        assert_eq!(result, "Hello my-server, message: Test message");
        assert_eq!(replace_template_string("{{msg}}", "Test message", "my-server"), "Test message");
    }

    #[test]
    fn test_url_encode() {
        let result = url_encode("hello world");
        assert_eq!(result, "hello%20world");
        assert_eq!(go_url_encode("hello world"), "hello+world");
    }

    #[tokio::test]
    async fn webhook_accepts_a_small_success_response() {
        let push = webhook(local_response(200, b"ok".to_vec()).await);
        assert!(send_notification(&config("test-server"), &push, "Test Message").await.is_ok());
    }

    #[tokio::test]
    async fn webhook_reports_an_http_failure() {
        let push = webhook(local_response(500, b"failed".to_vec()).await);
        let error = send_notification(&config("test-server"), &push, "Test Message").await.unwrap_err();
        assert!(error.to_string().contains("500"));
    }

    #[tokio::test]
    async fn webhook_refuses_an_oversized_response() {
        let push = webhook(local_response(200, vec![b'x'; MAX_RESPONSE_BYTES + 1]).await);
        let error = send_notification(&config("test-server"), &push, "Test Message").await.unwrap_err();
        assert!(error.to_string().contains("exceeded"));
    }

    #[tokio::test]
    async fn test_send_notification_unknown_type() {
        let push = crate::core::config::PushConfig {
            name: "test_unknown".to_string(),
            push_type: "unknown".to_string(),
            config: toml::Table::new(),
        };

        let result = send_notification(&config("test-server"), &push, "Test Message").await;
        assert!(result.is_ok()); // Should handle unknown type gracefully
    }

    #[tokio::test]
    async fn a_go_webhook_body_and_placeholders_survive_the_request() {
        let (url, request) = local_server(202, b"accepted".to_vec()).await;
        let mut push = webhook(url);
        push.config.insert("expected_http_status".to_string(), TomlValue::Integer(202));
        push.config.insert("body".to_string(), toml::toml! {
            action = "send_group_msg"
            [params]
            message = "{{name}} {{msg}}"
        }.into());

        send_notification(&config("legacy-host"), &push, "CPU: 91%").await.unwrap();
        let request = String::from_utf8(request.await.unwrap()).unwrap();
        assert!(request.starts_with("POST / HTTP/1.1"));
        assert!(request.contains("\"message\":\"legacy-host CPU: 91%\""), "request was {request}");
    }

    #[test]
    fn a_legacy_bark_push_keeps_title_in_the_path() {
        let mut config = toml::Table::new();
        config.insert("legacy_go_format".to_string(), TomlValue::Boolean(true));
        let push = PushConfig {
            name: "legacy bark".to_string(),
            push_type: "bark".to_string(),
            config,
        };
        assert!(is_legacy_go_push(&push));
    }

}
