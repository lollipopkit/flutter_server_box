//! Snippet macros FFI (sbm_parser::snippet)
//!
//! The same expansion the monitor agent serves to its panel as
//! `/snippets/plan`, so a `${…}` means one thing in both clients. The context
//! crosses as `SnippetContext` JSON (an absent key is a value the app does not
//! have), the steps as `Step` JSON, and a refusal as [`SnippetFfiError`].

use sbm_parser::snippet::{self, PlanError, SnippetContext};

/// A script the context cannot answer. `code` is `unanswerable` with the
/// placeholder in `key`, or `malformed` (empty `key`) for JSON the app should
/// never have sent.
#[derive(Debug, Clone)]
pub struct SnippetFfiError {
    pub code: String,
    pub key: String,
}

impl From<PlanError> for SnippetFfiError {
    fn from(error: PlanError) -> Self {
        SnippetFfiError {
            code: error.as_str().to_string(),
            key: error.key().to_string(),
        }
    }
}

fn malformed(_: serde_json::Error) -> SnippetFfiError {
    SnippetFfiError {
        code: "malformed".to_string(),
        key: String::new(),
    }
}

fn context(json: &str) -> Result<SnippetContext, SnippetFfiError> {
    serde_json::from_str(json).map_err(malformed)
}

/// What to type, as `Step` JSON
#[flutter_rust_bridge::frb(sync)]
pub fn snippet_plan(script: String, context_json: String) -> Result<String, SnippetFfiError> {
    let steps = snippet::plan(&script, &context(&context_json)?)?;
    serde_json::to_string(&steps).map_err(malformed)
}

/// The script as one command: server placeholders substituted, terminal
/// macros left as written
#[flutter_rust_bridge::frb(sync)]
pub fn snippet_expand(script: String, context_json: String) -> Result<String, SnippetFfiError> {
    Ok(snippet::expand(&script, &context(&context_json)?)?)
}

/// Whether the script names anything only a server can answer
#[flutter_rust_bridge::frb(sync)]
pub fn snippet_uses_server_context(script: String) -> bool {
    snippet::uses_server_context(&script)
}

/// The six `${…}` names a server answers, for the editor's help text
#[flutter_rust_bridge::frb(sync)]
pub fn snippet_server_keys() -> Vec<String> {
    snippet::SERVER_KEYS.iter().map(|key| key.to_string()).collect()
}
