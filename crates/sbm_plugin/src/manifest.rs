//! `manifest.json`, the one file that says what a plugin is.
//!
//! Parsed here rather than in Dart so there is one parser: the host reads it to
//! build [`Grants`], the app reads the same struct over FFI to draw the install
//! dialog, the editor form and the contributions. Two parsers would disagree
//! about a permission eventually, and the one that decides is this one.

use std::collections::{BTreeMap, BTreeSet};

use serde::{Deserialize, Serialize};

use crate::runtime::ABI_VERSION;
use crate::permission::{Grants, Permission};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Manifest {
    /// Reverse-DNS, and the key everything else is stored under.
    pub id: String,
    pub version: String,

    /// Which host ABI this was built against. Refused when higher than
    /// [`ABI_VERSION`]; the index keeps several versions of a plugin so an
    /// older app still finds one it can run.
    pub abi: u32,

    /// Shown when no `l10n/<locale>.json` has a name.
    pub name: String,
    #[serde(default)]
    pub description: String,

    #[serde(default)]
    pub permissions: Permissions,

    #[serde(default)]
    pub config: ConfigSchema,

    #[serde(default)]
    pub contributes: Contributions,

    /// Which hosts this plugin may run in. `["app"]` when absent.
    ///
    /// Declaring `agent` is a promise about what it uses: the monitor agent
    /// has no user, so nothing in `sb.ui`, `sb.nav` or `sb.clipboard` exists
    /// there and neither does `sb.server.list`. The promise is not taken on
    /// trust — those functions are installed as stubs that throw, as an
    /// ungranted one already is — so a plugin that breaks it fails on the call
    /// rather than silently doing less.
    ///
    /// A UI contribution is refused alongside `agent` at parse time, because
    /// there is nothing on a headless daemon for it to draw on. See
    /// PLUGINS.md 9.5.
    #[serde(default = "default_runs_in")]
    pub runs_in: Vec<String>,

    /// Locales `l10n/<locale>.json` exists for. `en` is the fallback and must
    /// be present.
    #[serde(default)]
    pub l10n: Vec<String>,

    #[serde(default)]
    pub license: Option<String>,
    #[serde(default)]
    pub source_url: Option<String>,
}

fn default_runs_in() -> Vec<String> {
    vec!["app".to_string()]
}

impl Manifest {
    pub fn parse(bytes: &[u8]) -> Result<Self, crate::error::PluginError> {
        let m: Manifest = serde_json::from_slice(bytes)
            .map_err(|e| crate::error::PluginError::Manifest(e.to_string()))?;
        m.validate()?;
        Ok(m)
    }

    fn validate(&self) -> Result<(), crate::error::PluginError> {
        let err = |m: String| Err(crate::error::PluginError::Manifest(m));
        if self.id.trim().is_empty() {
            return err("`id` is empty".into());
        }
        if self.abi > ABI_VERSION {
            return err(format!(
                "plugin needs ABI v{}, this build implements v{ABI_VERSION}",
                self.abi
            ));
        }
        for name in self.permissions.declared.keys() {
            if Permission::parse(name).is_none() {
                return err(format!("unknown permission `{name}`"));
            }
        }
        if let Some(status) = &self.contributes.status {
            if status.id.trim().is_empty() {
                return err("`contributes.status.id` is empty".into());
            }
            if status.platforms.is_empty() {
                return err("`contributes.status` names no platform".into());
            }
            // The command it answers with is run on the user's server, which
            // is exactly what `server.exec` means. Requiring it here rather
            // than checking at the call site is what puts a status plugin in
            // front of the user through the machinery that already exists:
            // the install dialog lists permissions, and this is one of them.
            //
            // PLUGINS.md 9.2 — a plugin that does not execute anything itself
            // is still arranging for something to be executed.
            if !self.permissions.contains(Permission::ServerExec) {
                return err(
                    "`contributes.status` runs a command on the server, so the manifest must \
                     ask for `server.exec`"
                        .into(),
                );
            }
        }
        let mut hosts = Vec::new();
        for name in &self.runs_in {
            match crate::hostfn::HostProfile::parse(name) {
                Some(h) => hosts.push(h),
                None => return err(format!("unknown host in `runs_in`: `{name}`")),
            }
        }
        if hosts.is_empty() {
            return err("`runs_in` names no host".into());
        }
        // A headless daemon has nothing to draw on, so a plugin that says it
        // runs there and contributes an interface is describing something that
        // cannot exist. Refused at parse time rather than silently ignored,
        // because the author is telling us two things that contradict.
        if hosts.contains(&crate::hostfn::HostProfile::Agent) && self.contributes.has_ui() {
            return err(
                "`runs_in` includes `agent`, which has no user interface — a tab, page, card \
                 or settings contribution cannot run there"
                    .into(),
            );
        }

        // A `$config.<key>` pattern that names no field would be a grant with
        // nothing behind it, and the install dialog would show the user an
        // address that never resolves.
        let keys: BTreeSet<&str> = self.config.fields.iter().map(|f| f.key.as_str()).collect();
        for p in self.permissions.http_patterns() {
            if let Some(key) = p.strip_prefix("$config.") {
                if !keys.contains(key) {
                    return err(format!("`net.http` names `$config.{key}`, which is not a field"));
                }
            }
        }
        Ok(())
    }

    /// What this plugin may actually do right now.
    ///
    /// The intersection of what the manifest asks for and what the user agreed
    /// to, never the manifest alone: an update that adds a permission must not
    /// be able to use it before the user has seen it (section 6.2).
    pub fn resolve_grants(
        &self,
        consented: &BTreeSet<Permission>,
        config: &BTreeMap<String, String>,
    ) -> Grants {
        let effective: Vec<Permission> = self
            .permissions
            .declared
            .keys()
            .filter_map(|n| Permission::parse(n))
            .filter(|p| consented.contains(p))
            .collect();

        let patterns = self
            .permissions
            .http_patterns()
            .iter()
            .filter_map(|p| match p.strip_prefix("$config.") {
                // An unfilled address field reaches nothing rather than
                // everything: dropping the entry is the safe direction, since
                // an empty pattern would otherwise read as a bare host name.
                Some(key) => config.get(key).filter(|v| !v.trim().is_empty()).cloned(),
                None => Some(p.clone()),
            })
            .collect::<Vec<_>>();

        Grants::new(effective).with_http_patterns(patterns)
    }

    /// Whether this plugin may run in [`profile`](crate::hostfn::HostProfile).
    pub fn runs_in_host(&self, profile: crate::hostfn::HostProfile) -> bool {
        self.runs_in.iter().any(|n| {
            crate::hostfn::HostProfile::parse(n) == Some(profile)
        })
    }

    /// Every permission the manifest asks for, which is what the install dialog
    /// lists and what `plugin_install.granted` is seeded from.
    pub fn requested(&self) -> Vec<Permission> {
        self.permissions.declared.keys().filter_map(|n| Permission::parse(n)).collect()
    }
}

/// `permissions` in the manifest.
///
/// An object rather than a list because one of them carries data:
/// `"net.http": ["$config.addr"]`. The others are `true`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(transparent)]
pub struct Permissions {
    declared: BTreeMap<String, serde_json::Value>,
}

impl Permissions {
    pub fn new(declared: BTreeMap<String, serde_json::Value>) -> Self {
        Self { declared }
    }

    pub fn contains(&self, p: Permission) -> bool {
        self.declared.contains_key(p.name())
    }

    /// The entries of `net.http`, unresolved — a literal host or
    /// `$config.<key>`.
    pub fn http_patterns(&self) -> Vec<String> {
        match self.declared.get(Permission::NetHttp.name()) {
            Some(serde_json::Value::Array(items)) => items
                .iter()
                .filter_map(|v| v.as_str().map(str::to_string))
                .collect(),
            Some(serde_json::Value::String(s)) => vec![s.clone()],
            _ => Vec::new(),
        }
    }
}

/// The server-editor form. Section 5.2: these do **not** go through the widget
/// vocabulary, because the app already has the form controls and a settings
/// page that looks like the rest of the app is worth more than a customisable
/// one.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ConfigSchema {
    #[serde(default)]
    pub fields: Vec<ConfigField>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfigField {
    pub key: String,
    #[serde(rename = "type")]
    pub kind: FieldKind,
    /// An `l10n.` key or a literal.
    pub label: String,
    #[serde(default)]
    pub hint: Option<String>,
    #[serde(default)]
    pub default: Option<String>,

    /// Kept out of a shared server, the way `bmc.credId` already is.
    #[serde(default)]
    pub secret: bool,

    #[serde(default)]
    pub required: bool,

    /// `address` marks the field a `$config.<key>` http pattern may name. A
    /// pattern pointing at a field that is not an address would let a plugin
    /// widen its own reach by writing to any config value.
    #[serde(default)]
    pub role: Option<FieldRole>,

    /// For [`FieldKind::Select`], when the choices are fixed.
    #[serde(default)]
    pub options: Vec<FieldOption>,

    /// For [`FieldKind::Select`], when they are not.
    ///
    /// The value passed to the plugin's `configOptions(key)` export, which
    /// answers `{"options": [{"value", "label"}]}`. What it exists for is
    /// picking one of something the plugin itself stores: a BMC account is
    /// shared by a rack, so the choices are records in the plugin's own
    /// key-value namespace and no manifest can enumerate them.
    #[serde(default)]
    pub options_from: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FieldKind {
    Text,
    Password,
    Bool,
    Int,
    Select,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FieldRole {
    Address,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldOption {
    pub value: String,
    pub label: String,
}

/// Where this plugin appears. Each of these replaces one `enum` case plus its
/// `switch` arms in the tables of section 1.3.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Contributions {
    /// A card on the server detail page.
    #[serde(default)]
    pub card: Option<CardContribution>,
    /// A button in the server function bar, opening a page.
    #[serde(default)]
    pub page: Option<PageContribution>,
    /// A tab on the home page.
    #[serde(default)]
    pub tab: Option<TabContribution>,
    /// A section on the settings page.
    #[serde(default)]
    pub settings: Option<SettingsContribution>,
    /// Readings on the server status page. PLUGINS.md section 9.
    #[serde(default)]
    pub status: Option<StatusContribution>,
}

impl Contributions {
    /// Whether any of these draws something.
    ///
    /// `status` is not one: it answers a command and a reading, and the host
    /// draws it with its own widgets — which is exactly why it is the
    /// contribution an agent can carry.
    pub fn has_ui(&self) -> bool {
        self.card.is_some()
            || self.page.is_some()
            || self.tab.is_some()
            || self.settings.is_some()
    }
}

/// Readings on the status page, collected by a command the host runs.
///
/// No surface: the plugin answers `statusCmd(platform)` with a command and
/// `parse(text)` with a [`crate::StatusResult`], and the app draws it with the
/// widgets it draws its own readings with.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StatusContribution {
    /// Stable within the plugin; the stored id is `<plugin id>:<this>`.
    pub id: String,
    pub label: String,
    #[serde(default)]
    pub icon: Option<String>,
    #[serde(default)]
    pub default_on: bool,
    /// See [`CardContribution::requires_config`].
    #[serde(default)]
    pub requires_config: bool,

    /// The platforms it has a command for.
    ///
    /// Declared rather than discovered by asking. A plugin that only knows
    /// Linux would otherwise be called on every BSD host in the list, once per
    /// collection, to answer nothing — or worse, to answer a Linux command,
    /// which is a command that fails on the machine it was sent to.
    pub platforms: Vec<Platform>,
}

/// What `statusCmd` is asked about, and the only values it is asked with.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Platform {
    Linux,
    Bsd,
    Windows,
}

impl Platform {
    pub const ALL: [Platform; 3] = [Platform::Linux, Platform::Bsd, Platform::Windows];

    pub const fn name(self) -> &'static str {
        match self {
            Platform::Linux => "linux",
            Platform::Bsd => "bsd",
            Platform::Windows => "windows",
        }
    }

    pub fn parse(name: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|p| p.name() == name)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CardContribution {
    /// Stable within the plugin; the stored id is `<plugin id>:<this>`.
    pub id: String,
    pub label: String,
    #[serde(default)]
    pub icon: Option<String>,
    /// Whether a fresh install adds it to the user's card order. Replaces
    /// `introducedAfterBuild`: a bundled plugin is installed by the release
    /// that carries it, which is the same moment.
    #[serde(default)]
    pub default_on: bool,

    /// Show this only on a server that has configuration for the plugin.
    ///
    /// Not a nicety. A card that appeared on every server to say "not
    /// configured" would be a row of noise on the machines that have no BMC,
    /// which is most of them — and the plugin cannot decide it for itself,
    /// because deciding means being instantiated and instantiated is already
    /// the cost.
    #[serde(default)]
    pub requires_config: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PageContribution {
    pub id: String,
    pub label: String,
    #[serde(default)]
    pub icon: Option<String>,
    #[serde(default)]
    pub default_on: bool,
    /// What the server must be able to do for the button to appear — the
    /// `availableWith` switch, moved into data.
    #[serde(default)]
    pub needs: Vec<String>,
    /// See [`CardContribution::requires_config`].
    #[serde(default)]
    pub requires_config: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TabContribution {
    pub id: String,
    pub label: String,
    #[serde(default)]
    pub icon: Option<String>,
    #[serde(default)]
    pub default_on: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SettingsContribution {
    pub id: String,
    pub label: String,
    #[serde(default)]
    pub icon: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::hostfn::HostProfile;

    const BMC: &str = r#"{
      "id": "app.serverbox.bmc",
      "version": "1.0.0",
      "abi": 1,
      "name": "BMC",
      "permissions": { "net.http": ["$config.addr"], "ui.dialog": true },
      "config": { "fields": [
        {"key": "addr", "type": "text", "label": "l10n.addr", "role": "address", "required": true},
        {"key": "pwd", "type": "password", "label": "l10n.pwd", "secret": true}
      ]},
      "contributes": { "card": {"id": "bmc", "label": "BMC", "default_on": true} },
      "l10n": ["en", "zh"]
    }"#;

    fn consented(ps: &[Permission]) -> BTreeSet<Permission> {
        ps.iter().copied().collect()
    }

    #[test]
    fn parses_and_lists_what_it_wants() {
        let m = Manifest::parse(BMC.as_bytes()).unwrap();
        assert_eq!(m.id, "app.serverbox.bmc");
        assert_eq!(m.requested(), vec![Permission::NetHttp, Permission::UiDialog]);
        assert_eq!(m.contributes.card.as_ref().unwrap().id, "bmc");
    }

    #[test]
    fn a_config_pattern_resolves_to_what_the_user_typed() {
        let m = Manifest::parse(BMC.as_bytes()).unwrap();
        let cfg = BTreeMap::from([("addr".to_string(), "https://10.0.0.9".to_string())]);
        let g = m.resolve_grants(&consented(&[Permission::NetHttp]), &cfg);
        assert!(g.allows_url("https://10.0.0.9/redfish/v1/"));
        assert!(!g.allows_url("https://10.0.0.10/redfish/v1/"));
    }

    #[test]
    fn an_unfilled_address_reaches_nothing() {
        let m = Manifest::parse(BMC.as_bytes()).unwrap();
        let g = m.resolve_grants(&consented(&[Permission::NetHttp]), &BTreeMap::new());
        assert!(!g.allows_url("https://10.0.0.9/"));
        let cfg = BTreeMap::from([("addr".to_string(), "   ".to_string())]);
        let g = m.resolve_grants(&consented(&[Permission::NetHttp]), &cfg);
        assert!(!g.allows_url("https://10.0.0.9/"));
    }

    #[test]
    fn what_the_user_did_not_consent_to_is_not_granted() {
        let m = Manifest::parse(BMC.as_bytes()).unwrap();
        let cfg = BTreeMap::from([("addr".to_string(), "https://10.0.0.9".to_string())]);
        let g = m.resolve_grants(&consented(&[Permission::UiDialog]), &cfg);
        assert!(!g.allows(Permission::NetHttp));
        assert!(!g.allows_url("https://10.0.0.9/"));
        assert!(g.allows(Permission::UiDialog));
    }

    #[test]
    fn consent_to_something_the_manifest_never_asked_for_grants_nothing() {
        let m = Manifest::parse(BMC.as_bytes()).unwrap();
        let g = m.resolve_grants(&consented(Permission::ALL), &BTreeMap::new());
        assert!(!g.allows(Permission::ServerExec));
        assert!(g.allows(Permission::UiDialog));
    }

    /// The app unless the manifest says otherwise. Every plugin written before
    /// `runs_in` existed says nothing, and every one of them is an app plugin.
    #[test]
    fn a_manifest_that_says_nothing_runs_in_the_app_only() {
        let m = Manifest::parse(BMC.as_bytes()).unwrap();
        assert!(m.runs_in_host(HostProfile::App));
        assert!(!m.runs_in_host(HostProfile::Agent));
    }

    #[test]
    fn a_status_plugin_may_say_it_runs_in_the_agent() {
        let json = r#"{
          "id": "p", "version": "1", "abi": 1, "name": "P",
          "runs_in": ["app", "agent"],
          "permissions": { "server.exec": true },
          "contributes": { "status": {
            "id": "s", "label": "S", "platforms": ["linux"]
          } }
        }"#;
        let m = Manifest::parse(json.as_bytes()).unwrap();
        assert!(m.runs_in_host(HostProfile::Agent));
        assert!(m.runs_in_host(HostProfile::App));
    }

    /// A headless daemon has nothing to draw on. The author is telling us two
    /// things that contradict, so this is refused rather than half-honoured.
    #[test]
    fn a_ui_contribution_cannot_run_in_the_agent() {
        let json = r#"{
          "id": "p", "version": "1", "abi": 1, "name": "P",
          "runs_in": ["agent"],
          "contributes": { "card": { "id": "c", "label": "C" } }
        }"#;
        let e = Manifest::parse(json.as_bytes()).unwrap_err();
        assert!(format!("{e}").contains("no user interface"), "{e}");
    }

    /// A status contribution is not a UI one: it answers a command and a
    /// reading, and the host draws it with its own widgets — which is exactly
    /// why it is the contribution an agent can carry.
    #[test]
    fn a_status_contribution_is_not_a_user_interface() {
        let json = r#"{
          "id": "p", "version": "1", "abi": 1, "name": "P",
          "permissions": { "server.exec": true },
          "contributes": { "status": {
            "id": "s", "label": "S", "platforms": ["linux"]
          } }
        }"#;
        let m = Manifest::parse(json.as_bytes()).unwrap();
        assert!(!m.contributes.has_ui());
    }

    #[test]
    fn an_unknown_host_is_refused_rather_than_ignored() {
        let json = r#"{
          "id": "p", "version": "1", "abi": 1, "name": "P",
          "runs_in": ["app", "toaster"]
        }"#;
        let e = Manifest::parse(json.as_bytes()).unwrap_err();
        assert!(format!("{e}").contains("toaster"), "{e}");
    }

    #[test]
    fn an_empty_runs_in_is_refused() {
        let json = r#"{ "id": "p", "version": "1", "abi": 1, "name": "P", "runs_in": [] }"#;
        assert!(Manifest::parse(json.as_bytes()).is_err());
    }

    #[test]
    fn a_newer_abi_is_refused_with_both_numbers() {
        let src = BMC.replace("\"abi\": 1", "\"abi\": 99");
        let e = Manifest::parse(src.as_bytes()).unwrap_err();
        assert!(e.to_string().contains("v99"), "{e}");
        assert!(e.to_string().contains(&format!("v{ABI_VERSION}")), "{e}");
    }

    #[test]
    fn an_unknown_permission_is_refused_rather_than_ignored() {
        let src = BMC.replace("\"ui.dialog\": true", "\"fs.write\": true");
        let e = Manifest::parse(src.as_bytes()).unwrap_err();
        assert!(e.to_string().contains("fs.write"), "{e}");
    }

    #[test]
    fn a_config_pattern_must_name_a_field_that_exists() {
        let src = BMC.replace("$config.addr", "$config.nope");
        let e = Manifest::parse(src.as_bytes()).unwrap_err();
        assert!(e.to_string().contains("nope"), "{e}");
    }
}
