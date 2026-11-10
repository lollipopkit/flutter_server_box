//! Ubuntu Pro through its client (`pro`): whether the machine is attached to
//! a subscription, to which account and contract, until when, the services
//! (Livepatch, ESM, FIPS, the realtime kernel, …) with what each is
//! entitled to and whether it runs, and Livepatch's own state.
//!
//! Changes are root's, one at a time ([`Action`], checked against a fresh
//! [`parse`] by [`check`], run as [`script`]): install the client, attach
//! with a token (read from a file only the agent's account and root can
//! read, never on a command line; [`attach_config`]), detach, enable or
//! disable a service.

use serde::{Deserialize, Serialize};
use serde_json::Value;

/// What [`parse`] reads, by `### <name>` sections. Not root's: `pro status`
/// answers any account.
pub const READ_COMMAND: &str = r####"echo '### os'; ( . /etc/os-release 2>/dev/null; echo "$ID"; echo "$VERSION_ID" )
echo '### status'; command -v pro >/dev/null && pro status --all --format json 2>/dev/null
echo
echo '### livepatch'; command -v canonical-livepatch >/dev/null && canonical-livepatch status --format json 2>/dev/null
echo
true"####;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Service {
    pub name: String,
    pub description: String,
    /// Offered for this release and machine.
    pub available: bool,
    /// The contract covers it (attached only).
    pub entitled: Option<bool>,
    /// `enabled`, `disabled`, `warning`, `n/a` (attached only).
    pub status: Option<String>,
    pub status_details: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Livepatch {
    pub kernel: Option<String>,
    /// `applied`, `nothing-to-apply`, `unapplied`, `kernel-upgrade-required`…
    pub state: Option<String>,
    pub version: Option<String>,
    /// Whether this kernel is one Livepatch patches.
    pub supported: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProView {
    /// Ubuntu: the only system Pro attaches.
    pub ubuntu: bool,
    pub release: Option<String>,
    /// The client is installed (`pro`).
    pub client: Option<String>,
    pub attached: bool,
    pub account: Option<String>,
    pub contract: Option<String>,
    pub expires: Option<String>,
    pub tech_support: Option<String>,
    pub services: Vec<Service>,
    pub livepatch: Option<Livepatch>,
}

fn sections(out: &str) -> std::collections::HashMap<&str, String> {
    let mut map: std::collections::HashMap<&str, String> = std::collections::HashMap::new();
    let mut current = "";
    for line in out.lines() {
        if let Some(name) = line.strip_prefix("### ") {
            current = name.trim();
            map.entry(current).or_default();
        } else if !line.trim().is_empty() {
            let s = map.entry(current).or_default();
            s.push_str(line);
            s.push('\n');
        }
    }
    map
}

fn text(v: &Value) -> Option<String> {
    v.as_str().map(str::trim).filter(|s| !s.is_empty()).map(str::to_string)
}

fn yes(v: &Value) -> Option<bool> {
    match v {
        Value::Bool(b) => Some(*b),
        Value::String(s) => match s.as_str() {
            "yes" => Some(true),
            "no" => Some(false),
            _ => None,
        },
        _ => None,
    }
}

/// A key in Livepatch's JSON, which has used both cases.
fn field<'a>(v: &'a Value, key: &str) -> &'a Value {
    let Some(map) = v.as_object() else { return &Value::Null };
    map.iter().find(|(k, _)| k.eq_ignore_ascii_case(key)).map(|(_, v)| v).unwrap_or(&Value::Null)
}

fn livepatch(out: &str) -> Option<Livepatch> {
    let v: Value = serde_json::from_str(out.trim()).ok()?;
    let status = field(&v, "status");
    let running = status.as_array().and_then(|a| a.iter().find(|k| field(k, "running").as_bool() == Some(true)).or(a.first()))?;
    let lp = field(running, "livepatch");
    Some(Livepatch {
        kernel: text(field(running, "kernel")),
        state: text(field(lp, "patchState")).or_else(|| text(field(lp, "state"))),
        version: text(field(lp, "version")),
        supported: text(field(running, "supported")),
    })
}

/// [`READ_COMMAND`]'s output.
pub fn parse(out: &str) -> ProView {
    let s = sections(out);
    let os: Vec<&str> = s.get("os").map(|o| o.lines().collect()).unwrap_or_default();
    let status: Value = s.get("status").and_then(|t| serde_json::from_str(t.trim()).ok()).unwrap_or(Value::Null);
    let services = status["services"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|v| {
            Some(Service {
                name: text(&v["name"])?,
                description: text(&v["description_override"]).or_else(|| text(&v["description"])).unwrap_or_default(),
                // Attached, `available` is left out of a service the
                // contract has; it is offered then.
                available: yes(&v["available"]).unwrap_or(true),
                entitled: yes(&v["entitled"]),
                status: text(&v["status"]),
                status_details: text(&v["status_details"]),
            })
        })
        .collect();
    ProView {
        ubuntu: os.first().map(|i| i.trim()) == Some("ubuntu"),
        release: os.get(1).map(|r| r.trim().to_string()).filter(|r| !r.is_empty()),
        client: text(&status["version"]),
        attached: status["attached"].as_bool().unwrap_or(false),
        account: text(&status["account"]["name"]),
        contract: text(&status["contract"]["name"]),
        expires: text(&status["expires"]),
        tech_support: text(&status["contract"]["tech_support_level"]).filter(|t| t != "n/a"),
        services,
        livepatch: s.get("livepatch").and_then(|t| livepatch(t)),
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "action", rename_all = "camelCase", rename_all_fields = "camelCase")]
pub enum Action {
    /// `ubuntu-pro-client` from the archive.
    InstallClient,
    /// The token travels apart ([`attach_config`]); [auto_enable] lets the
    /// contract turn on what it recommends (ESM, Livepatch).
    Attach {
        #[serde(default)]
        auto_enable: bool,
    },
    Detach,
    Enable { service: String },
    Disable { service: String },
}

/// A token as the Pro dashboard shows one.
pub fn token_ok(token: &str) -> bool {
    (16..=64).contains(&token.len()) && token.bytes().all(|b| b.is_ascii_alphanumeric())
}

/// Whether [a] may run on the machine [v] describes; the refusal's code.
pub fn check(v: &ProView, a: &Action) -> Result<(), &'static str> {
    if !v.ubuntu {
        return Err("notUbuntu");
    }
    if v.client.is_none() && *a != Action::InstallClient {
        return Err("noClient");
    }
    match a {
        Action::InstallClient if v.client.is_some() => Err("installed"),
        Action::InstallClient => Ok(()),
        Action::Attach { .. } if v.attached => Err("attached"),
        Action::Attach { .. } => Ok(()),
        _ if !v.attached => Err("notAttached"),
        Action::Detach => Ok(()),
        Action::Enable { service } | Action::Disable { service } => {
            let s = v.services.iter().find(|s| &s.name == service).ok_or("unknownService")?;
            let enable = matches!(a, Action::Enable { .. });
            if enable && (s.entitled == Some(false) || !s.available) {
                return Err("notEntitled");
            }
            match (enable, s.status.as_deref()) {
                (true, Some("enabled")) => Err("enabled"),
                (false, Some("disabled" | "n/a")) => Err("disabled"),
                _ => Ok(()),
            }
        }
    }
}

/// The attach configuration [`script`] reads, written to a private file.
pub fn attach_config(token: &str) -> Option<String> {
    token_ok(token).then(|| format!("token: {token}\n"))
}

/// Root's script for [a], after [`check`]. [config] is the private file
/// holding [`attach_config`] (attach only).
pub fn script(a: &Action, config: Option<&str>) -> Result<String, &'static str> {
    let q = crate::script::shell_quote_unix;
    Ok(match a {
        Action::InstallClient => "set -e\nexport DEBIAN_FRONTEND=noninteractive\napt-get update -q\napt-get install -y ubuntu-pro-client".to_string(),
        Action::Attach { auto_enable } => {
            let config = config.ok_or("noToken")?;
            format!("pro attach --attach-config {}{}", q(config), if *auto_enable { "" } else { " --no-auto-enable" })
        }
        Action::Detach => "pro detach --assume-yes".to_string(),
        Action::Enable { service } => format!("pro enable {} --assume-yes", q(service)),
        Action::Disable { service } => format!("pro disable {} --assume-yes", q(service)),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    const UNATTACHED: &str = r#"{"attached": false, "account": {"name": ""}, "contract": {"name": "", "tech_support_level": "n/a"}, "expires": null, "version": "37.2ubuntu0.1",
      "services": [{"available": "yes", "description": "Canonical Livepatch service", "description_override": null, "name": "livepatch"},
                   {"available": "no", "description": "Ubuntu kernel with PREEMPT_RT patches integrated", "description_override": null, "name": "realtime-kernel"}]}"#;
    const ATTACHED: &str = r#"{"attached": true, "account": {"name": "someone"}, "contract": {"name": "Ubuntu Pro - free personal subscription", "tech_support_level": "n/a"}, "expires": "9999-12-31T00:00:00+00:00", "version": "37.2ubuntu0.1",
      "services": [{"name": "esm-infra", "description": "Expanded Security Maintenance for Infrastructure", "entitled": "yes", "status": "enabled", "status_details": "Ubuntu Pro: ESM Infra is active", "available": "yes"},
                   {"name": "livepatch", "description": "Canonical Livepatch service", "entitled": "yes", "status": "disabled", "status_details": "", "available": "yes"},
                   {"name": "fips", "description": "NIST-certified FIPS crypto packages", "entitled": "no", "status": "n/a", "available": "no"}]}"#;

    fn out(status: &str, livepatch: &str) -> String {
        format!("### os\nubuntu\n26.04\n### status\n{status}\n\n### livepatch\n{livepatch}\n\n")
    }

    #[test]
    fn reads_unattached_and_attached() {
        let v = parse(&out(UNATTACHED, ""));
        assert!(v.ubuntu && !v.attached && v.client.as_deref() == Some("37.2ubuntu0.1") && v.release.as_deref() == Some("26.04"));
        assert_eq!(v.services.len(), 2);
        assert!(v.services[0].available && !v.services[1].available && v.services[0].entitled.is_none());
        assert_eq!(v.tech_support, None);

        let lp = r#"{"client-version": "10.8.3", "status": [{"kernel": "7.0.0-34.34-generic", "running": true, "livepatch": {"checkState": "checked", "patchState": "nothing-to-apply", "version": ""}, "supported": "supported"}]}"#;
        let v = parse(&out(ATTACHED, lp));
        assert!(v.attached && v.account.as_deref() == Some("someone") && v.expires.is_some());
        let livepatch = v.livepatch.unwrap();
        assert_eq!((livepatch.state.as_deref(), livepatch.kernel.as_deref(), livepatch.version), (Some("nothing-to-apply"), Some("7.0.0-34.34-generic"), None));
        assert_eq!(v.services[1].status.as_deref(), Some("disabled"));
        assert_eq!(parse("### os\ndebian\n13\n### status\n\n### livepatch\n").client, None);
    }

    #[test]
    fn refuses_what_does_not_apply() {
        let un = parse(&out(UNATTACHED, ""));
        let at = parse(&out(ATTACHED, ""));
        let enable = |v: &ProView, s: &str| check(v, &Action::Enable { service: s.into() });
        assert_eq!(enable(&un, "livepatch"), Err("notAttached"));
        assert_eq!(check(&un, &Action::Attach { auto_enable: false }), Ok(()));
        assert_eq!(check(&at, &Action::Attach { auto_enable: false }), Err("attached"));
        assert_eq!(enable(&at, "livepatch"), Ok(()));
        assert_eq!(enable(&at, "esm-infra"), Err("enabled"));
        assert_eq!(enable(&at, "fips"), Err("notEntitled"));
        assert_eq!(enable(&at, "nope"), Err("unknownService"));
        assert_eq!(check(&at, &Action::Disable { service: "livepatch".into() }), Err("disabled"));
        assert_eq!(check(&at, &Action::InstallClient), Err("installed"));
        let mut debian = un.clone();
        debian.ubuntu = false;
        assert_eq!(check(&debian, &Action::Detach), Err("notUbuntu"));
    }

    #[test]
    fn keeps_the_token_off_the_command_line() {
        let a: Action = serde_json::from_str(r#"{"action":"attach","autoEnable":true}"#).unwrap();
        assert_eq!(a, Action::Attach { auto_enable: true });
        assert_eq!(attach_config("C1xQwT5dTn7yQvMsWbA3ue"), Some("token: C1xQwT5dTn7yQvMsWbA3ue\n".into()));
        assert_eq!(attach_config("short"), None);
        assert_eq!(attach_config("C1xQwT5dTn7yQvMsWbA3ue\nenable_services: [fips]"), None);
        let s = script(&Action::Attach { auto_enable: false }, Some("/tmp/sbm-root-x.sh")).unwrap();
        assert_eq!(s, "pro attach --attach-config '/tmp/sbm-root-x.sh' --no-auto-enable");
        assert_eq!(script(&Action::Attach { auto_enable: true }, None), Err("noToken"));
        assert_eq!(script(&Action::Enable { service: "livepatch".into() }, None).unwrap(), "pro enable 'livepatch' --assume-yes");
    }
}
