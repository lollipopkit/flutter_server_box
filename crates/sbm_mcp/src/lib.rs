//! The MCP server core, shared by every ServerBox host that serves one: the
//! monitor behind `/api/v1/mcp` (#1681) and the app behind its own listener.
//!
//! [`serve`] is the protocol; [`http`] the transport's checks; [`token`] and
//! [`access`] the credential and what it may do; [`catalog`] the tools;
//! [`machine`] what a machine reached through a shell answers.
//!
//! **Stateless by design** (`stateful_mode: false`): every request names
//! everything it needs, the protocol carries no session, and [`serve`] turns
//! one JSON-RPC message into one answer. The transport — which HTTP framework,
//! what credential checked first — is the host's; this crate never opens a
//! socket. `rmcp` is used for its model types (`Tool`, results, protocol
//! versions) so the wire stays what the spec says, and nothing else of it.

pub mod access;
pub mod catalog;
pub mod http;
pub mod machine;
pub mod token;

use async_trait::async_trait;
use rmcp::model::{ContentBlock, Implementation, InitializeResult, ListToolsResult, ProtocolVersion, ServerCapabilities};
/// The protocol's own types, re-exported: a host answers in them.
pub use rmcp::model::{CallToolResult, Tool};
use serde::Serialize;
use serde_json::{Value, json};

/// What the host serves: its tools, and what calling one does.
#[async_trait]
pub trait Host: Send + Sync {
    /// The server, as `initialize` names it: (name, version).
    fn server_info(&self) -> (&'static str, &'static str);
    /// Every tool, as `tools/list` answers them. Filtered by whatever the
    /// host's credential allows — a caller sees only what it may call.
    fn tools(&self) -> Vec<Tool>;
    /// One call. `name` is one of [`Host::tools`]' names.
    async fn call(&self, name: &str, arguments: Value) -> CallToolResult;
}

/// What one request became.
pub enum Answer {
    /// A JSON-RPC message, as the body of a 200.
    Json(Value),
    /// A notification or client response: nothing to answer, the transport says 202.
    Accepted,
}

const SPOKEN: [ProtocolVersion; 2] = [
    ProtocolVersion::V_2025_11_25,
    ProtocolVersion::V_2025_06_18,
];

/// Whether `MCP-Protocol-Version` names a protocol version this server speaks.
pub fn speaks_version(v: &str) -> bool {
    SPOKEN.iter().any(|sp| sp.as_str() == v)
}

/// Turns one JSON-RPC message into one answer.
pub async fn serve(host: &dyn Host, body: &Value) -> Answer {
    let Some(request) = body.as_object() else {
        return Answer::Json(error(&Value::Null, INVALID_REQUEST, "a request must be an object"));
    };
    if request.get("jsonrpc").and_then(Value::as_str) != Some("2.0") {
        return Answer::Json(error(&Value::Null, INVALID_REQUEST, "jsonrpc must be 2.0"));
    }
    // Streamable HTTP: a JSON-RPC response sent by the client (no `method`,
    // valid `id`, and exactly one of `result` or `error`) is acknowledged with
    // 202 Accepted.
    if !request.contains_key("method") && (request.contains_key("result") || request.contains_key("error")) {
        let valid_id = request.get("id").is_some_and(|id| id.is_string() || id.is_number());
        let exactly_one = request.contains_key("result") ^ request.contains_key("error");
        if valid_id && exactly_one {
            return Answer::Accepted;
        }
        return Answer::Json(error(&Value::Null, INVALID_REQUEST, "malformed JSON-RPC response"));
    }
    let Some(method) = request.get("method").and_then(Value::as_str).filter(|m| !m.is_empty()) else {
        let bad_id = request
            .get("id")
            .filter(|id| id.is_string() || id.is_number())
            .unwrap_or(&Value::Null);
        return Answer::Json(error(bad_id, INVALID_REQUEST, "method must be a non-empty string"));
    };
    let Some(id) = request.get("id") else {
        // A notification has no `id`.
        return Answer::Accepted;
    };
    // MCP requires `RequestId` to be a string or number (`null` is forbidden).
    if !(id.is_string() || id.is_number()) {
        return Answer::Json(error(&Value::Null, INVALID_REQUEST, "id must be a string or number"));
    }
    let params = request.get("params").cloned().unwrap_or(Value::Null);
    let reply = match method {
        "initialize" => {
            let client = params.get("protocolVersion").and_then(Value::as_str);
            let (name, version) = host.server_info();
            let result = InitializeResult::new(
                ServerCapabilities::builder().enable_tools().build(),
            )
            .with_server_info(Implementation::new(name, version))
            .with_protocol_version(negotiate(client));
            answer(id, to_value(&result))
        }
        "ping" => answer(id, json!({})),
        "tools/list" => {
            let result = ListToolsResult::with_all_items(host.tools());
            answer(id, to_value(&result))
        }
        "tools/call" => match params.get("name").and_then(Value::as_str) {
            Some(name) if host.tools().iter().any(|t| t.name == name) => {
                let arguments = match params.get("arguments") {
                    None => json!({}),
                    Some(v) if v.is_object() => v.clone(),
                    Some(_) => return Answer::Json(error(id, INVALID_PARAMS, "arguments must be an object")),
                };
                let result = host.call(name, arguments).await;
                answer(id, to_value(&result))
            }
            _ => error(id, INVALID_PARAMS, "unknown tool"),
        },
        _ => error(id, METHOD_NOT_FOUND, "unknown method"),
    };
    Answer::Json(reply)
}

fn negotiate(client: Option<&str>) -> ProtocolVersion {
    match client {
        Some(v) => SPOKEN
            .iter()
            .find(|sp| sp.as_str() == v)
            .cloned()
            .unwrap_or(ProtocolVersion::V_2025_11_25),
        None => ProtocolVersion::V_2025_11_25,
    }
}

fn answer(id: &Value, result: Value) -> Value {
    json!({ "jsonrpc": "2.0", "id": id, "result": result })
}

fn error(id: &Value, code: i64, message: &str) -> Value {
    json!({ "jsonrpc": "2.0", "id": id, "error": { "code": code, "message": message } })
}

fn to_value(result: &impl Serialize) -> Value {
    serde_json::to_value(result).unwrap_or_else(|_| json!({}))
}

const INVALID_REQUEST: i64 = -32600;
const METHOD_NOT_FOUND: i64 = -32601;
const INVALID_PARAMS: i64 = -32602;

pub fn tool(name: &'static str, description: &'static str, schema: Value) -> Tool {
    Tool::new(name, description, schema.as_object().cloned().unwrap_or_default())
}

fn plain_result(mut result: CallToolResult) -> CallToolResult {
    result.result_type = None;
    result
}

pub fn text(content: impl Into<String>) -> CallToolResult {
    plain_result(CallToolResult::success(vec![ContentBlock::text(content.into())]))
}

pub fn tool_error(message: impl Into<String>) -> CallToolResult {
    plain_result(CallToolResult::error(vec![ContentBlock::text(message.into())]))
}

pub fn structured(value: Value) -> CallToolResult {
    plain_result(CallToolResult::structured(value))
}

#[cfg(test)]
mod tests {
    use super::*;
    use async_trait::async_trait;
    use rmcp::model::{CallToolResult, Tool};
    use serde_json::json;

    struct TestHost;

    #[async_trait]
    impl Host for TestHost {
        fn server_info(&self) -> (&'static str, &'static str) {
            ("test", "0.0.0")
        }

        fn tools(&self) -> Vec<Tool> {
            vec![tool(
                "echo",
                "Answers its text.",
                json!({ "type": "object", "properties": { "text": { "type": "string" } } }),
            )]
        }

        async fn call(&self, name: &str, arguments: Value) -> CallToolResult {
            match name {
                "echo" => text(arguments.get("text").and_then(Value::as_str).unwrap_or("")),
                _ => tool_error("unknown"),
            }
        }
    }

    async fn answer(body: Value) -> Value {
        match serve(&TestHost, &body).await {
            Answer::Json(value) => value,
            Answer::Accepted => panic!("accepted a request"),
        }
    }

    #[tokio::test]
    async fn a_version_the_client_speaks_is_answered_with_it() {
        for (asked, answered) in [
            ("2025-06-18", "2025-06-18"),
            ("2025-11-25", "2025-11-25"),
            ("2025-03-26", "2025-11-25"),
            ("2026-07-28", "2025-11-25"),
            ("1999-01-01", "2025-11-25"),
        ] {
            let reply = answer(json!({
                "jsonrpc": "2.0", "id": 1, "method": "initialize",
                "params": { "protocolVersion": asked, "capabilities": {}, "clientInfo": { "name": "t", "version": "0" } }
            }))
            .await;
            assert_eq!(reply["result"]["protocolVersion"], answered, "asked {asked}");
            assert_eq!(reply["result"]["serverInfo"]["name"], "test");
            assert!(reply["result"]["capabilities"]["tools"].is_object());
        }
        assert!(speaks_version("2025-06-18"));
        assert!(speaks_version("2025-11-25"));
        assert!(!speaks_version("2025-03-26"));
        assert!(!speaks_version("2026-07-28"));
        assert!(!speaks_version("1999-01-01"));
    }

    #[tokio::test]
    async fn a_tool_is_listed_and_run() {
        let listed = answer(json!({ "jsonrpc": "2.0", "id": 1, "method": "tools/list" })).await;
        assert_eq!(listed["result"]["tools"][0]["name"], "echo");

        let called = answer(json!({
            "jsonrpc": "2.0", "id": 2, "method": "tools/call",
            "params": { "name": "echo", "arguments": { "text": "hi" } }
        }))
        .await;
        assert_eq!(called["result"]["content"][0]["text"], "hi");
        assert_eq!(called["result"]["isError"], false);
        assert!(called["result"].get("resultType").is_none());
    }

    #[tokio::test]
    async fn what_the_protocol_refuses_is_refused_in_its_own_words() {
        for (body, code) in [
            (json!({ "jsonrpc": "2.0", "id": 1, "method": "nope" }), METHOD_NOT_FOUND),
            (json!({ "jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": { "name": "nope" } }), INVALID_PARAMS),
            (json!({ "jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": { "name": "echo", "arguments": "not-an-object" } }), INVALID_PARAMS),
            (json!({ "jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": { "name": "echo", "arguments": null } }), INVALID_PARAMS),
            (json!({ "jsonrpc": "2.0", "id": 1, "method": "tools/call" }), INVALID_PARAMS),
            (json!({ "jsonrpc": "2.0", "id": 1 }), INVALID_REQUEST),
            (json!({ "jsonrpc": "2.0", "result": {} }), INVALID_REQUEST),
            (json!({ "jsonrpc": "2.0", "id": 1, "result": {}, "error": { "code": -1, "message": "both" } }), INVALID_REQUEST),
            (json!({ "jsonrpc": "2.0", "id": 1, "method": 42 }), INVALID_REQUEST),
            (json!({ "jsonrpc": "2.0", "id": null, "method": "ping" }), INVALID_REQUEST),
            (json!({ "jsonrpc": "2.0", "id": [1], "method": "ping" }), INVALID_REQUEST),
            (json!({ "id": 1, "method": "ping" }), INVALID_REQUEST),
            (json!([{ "jsonrpc": "2.0", "id": 1, "method": "ping" }]), INVALID_REQUEST),
            (json!("ping"), INVALID_REQUEST),
        ] {
            let reply = answer(body.clone()).await;
            assert_eq!(reply["error"]["code"], code, "{body}");
            assert_eq!(reply["jsonrpc"], "2.0");
        }
    }

    #[tokio::test]
    async fn notifications_and_client_responses_are_accepted() {
        for body in [
            json!({ "jsonrpc": "2.0", "method": "notifications/initialized" }),
            json!({ "jsonrpc": "2.0", "method": "ping" }),
            json!({ "jsonrpc": "2.0", "id": 1, "result": {} }),
            json!({ "jsonrpc": "2.0", "id": 1, "error": { "code": -32600, "message": "x" } }),
        ] {
            assert!(matches!(serve(&TestHost, &body).await, Answer::Accepted), "{body}");
        }
    }
}
