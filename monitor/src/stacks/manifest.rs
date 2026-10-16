//! The web app manifest: `store/apps/<id>/manifest.toml` (`<id>` is
//! `<publisher>.<name>`, `core::app_id`), a web service the
//! agent deploys with Docker Compose and the desk shows in a window.
//!
//! The format is published as `docs/schemas/monitor-app.schema.json` (for
//! editors and the `serverbox-webapp` skill's validator); this module is what
//! the agent itself reads and checks, and the two must agree. A manifest
//! describes:
//!
//! - what the service is (names, licence, requirements),
//! - its compose files (beside the manifest, copied into the stack's
//!   directory),
//! - the env file those files read: fixed values, generated secrets, the
//!   values of the settings the deploy dialog asks for, and what the agent
//!   says of the machine ([`RESERVED`]),
//! - how the admin signs in the first time ([`Login`]).
//!
//! [`Package::read`] checks a whole folder: the manifest, its files, and that
//! every variable a compose file needs is one the env file sets.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};
use std::sync::LazyLock;

use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::ports::PortProtocol;
use crate::core::app_id;

pub const SCHEMA: u32 = 1;
/// One file of a package, and all of them together.
const MAX_FILE_BYTES: usize = 256 << 10;
const MAX_PACKAGE_BYTES: usize = 1 << 20;
const MAX_FILES: usize = 32;
/// How far past a taken default port the next free one is looked for.
const PORT_SEARCH: u16 = 100;

const TONES: &[&str] = &["berry", "soft", "ink", "sky", "teal", "violet", "amber", "leaf", "pale", "bright", "mist"];
const CATEGORIES: &[&str] = &[
    "photos", "media", "files", "documents", "productivity", "development", "ai", "home", "network", "monitoring",
    "security", "tools",
];

/// Env names the agent writes for every app, from the machine: the owner of
/// the shared folder (`{shared}`), the host's time zone, and the group that
/// may use the GPU (`/dev/dri/renderD128`'s, else `SBM_GID`) for a service
/// that is not root to `group_add`. A manifest uses them and never sets them.
pub const RESERVED: &[&str] = &["SBM_UID", "SBM_GID", "SBM_TZ", "SBM_RENDER_GID"];

pub type Text = BTreeMap<String, String>;
pub type EnvMap = BTreeMap<String, String>;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Notice {
    PullsImages,
    /// Builds an image on the machine from a Dockerfile in the package.
    BuildsImages,
    BindsPaths,
    MountsHostFiles,
    GpuDevices,
    PublishesPort,
    Privileged,
    HostNetwork,
    DockerSocket,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Manifest {
    pub schema: u32,
    /// Who makes the service and the entry's name; the id is
    /// `<publisher>.<name>` (`futo.immich`), never written in the file.
    pub publisher: String,
    pub name: String,
    #[serde(skip_deserializing)]
    pub id: String,
    /// The project's own name (`Immich`), shown as it.
    pub project: String,
    pub version: String,
    pub homepage: String,
    pub source: String,
    /// Who makes the service (`Immich (FUTO)`), shown before deploying.
    #[serde(default)]
    pub developer: Option<String>,
    pub glyph: String,
    pub tone: String,
    #[serde(default)]
    pub categories: Vec<String>,
    /// Recommended to someone who has just installed the agent: listed by
    /// the desk's first-run guide.
    #[serde(default)]
    pub recommended: bool,
    #[serde(default)]
    pub notices: Vec<Notice>,
    pub title: Text,
    pub description: Text,
    pub license: License,
    #[serde(default)]
    pub requirements: Requirements,
    pub compose: Compose,
    pub web: Web,
    #[serde(default)]
    pub env: EnvMap,
    #[serde(default)]
    pub secrets: Vec<Secret>,
    #[serde(default)]
    pub settings: Vec<Setting>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub login: Option<Login>,
}

/// How the admin signs in the first time, shown in the app's details: the
/// account the service is seeded with, its password (a secret, shown only
/// when asked for), and what else to know.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Login {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub user: Option<String>,
    /// The env name of the `[[secrets]]` entry holding the password.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub password: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub note: Option<Text>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct License {
    pub spdx: String,
    pub url: String,
    #[serde(default)]
    pub accept: bool,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Requirements {
    pub memory_min_mib: Option<u64>,
    pub memory_recommended_mib: Option<u64>,
    pub cores_min: Option<u32>,
    #[serde(default)]
    pub arch: Vec<String>,
    #[serde(default)]
    pub os: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Compose {
    pub files: Vec<String>,
    /// Services that run once and exit (a migration): exited with 0 they are
    /// done, not down (`health`).
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub jobs: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Web {
    /// The key of the `port` setting the window reaches.
    pub port: String,
    #[serde(default = "root")]
    pub path: String,
    /// The service asks for HTTP basic auth, which a browser cannot answer
    /// inside the desk's frame: the proxy sends `[login]`'s user and
    /// password itself (a request carrying its own `Authorization` keeps it).
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub basic_auth: bool,
}

fn root() -> String {
    "/".into()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Secret {
    pub env: String,
    #[serde(default = "secret_length")]
    pub length: usize,
}

fn secret_length() -> usize {
    32
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "lowercase", deny_unknown_fields)]
pub enum Setting {
    Path {
        key: String,
        label: Text,
        #[serde(default)]
        help: Option<Text>,
        env: String,
        /// Absolute, or under `{stack}` or `{shared}`.
        default: String,
        #[serde(default)]
        data: bool,
    },
    Port {
        key: String,
        label: Text,
        #[serde(default)]
        help: Option<Text>,
        env: String,
        default: u16,
        #[serde(default)]
        protocol: Protocol,
    },
    Bool {
        key: String,
        label: Text,
        #[serde(default)]
        help: Option<Text>,
        default: bool,
        on: EnvMap,
        off: EnvMap,
    },
    Choice {
        key: String,
        label: Text,
        #[serde(default)]
        help: Option<Text>,
        default: String,
        options: Vec<ChoiceOption>,
    },
    Text {
        key: String,
        label: Text,
        #[serde(default)]
        help: Option<Text>,
        env: String,
        #[serde(default)]
        default: Option<String>,
        #[serde(default)]
        optional: bool,
        pattern: String,
    },
}

/// What a port setting's port is published for.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Protocol {
    #[default]
    Tcp,
    Udp,
    Both,
}

impl Protocol {
    fn transports(self) -> &'static [PortProtocol] {
        match self {
            Self::Tcp => &[PortProtocol::Tcp],
            Self::Udp => &[PortProtocol::Udp],
            Self::Both => &[PortProtocol::Tcp, PortProtocol::Udp],
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ChoiceOption {
    pub value: String,
    pub label: Text,
    pub env: EnvMap,
    #[serde(default)]
    pub suggest: Option<Suggest>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Suggest {
    pub gpu: Option<String>,
    pub wsl: Option<bool>,
}

impl Setting {
    pub fn key(&self) -> &str {
        match self {
            Self::Path { key, .. }
            | Self::Port { key, .. }
            | Self::Bool { key, .. }
            | Self::Choice { key, .. }
            | Self::Text { key, .. } => key,
        }
    }

    fn label(&self) -> &Text {
        match self {
            Self::Path { label, .. }
            | Self::Port { label, .. }
            | Self::Bool { label, .. }
            | Self::Choice { label, .. }
            | Self::Text { label, .. } => label,
        }
    }

    fn help(&self) -> Option<&Text> {
        match self {
            Self::Path { help, .. }
            | Self::Port { help, .. }
            | Self::Bool { help, .. }
            | Self::Choice { help, .. }
            | Self::Text { help, .. } => help.as_ref(),
        }
    }

    /// Every env name the setting can write.
    fn env_names(&self) -> BTreeSet<&str> {
        match self {
            Self::Path { env, .. } | Self::Port { env, .. } | Self::Text { env, .. } => BTreeSet::from([env.as_str()]),
            Self::Bool { on, off, .. } => on.keys().chain(off.keys()).map(String::as_str).collect(),
            Self::Choice { options, .. } => options.iter().flat_map(|o| o.env.keys()).map(String::as_str).collect(),
        }
    }
}

/// What a package or a manifest got wrong: where, and what.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Problem {
    pub at: String,
    pub message: String,
}

fn problem(at: impl Into<String>, message: impl Into<String>) -> Problem {
    Problem { at: at.into(), message: message.into() }
}

static KEY: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^[a-z][a-z0-9_]{0,31}$").expect("regex"));
static ENV_NAME: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^[A-Z_][A-Z0-9_]{0,63}$").expect("regex"));
static FILE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$").expect("regex"));
static GLYPH: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^[a-z0-9_]{1,64}$").expect("regex"));
static LOCALE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^[a-z]{2,3}(-[A-Za-z0-9]{2,8})*$").expect("regex"));
static OPTION_VALUE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^[A-Za-z0-9._-]{1,64}$").expect("regex"));
/// `${NAME…}` and `$NAME` in a compose file; `$$` is a literal `$` and is
/// taken out first. The operator says whether a value is needed: `:-`/`-`
/// and `:+`/`+` carry their own.
static VARIABLE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(:?[-+?])?|\$([A-Za-z_][A-Za-z0-9_]*)").expect("regex")
});

/// The name a built image (`build:`) must have: `localhost/` is never a
/// registry anyone pulls from, so the image is told apart from those pulled.
pub const BUILT_PREFIX: &str = "localhost/";

/// A `key: value` line of a compose file, the value unquoted; comments and
/// blank lines are not.
fn yaml_entry(line: &str) -> Option<(&str, &str)> {
    let line = match line.find(" #") {
        Some(at) => &line[..at],
        None => line,
    };
    let line = line.trim_start().trim_start_matches("- ");
    if line.starts_with('#') {
        return None;
    }
    let (key, value) = line.split_once(':')?;
    let key = key.trim().trim_matches(['\'', '"']);
    (!key.is_empty() && !key.contains(char::is_whitespace)).then(|| (key, value.trim().trim_matches(['\'', '"'])))
}

/// What a compose file builds: the Dockerfiles its `build:` sections name.
/// A build runs in the stack's folder (`context: .`, where the agent's
/// `.dockerignore` keeps the env file out) from a Dockerfile of the package;
/// `additional_contexts` would hand it any folder of the host, and the short
/// form or `dockerfile_inline` would leave the package unread.
fn compose_builds(file: &str, compose: &str, texts: &BTreeMap<String, String>, problems: &mut Vec<Problem>) -> Vec<String> {
    let (mut builds, mut dockerfiles) = (0, Vec::new());
    for line in compose.lines() {
        let Some((key, value)) = yaml_entry(line) else { continue };
        match key {
            "build" if value.is_empty() => builds += 1,
            "build" => problems.push(problem(file, "build: a mapping with `dockerfile:`")),
            "context" if value != "." && value != "./" => problems.push(problem(file, "build context: only `.`")),
            "dockerfile" => {
                if !texts.contains_key(value) || value == "manifest.toml" {
                    problems.push(problem(file, format!("dockerfile {value} is not in the package")));
                }
                dockerfiles.push(value.to_string());
            }
            "additional_contexts" | "dockerfile_inline" => problems.push(problem(file, format!("build: no `{key}`"))),
            _ => {}
        }
    }
    if builds != dockerfiles.len() {
        problems.push(problem(file, "every build: names its dockerfile"));
    }
    dockerfiles
}

/// The images a Dockerfile starts from (`FROM`), its stages and `scratch`
/// left out, `${ARG}` read from the `ARG` defaults before it; heredoc bodies
/// (`COPY <<EOF`) are not instructions.
pub fn base_images(dockerfile: &str) -> Vec<String> {
    let (mut images, mut stages, mut args) = (Vec::new(), BTreeSet::new(), BTreeMap::new());
    let mut heredoc: Option<String> = None;
    for line in dockerfile.lines() {
        let trimmed = line.trim();
        if let Some(end) = &heredoc {
            if trimmed == end {
                heredoc = None;
            }
            continue;
        }
        if let Some(at) = trimmed.find("<<") {
            let marker = trimmed[at + 2..].trim_start_matches('-').trim_matches(['\'', '"']);
            let marker: String = marker.chars().take_while(|c| c.is_ascii_alphanumeric() || *c == '_').collect();
            if !marker.is_empty() {
                heredoc = Some(marker);
            }
        }
        let mut words = trimmed.split_whitespace();
        match words.next().map(str::to_ascii_uppercase).as_deref() {
            Some("ARG") => {
                for arg in words {
                    if let Some((name, value)) = arg.split_once('=') {
                        args.insert(name.to_string(), value.trim_matches(['\'', '"']).to_string());
                    }
                }
            }
            Some("FROM") => {
                let rest: Vec<&str> = words.filter(|w| !w.starts_with("--")).collect();
                if let Some(image) = rest.first() {
                    let image = interpolate(image, &args);
                    if image != "scratch" && !stages.contains(&image) && !images.contains(&image) {
                        images.push(image);
                    }
                }
                if let [_, as_, name, ..] = rest.as_slice()
                    && as_.eq_ignore_ascii_case("as")
                {
                    stages.insert(name.to_string());
                }
            }
            _ => {}
        }
    }
    images
}

/// An env value Compose reads back literally: written single-quoted, so no
/// `'`, no line break, no NUL.
fn env_value_ok(value: &str) -> bool {
    value.len() <= 1024 && !value.contains(['\'', '\n', '\r', '\0'])
}

fn text_ok(text: &Text) -> bool {
    text.contains_key("en")
        && text.iter().all(|(locale, value)| LOCALE.is_match(locale) && (1..=512).contains(&value.chars().count()))
}

fn https(url: &str) -> bool {
    url.starts_with("https://") && url.len() <= 512
}

/// The variables [compose] needs a value for, and those it can do without.
pub fn compose_variables(compose: &str) -> (BTreeSet<String>, BTreeSet<String>) {
    let (mut needed, mut optional) = (BTreeSet::new(), BTreeSet::new());
    for line in compose.lines() {
        // A comment can name a variable without using it.
        let line = match line.find(" #") {
            Some(at) => &line[..at],
            None if line.trim_start().starts_with('#') => continue,
            None => line,
        };
        let line = line.replace("$$", "");
        for caps in VARIABLE.captures_iter(&line) {
            if let Some(name) = caps.get(3) {
                needed.insert(name.as_str().to_string());
                continue;
            }
            let name = caps[1].to_string();
            match caps.get(2).map(|m| m.as_str()) {
                Some(op) if op.ends_with('-') || op.ends_with('+') => optional.insert(name),
                _ => needed.insert(name),
            };
        }
    }
    optional.retain(|n| !needed.contains(n));
    (needed, optional)
}

impl Manifest {
    pub fn parse(text: &str) -> Result<Self, Problem> {
        let mut manifest: Self = toml::from_str(text).map_err(|e| problem("manifest.toml", e.message().to_string()))?;
        manifest.id = format!("{}.{}", manifest.publisher, manifest.name);
        Ok(manifest)
    }

    /// Everything one table cannot say about itself; empty when it is fine.
    pub fn problems(&self) -> Vec<Problem> {
        let mut out = Vec::new();
        {
            let mut bad = |at: &str, message: &str| out.push(problem(at, message));
            if self.schema != SCHEMA {
                bad("schema", "unsupported schema");
            }
            if !(self.publisher.len() >= 2 && app_id::valid_part(&self.publisher)) {
                bad("publisher", "lowercase letters, digits and _, starting with a letter, 2 to 24");
            }
            if !app_id::valid_part(&self.name) {
                bad("name", "lowercase letters, digits and _, starting with a letter, at most 24");
            }
            if !(1..=64).contains(&self.project.chars().count()) {
                bad("project", "1 to 64 characters");
            }
            if !(1..=32).contains(&self.version.chars().count()) {
                bad("version", "1 to 32 characters");
            }
            if self.developer.as_ref().is_some_and(|d| !(1..=128).contains(&d.chars().count())) {
                bad("developer", "1 to 128 characters");
            }
            for (at, url) in [("homepage", &self.homepage), ("source", &self.source), ("license.url", &self.license.url)] {
                if !https(url) {
                    bad(at, "an https:// URL");
                }
            }
            if !GLYPH.is_match(&self.glyph) {
                bad("glyph", "a Material Symbols name");
            }
            if !TONES.contains(&self.tone.as_str()) {
                bad("tone", "not a tone");
            }
            if self.categories.iter().any(|c| !CATEGORIES.contains(&c.as_str())) {
                bad("categories", "not a category");
            }
            if !text_ok(&self.title) {
                bad("title", "needs `en`; locales like zh-TW, 1 to 512 characters");
            }
            if !text_ok(&self.description) {
                bad("description", "needs `en`; locales like zh-TW, 1 to 512 characters");
            }
            if self.license.spdx.is_empty() {
                bad("license.spdx", "empty");
            }
            if self.compose.files.is_empty() {
                bad("compose.files", "names no file");
            }
            if !self.web.path.starts_with('/') {
                bad("web.path", "starts with /");
            }
        }

        // Every env name comes from one place.
        let mut sources: BTreeMap<&str, Vec<String>> = BTreeMap::new();
        for name in self.env.keys() {
            sources.entry(name).or_default().push("env".into());
        }
        for (i, s) in self.secrets.iter().enumerate() {
            sources.entry(&s.env).or_default().push(format!("secrets[{i}]"));
            if !(16..=128).contains(&s.length) {
                out.push(problem(format!("secrets[{i}].length"), "16 to 128"));
            }
        }
        for (name, value) in &self.env {
            if !env_value_ok(value) {
                out.push(problem(format!("env.{name}"), "no ', line break or NUL; at most 1024 bytes"));
            }
        }
        let mut keys = BTreeSet::new();
        for (i, s) in self.settings.iter().enumerate() {
            let at = format!("settings[{i}]");
            if !KEY.is_match(s.key()) {
                out.push(problem(format!("{at}.key"), "lowercase letters, digits and _, at most 32"));
            }
            if !keys.insert(s.key()) {
                out.push(problem(format!("{at}.key"), "used twice"));
            }
            if !text_ok(s.label()) {
                out.push(problem(format!("{at}.label"), "needs `en`"));
            }
            if s.help().is_some_and(|h| !text_ok(h)) {
                out.push(problem(format!("{at}.help"), "needs `en`"));
            }
            for name in s.env_names() {
                sources.entry(name).or_default().push(at.clone());
            }
            out.extend(setting_problems(s, &at));
        }
        for (name, from) in &sources {
            if RESERVED.contains(name) {
                out.push(problem(from[0].clone(), format!("{name} is written by the agent")));
            }
            if !ENV_NAME.is_match(name) {
                out.push(problem(from[0].clone(), format!("{name}: not an env name")));
            }
            if from.len() > 1 {
                out.push(problem(from[1].clone(), format!("{name} is also set by {}", from[0])));
            }
        }
        match self.settings.iter().find(|s| s.key() == self.web.port) {
            Some(Setting::Port { protocol: Protocol::Tcp, .. }) => {}
            Some(Setting::Port { .. }) => out.push(problem("web.port", "a TCP port setting")),
            _ => out.push(problem("web.port", "names no port setting")),
        }
        if let Some(login) = &self.login {
            if login.user.is_none() && login.password.is_none() && login.note.is_none() {
                out.push(problem("login", "says nothing"));
            }
            if login.user.as_ref().is_some_and(|u| !(1..=64).contains(&u.chars().count()) || u.chars().any(char::is_control)) {
                out.push(problem("login.user", "1 to 64 characters"));
            }
            if let Some(env) = &login.password
                && !self.secrets.iter().any(|s| &s.env == env)
            {
                out.push(problem("login.password", format!("{env} is not a [[secrets]] entry")));
            }
            if login.note.as_ref().is_some_and(|n| !text_ok(n)) {
                out.push(problem("login.note", "needs `en`"));
            }
        }
        if self.web.basic_auth
            && !self.login.as_ref().is_some_and(|l| l.password.is_some() && l.user.as_ref().is_some_and(|u| !u.contains(':')))
        {
            out.push(problem("web.basic_auth", "needs [login] user (no `:`) and password"));
        }
        out
    }

    /// Every env name the env file sets.
    pub fn provided(&self) -> BTreeSet<String> {
        let mut names: BTreeSet<String> = self.env.keys().cloned().collect();
        names.extend(RESERVED.iter().map(|n| n.to_string()));
        names.extend(self.secrets.iter().map(|s| s.env.clone()));
        for s in &self.settings {
            names.extend(s.env_names().into_iter().map(String::from));
        }
        names
    }

    /// Settings filled in for [machine], for the deploy dialog to start from.
    pub fn defaults(&self, machine: &Machine) -> BTreeMap<String, Value> {
        self.settings
            .iter()
            .map(|s| {
                let value = match s {
                    Setting::Path { default, .. } => Value::from(machine.path(default)),
                    Setting::Port { default, protocol, .. } => {
                        let free = (*default..=default.saturating_add(PORT_SEARCH)).find(|p| machine.free(*p, *protocol));
                        Value::from(free.unwrap_or(*default))
                    }
                    Setting::Bool { default, .. } => Value::from(*default),
                    Setting::Choice { default, options, .. } => {
                        let suggested = options.iter().find(|o| o.suggest.as_ref().is_some_and(|s| machine.matches(s)));
                        Value::from(suggested.map_or(default.as_str(), |o| o.value.as_str()))
                    }
                    Setting::Text { default, .. } => Value::from(default.clone().unwrap_or_default()),
                };
                (s.key().to_string(), value)
            })
            .collect()
    }

    /// [given] checked against the settings: every one present (a missing one
    /// takes its default), of its type, nothing else.
    pub fn check_settings(&self, given: &BTreeMap<String, Value>, machine: &Machine) -> Result<BTreeMap<String, Value>, Invalid> {
        if let Some(unknown) = given.keys().find(|k| !self.settings.iter().any(|s| s.key() == k.as_str())) {
            return Err(Invalid { field: unknown.clone(), error: "unknownSetting" });
        }
        let defaults = self.defaults(machine);
        let mut out = BTreeMap::new();
        for s in &self.settings {
            let key = s.key();
            let value = given.get(key).or_else(|| defaults.get(key)).cloned().unwrap_or(Value::Null);
            let invalid = || Invalid { field: key.to_string(), error: "invalidSetting" };
            let ok = match s {
                Setting::Path { .. } => {
                    value.as_str().is_some_and(|p| Path::new(p).is_absolute() && env_value_ok(p) && !p.is_empty())
                }
                Setting::Port { .. } => value.as_u64().is_some_and(|p| (1..=65535).contains(&p)),
                Setting::Bool { .. } => value.is_boolean(),
                Setting::Choice { options, .. } => value.as_str().is_some_and(|v| options.iter().any(|o| o.value == v)),
                Setting::Text { pattern, optional, .. } => value.as_str().is_some_and(|v| {
                    (v.is_empty() && *optional) || (env_value_ok(v) && anchored(pattern).is_some_and(|r| r.is_match(v)))
                }),
            };
            if !ok {
                return Err(invalid());
            }
            out.insert(key.to_string(), value);
        }
        Ok(out)
    }

    /// The env file for checked [settings], the generated [secrets] and what
    /// the agent says of the machine ([`RESERVED`]).
    pub fn env_file(&self, settings: &BTreeMap<String, Value>, secrets: &BTreeMap<String, String>, host: &HostEnv) -> String {
        let mut out = String::from("# Written by ServerBox Monitor from the app's manifest; replaced on every update.\n");
        let mut values = self.env_values(settings, secrets);
        values.extend(host.values());
        for (name, value) in values {
            out.push_str(&format!("{name}='{value}'\n"));
        }
        out
    }

    /// Every value the env file sets, by name.
    pub fn env_values(&self, settings: &BTreeMap<String, Value>, secrets: &BTreeMap<String, String>) -> BTreeMap<String, String> {
        let mut values: BTreeMap<String, String> = self.env.clone();
        for s in &self.secrets {
            if let Some(v) = secrets.get(&s.env) {
                values.insert(s.env.clone(), v.clone());
            }
        }
        for s in &self.settings {
            let Some(value) = settings.get(s.key()) else { continue };
            match s {
                Setting::Path { env, .. } | Setting::Text { env, .. } => {
                    if let Some(v) = value.as_str().filter(|v| !v.is_empty()) {
                        values.insert(env.clone(), v.to_string());
                    }
                }
                Setting::Port { env, .. } => {
                    values.insert(env.clone(), value.to_string());
                }
                Setting::Bool { on, off, .. } => {
                    values.extend(if value.as_bool() == Some(true) { on } else { off }.clone());
                }
                Setting::Choice { options, .. } => {
                    if let Some(o) = options.iter().find(|o| value.as_str() == Some(o.value.as_str())) {
                        values.extend(o.env.clone());
                    }
                }
            }
        }
        values
    }

    /// The port the window reaches, from checked [settings].
    /// Checks every port setting of [settings] against [machine] and each
    /// other. With [follow], a port in the range the dialog suggests from
    /// (the default and the next [`PORT_SEARCH`]) that has been taken since
    /// moves to the next free one there; a port chosen outside it is the
    /// operator's choice and is refused instead. Answers the ports moved.
    pub fn settle_ports(&self, settings: &mut BTreeMap<String, Value>, machine: &Machine, follow: bool) -> Result<Vec<MovedPort>, Invalid> {
        let mut used = BTreeSet::new();
        let mut moved = Vec::new();
        for s in &self.settings {
            let Setting::Port { key, default, protocol, .. } = s else { continue };
            let Some(port) = settings.get(key).and_then(Value::as_u64).and_then(|p| u16::try_from(p).ok()) else {
                continue;
            };
            let transports = protocol.transports();
            let ok = |p: u16| transports.iter().all(|t| !used.contains(&(p, *t))) && machine.free(p, *protocol);
            let port = if ok(port) {
                port
            } else {
                let last = default.saturating_add(PORT_SEARCH);
                let next = if follow && (*default..=last).contains(&port) {
                    (port.saturating_add(1)..=last).find(|p| ok(*p))
                } else {
                    None
                };
                let Some(next) = next else { return Err(Invalid { field: key.clone(), error: "portTaken" }) };
                settings.insert(key.clone(), Value::from(next));
                moved.push(MovedPort { setting: key.clone(), from: port, to: next });
                next
            };
            used.extend(transports.iter().map(|t| (port, *t)));
        }
        Ok(moved)
    }

    pub fn web_port(&self, settings: &BTreeMap<String, Value>) -> Option<u16> {
        settings.get(&self.web.port)?.as_u64()?.try_into().ok()
    }

    /// Directories holding the service's data, removed only when asked.
    pub fn data_paths(&self, settings: &BTreeMap<String, Value>) -> Vec<PathBuf> {
        self.settings
            .iter()
            .filter(|s| matches!(s, Setting::Path { data: true, .. }))
            .filter_map(|s| settings.get(s.key())?.as_str().map(PathBuf::from))
            .collect()
    }
}

fn setting_problems(s: &Setting, at: &str) -> Vec<Problem> {
    let mut out = Vec::new();
    match s {
        Setting::Path { default, data, .. } => {
            if !(default.starts_with('/') || default.starts_with("{stack}") || default.starts_with("{shared}"))
                || !env_value_ok(default)
            {
                out.push(problem(format!("{at}.default"), "absolute, or under {stack} or {shared}"));
            }
            // Removing an app's data never empties what other apps use.
            if *data && default.starts_with("{shared}") {
                out.push(problem(format!("{at}.data"), "a {shared} folder is not one app's data"));
            }
        }
        Setting::Port { default, .. } => {
            if *default == 0 {
                out.push(problem(format!("{at}.default"), "1 to 65535"));
            }
        }
        Setting::Bool { on, off, .. } => {
            if on.is_empty() || on.keys().ne(off.keys()) {
                out.push(problem(at, "`on` and `off` set the same names, at least one"));
            }
            for (name, value) in on.iter().chain(off) {
                if !env_value_ok(value) {
                    out.push(problem(format!("{at}.{name}"), "no ', line break or NUL"));
                }
            }
        }
        Setting::Choice { default, options, .. } => {
            if options.len() < 2 {
                out.push(problem(format!("{at}.options"), "at least two"));
            }
            if !options.iter().any(|o| &o.value == default) {
                out.push(problem(format!("{at}.default"), "not one of the options"));
            }
            let mut values = BTreeSet::new();
            for (i, o) in options.iter().enumerate() {
                let oat = format!("{at}.options[{i}]");
                if !OPTION_VALUE.is_match(&o.value) || !values.insert(&o.value) {
                    out.push(problem(format!("{oat}.value"), "letters, digits, ._-; each once"));
                }
                if !text_ok(&o.label) {
                    out.push(problem(format!("{oat}.label"), "needs `en`"));
                }
                if o.env.is_empty() || options.first().is_some_and(|f| f.env.keys().ne(o.env.keys())) {
                    out.push(problem(format!("{oat}.env"), "every option sets the same names, at least one"));
                }
                if o.env.values().any(|v| !env_value_ok(v)) {
                    out.push(problem(format!("{oat}.env"), "no ', line break or NUL"));
                }
                if let Some(gpu) = o.suggest.as_ref().and_then(|s| s.gpu.as_deref())
                    && !["nvidia", "amd", "intel"].contains(&gpu)
                {
                    out.push(problem(format!("{oat}.suggest.gpu"), "nvidia, amd or intel"));
                }
            }
        }
        Setting::Text { pattern, default, .. } => match anchored(pattern) {
            None => out.push(problem(format!("{at}.pattern"), "not a regular expression")),
            Some(r) => {
                if default.as_deref().is_some_and(|d| !d.is_empty() && !r.is_match(d)) {
                    out.push(problem(format!("{at}.default"), "does not match the pattern"));
                }
            }
        },
    }
    out
}

static REFERENCE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::?[-?+]([^}]*))?\}|\$([A-Za-z_][A-Za-z0-9_]*)").expect("regex"));

/// [text] with `${NAME}`, `${NAME:-default}` and `$NAME` replaced from
/// [values], as Compose interpolates; `$$` is a literal `$`.
fn interpolate(text: &str, values: &BTreeMap<String, String>) -> String {
    text.split("$$")
        .map(|part| {
            REFERENCE
                .replace_all(part, |c: &regex::Captures| {
                    let name = c.get(1).or(c.get(3)).map_or("", |m| m.as_str());
                    match values.get(name).filter(|v| !v.is_empty()) {
                        Some(v) => v.clone(),
                        None => c.get(2).map_or("", |m| m.as_str()).to_string(),
                    }
                })
                .into_owned()
        })
        .collect::<Vec<_>>()
        .join("$")
}

/// [pattern] matched against the whole value.
fn anchored(pattern: &str) -> Option<Regex> {
    Regex::new(&format!("^(?:{pattern})$")).ok()
}

/// What the agent writes for [`RESERVED`].
#[derive(Debug, Clone)]
pub struct HostEnv {
    pub uid: u32,
    pub gid: u32,
    /// An IANA time zone name.
    pub tz: String,
    /// The GPU render node's group; [gid] without one.
    pub render_gid: u32,
}

impl HostEnv {
    fn values(&self) -> [(String, String); 4] {
        [
            ("SBM_UID".into(), self.uid.to_string()),
            ("SBM_GID".into(), self.gid.to_string()),
            ("SBM_TZ".into(), self.tz.clone()),
            ("SBM_RENDER_GID".into(), self.render_gid.to_string()),
        ]
    }
}

/// What a setting check refused: the setting, and a code the panel words.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Invalid {
    pub field: String,
    pub error: &'static str,
}

/// A port setting moved off a port in use (`Manifest::settle_ports`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct MovedPort {
    pub setting: String,
    pub from: u16,
    pub to: u16,
}

/// What the defaults depend on.
#[derive(Debug, Clone, Default)]
pub struct Machine {
    /// The stack's directory (`{stack}`).
    pub stack: PathBuf,
    /// The folder every app shares (`{shared}`).
    pub shared: PathBuf,
    /// Vendors of the GPUs the agent sees, lowercase.
    pub gpus: Vec<String>,
    /// Linux under WSL2.
    pub wsl: bool,
    /// Which ports the stack may publish; every port is free without.
    pub ports: Option<super::ports::Ports>,
}

impl Machine {
    pub fn free(&self, port: u16, protocol: Protocol) -> bool {
        self.ports.as_ref().is_none_or(|p| protocol.transports().iter().all(|t| p.free(port, *t)))
    }

    /// A path setting's [default] with `{stack}` or `{shared}` filled in.
    fn path(&self, default: &str) -> String {
        for (token, dir) in [("{stack}", &self.stack), ("{shared}", &self.shared)] {
            if let Some(rest) = default.strip_prefix(token) {
                return format!("{}{rest}", dir.to_string_lossy().trim_end_matches('/'));
            }
        }
        default.to_string()
    }

    fn matches(&self, s: &Suggest) -> bool {
        s.gpu.as_ref().is_none_or(|g| self.gpus.iter().any(|v| v == g)) && s.wsl.is_none_or(|w| w == self.wsl)
    }
}

/// A checked package: the manifest and its files by name.
#[derive(Debug, Clone)]
pub struct Package {
    pub manifest: Manifest,
    /// `manifest.toml` as written, to keep the package whole (`catalog`).
    pub manifest_text: String,
    pub files: BTreeMap<String, String>,
}

impl Package {
    /// A package folder's files, by name: the manifest and every file it
    /// copies. All problems at once, so a contributor fixes them in one go.
    pub fn read(files: &BTreeMap<String, Vec<u8>>) -> Result<Self, Vec<Problem>> {
        let mut problems = Vec::new();
        if files.len() > MAX_FILES {
            problems.push(problem("package", format!("more than {MAX_FILES} files")));
        }
        if files.values().map(Vec::len).sum::<usize>() > MAX_PACKAGE_BYTES {
            problems.push(problem("package", "more than 1 MiB"));
        }
        let mut texts = BTreeMap::new();
        for (name, bytes) in files {
            if !FILE.is_match(name) {
                problems.push(problem(name, "a plain file name: letters, digits, ._-"));
            }
            if name.ends_with(".dockerignore") {
                // BuildKit would read it before the agent's `.dockerignore`.
                problems.push(problem(name, "no .dockerignore: the agent writes the stack's"));
            }
            if bytes.len() > MAX_FILE_BYTES {
                problems.push(problem(name, "more than 256 KiB"));
            }
            match String::from_utf8(bytes.clone()) {
                Ok(text) => {
                    texts.insert(name.clone(), text);
                }
                Err(_) => problems.push(problem(name, "not UTF-8 text")),
            }
        }
        let Some(text) = texts.remove("manifest.toml") else {
            problems.push(problem("manifest.toml", "missing"));
            return Err(problems);
        };
        let manifest = match Manifest::parse(&text) {
            Ok(m) => m,
            Err(p) => {
                problems.push(p);
                return Err(problems);
            }
        };
        problems.extend(manifest.problems());

        let provided = manifest.provided();
        let mut used = BTreeSet::new();
        let (mut dockerfiles, mut built_images) = (Vec::new(), false);
        for file in &manifest.compose.files {
            let Some(compose) = texts.get(file) else {
                problems.push(problem("compose.files", format!("{file} is not in the package")));
                continue;
            };
            dockerfiles.extend(compose_builds(file, compose, &texts, &mut problems));
            built_images |= compose
                .lines()
                .filter_map(yaml_entry)
                .any(|(key, value)| key == "image" && value.starts_with(BUILT_PREFIX));
            let (needed, optional) = compose_variables(compose);
            for name in needed.difference(&provided) {
                problems.push(problem(file, format!("${{{name}}} is not set by the manifest")));
            }
            used.extend(needed);
            used.extend(optional);
        }
        match (dockerfiles.is_empty(), built_images) {
            (false, false) => problems.push(problem("compose.files", format!("a built image is named {BUILT_PREFIX}…"))),
            (true, true) => problems.push(problem("compose.files", format!("{BUILT_PREFIX}… is for a built image; nothing is built"))),
            _ => {}
        }
        if !dockerfiles.is_empty() && !manifest.notices.contains(&Notice::BuildsImages) {
            problems.push(problem("notices", "buildsImages: the compose files build an image"));
        }
        for name in provided.difference(&used) {
            // Read by the containers through `env_file`, which Compose does not
            // name: only worth a look, so a hint rather than a refusal.
            tracing::debug!("{}: {name} is set but no compose file names it", manifest.id);
        }
        if problems.is_empty() { Ok(Self { manifest, manifest_text: text, files: texts }) } else { Err(problems) }
    }

    /// The images [settings] make the compose files name, as Compose would
    /// read them (`${NAME}` from the env file; `${NAME:-default}` falls back).
    fn named_images(&self, settings: &BTreeMap<String, Value>) -> Vec<String> {
        let values = self.manifest.env_values(settings, &BTreeMap::new());
        let mut images = Vec::new();
        for file in &self.manifest.compose.files {
            let Some(text) = self.files.get(file) else { continue };
            for (key, raw) in text.lines().filter_map(yaml_entry) {
                let image = interpolate(raw, &values);
                if key == "image" && !image.is_empty() && !images.contains(&image) {
                    images.push(image);
                }
            }
        }
        images
    }

    /// The Dockerfiles the compose files build from.
    fn dockerfiles(&self) -> Vec<&str> {
        let mut out = Vec::new();
        for file in &self.manifest.compose.files {
            let Some(text) = self.files.get(file) else { continue };
            for (key, value) in text.lines().filter_map(yaml_entry) {
                if key == "dockerfile" && !out.contains(&value) {
                    out.push(value);
                }
            }
        }
        out
    }

    /// Whether a service is built on the machine (`build:`).
    pub fn builds(&self) -> bool {
        !self.dockerfiles().is_empty()
    }

    /// The images deploying with [settings] pulls: those the compose files
    /// name, and those the built ones start from.
    pub fn images(&self, settings: &BTreeMap<String, Value>) -> Vec<String> {
        let mut images: Vec<String> = self.named_images(settings).into_iter().filter(|i| !i.starts_with(BUILT_PREFIX)).collect();
        for dockerfile in self.dockerfiles() {
            for image in self.files.get(dockerfile).map(|t| base_images(t)).unwrap_or_default() {
                if !images.contains(&image) {
                    images.push(image);
                }
            }
        }
        images
    }

    /// The images deploying with [settings] builds on the machine.
    pub fn built(&self, settings: &BTreeMap<String, Value>) -> Vec<String> {
        self.named_images(settings).into_iter().filter(|i| i.starts_with(BUILT_PREFIX)).collect()
    }

    /// The package in folder [dir], read from disk.
    pub fn read_dir(dir: &Path) -> Result<Self, Vec<Problem>> {
        let mut files = BTreeMap::new();
        let entries = std::fs::read_dir(dir).map_err(|e| vec![problem(dir.display().to_string(), e.to_string())])?;
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().into_owned();
            let path = entry.path();
            if !path.is_file() {
                return Err(vec![problem(name, "only plain files; no folders or links")]);
            }
            let bytes = std::fs::read(&path).map_err(|e| vec![problem(name.clone(), e.to_string())])?;
            files.insert(name, bytes);
        }
        let package = Self::read(&files)?;
        let folder = dir.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
        if package.manifest.id != folder {
            return Err(vec![problem("name", format!("the folder is {folder}, the id {}", package.manifest.id))]);
        }
        Ok(package)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn store() -> PathBuf {
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../store/apps")
    }

    fn immich() -> Package {
        Package::read_dir(&store().join("futo.immich")).expect("immich")
    }

    #[test]
    fn every_store_app_reads() {
        let mut seen = 0;
        for entry in std::fs::read_dir(store()).expect("store/apps") {
            let dir = entry.expect("entry").path();
            if dir.is_dir() {
                if let Err(p) = Package::read_dir(&dir) {
                    panic!("{}: {p:#?}", dir.display());
                }
                seen += 1;
            }
        }
        assert!(seen >= 1);
    }

    #[test]
    fn ports_settle_against_the_machine_and_each_other() {
        let text = format!("{MINIMAL}\n[[settings]]\nkey = \"admin\"\ntype = \"port\"\nenv = \"ADMIN\"\ndefault = 8080\nlabel = {{ en = \"Admin\" }}\n");
        let m = package(&text, "services:\n  a:\n    image: x\n    ports: ['${PORT}:80', '${ADMIN}:81']\n").expect("package").manifest;
        let machine = Machine { ports: Some(super::super::ports::Ports::new(vec![], "x", |p, _| p != 8081 && p != 9999)), ..Default::default() };
        let both = || BTreeMap::from([("port".to_string(), Value::from(8080)), ("admin".to_string(), Value::from(8080))]);
        let mut s = both();
        assert_eq!(m.settle_ports(&mut s, &machine, true).unwrap(), vec![MovedPort { setting: "admin".into(), from: 8080, to: 8082 }]);
        assert_eq!(s["admin"], 8082);
        // Not followed: the second is refused.
        let mut s = both();
        let refused = m.settle_ports(&mut s, &machine, false).unwrap_err();
        assert_eq!((refused.field.as_str(), refused.error), ("admin", "portTaken"));
        // Chosen outside the suggested range: the operator's to change.
        let mut s = BTreeMap::from([("port".to_string(), Value::from(9999)), ("admin".to_string(), Value::from(8082))]);
        assert_eq!(m.settle_ports(&mut s, &machine, true).unwrap_err().field, "port");
    }

    #[test]
    fn defaults_follow_the_machine() {
        let m = immich().manifest;
        let mut machine = Machine { stack: PathBuf::from("/srv/sbm/stacks/immich"), ..Default::default() };
        let d = m.defaults(&machine);
        assert_eq!(d["library"], "/srv/sbm/stacks/immich/library");
        assert_eq!((d["ml"].as_str(), d["transcode"].as_str()), (Some("cpu"), Some("cpu")));
        assert_eq!(d["port"], 2283);

        machine.gpus = vec!["nvidia".into()];
        machine.ports = Some(super::super::ports::Ports::new(vec![], "x", |p, _| p != 2283));
        let d = m.defaults(&machine);
        assert_eq!((d["ml"].as_str(), d["transcode"].as_str()), (Some("cuda"), Some("nvenc")));
        assert_eq!(d["port"], 2284);

        machine.gpus = vec!["intel".into()];
        machine.wsl = true;
        let d = m.defaults(&machine);
        assert_eq!((d["ml"].as_str(), d["transcode"].as_str()), (Some("openvino-wsl"), Some("vaapi-wsl")));
    }

    #[test]
    fn settings_are_checked() {
        let m = immich().manifest;
        let machine = Machine { stack: PathBuf::from("/srv/s"), ..Default::default() };
        let full = m.check_settings(&BTreeMap::new(), &machine).expect("defaults pass");
        assert_eq!(full.len(), m.settings.len());

        let with = |key: &str, value: Value| BTreeMap::from([(key.to_string(), value)]);
        let field = |r: Result<_, Invalid>| r.unwrap_err().field;
        assert_eq!(field(m.check_settings(&with("library", "relative".into()), &machine)), "library");
        assert_eq!(field(m.check_settings(&with("library", "/a/it's".into()), &machine)), "library");
        assert_eq!(field(m.check_settings(&with("ml", "tpu".into()), &machine)), "ml");
        assert_eq!(field(m.check_settings(&with("port", 0.into()), &machine)), "port");
        assert_eq!(field(m.check_settings(&with("nope", 1.into()), &machine)), "nope");
        assert_eq!(field(m.check_settings(&with("timezone", "x; rm".into()), &machine)), "timezone");
        assert!(m.check_settings(&with("timezone", "Asia/Shanghai".into()), &machine).is_ok());
        assert!(m.check_settings(&with("timezone", "".into()), &machine).is_ok());
    }

    #[test]
    fn env_file_carries_everything_quoted() {
        let m = immich().manifest;
        let machine = Machine { stack: PathBuf::from("/srv/s"), ..Default::default() };
        let mut given = BTreeMap::new();
        given.insert("ml".to_string(), Value::from("cuda"));
        given.insert("expose".to_string(), Value::from(true));
        let settings = m.check_settings(&given, &machine).expect("ok");
        let secrets = BTreeMap::from([("DB_PASSWORD".to_string(), "abc123".to_string())]);
        let host = HostEnv { uid: 1000, gid: 100, tz: "Asia/Shanghai".into(), render_gid: 993 };
        let env = m.env_file(&settings, &secrets, &host);
        for line in [
            "IMMICH_VERSION='v3.3.1'",
            "UPLOAD_LOCATION='/srv/s/library'",
            "ML_BACKEND='cuda'",
            "ML_IMAGE_SUFFIX='-cuda'",
            "IMMICH_BIND='0.0.0.0'",
            "IMMICH_PORT='2283'",
            "DB_STORAGE_TYPE='SSD'",
            "DB_PASSWORD='abc123'",
            "SBM_UID='1000'",
            "SBM_GID='100'",
            "SBM_TZ='Asia/Shanghai'",
            "SBM_RENDER_GID='993'",
        ] {
            assert!(env.lines().any(|l| l == line), "{line} missing in\n{env}");
        }
        // An empty optional text is left out, so the host's TZ applies.
        assert!(!env.lines().any(|l| l.starts_with("TZ=")));
        assert_eq!(m.web_port(&settings), Some(2283));
        assert_eq!(m.data_paths(&settings), vec![PathBuf::from("/srv/s/library"), PathBuf::from("/srv/s/postgres")]);
    }

    #[test]
    fn images_are_read_as_compose_would() {
        let p = immich();
        let machine = Machine { stack: PathBuf::from("/srv/s"), ..Default::default() };
        let cpu = p.manifest.check_settings(&BTreeMap::new(), &machine).unwrap();
        let images = p.images(&cpu);
        assert!(images.contains(&"ghcr.io/immich-app/immich-server:v3.3.1".to_string()), "{images:?}");
        assert!(images.contains(&"ghcr.io/immich-app/immich-machine-learning:v3.3.1".to_string()), "{images:?}");
        assert!(images.iter().any(|i| i.starts_with("docker.io/valkey/valkey:9@sha256:")));
        let cuda = p.manifest.check_settings(&BTreeMap::from([("ml".to_string(), Value::from("cuda"))]), &machine).unwrap();
        assert!(p.images(&cuda).contains(&"ghcr.io/immich-app/immich-machine-learning:v3.3.1-cuda".to_string()));
        let values = BTreeMap::from([("A".to_string(), "1".to_string())]);
        assert_eq!(interpolate("x:${A}-${B:-dflt}-$A-$$A", &values), "x:1-dflt-1-$A");
    }

    #[test]
    fn compose_variables_read_operators_and_comments() {
        let (needed, optional) = compose_variables(
            "image: x:${TAG}\n  # ${IN_COMMENT}\nports: ['${BIND:-0.0.0.0}:$PORT:80'] # ${TRAILING}\ncmd: echo $$HOME ${REQ:?set it}\n",
        );
        assert_eq!(needed, BTreeSet::from(["TAG".into(), "PORT".into(), "REQ".into()]));
        assert_eq!(optional, BTreeSet::from(["BIND".to_string()]));
    }

    fn package(manifest: &str, compose: &str) -> Result<Package, Vec<Problem>> {
        Package::read(&BTreeMap::from([
            ("manifest.toml".to_string(), manifest.as_bytes().to_vec()),
            ("compose.yaml".to_string(), compose.as_bytes().to_vec()),
        ]))
    }

    const MINIMAL: &str = r#"
schema = 1
publisher = "acme"
name = "demo"
project = "Demo"
version = "1.0"
homepage = "https://example.com"
source = "https://example.com/src"
glyph = "apps"
tone = "teal"
title = { en = "Demo" }
description = { en = "A demo." }
license = { spdx = "MIT", url = "https://example.com/LICENSE" }
compose = { files = ["compose.yaml"] }
web = { port = "port" }

[[settings]]
key = "port"
type = "port"
env = "PORT"
default = 8080
label = { en = "Port" }
"#;

    fn files(manifest: &str, compose: &str, others: &[(&str, &str)]) -> BTreeMap<String, Vec<u8>> {
        let mut files = BTreeMap::from([
            ("manifest.toml".to_string(), manifest.as_bytes().to_vec()),
            ("compose.yaml".to_string(), compose.as_bytes().to_vec()),
        ]);
        files.extend(others.iter().map(|(n, t)| (n.to_string(), t.as_bytes().to_vec())));
        files
    }

    const BUILT: &str = "services:\n  web:\n    image: localhost/demo-web:${TAG}\n    build:\n      context: .\n      dockerfile: web.Dockerfile\n    ports: ['${PORT}:80']\n  db:\n    image: 'docker.io/library/postgres:18'\n";

    #[test]
    fn a_built_image_is_listed_apart_and_its_bases_pulled() {
        let manifest = MINIMAL.replace("compose = {", "notices = [\"buildsImages\"]\nenv = { TAG = \"1.0\" }\ncompose = {");
        let dockerfile = "# syntax=docker/dockerfile:1\nARG ALPINE=3.22\nFROM --platform=$BUILDPLATFORM alpine:${ALPINE} AS fetch\nCOPY <<EOF /x\nFROM not-an-image\nEOF\nFROM fetch AS again\nFROM scratch\nFROM docker.io/library/caddy:2-alpine\n";
        let p = Package::read(&files(&manifest, BUILT, &[("web.Dockerfile", dockerfile)])).expect("package");
        assert!(p.builds());
        let settings = BTreeMap::new();
        assert_eq!(p.built(&settings), vec!["localhost/demo-web:1.0".to_string()]);
        assert_eq!(
            p.images(&settings),
            vec!["docker.io/library/postgres:18".to_string(), "alpine:3.22".into(), "docker.io/library/caddy:2-alpine".into()]
        );

        let plain = package(MINIMAL, "services:\n  a:\n    image: x\n").expect("package");
        assert!(!plain.builds());
        assert!(plain.built(&settings).is_empty());
    }

    #[test]
    fn builds_are_held_to_the_package() {
        let manifest = MINIMAL.replace("compose = {", "notices = [\"buildsImages\"]\nenv = { TAG = \"1.0\" }\ncompose = {");
        let at = |problems: Vec<Problem>| problems.into_iter().map(|p| format!("{}: {}", p.at, p.message)).collect::<Vec<_>>();

        let missing = at(Package::read(&files(&manifest, BUILT, &[])).unwrap_err());
        assert!(missing.iter().any(|p| p.contains("web.Dockerfile is not in the package")), "{missing:?}");

        let elsewhere = BUILT.replace("context: .", "context: /etc").replace("dockerfile: web.Dockerfile", "dockerfile: web.Dockerfile\n      additional_contexts:\n        host: /");
        let elsewhere = at(Package::read(&files(&manifest, &elsewhere, &[("web.Dockerfile", "FROM alpine\n")])).unwrap_err());
        assert!(elsewhere.iter().any(|p| p.contains("only `.`")), "{elsewhere:?}");
        assert!(elsewhere.iter().any(|p| p.contains("additional_contexts")), "{elsewhere:?}");

        let short = BUILT.replace("    build:\n      context: .\n      dockerfile: web.Dockerfile\n", "    build: .\n");
        let short = at(Package::read(&files(&manifest, &short, &[])).unwrap_err());
        assert!(short.iter().any(|p| p.contains("a mapping")), "{short:?}");

        let unnamed = BUILT.replace("localhost/demo-web", "demo-web");
        let unnamed = at(Package::read(&files(&manifest, &unnamed, &[("web.Dockerfile", "FROM alpine\n")])).unwrap_err());
        assert!(unnamed.iter().any(|p| p.contains("a built image is named localhost/")), "{unnamed:?}");

        let unbuilt = at(package(MINIMAL, "services:\n  a:\n    image: localhost/x\n").unwrap_err());
        assert!(unbuilt.iter().any(|p| p.contains("nothing is built")), "{unbuilt:?}");

        let undeclared = MINIMAL.replace("compose = {", "env = { TAG = \"1.0\" }\ncompose = {");
        let undeclared = at(Package::read(&files(&undeclared, BUILT, &[("web.Dockerfile", "FROM alpine\n")])).unwrap_err());
        assert!(undeclared.iter().any(|p| p.starts_with("notices")), "{undeclared:?}");

        let ignore = at(Package::read(&files(&manifest, BUILT, &[("web.Dockerfile", "FROM alpine\n"), ("web.Dockerfile.dockerignore", "")])).unwrap_err());
        assert!(ignore.iter().any(|p| p.contains("no .dockerignore")), "{ignore:?}");
    }

    #[test]
    fn shared_folders_and_reserved_names() {
        let text = format!(
            "{MINIMAL}\n[[settings]]\nkey = \"media\"\ntype = \"path\"\nenv = \"MEDIA\"\ndefault = \"{{shared}}/media\"\nlabel = {{ en = \"Media\" }}\n"
        );
        let compose = "services:\n  a:\n    user: '${SBM_UID}:${SBM_GID}'\n    environment: {TZ: '${SBM_TZ}'}\n    volumes: ['${MEDIA}:/media:ro']\n    ports: ['${PORT}:80']\n";
        let m = package(&text, compose).expect("reserved names are provided").manifest;
        let machine = Machine { stack: PathBuf::from("/srv/s/demo"), shared: PathBuf::from("/srv/shared/"), ..Default::default() };
        assert_eq!(m.defaults(&machine)["media"], "/srv/shared/media");
        let settings = m.check_settings(&BTreeMap::new(), &machine).unwrap();
        assert!(m.data_paths(&settings).is_empty(), "a shared folder is never removed with the app");

        let owned = text.replace("label = { en = \"Media\" }", "data = true\nlabel = { en = \"Media\" }");
        let problems = package(&owned, compose).unwrap_err();
        assert!(problems.iter().any(|p| p.at.ends_with(".data")), "{problems:?}");
        let set = format!("{MINIMAL}\n[env]\nSBM_TZ = \"UTC\"\n");
        let problems = package(&set, "x: ${PORT}\n").unwrap_err();
        assert!(problems.iter().any(|p| p.message.contains("written by the agent")), "{problems:?}");
    }

    #[test]
    fn udp_and_low_ports() {
        let text = format!(
            "{MINIMAL}\n[[settings]]\nkey = \"dns\"\ntype = \"port\"\nenv = \"DNS\"\ndefault = 53\nprotocol = \"both\"\nlabel = {{ en = \"DNS\" }}\n"
        );
        let m = package(&text, "services:\n  a:\n    ports: ['${PORT}:80', '${DNS}:53/tcp', '${DNS}:53/udp']\n").expect("package").manifest;
        // 53/udp is taken; 54 is free both ways.
        let machine = Machine {
            ports: Some(super::super::ports::Ports::new(vec![], "x", |p, t| !(p == 53 && t == PortProtocol::Udp))),
            ..Default::default()
        };
        assert_eq!(m.defaults(&machine)["dns"], 54);
        let mut s = BTreeMap::from([("port".to_string(), Value::from(8080)), ("dns".to_string(), Value::from(53))]);
        assert_eq!(m.settle_ports(&mut s, &machine, true).unwrap(), vec![MovedPort { setting: "dns".into(), from: 53, to: 54 }]);
        assert!(m.check_settings(&BTreeMap::from([("dns".to_string(), Value::from(53))]), &Machine::default()).is_ok());

        // The window's port is a TCP one.
        let udp_web = text.replace("web = { port = \"port\" }", "web = { port = \"dns\" }");
        let problems = package(&udp_web, "x: ${PORT} ${DNS}\n").unwrap_err();
        assert!(problems.iter().any(|p| p.at == "web.port"), "{problems:?}");
    }

    #[test]
    fn login_names_a_secret() {
        let ok = format!("{MINIMAL}\n[[secrets]]\nenv = \"ADMIN_PASSWORD\"\n\n[login]\nuser = \"admin\"\npassword = \"ADMIN_PASSWORD\"\nnote = {{ en = \"Change it after signing in.\" }}\n");
        let m = package(&ok, "x: ${PORT}\n").expect("package").manifest;
        assert_eq!(m.login.as_ref().and_then(|l| l.user.as_deref()), Some("admin"));
        let wrong = ok.replace("password = \"ADMIN_PASSWORD\"", "password = \"NOPE\"");
        let problems = package(&wrong, "x: ${PORT}\n").unwrap_err();
        assert!(problems.iter().any(|p| p.at == "login.password"), "{problems:?}");
        let empty = format!("{MINIMAL}\n[login]\n");
        assert!(package(&empty, "x: ${PORT}\n").unwrap_err().iter().any(|p| p.at == "login"));

        let basic = ok.replace("web = { port = \"port\" }", "web = { port = \"port\", basic_auth = true }");
        assert!(package(&basic, "x: ${PORT}\n").expect("package").manifest.web.basic_auth);
        let colon = basic.replace("user = \"admin\"", "user = \"a:b\"");
        assert!(package(&colon, "x: ${PORT}\n").unwrap_err().iter().any(|p| p.at == "web.basic_auth"));
        let bare = MINIMAL.replace("web = { port = \"port\" }", "web = { port = \"port\", basic_auth = true }");
        assert!(package(&bare, "x: ${PORT}\n").unwrap_err().iter().any(|p| p.at == "web.basic_auth"));
    }

    #[test]
    fn a_minimal_package_reads() {
        package(MINIMAL, "services:\n  app:\n    ports: ['127.0.0.1:${PORT}:80']\n").expect("reads");
    }

    #[test]
    fn package_problems_are_all_reported() {
        let problems = package(MINIMAL, "image: ${TAG}\n").unwrap_err();
        assert!(problems.iter().any(|p| p.message.contains("${TAG}")), "{problems:?}");

        let unknown = MINIMAL.replace("tone = \"teal\"", "tone = \"teal\"\ncolour = 1");
        assert!(package(&unknown, "").is_err());

        let twice = format!("{MINIMAL}\n[env]\nPORT = \"1\"\n");
        let problems = package(&twice, "x: ${PORT}\n").unwrap_err();
        assert!(problems.iter().any(|p| p.message.contains("also set by")), "{problems:?}");

        let no_port = MINIMAL.replace("web = { port = \"port\" }", "web = { port = \"nope\" }");
        let problems = package(&no_port, "x: ${PORT}\n").unwrap_err();
        assert!(problems.iter().any(|p| p.at == "web.port"), "{problems:?}");

        let missing = Package::read(&BTreeMap::from([("manifest.toml".to_string(), MINIMAL.as_bytes().to_vec())]))
            .unwrap_err();
        assert!(missing.iter().any(|p| p.message.contains("not in the package")), "{missing:?}");
    }
}
