//! The web app manifest: `store/apps/<id>/manifest.toml`, a web service the
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
//! - the env file those files read: fixed values, generated secrets, and the
//!   values of the settings the deploy dialog asks for.
//!
//! [`Package::read`] checks a whole folder: the manifest, its files, and that
//! every variable a compose file needs is one the env file sets.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};
use std::sync::LazyLock;

use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::Value;

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

pub type Text = BTreeMap<String, String>;
pub type EnvMap = BTreeMap<String, String>;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Notice {
    PullsImages,
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
    pub id: String,
    pub name: String,
    pub version: String,
    pub homepage: String,
    pub source: String,
    pub glyph: String,
    pub tone: String,
    #[serde(default)]
    pub categories: Vec<String>,
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
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Web {
    /// The key of the `port` setting the window reaches.
    pub port: String,
    #[serde(default = "root")]
    pub path: String,
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
        /// Absolute, or under `{stack}`.
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

static ID: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^[a-z][a-z0-9-]{0,31}$").expect("regex"));
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
        toml::from_str(text).map_err(|e| problem("manifest.toml", e.message().to_string()))
    }

    /// Everything one table cannot say about itself; empty when it is fine.
    pub fn problems(&self) -> Vec<Problem> {
        let mut out = Vec::new();
        {
            let mut bad = |at: &str, message: &str| out.push(problem(at, message));
            if self.schema != SCHEMA {
                bad("schema", "unsupported schema");
            }
            if !ID.is_match(&self.id) {
                bad("id", "lowercase letters, digits and -, starting with a letter, at most 32");
            }
            if !(1..=64).contains(&self.name.chars().count()) {
                bad("name", "1 to 64 characters");
            }
            if !(1..=32).contains(&self.version.chars().count()) {
                bad("version", "1 to 32 characters");
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
            if !ENV_NAME.is_match(name) {
                out.push(problem(from[0].clone(), format!("{name}: not an env name")));
            }
            if from.len() > 1 {
                out.push(problem(from[1].clone(), format!("{name} is also set by {}", from[0])));
            }
        }
        match self.settings.iter().find(|s| s.key() == self.web.port) {
            Some(Setting::Port { .. }) => {}
            _ => out.push(problem("web.port", "names no port setting")),
        }
        out
    }

    /// Every env name the env file sets.
    pub fn provided(&self) -> BTreeSet<String> {
        let mut names: BTreeSet<String> = self.env.keys().cloned().collect();
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
                    Setting::Path { default, .. } => Value::from(stack_path(default, &machine.stack)),
                    Setting::Port { default, .. } => {
                        let free = (*default..=default.saturating_add(PORT_SEARCH)).find(|p| machine.free(*p));
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
                Setting::Port { .. } => value.as_u64().is_some_and(|p| (1024..=65535).contains(&p)),
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

    /// The env file for checked [settings] and the generated [secrets].
    pub fn env_file(&self, settings: &BTreeMap<String, Value>, secrets: &BTreeMap<String, String>) -> String {
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
        let mut out = String::from("# Written by ServerBox Monitor from the app's manifest; replaced on every update.\n");
        for (name, value) in values {
            out.push_str(&format!("{name}='{value}'\n"));
        }
        out
    }

    /// The port the window reaches, from checked [settings].
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
        Setting::Path { default, .. } => {
            if !(default.starts_with('/') || default.starts_with("{stack}")) || !env_value_ok(default) {
                out.push(problem(format!("{at}.default"), "absolute, or under {stack}"));
            }
        }
        Setting::Port { default, .. } => {
            if *default < 1024 {
                out.push(problem(format!("{at}.default"), "1024 to 65535"));
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

/// [pattern] matched against the whole value.
fn anchored(pattern: &str) -> Option<Regex> {
    Regex::new(&format!("^(?:{pattern})$")).ok()
}

fn stack_path(default: &str, stack: &Path) -> String {
    match default.strip_prefix("{stack}") {
        Some(rest) => format!("{}{rest}", stack.to_string_lossy().trim_end_matches('/')),
        None => default.to_string(),
    }
}

/// What a setting check refused: the setting, and a code the panel words.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Invalid {
    pub field: String,
    pub error: &'static str,
}

/// What the defaults depend on.
#[derive(Debug, Clone, Default)]
pub struct Machine {
    /// The stack's directory (`{stack}`).
    pub stack: PathBuf,
    /// Vendors of the GPUs the agent sees, lowercase.
    pub gpus: Vec<String>,
    /// Linux under WSL2.
    pub wsl: bool,
    /// Whether a port can be bound now; every port is free without one.
    pub port_free: Option<fn(u16) -> bool>,
}

impl Machine {
    fn free(&self, port: u16) -> bool {
        self.port_free.is_none_or(|f| f(port))
    }

    fn matches(&self, s: &Suggest) -> bool {
        s.gpu.as_ref().is_none_or(|g| self.gpus.iter().any(|v| v == g)) && s.wsl.is_none_or(|w| w == self.wsl)
    }
}

/// A checked package: the manifest and its files by name.
#[derive(Debug, Clone)]
pub struct Package {
    pub manifest: Manifest,
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
        for file in &manifest.compose.files {
            let Some(compose) = texts.get(file) else {
                problems.push(problem("compose.files", format!("{file} is not in the package")));
                continue;
            };
            let (needed, optional) = compose_variables(compose);
            for name in needed.difference(&provided) {
                problems.push(problem(file, format!("${{{name}}} is not set by the manifest")));
            }
            used.extend(needed);
            used.extend(optional);
        }
        for name in provided.difference(&used) {
            // Read by the containers through `env_file`, which Compose does not
            // name: only worth a look, so a hint rather than a refusal.
            tracing::debug!("{}: {name} is set but no compose file names it", manifest.id);
        }
        if problems.is_empty() { Ok(Self { manifest, files: texts }) } else { Err(problems) }
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
            return Err(vec![problem("id", format!("the folder is {folder}"))]);
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
        Package::read_dir(&store().join("immich")).expect("immich")
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
    fn defaults_follow_the_machine() {
        let m = immich().manifest;
        let mut machine = Machine { stack: PathBuf::from("/srv/sbm/stacks/immich"), ..Default::default() };
        let d = m.defaults(&machine);
        assert_eq!(d["library"], "/srv/sbm/stacks/immich/library");
        assert_eq!((d["ml"].as_str(), d["transcode"].as_str()), (Some("cpu"), Some("cpu")));
        assert_eq!(d["port"], 2283);

        machine.gpus = vec!["nvidia".into()];
        machine.port_free = Some(|p| p != 2283);
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
        assert_eq!(field(m.check_settings(&with("port", 80.into()), &machine)), "port");
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
        let env = m.env_file(&settings, &secrets);
        for line in [
            "IMMICH_VERSION='v3.3.1'",
            "UPLOAD_LOCATION='/srv/s/library'",
            "ML_BACKEND='cuda'",
            "ML_IMAGE_SUFFIX='-cuda'",
            "IMMICH_BIND='0.0.0.0'",
            "IMMICH_PORT='2283'",
            "DB_STORAGE_TYPE='SSD'",
            "DB_PASSWORD='abc123'",
        ] {
            assert!(env.lines().any(|l| l == line), "{line} missing in\n{env}");
        }
        // An empty optional text is left out, so the host's TZ applies.
        assert!(!env.contains("TZ="));
        assert_eq!(m.web_port(&settings), Some(2283));
        assert_eq!(m.data_paths(&settings), vec![PathBuf::from("/srv/s/library"), PathBuf::from("/srv/s/postgres")]);
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
id = "demo"
name = "Demo"
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
