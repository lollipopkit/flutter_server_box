//! The MCP server core, shared by every ServerBox host that serves one: the
//! monitor behind `/api/v1/mcp` (#1681), the app behind its own embedded
//! server later.
//!
//! **Stateless by design** (`stateful_mode: false`): every request names
//! everything it needs, the protocol carries no session, and [`serve`] turns
//! one JSON-RPC message into one answer. The transport — which HTTP framework,
//! what credential checked first — is the host's; this crate never opens a
//! socket. `rmcp` is used for its model types (`Tool`, results, protocol
//! versions) so the wire stays what the spec says, and nothing else of it.
//!
//! A JSON-RPC envelope is four fields; this dispatches it over `Value`
//! rather than through rmcp's session machinery, which is what a sessionless
//! server wants anyway.

use rmcp::model::{ContentBlock, Implementation, InitializeResult, ListToolsResult, ProtocolVersion, ServerCapabilities};
/// The protocol's own types, re-exported: a host answers in them.
pub use rmcp::model::{CallToolResult, Tool};
use async_trait::async_trait;
use serde::Serialize;
use serde_json::{Value, json};

/// What the host serves: its tools, and what calling one does.
///
/// `call` answers the client whatever happened — the protocol carries a
/// tool's own failure in the result (`isError`), so an error the model can
/// read is an answer, not a transport failure.
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
    /// A notification: nothing to answer, the transport says 202.
    Accepted,
}

/// Turns one JSON-RPC message into one answer. Unknown methods and tools are
/// the protocol's own errors, in the protocol's own words; a body that is
/// not JSON-RPC at all is the transport's to refuse before this.
pub async fn serve(host: &dyn Host, body: &Value) -> Answer {
    let Some(request) = body.as_object() else {
        // A batch was removed from the protocol; an array is not one
        // request, and answering it as a notification would tell the client
        // its request was received.
        return Answer::Json(error(&Value::Null, INVALID_REQUEST, "a request must be an object"));
    };
    if request.get("jsonrpc").and_then(Value::as_str) != Some("2.0") {
        return Answer::Json(error(&Value::Null, INVALID_REQUEST, "jsonrpc must be 2.0"));
    }
    let Some(id) = request.get("id") else {
        // A notification. Nothing here carries state between requests, so
        // there is nothing to be notified of.
        return Answer::Accepted;
    };
    let method = request.get("method").and_then(Value::as_str).unwrap_or("");
    let params = request.get("params").cloned().unwrap_or(Value::Null);
    let reply = match method {
        "initialize" => {
            let client = params.get("protocolVersion").and_then(Value::as_str);
            let (name, version) = host.server_info();
            // The client's version when this speaks it, else the latest:
            // what a client cannot speak it must not be told we do.
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
                let arguments = params.get("arguments").cloned().unwrap_or(json!({}));
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
    // The versions this speaks, newest first: what `initialize` accepts.
    const SPOKEN: [ProtocolVersion; 3] = [
        ProtocolVersion::V_2026_07_28,
        ProtocolVersion::V_2025_11_25,
        ProtocolVersion::V_2025_06_18,
    ];
    match client {
        // The client's, when this speaks it: a version the client cannot
        // speak it must not be told we do.
        Some(v) => SPOKEN.iter().find(|sp| sp.as_str() == v).cloned().unwrap_or(ProtocolVersion::LATEST),
        None => ProtocolVersion::LATEST,
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

/// JSON-RPC's method codes, the ones this answers with.
const INVALID_REQUEST: i64 = -32600;
const METHOD_NOT_FOUND: i64 = -32601;
const INVALID_PARAMS: i64 = -32602;

/// A tool, with its JSON-schema object naming the arguments it takes.
///
/// `Tool::new` takes a `Map` rather than a `Value`, and every tool here
/// describes its arguments as one; this is the one place that conversion is
/// written.
pub fn tool(name: &'static str, description: &'static str, schema: Value) -> Tool {
    Tool::new(name, description, schema.as_object().cloned().unwrap_or_default())
}

/// A tool's text answer, as a host returns it.
pub fn text(content: impl Into<String>) -> CallToolResult {
    CallToolResult::success(vec![ContentBlock::text(content.into())])
}

/// A tool's failure, in the protocol's own way: an answer the model can read.
pub fn tool_error(message: impl Into<String>) -> CallToolResult {
    CallToolResult::error(vec![ContentBlock::text(message.into())])
}

/// A tool's JSON answer.
pub fn structured(value: Value) -> CallToolResult {
    CallToolResult::structured(value)
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
            ("1999-01-01", ProtocolVersion::LATEST.as_str()),
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
    }

    #[tokio::test]
    async fn what_the_protocol_refuses_is_refused_in_its_own_words() {
        for (body, code) in [
            (json!({ "jsonrpc": "2.0", "id": 1, "method": "nope" }), METHOD_NOT_FOUND),
            (json!({ "jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": { "name": "nope" } }), INVALID_PARAMS),
            (json!({ "jsonrpc": "2.0", "id": 1, "method": "tools/call" }), INVALID_PARAMS),
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
    async fn a_notification_is_accepted_without_an_answer() {
        for body in [
            json!({ "jsonrpc": "2.0", "method": "notifications/initialized" }),
            json!({ "jsonrpc": "2.0", "method": "ping" }),
        ] {
            assert!(matches!(serve(&TestHost, &body).await, Answer::Accepted), "{body}");
        }
    }
}
