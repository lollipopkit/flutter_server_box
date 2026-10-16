//! AI agents on a machine: Codex, Claude Code, pi, opencode, Hermes and
//! OpenClaw, installed for the account that runs them (never root), each by
//! its project's own installer, pinned where the installer takes a version.
//!
//! - [`probe_command`] finds each one and its version ([`parse_probe`]).
//! - [`install_script`], [`update_script`], [`uninstall_script`] change one.
//! - [`configure`] points one at a model: the files its own format takes, with
//!   what was there kept (TOML through `toml_edit`, so comments stay), the
//!   key in a file only its account reads, never on a command line.
//! - Hermes and OpenClaw run a gateway: [`gateway_script`].
//!
//! Every script starts with [`PATH_PRELUDE`], so a tool installed into the
//! account's own folders is found without a login shell.

use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Tool {
    Codex,
    #[serde(rename = "claude")]
    ClaudeCode,
    Pi,
    Opencode,
    Hermes,
    Openclaw,
}

impl Tool {
    pub const ALL: [Tool; 6] = [Tool::Codex, Tool::ClaudeCode, Tool::Pi, Tool::Opencode, Tool::Hermes, Tool::Openclaw];

    pub fn id(self) -> &'static str {
        match self {
            Tool::Codex => "codex",
            Tool::ClaudeCode => "claude",
            Tool::Pi => "pi",
            Tool::Opencode => "opencode",
            Tool::Hermes => "hermes",
            Tool::Openclaw => "openclaw",
        }
    }

    pub fn from_id(id: &str) -> Option<Tool> {
        Tool::ALL.into_iter().find(|t| t.id() == id)
    }

    /// The command on the `PATH`.
    pub fn binary(self) -> &'static str {
        self.id()
    }

    /// The release installed, when its installer takes one: at least two
    /// weeks old when chosen. pi's and Hermes' installers take none.
    pub fn pinned(self) -> Option<&'static str> {
        match self {
            Tool::Codex => Some("0.159.3"),
            Tool::ClaudeCode => Some("2.1.288"),
            Tool::Pi | Tool::Hermes => None,
            Tool::Opencode => Some("1.18.34"),
            Tool::Openclaw => Some("2026.9.8"),
        }
    }

    pub fn homepage(self) -> &'static str {
        match self {
            Tool::Codex => "https://github.com/openai/codex",
            Tool::ClaudeCode => "https://code.claude.com",
            Tool::Pi => "https://pi.dev",
            Tool::Opencode => "https://opencode.ai",
            Tool::Hermes => "https://github.com/NousResearch/hermes-agent",
            Tool::Openclaw => "https://openclaw.ai",
        }
    }

    /// It runs a gateway of its own (messaging bridges), as a service of
    /// the account.
    pub fn has_gateway(self) -> bool {
        matches!(self, Tool::Hermes | Tool::Openclaw)
    }

    /// The model APIs it can be pointed at.
    pub fn apis(self) -> &'static [Api] {
        match self {
            Tool::Codex => &[Api::OpenaiResponses],
            Tool::ClaudeCode => &[Api::AnthropicMessages],
            Tool::Pi => &[Api::OpenaiCompletions, Api::OpenaiResponses, Api::AnthropicMessages],
            Tool::Opencode | Tool::Hermes => &[Api::OpenaiCompletions],
            Tool::Openclaw => &[Api::OpenaiCompletions, Api::AnthropicMessages],
        }
    }
}

/// A model API, as Agent mode's providers name them.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Api {
    #[serde(rename = "openai-completions")]
    OpenaiCompletions,
    #[serde(rename = "openai-responses")]
    OpenaiResponses,
    #[serde(rename = "anthropic-messages")]
    AnthropicMessages,
}

impl Api {
    pub fn from_id(id: &str) -> Option<Api> {
        serde_json::from_value(Value::String(id.into())).ok()
    }
}

/// Where the account's own tools land, ahead of the rest.
pub const PATH_PRELUDE: &str =
    r#"PATH="$HOME/.local/bin:$HOME/bin:$HOME/.opencode/bin:$HOME/.openclaw/bin:$HOME/.npm-global/bin:$PATH"; export PATH"#;

const MARK: &str = "--sbm-agent--";

/// Each tool's path and `--version` output, one block each.
pub fn probe_command() -> String {
    let mut s = format!("{PATH_PRELUDE}\n");
    for t in Tool::ALL {
        let b = t.binary();
        s.push_str(&format!(
            "echo '{MARK} {id}'\nif p=$(command -v {b} 2>/dev/null); then echo \"path=$p\"; {b} --version </dev/null 2>&1 | head -n 3; fi\n",
            id = t.id()
        ));
    }
    s.push_str("true");
    s
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Installed {
    pub tool: Tool,
    pub path: Option<String>,
    pub version: Option<String>,
}

/// [`probe_command`]'s output, every tool in [`Tool::ALL`]'s order.
pub fn parse_probe(out: &str) -> Vec<Installed> {
    let mut found: Vec<Installed> = Tool::ALL.iter().map(|t| Installed { tool: *t, path: None, version: None }).collect();
    let mut current: Option<usize> = None;
    for line in out.lines() {
        if let Some(id) = line.strip_prefix(MARK).map(str::trim) {
            current = Tool::ALL.iter().position(|t| t.id() == id);
            continue;
        }
        let Some(i) = current else { continue };
        if let Some(p) = line.strip_prefix("path=") {
            found[i].path = Some(p.trim().to_string());
        } else if found[i].version.is_none() {
            found[i].version = version_in(line);
        }
    }
    found
}

/// The first version-looking word: `0.159.3`, `v0.21.5`, `2026.9.8`.
fn version_in(line: &str) -> Option<String> {
    line.split(|c: char| c.is_whitespace() || c == '(' || c == ')' || c == ',')
        .map(|w| w.trim_start_matches('v'))
        .find(|w| {
            let parts: Vec<&str> = w.split('.').collect();
            parts.len() >= 2 && parts.iter().all(|p| !p.is_empty() && p.chars().next().is_some_and(|c| c.is_ascii_digit()))
        })
        .map(str::to_string)
}

/// Installs [tool] with its project's installer, for this account.
pub fn install_script(tool: Tool) -> String {
    let body = match tool {
        Tool::Codex => format!("curl -fsSL https://chatgpt.com/codex/install.sh | sh -s -- --release {}", tool.pinned().unwrap_or_default()),
        Tool::ClaudeCode => format!("curl -fsSL https://claude.ai/install.sh | bash -s {}", tool.pinned().unwrap_or_default()),
        Tool::Pi => "curl -fsSL https://pi.dev/install.sh | sh".to_string(),
        Tool::Opencode => format!("curl -fsSL https://opencode.ai/install | bash -s -- --version {}", tool.pinned().unwrap_or_default()),
        Tool::Hermes => "curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --non-interactive --skip-browser --skip-computer-use".to_string(),
        Tool::Openclaw => format!("curl -fsSL https://openclaw.ai/install-cli.sh | bash -s -- --version {} --no-onboard", tool.pinned().unwrap_or_default()),
    };
    format!("set -e\n{PATH_PRELUDE}\n{body}\n{} --version </dev/null", tool.binary())
}

/// Updates [tool] with its own command.
pub fn update_script(tool: Tool) -> String {
    let body = match tool {
        Tool::Codex => "codex update",
        Tool::ClaudeCode => "claude update",
        Tool::Pi => "pi update",
        Tool::Opencode => "opencode upgrade",
        Tool::Hermes => "hermes update",
        Tool::Openclaw => "openclaw update --yes",
    };
    format!("set -e\n{PATH_PRELUDE}\n{body} </dev/null\n{} --version </dev/null", tool.binary())
}

/// Removes [tool]; with [purge] its configuration, sessions and data too.
pub fn uninstall_script(tool: Tool, purge: bool) -> String {
    let body = match (tool, purge) {
        (Tool::Codex, false) => r#"rm -f "$HOME/.local/bin/codex"; rm -rf "$HOME/.codex/packages/standalone""#.to_string(),
        (Tool::Codex, true) => r#"rm -f "$HOME/.local/bin/codex"; rm -rf "$HOME/.codex""#.to_string(),
        (Tool::ClaudeCode, false) => r#"rm -f "$HOME/.local/bin/claude"; rm -rf "$HOME/.local/share/claude""#.to_string(),
        (Tool::ClaudeCode, true) => r#"rm -f "$HOME/.local/bin/claude"; rm -rf "$HOME/.local/share/claude" "$HOME/.claude" "$HOME/.claude.json""#.to_string(),
        // The installer's own removal asks on a terminal.
        (Tool::Pi, purge) => format!(
            r#"p=$(command -v pi || true); case "$p" in "$HOME"/*) rm -f "$p";; esac; rm -rf "$HOME/.pi/agent/install"{}"#,
            if purge { r#" "$HOME/.pi""# } else { "" }
        ),
        // Its own removal takes the data with it and leaves the binary: the
        // binary alone, unless the data goes too.
        (Tool::Opencode, purge) => format!(
            r#"{}p=$(command -v opencode || true); case "$p" in "$HOME"/*) rm -f "$p"; rmdir "$(dirname "$p")" 2>/dev/null;; esac"#,
            if purge { "opencode uninstall -f </dev/null; " } else { "" }
        ),
        (Tool::Hermes, false) => "hermes uninstall --yes </dev/null".to_string(),
        // `--full` takes the configuration and data too (`--data` alone, the
        // data and not the program).
        (Tool::Hermes, true) => "hermes uninstall --full --yes </dev/null".to_string(),
        // Its installer keeps the program in `~/.openclaw/{bin,tools}` beside
        // the state; its own removal refuses a home it does not call the
        // account's, so the service goes by its command and the rest here.
        (Tool::Openclaw, purge) => format!(
            r#"openclaw gateway uninstall </dev/null 2>&1 || true; rm -rf {}"#,
            if purge { r#""$HOME/.openclaw""# } else { r#""$HOME/.openclaw/bin" "$HOME/.openclaw/tools""# }
        ),
    };
    // Gone is the copy found first: another one elsewhere on the `PATH` (a
    // system package, another account's prefix) is not this install's.
    format!("{PATH_PRELUDE}\nwas=$(command -v {b} || true)\n{body}\n[ -z \"$was\" ] || [ ! -e \"$was\" ]", b = tool.binary())
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum GatewayAction {
    Status,
    Install,
    Start,
    Stop,
}

/// [tool]'s gateway, through its own command; `None` for a tool with none.
pub fn gateway_script(tool: Tool, action: GatewayAction) -> Option<String> {
    if !tool.has_gateway() {
        return None;
    }
    let verb = match action {
        GatewayAction::Status => "status",
        GatewayAction::Install => "install",
        GatewayAction::Start => "start",
        GatewayAction::Stop => "stop",
    };
    Some(format!("{PATH_PRELUDE}\n{} gateway {verb} </dev/null 2>&1", tool.binary()))
}

// ---------------------------------------------------------------------------
// Pointing a tool at a model

/// The model a tool is pointed at.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Target {
    /// Up to `/v1` for the OpenAI APIs; the API's own root for Anthropic's.
    pub base_url: String,
    pub api: Api,
    pub key: String,
    pub model: String,
}

/// The provider's name in every tool's configuration.
pub const PROVIDER: &str = "serverbox";
/// The env name Hermes reads the key from (its `.env`).
pub const HERMES_KEY_ENV: &str = "SERVERBOX_API_KEY";

/// A file under the account's home to write, mode 0600.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Write {
    /// Relative to the home directory.
    pub path: &'static str,
    pub content: String,
}

/// What pointing [tool] at a model reads first: the files [`configure`]
/// merges into, relative to the home directory.
pub fn config_files(tool: Tool) -> &'static [&'static str] {
    match tool {
        Tool::Codex => &[".codex/config.toml"],
        Tool::ClaudeCode => &[".claude/settings.json"],
        Tool::Pi => &[".pi/agent/models.json", ".pi/agent/settings.json"],
        Tool::Opencode => &[".config/opencode/opencode.json"],
        Tool::Hermes => &[".hermes/.env"],
        Tool::Openclaw => &[],
    }
}

/// Why [`configure`] refused: codes a client words.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase", tag = "error")]
pub enum ConfigureError {
    /// The tool cannot speak the target's API.
    WrongApi,
    /// A field a config file cannot carry (a line break, a quote in a URL).
    Invalid,
    /// A file there does not parse (comments in opencode's JSON); left alone.
    Unreadable { path: String },
}

/// The files to write and the commands to run (after them, the key in none
/// of them) to point [tool] at [target]; [existing] holds the current text
/// of each of [`config_files`], or `None` when it is not there.
pub fn configure(tool: Tool, target: &Target, existing: &[Option<String>]) -> Result<(Vec<Write>, Vec<String>), ConfigureError> {
    if !tool.apis().contains(&target.api) {
        return Err(ConfigureError::WrongApi);
    }
    let plain = |s: &str| !s.is_empty() && s.len() <= 2048 && !s.chars().any(|c| c.is_control() || c == '"' || c == '\'' || c == '\\');
    if !plain(&target.base_url) || !(target.base_url.starts_with("http://") || target.base_url.starts_with("https://")) || !plain(&target.model) {
        return Err(ConfigureError::Invalid);
    }
    if target.key.len() > 8192 || target.key.chars().any(char::is_control) {
        return Err(ConfigureError::Invalid);
    }
    let text = |i: usize| existing.get(i).cloned().flatten();
    let json_of = |i: usize| -> Result<serde_json::Map<String, Value>, ConfigureError> {
        match text(i) {
            None => Ok(serde_json::Map::new()),
            Some(t) if t.trim().is_empty() => Ok(serde_json::Map::new()),
            Some(t) => match serde_json::from_str::<Value>(&t) {
                Ok(Value::Object(m)) => Ok(m),
                _ => Err(ConfigureError::Unreadable { path: config_files(tool)[i].to_string() }),
            },
        }
    };
    let pretty = |m: serde_json::Map<String, Value>| serde_json::to_string_pretty(&Value::Object(m)).unwrap_or_default() + "\n";
    let t = target;
    match tool {
        Tool::Codex => {
            let mut doc: toml_edit::DocumentMut = text(0)
                .unwrap_or_default()
                .parse()
                .map_err(|_| ConfigureError::Unreadable { path: config_files(tool)[0].to_string() })?;
            doc["model"] = toml_edit::value(&t.model);
            doc["model_provider"] = toml_edit::value(PROVIDER);
            if !doc.contains_table("model_providers") {
                let mut providers = toml_edit::Table::new();
                providers.set_implicit(true);
                doc["model_providers"] = toml_edit::Item::Table(providers);
            }
            let mut p = toml_edit::Table::new();
            p["name"] = toml_edit::value("ServerBox");
            p["base_url"] = toml_edit::value(&t.base_url);
            p["experimental_bearer_token"] = toml_edit::value(&t.key);
            p["wire_api"] = toml_edit::value("responses");
            doc["model_providers"][PROVIDER] = toml_edit::Item::Table(p);
            Ok((vec![Write { path: ".codex/config.toml", content: doc.to_string() }], vec![]))
        }
        Tool::ClaudeCode => {
            let mut m = json_of(0)?;
            let env = m.entry("env").or_insert_with(|| json!({}));
            if !env.is_object() {
                *env = json!({});
            }
            let env = env.as_object_mut().expect("an object");
            env.insert("ANTHROPIC_BASE_URL".into(), json!(t.base_url.trim_end_matches('/').trim_end_matches("/v1")));
            env.insert("ANTHROPIC_AUTH_TOKEN".into(), json!(t.key));
            env.insert("ANTHROPIC_MODEL".into(), json!(t.model));
            Ok((vec![Write { path: ".claude/settings.json", content: pretty(m) }], vec![]))
        }
        Tool::Pi => {
            let mut models = json_of(0)?;
            let providers = models.entry("providers").or_insert_with(|| json!({}));
            if !providers.is_object() {
                *providers = json!({});
            }
            let api = serde_json::to_value(t.api).unwrap_or_default();
            providers.as_object_mut().expect("an object").insert(
                PROVIDER.into(),
                json!({ "baseUrl": t.base_url, "api": api, "apiKey": t.key, "models": [{ "id": t.model }] }),
            );
            let mut settings = json_of(1)?;
            settings.insert("defaultProvider".into(), json!(PROVIDER));
            settings.insert("defaultModel".into(), json!(t.model));
            Ok((
                vec![
                    Write { path: ".pi/agent/models.json", content: pretty(models) },
                    Write { path: ".pi/agent/settings.json", content: pretty(settings) },
                ],
                vec![],
            ))
        }
        Tool::Opencode => {
            let mut m = json_of(0)?;
            m.entry("$schema").or_insert_with(|| json!("https://opencode.ai/config.json"));
            m.insert("model".into(), json!(format!("{PROVIDER}/{}", t.model)));
            let providers = m.entry("provider").or_insert_with(|| json!({}));
            if !providers.is_object() {
                *providers = json!({});
            }
            providers.as_object_mut().expect("an object").insert(
                PROVIDER.into(),
                json!({
                    "npm": "@ai-sdk/openai-compatible",
                    "name": "ServerBox",
                    "options": { "baseURL": t.base_url, "apiKey": t.key },
                    "models": { t.model.clone(): {} },
                }),
            );
            Ok((vec![Write { path: ".config/opencode/opencode.json", content: pretty(m) }], vec![]))
        }
        Tool::Hermes => {
            // The key in its .env; the rest through its own command, which
            // knows where each setting goes.
            let env = set_env_line(&text(0).unwrap_or_default(), HERMES_KEY_ENV, &t.key);
            let set = |k: &str, v: &str| format!("{PATH_PRELUDE}\nhermes config set {k} '{v}' </dev/null");
            Ok((
                vec![Write { path: ".hermes/.env", content: env }],
                vec![
                    set("model.provider", "custom"),
                    set("model.base_url", &t.base_url),
                    set("model.default", &t.model),
                    set("model.key_env", HERMES_KEY_ENV),
                ],
            ))
        }
        Tool::Openclaw => {
            let api = serde_json::to_value(t.api).unwrap_or_default();
            let patch = json!({
                "agents": { "defaults": { "model": { "primary": format!("{PROVIDER}/{}", t.model) } } },
                "models": { "mode": "merge", "providers": { PROVIDER: {
                    "baseUrl": t.base_url, "apiKey": t.key, "api": api,
                    "models": [{ "id": t.model, "name": t.model, "input": ["text"], "contextWindow": 32768, "maxTokens": 8192 }],
                } } },
            });
            // Run with its gateway stopped ([`OPENCLAW_STATUS`] says whether
            // it runs; the caller stops and starts it around this).
            let apply = format!(
                r#"{PATH_PRELUDE}
openclaw config patch --file "$HOME/{OPENCLAW_PATCH}" </dev/null
status=$?
rm -f "$HOME/{OPENCLAW_PATCH}"
exit $status"#
            );
            Ok((vec![Write { path: OPENCLAW_PATCH, content: serde_json::to_string_pretty(&patch).unwrap_or_default() }], vec![apply]))
        }
    }
}

/// OpenClaw's gateway, as JSON: [`openclaw_gateway_running`] reads it. Its
/// configuration changes only while the gateway is stopped.
pub const OPENCLAW_STATUS: &str = "PATH=\"$HOME/.openclaw/bin:$HOME/.local/bin:$PATH\" openclaw gateway status --json </dev/null";

/// Whether [`OPENCLAW_STATUS`]'s answer says the gateway runs (its exit
/// code does not: 0 either way).
pub fn openclaw_gateway_running(json: &str) -> bool {
    serde_json::from_str::<Value>(json).is_ok_and(|v| v["service"]["runtime"]["status"] == "running" || v["rpc"]["ok"] == true)
}

/// Where the patch for OpenClaw waits (0600) until its command reads it.
const OPENCLAW_PATCH: &str = ".openclaw/serverbox.patch.json";

/// [text] (an env file) with `NAME='value'` set, other lines kept.
fn set_env_line(text: &str, name: &str, value: &str) -> String {
    let line = format!("{name}='{}'", value.replace('\'', r"'\''"));
    let mut out: Vec<String> = text.lines().filter(|l| !l.trim_start().starts_with(&format!("{name}="))).map(str::to_string).collect();
    out.push(line);
    out.join("\n") + "\n"
}

#[cfg(test)]
mod tests {
    use super::*;

    fn target(api: Api) -> Target {
        Target { base_url: "http://127.0.0.1:11434/v1".into(), api, key: "sk-local".into(), model: "qwen3:0.6b".into() }
    }

    #[test]
    fn reads_what_is_installed() {
        let out = format!(
            "{MARK} codex\npath=/home/a/.local/bin/codex\ncodex-cli 0.159.3\n{MARK} claude\npath=/home/a/.local/bin/claude\n2.1.288 (Claude Code)\n{MARK} pi\n{MARK} opencode\npath=/x/opencode\n1.18.34\n{MARK} hermes\npath=/x/hermes\nHermes Agent v0.21.5 (2026.9.24)\nInstall directory: /x\n{MARK} openclaw\npath=/x/openclaw\nOpenClaw 2026.9.8 (abc123)\n"
        );
        let found = parse_probe(&out);
        let v: Vec<(Tool, Option<&str>)> = found.iter().map(|f| (f.tool, f.version.as_deref())).collect();
        assert_eq!(
            v,
            [
                (Tool::Codex, Some("0.159.3")),
                (Tool::ClaudeCode, Some("2.1.288")),
                (Tool::Pi, None),
                (Tool::Opencode, Some("1.18.34")),
                (Tool::Hermes, Some("0.21.5")),
                (Tool::Openclaw, Some("2026.9.8")),
            ]
        );
        assert!(found[2].path.is_none());
        assert!(probe_command().starts_with(PATH_PRELUDE));
    }

    #[test]
    fn installs_pinned_where_it_can() {
        assert!(install_script(Tool::Codex).contains("--release 0.159.3"));
        assert!(install_script(Tool::ClaudeCode).contains("bash -s 2.1.288"));
        assert!(install_script(Tool::Openclaw).contains("--version 2026.9.8 --no-onboard"));
        assert!(install_script(Tool::Hermes).contains("--non-interactive"));
        assert!(Tool::ALL.iter().all(|t| !install_script(*t).contains("sudo")));
        // Removal ends by checking it is gone; data stays unless asked.
        assert!(uninstall_script(Tool::Codex, false).ends_with(r#"[ -z "$was" ] || [ ! -e "$was" ]"#));
        assert!(!uninstall_script(Tool::ClaudeCode, false).contains(".claude.json"));
        assert!(uninstall_script(Tool::ClaudeCode, true).contains(".claude.json"));
        assert!(!uninstall_script(Tool::Opencode, false).contains("opencode uninstall"), "it would take the data");
        assert!(gateway_script(Tool::Pi, GatewayAction::Status).is_none());
        assert!(gateway_script(Tool::Openclaw, GatewayAction::Stop).unwrap().contains("openclaw gateway stop"));
    }

    #[test]
    fn codex_keeps_what_was_there() {
        let before = "# mine\nmodel = \"gpt-5\"\n\n[model_providers.other]\nname = \"other\"\n";
        let (w, cmds) = configure(Tool::Codex, &target(Api::OpenaiResponses), &[Some(before.into())]).unwrap();
        assert!(cmds.is_empty());
        let after = &w[0].content;
        assert!(after.contains("# mine"), "{after}");
        assert!(after.contains("[model_providers.other]"), "{after}");
        let parsed: toml_edit::DocumentMut = after.parse().unwrap();
        assert_eq!(parsed["model"].as_str(), Some("qwen3:0.6b"));
        assert_eq!(parsed["model_provider"].as_str(), Some(PROVIDER));
        assert_eq!(parsed["model_providers"][PROVIDER]["wire_api"].as_str(), Some("responses"));
        assert_eq!(parsed["model_providers"][PROVIDER]["base_url"].as_str(), Some("http://127.0.0.1:11434/v1"));
        // Codex speaks Responses alone.
        assert_eq!(configure(Tool::Codex, &target(Api::OpenaiCompletions), &[None]), Err(ConfigureError::WrongApi));
    }

    #[test]
    fn claude_code_takes_the_api_root() {
        let before = r#"{"permissions":{"allow":["Bash(ls)"]},"env":{"FOO":"1"}}"#;
        let (w, _) = configure(Tool::ClaudeCode, &target(Api::AnthropicMessages), &[Some(before.into())]).unwrap();
        let v: Value = serde_json::from_str(&w[0].content).unwrap();
        assert_eq!(v["env"]["ANTHROPIC_BASE_URL"], "http://127.0.0.1:11434");
        assert_eq!(v["env"]["FOO"], "1");
        assert_eq!(v["permissions"]["allow"][0], "Bash(ls)");
    }

    #[test]
    fn pi_opencode_hermes_and_openclaw() {
        let (w, _) = configure(Tool::Pi, &target(Api::OpenaiCompletions), &[None, Some(r#"{"theme":"dark"}"#.into())]).unwrap();
        let models: Value = serde_json::from_str(&w[0].content).unwrap();
        assert_eq!(models["providers"][PROVIDER]["api"], "openai-completions");
        let settings: Value = serde_json::from_str(&w[1].content).unwrap();
        assert_eq!((settings["theme"].as_str(), settings["defaultModel"].as_str()), (Some("dark"), Some("qwen3:0.6b")));

        let (w, _) = configure(Tool::Opencode, &target(Api::OpenaiCompletions), &[None]).unwrap();
        let v: Value = serde_json::from_str(&w[0].content).unwrap();
        assert_eq!(v["model"], "serverbox/qwen3:0.6b");
        assert_eq!(v["provider"][PROVIDER]["options"]["baseURL"], "http://127.0.0.1:11434/v1");
        // A JSONC file with comments is not rewritten.
        let jsonc = Some("{ // mine\n}".to_string());
        assert!(matches!(configure(Tool::Opencode, &target(Api::OpenaiCompletions), &[jsonc]), Err(ConfigureError::Unreadable { .. })));

        let (w, cmds) = configure(Tool::Hermes, &target(Api::OpenaiCompletions), &[Some("OTHER=1\nSERVERBOX_API_KEY='old'\n".into())]).unwrap();
        assert_eq!(w[0].content, "OTHER=1\nSERVERBOX_API_KEY='sk-local'\n");
        assert!(cmds.iter().all(|c| !c.contains("sk-local")), "the key stays off the command line");
        assert!(cmds.iter().any(|c| c.contains("hermes config set model.base_url 'http://127.0.0.1:11434/v1'")));

        let (w, cmds) = configure(Tool::Openclaw, &target(Api::OpenaiCompletions), &[]).unwrap();
        let patch: Value = serde_json::from_str(&w[0].content).unwrap();
        assert_eq!(patch["models"]["providers"][PROVIDER]["apiKey"], "sk-local");
        assert!(!cmds[0].contains("sk-local") && cmds[0].contains("config patch --file"));
        assert!(!openclaw_gateway_running(r#"{"service":{"runtime":{"status":"stopped"}},"rpc":{"ok":false}}"#));
        assert!(openclaw_gateway_running(r#"{"service":{"runtime":{"status":"running"}},"rpc":{"ok":true}}"#));
        assert!(!openclaw_gateway_running("not json"));
    }

    #[test]
    fn refuses_what_a_file_cannot_carry() {
        let mut t = target(Api::OpenaiCompletions);
        t.base_url = "http://x/v1'; rm -rf ~".into();
        assert_eq!(configure(Tool::Hermes, &t, &[None]), Err(ConfigureError::Invalid));
        let mut t = target(Api::OpenaiCompletions);
        t.model = "a\nb".into();
        assert_eq!(configure(Tool::Pi, &t, &[None]), Err(ConfigureError::Invalid));
        let mut t = target(Api::OpenaiCompletions);
        t.base_url = "file:///etc".into();
        assert_eq!(configure(Tool::Pi, &t, &[None]), Err(ConfigureError::Invalid));
    }
}
