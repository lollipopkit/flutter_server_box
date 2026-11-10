//! Snippet macros FFI (sbm_parser::snippet)
//!
//! The same expansion the monitor agent serves to its panel as
//! `/snippets/plan`, so a `${…}` means one thing in both clients. The
//! context, the steps and a refusal are `sbm_parser::snippet`'s own, mirrored;
//! an absent context value is one the app does not have.

use flutter_rust_bridge::frb;
use sbm_parser::snippet;
pub use sbm_parser::snippet::{PlanError, SnippetContext, Step};

// --- Mirrors -----------------------------------------------------------------

#[frb(mirror(SnippetContext))]
pub struct _SnippetContext {
    pub host: Option<String>,
    pub port: Option<String>,
    pub user: Option<String>,
    pub pwd: Option<String>,
    pub id: Option<String>,
    pub name: Option<String>,
}

#[frb(mirror(Step))]
pub enum _Step {
    Text { text: String },
    Combo { ctrl: bool, alt: bool, key: char, rest: String },
    Sleep { seconds: u64 },
    Enter { times: u32 },
}

#[frb(mirror(PlanError))]
pub enum _PlanError {
    Unanswerable { key: String },
}

// --- Functions ---------------------------------------------------------------

/// What to type
#[frb(sync)]
pub fn snippet_plan(script: String, context: SnippetContext) -> Result<Vec<Step>, PlanError> {
    snippet::plan(&script, &context)
}

/// The script as one command: server placeholders substituted, terminal
/// macros left as written
#[frb(sync)]
pub fn snippet_expand(script: String, context: SnippetContext) -> Result<String, PlanError> {
    snippet::expand(&script, &context)
}

/// Whether the script names anything only a server can answer
#[frb(sync)]
pub fn snippet_uses_server_context(script: String) -> bool {
    snippet::uses_server_context(&script)
}

/// The six `${…}` names a server answers, for the editor's help text
#[frb(sync)]
pub fn snippet_server_keys() -> Vec<String> {
    snippet::SERVER_KEYS.iter().map(|key| key.to_string()).collect()
}
