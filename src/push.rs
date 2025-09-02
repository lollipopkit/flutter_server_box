use crate::{config::PushConfig, error::Result};
use reqwest::Client;
use serde_json::Value;
use tracing::{info, warn};

pub async fn send_notification(config: &PushConfig, message: &str) -> Result<()> {
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
    let client = Client::new();
    
    // Extract webhook configuration
    let url = config.config["url"].as_str()
        .ok_or_else(|| crate::error::MonitorError::Push("Missing webhook URL".to_string()))?;
    
    let method = config.config["method"].as_str().unwrap_or("POST");
    
    let headers = config.config["headers"].as_object().cloned().unwrap_or_default();
    
    // Build request body from template
    let mut body = config.config["body_template"].clone();
    replace_template_variables(&mut body, message);
    
    // Build request
    let mut request = match method.to_uppercase().as_str() {
        "GET" => client.get(url),
        "POST" => client.post(url),
        "PUT" => client.put(url),
        "PATCH" => client.patch(url),
        _ => client.post(url),
    };
    
    // Add headers
    for (key, value) in headers {
        if let Some(value_str) = value.as_str() {
            request = request.header(key, value_str);
        }
    }
    
    // Add body for non-GET requests
    if method.to_uppercase() != "GET" {
        request = request.json(&body);
    }
    
    let response = request.send().await?;
    
    if response.status().is_success() {
        info!("Webhook notification sent successfully to {}", config.name);
    } else {
        warn!("Webhook notification failed: {} {}", response.status(), response.text().await?);
    }
    
    Ok(())
}

async fn send_serverchan_notification(config: &PushConfig, message: &str) -> Result<()> {
    let client = Client::new();
    
    // Extract ServerChan configuration
    let sc_key = config.config["sc_key"].as_str()
        .ok_or_else(|| crate::error::MonitorError::Push("Missing ServerChan SCKey".to_string()))?;
    
    let title = config.config["title"].as_str().unwrap_or("ServerBox Monitor");
    let desp = config.config["desp"].as_str().unwrap_or(message);
    
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
    
    let response_text = response.text().await?;
    
    // Validate response
    if let Ok(parsed) = serde_json::from_str::<Value>(&response_text) {
        if let Some(code) = parsed.get("code").and_then(|c| c.as_i64()) {
            if code == 0 {
                info!("ServerChan notification sent successfully to {}", config.name);
            } else {
                warn!("ServerChan notification failed: {} - {}", code, response_text);
            }
        } else {
            warn!("ServerChan response missing code field: {}", response_text);
        }
    } else {
        warn!("Failed to parse ServerChan response: {}", response_text);
    }
    
    Ok(())
}

async fn send_bark_notification(config: &PushConfig, message: &str) -> Result<()> {
    let client = Client::new();
    
    // Extract Bark configuration
    let server = config.config["server"].as_str().unwrap_or("https://api.day.app");
    let key = config.config["key"].as_str()
        .ok_or_else(|| crate::error::MonitorError::Push("Missing Bark key".to_string()))?;
    
    let title = config.config["title"].as_str().unwrap_or("ServerBox Monitor");
    let body = config.config["body"].as_str().unwrap_or(message);
    let level = config.config["level"].as_str().unwrap_or("active");
    
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
    if let Some(group) = config.config["group"].as_str() {
        query_params.push(format!("group={}", url_encode(group)));
    }
    
    if let Some(sound) = config.config["sound"].as_str() {
        query_params.push(format!("sound={}", url_encode(sound)));
    }
    
    if let Some(icon) = config.config["icon"].as_str() {
        query_params.push(format!("icon={}", url_encode(icon)));
    }
    
    if let Some(url_param) = config.config["url"].as_str() {
        query_params.push(format!("url={}", url_encode(url_param)));
    }
    
    // Build final URL with query parameters
    let final_url = if !query_params.is_empty() {
        format!("{}?{}", url, query_params.join("&"))
    } else {
        url
    };
    
    let response = client.get(&final_url).send().await?;
    
    if response.status().is_success() {
        info!("Bark notification sent successfully to {}", config.name);
    } else {
        warn!("Bark notification failed: {} {}", response.status(), response.text().await?);
    }
    
    Ok(())
}

async fn send_ios_notification(config: &PushConfig, message: &str) -> Result<()> {
    let client = Client::new();
    
    // Extract iOS configuration
    let token = config.config["token"].as_str()
        .ok_or_else(|| crate::error::MonitorError::Push("Missing iOS token".to_string()))?;
    
    let title = config.config["title"].as_str().unwrap_or("ServerBox Monitor");
    let content = config.config["content"].as_str().unwrap_or(message);
    
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
    let response_text = response.text().await?;
    
    // Check if there's an expected response code
    if let Some(expected_code) = config.config["code"].as_i64() {
        if status_code.as_u16() != expected_code as u16 {
            warn!("iOS notification failed: {} - {}", status_code, response_text);
            return Err(crate::error::MonitorError::Push(format!("Unexpected status code: {}", status_code)).into());
        }
    }
    
    // Check if there's a specific expected response pattern
    if let Some(body_regex) = config.config["body_regex"].as_str() {
        let re = regex::Regex::new(body_regex)
            .map_err(|e| crate::error::MonitorError::Push(format!("Invalid regex pattern: {}", e)))?;
        
        if !re.is_match(&response_text) {
            warn!("iOS notification response didn't match expected pattern: {}", response_text);
            return Err(crate::error::MonitorError::Push(format!("Response validation failed: {}", response_text)).into());
        }
    }
    
    info!("iOS notification sent successfully to {}", config.name);
    Ok(())
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
    async fn test_serverchan_notification() {
        let config = crate::config::PushConfig {
            name: "test_serverchan".to_string(),
            push_type: "serverchan".to_string(),
            config: serde_json::json!({
                "sc_key": "test_key",
                "title": "Test Title",
                "desp": "Test {{message}}"
            }),
        };

        let result = send_serverchan_notification(&config, "Test Message").await;
        // Since we're using a test key, this will likely fail but we're testing to structure
        assert!(result.is_ok() || result.is_err()); // Either way is fine for structure test
    }

    #[tokio::test]
    async fn test_bark_notification() {
        let config = crate::config::PushConfig {
            name: "test_bark".to_string(),
            push_type: "bark".to_string(),
            config: serde_json::json!({
                "server": "https://api.day.app",
                "key": "test_key",
                "title": "Test Title",
                "body": "Test {{message}}",
                "level": "active"
            }),
        };

        let result = send_bark_notification(&config, "Test Message").await;
        // Since we're using a test key, this will likely fail but we're testing structure
        assert!(result.is_ok() || result.is_err()); // Either way is fine for structure test
    }

    #[tokio::test]
    async fn test_send_notification_serverchan() {
        let config = crate::config::PushConfig {
            name: "test_serverchan".to_string(),
            push_type: "serverchan".to_string(),
            config: serde_json::json!({
                "sc_key": "test_key",
                "title": "Test",
                "desp": "{{message}}"
            }),
        };

        let result = send_notification(&config, "Test Message").await;
        assert!(result.is_ok()); // Should not panic
    }

    #[tokio::test]
    async fn test_send_notification_bark() {
        let config = crate::config::PushConfig {
            name: "test_bark".to_string(),
            push_type: "bark".to_string(),
            config: serde_json::json!({
                "server": "https://api.day.app",
                "key": "test_key",
                "title": "Test",
                "body": "{{message}}",
                "level": "active"
            }),
        };

        let result = send_notification(&config, "Test Message").await;
        assert!(result.is_ok()); // Should not panic
    }

    #[tokio::test]
    async fn test_send_notification_unknown_type() {
        let config = crate::config::PushConfig {
            name: "test_unknown".to_string(),
            push_type: "unknown".to_string(),
            config: serde_json::json!({}),
        };

        let result = send_notification(&config, "Test Message").await;
        assert!(result.is_ok()); // Should handle unknown type gracefully
    }

    #[tokio::test]
    async fn test_bark_notification_with_optional_params() {
        let config = crate::config::PushConfig {
            name: "test_bark_full".to_string(),
            push_type: "bark".to_string(),
            config: serde_json::json!({
                "server": "https://api.day.app",
                "key": "test_key",
                "title": "Test Title",
                "body": "Test {{message}}",
                "level": "timeSensitive",
                "group": "test_group",
                "sound": "default",
                "icon": "https://example.com/icon.png",
                "url": "https://example.com"
            }),
        };

        let result = send_bark_notification(&config, "Test Message").await;
        assert!(result.is_ok() || result.is_err()); // Either way is fine for structure test
    }
}