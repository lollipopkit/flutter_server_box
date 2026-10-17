//! Tailscale on this machine, through its CLI: installed and running or
//! not, signed in or waiting for a sign-in (the URL to open), this device
//! and its tailnet, the peers (online, how they are reached, which offer an
//! exit node or routes), and the settings `tailscale set` changes.
//!
//! Reading is any account's (tailscaled's socket answers status and prefs
//! to everyone); changes are root's, one at a time ([`Action`], checked
//! against a fresh [`parse`] by [`check`], run as [`script`]). An auth key
//! goes in a file only the agent's account and root can read
//! (`--auth-key=file:<path>`), never on a command line. Connecting again
//! after `tailscale down` repeats every non-default setting ([`up_args`]),
//! as `tailscale up` requires.
//!
//! Using an exit node sends this machine's traffic through it, its LAN's
//! too unless `exit-node-allow-lan-access` is on, which cuts a panel that
//! reaches the agent over the LAN off: [`check`] refuses an exit node
//! without it unless the caller says so.

use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::script::shell_quote_unix as q;

/// What [`parse`] reads, by `### <name>` sections: tailscaled is this
/// machine's, not a container's (`script::HOST_RUNNING_FN`).
pub fn read_command() -> String {
    format!("{}\n{READ_BODY}", crate::script::HOST_RUNNING_FN)
}

const READ_BODY: &str = r####"echo '### os'; ( . /etc/os-release 2>/dev/null; echo "$ID"; echo "$VERSION_CODENAME" )
echo '### version'; command -v tailscale >/dev/null && tailscale version 2>/dev/null | head -n 1
echo '### daemon'; if command -v systemctl >/dev/null && [ -d /run/systemd/system ]; then systemctl is-active tailscaled 2>/dev/null; else host_running tailscaled && echo active; fi
echo '### status'; command -v tailscale >/dev/null && tailscale status --json 2>/dev/null
echo
echo '### prefs'; command -v tailscale >/dev/null && tailscale debug prefs 2>/dev/null
echo
true"####;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Peer {
    /// The control server's id, what `--exit-node` is matched against.
    pub id: String,
    pub name: String,
    pub dns_name: Option<String>,
    pub ips: Vec<String>,
    pub os: Option<String>,
    pub online: bool,
    /// Traffic went to it lately.
    pub active: bool,
    /// It offers itself as an exit node.
    pub exit_node_option: bool,
    /// This machine uses it as its exit node.
    pub exit_node: bool,
    /// Subnets it routes for the tailnet.
    pub routes: Vec<String>,
    /// Reached directly at this address; none is through a relay.
    pub direct: Option<String>,
    pub relay: Option<String>,
    pub rx_bytes: u64,
    pub tx_bytes: u64,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Prefs {
    /// Empty is Tailscale's own.
    pub control_url: String,
    pub hostname: String,
    pub accept_routes: bool,
    pub accept_dns: bool,
    pub ssh: bool,
    pub shields_up: bool,
    pub want_running: bool,
    pub logged_out: bool,
    pub exit_node_id: String,
    pub exit_node_ip: String,
    pub exit_node_allow_lan: bool,
    /// Without the two default routes, which say exit node.
    pub advertise_routes: Vec<String>,
    pub advertise_exit_node: bool,
    pub operator: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TailscaleView {
    /// Debian or Ubuntu: installable from Tailscale's repository here.
    pub installable: bool,
    pub version: Option<String>,
    pub daemon: bool,
    /// `NoState`, `NeedsLogin`, `NeedsMachineAuth`, `Stopped`, `Starting`, `Running`.
    pub state: Option<String>,
    /// Where to sign in, while a sign-in waits.
    pub auth_url: Option<String>,
    pub name: Option<String>,
    pub dns_name: Option<String>,
    pub ips: Vec<String>,
    pub tailnet: Option<String>,
    pub user: Option<String>,
    pub health: Vec<String>,
    pub peers: Vec<Peer>,
    pub prefs: Option<Prefs>,
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
    v.as_str().map(|s| s.trim().trim_end_matches('.')).filter(|s| !s.is_empty()).map(str::to_string)
}

fn strings(v: &Value) -> Vec<String> {
    v.as_array().into_iter().flatten().filter_map(|s| s.as_str().map(str::to_string)).collect()
}

const DEFAULT_ROUTES: [&str; 2] = ["0.0.0.0/0", "::/0"];

fn prefs(v: &Value) -> Prefs {
    let routes = strings(&v["AdvertiseRoutes"]);
    Prefs {
        control_url: v["ControlURL"].as_str().unwrap_or("").to_string(),
        hostname: v["Hostname"].as_str().unwrap_or("").to_string(),
        accept_routes: v["RouteAll"].as_bool().unwrap_or(false),
        accept_dns: v["CorpDNS"].as_bool().unwrap_or(true),
        ssh: v["RunSSH"].as_bool().unwrap_or(false),
        shields_up: v["ShieldsUp"].as_bool().unwrap_or(false),
        want_running: v["WantRunning"].as_bool().unwrap_or(false),
        logged_out: v["LoggedOut"].as_bool().unwrap_or(false),
        exit_node_id: v["ExitNodeID"].as_str().unwrap_or("").to_string(),
        exit_node_ip: v["ExitNodeIP"].as_str().unwrap_or("").to_string(),
        exit_node_allow_lan: v["ExitNodeAllowLANAccess"].as_bool().unwrap_or(false),
        advertise_exit_node: DEFAULT_ROUTES.iter().all(|d| routes.iter().any(|r| r == d)),
        advertise_routes: routes.into_iter().filter(|r| !DEFAULT_ROUTES.contains(&r.as_str())).collect(),
        operator: v["OperatorUser"].as_str().unwrap_or("").to_string(),
    }
}

/// [`read_command`]'s output.
pub fn parse(out: &str) -> TailscaleView {
    let s = sections(out);
    let os: Vec<String> = s.get("os").map(|o| o.lines().map(|l| l.trim().to_string()).collect()).unwrap_or_default();
    let status: Value = s.get("status").and_then(|t| serde_json::from_str(t.trim()).ok()).unwrap_or(Value::Null);
    let prefs_json: Option<Value> = s.get("prefs").and_then(|t| serde_json::from_str(t.trim()).ok());
    let me = &status["Self"];
    let mut peers: Vec<Peer> = status["Peer"]
        .as_object()
        .into_iter()
        .flat_map(|m| m.values())
        .map(|p| Peer {
            id: p["ID"].as_str().unwrap_or("").to_string(),
            name: text(&p["HostName"]).unwrap_or_default(),
            dns_name: text(&p["DNSName"]),
            ips: strings(&p["TailscaleIPs"]),
            os: text(&p["OS"]),
            online: p["Online"].as_bool().unwrap_or(false),
            active: p["Active"].as_bool().unwrap_or(false),
            exit_node_option: p["ExitNodeOption"].as_bool().unwrap_or(false),
            exit_node: p["ExitNode"].as_bool().unwrap_or(false),
            routes: strings(&p["PrimaryRoutes"]),
            direct: text(&p["CurAddr"]),
            relay: text(&p["Relay"]).filter(|r| r != "none"),
            rx_bytes: p["RxBytes"].as_u64().unwrap_or(0),
            tx_bytes: p["TxBytes"].as_u64().unwrap_or(0),
        })
        .collect();
    peers.sort_by(|a, b| b.online.cmp(&a.online).then_with(|| a.name.cmp(&b.name)));
    let user = me["UserID"].as_u64().and_then(|id| text(&status["User"][id.to_string()]["LoginName"]));
    TailscaleView {
        installable: matches!(os.first().map(String::as_str), Some("debian" | "ubuntu")) && os.get(1).is_some_and(|c| !c.is_empty()),
        version: s.get("version").map(|v| v.trim().to_string()).filter(|v| !v.is_empty()),
        daemon: s.get("daemon").is_some_and(|d| d.trim() == "active"),
        state: text(&status["BackendState"]),
        auth_url: text(&status["AuthURL"]),
        name: text(&me["HostName"]),
        dns_name: text(&me["DNSName"]),
        ips: strings(&status["TailscaleIPs"]),
        tailnet: text(&status["CurrentTailnet"]["Name"]),
        user,
        health: strings(&status["Health"]),
        peers,
        prefs: prefs_json.as_ref().map(prefs),
    }
}

/// What `tailscale set` changes; an absent field stays as it is.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Settings {
    /// A peer's id or Tailscale IP; empty uses none.
    pub exit_node: Option<String>,
    pub exit_node_allow_lan: Option<bool>,
    pub accept_routes: Option<bool>,
    pub accept_dns: Option<bool>,
    pub ssh: Option<bool>,
    pub shields_up: Option<bool>,
    pub hostname: Option<String>,
    pub advertise_exit_node: Option<bool>,
    pub advertise_routes: Option<Vec<String>>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "action", rename_all = "camelCase", rename_all_fields = "camelCase")]
pub enum Action {
    /// From Tailscale's own repository (Debian, Ubuntu), the daemon started.
    Install,
    /// The daemon started and enabled.
    StartDaemon,
    /// Sign in: with an auth key (travelling apart), or waiting for the
    /// sign-in URL to be opened.
    Login {
        #[serde(default)]
        login_server: Option<String>,
        #[serde(default)]
        hostname: Option<String>,
    },
    Logout,
    /// `tailscale up` with the settings it had.
    Connect,
    Disconnect,
    Set {
        settings: Settings,
        /// The caller knows an exit node without LAN access cuts this
        /// machine's LAN off.
        #[serde(default)]
        lan_cut_ok: bool,
    },
}

fn hostname_ok(h: &str) -> bool {
    !h.is_empty() && h.len() <= 63 && h.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-') && !h.starts_with('-') && !h.ends_with('-')
}

fn url_ok(u: &str) -> bool {
    (u.starts_with("https://") || u.starts_with("http://")) && u.len() <= 256 && !u.bytes().any(|b| b.is_ascii_whitespace() || b.is_ascii_control() || b"'\"`$\\".contains(&b))
}

/// An IPv4 or IPv6 prefix in canonical form.
fn cidr_ok(c: &str) -> bool {
    let Some((ip, len)) = c.split_once('/') else { return false };
    let Ok(len) = len.parse::<u8>() else { return false };
    match ip.parse::<std::net::IpAddr>() {
        Ok(std::net::IpAddr::V4(_)) => len <= 32,
        Ok(std::net::IpAddr::V6(_)) => len <= 128,
        Err(_) => false,
    }
}

/// An auth key as the admin console or a control server gives one.
pub fn auth_key_ok(key: &str) -> bool {
    (16..=200).contains(&key.len()) && key.bytes().all(|b| b.is_ascii_alphanumeric() || b"-_:".contains(&b))
}

/// Whether [a] may run on the machine [v] describes; the refusal's code.
pub fn check(v: &TailscaleView, a: &Action) -> Result<(), &'static str> {
    let installed = v.version.is_some();
    match a {
        Action::Install if installed => Err("installed"),
        Action::Install if !v.installable => Err("notInstallable"),
        Action::Install => Ok(()),
        _ if !installed => Err("notInstalled"),
        Action::StartDaemon if v.daemon => Err("running"),
        Action::StartDaemon => Ok(()),
        _ if !v.daemon => Err("daemonStopped"),
        Action::Login { login_server, hostname } => {
            if login_server.as_deref().is_some_and(|u| !u.is_empty() && !url_ok(u)) {
                return Err("invalidServer");
            }
            if hostname.as_deref().is_some_and(|h| !h.is_empty() && !hostname_ok(h)) {
                return Err("invalidHostname");
            }
            match v.state.as_deref() {
                Some("NeedsLogin" | "NoState") | None => Ok(()),
                _ => Err("signedIn"),
            }
        }
        _ if matches!(v.state.as_deref(), Some("NeedsLogin" | "NoState") | None) => Err("notSignedIn"),
        Action::Logout => Ok(()),
        Action::Connect if v.state.as_deref() == Some("Running") => Err("connected"),
        Action::Connect => Ok(()),
        Action::Disconnect if v.state.as_deref() != Some("Running") => Err("disconnected"),
        Action::Disconnect => Ok(()),
        Action::Set { settings: s, lan_cut_ok } => {
            if s.hostname.as_deref().is_some_and(|h| !h.is_empty() && !hostname_ok(h)) {
                return Err("invalidHostname");
            }
            if s.advertise_routes.as_ref().is_some_and(|r| r.len() > 64 || r.iter().any(|c| !cidr_ok(c))) {
                return Err("invalidRoute");
            }
            if let Some(exit) = s.exit_node.as_deref().filter(|e| !e.is_empty()) {
                let peer = peer(v, exit).ok_or("unknownPeer")?;
                if !peer.exit_node_option {
                    return Err("notExitNode");
                }
                let advertising = s.advertise_exit_node.or(v.prefs.as_ref().map(|p| p.advertise_exit_node)).unwrap_or(false);
                if advertising {
                    return Err("exitNodeConflict");
                }
                let lan = s.exit_node_allow_lan.or(v.prefs.as_ref().map(|p| p.exit_node_allow_lan)).unwrap_or(false);
                if !lan && !lan_cut_ok {
                    return Err("lanCut");
                }
            }
            let using = s.exit_node.as_deref().map(|e| !e.is_empty()).unwrap_or_else(|| v.peers.iter().any(|p| p.exit_node));
            if s.advertise_exit_node == Some(true) && using {
                return Err("exitNodeConflict");
            }
            if *s == Settings::default() {
                return Err("nothingChanged");
            }
            Ok(())
        }
    }
}

/// The peer [key] names: its id or one of its Tailscale IPs.
fn peer<'a>(v: &'a TailscaleView, key: &str) -> Option<&'a Peer> {
    v.peers.iter().find(|p| p.id == key || p.ips.iter().any(|ip| ip == key))
}

/// What `--exit-node` takes for [key] (an id or an IP): the peer's
/// Tailscale IP; it refuses an id.
fn exit_node_ip(v: &TailscaleView, key: &str) -> String {
    peer(v, key).and_then(|p| p.ips.iter().find(|ip| !ip.contains(':')).or(p.ips.first())).cloned().unwrap_or_else(|| key.to_string())
}

/// `tailscale up`'s flags that keep [p] as it is: it refuses to change a
/// setting it is not told about. [v]'s peers turn the exit node's id into
/// its IP.
pub fn up_args(p: &Prefs, v: &TailscaleView) -> Vec<String> {
    let mut a = Vec::new();
    if !p.control_url.is_empty() {
        a.push(format!("--login-server={}", p.control_url));
    }
    if !p.hostname.is_empty() {
        a.push(format!("--hostname={}", p.hostname));
    }
    a.push(format!("--accept-routes={}", p.accept_routes));
    a.push(format!("--accept-dns={}", p.accept_dns));
    a.push(format!("--ssh={}", p.ssh));
    a.push(format!("--shields-up={}", p.shields_up));
    a.push(format!("--advertise-exit-node={}", p.advertise_exit_node));
    a.push(format!("--advertise-routes={}", p.advertise_routes.join(",")));
    let exit = if !p.exit_node_ip.is_empty() {
        p.exit_node_ip.clone()
    } else if !p.exit_node_id.is_empty() {
        exit_node_ip(v, &p.exit_node_id)
    } else {
        String::new()
    };
    a.push(format!("--exit-node={exit}"));
    if !exit.is_empty() {
        a.push(format!("--exit-node-allow-lan-access={}", p.exit_node_allow_lan));
    }
    if !p.operator.is_empty() {
        a.push(format!("--operator={}", p.operator));
    }
    a
}

/// `tailscale set`'s flags for [s].
fn set_args(s: &Settings, v: &TailscaleView) -> Vec<String> {
    let mut a = Vec::new();
    let flag = |name: &str, v: Option<bool>| v.map(|b| format!("--{name}={b}"));
    if let Some(e) = &s.exit_node {
        a.push(format!("--exit-node={}", if e.is_empty() { String::new() } else { exit_node_ip(v, e) }));
    }
    a.extend(flag("exit-node-allow-lan-access", s.exit_node_allow_lan));
    a.extend(flag("accept-routes", s.accept_routes));
    a.extend(flag("accept-dns", s.accept_dns));
    a.extend(flag("ssh", s.ssh));
    a.extend(flag("shields-up", s.shields_up));
    a.extend(flag("advertise-exit-node", s.advertise_exit_node));
    if let Some(h) = &s.hostname {
        a.push(format!("--hostname={h}"));
    }
    if let Some(r) = &s.advertise_routes {
        a.push(format!("--advertise-routes={}", r.join(",")));
    }
    a
}

/// How long an interactive sign-in waits for its URL to be opened.
pub const LOGIN_WAIT_SECS: u32 = 900;

/// Root's script for [a], after [`check`] against [v]. [os] and
/// [codename] name Tailscale's repository (install); [key_file] holds an
/// auth key (login).
pub fn script(a: &Action, v: &TailscaleView, os: &str, codename: &str, key_file: Option<&str>) -> Result<String, &'static str> {
    let quoted = |args: Vec<String>| args.iter().map(|x| q(x)).collect::<Vec<_>>().join(" ");
    Ok(match a {
        Action::Install => {
            if !matches!(os, "debian" | "ubuntu") || codename.is_empty() || !codename.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit()) {
                return Err("notInstallable");
            }
            format!(
                "set -e\nexport DEBIAN_FRONTEND=noninteractive\n\
                 curl -fsSL https://pkgs.tailscale.com/stable/{os}/{codename}.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg\n\
                 echo 'deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/{os} {codename} main' > /etc/apt/sources.list.d/tailscale.list\n\
                 apt-get update -q\napt-get install -y tailscale\n\
                 if [ -d /run/systemd/system ]; then systemctl enable --now tailscaled; fi\ntailscale version | head -n 1"
            )
        }
        Action::StartDaemon => "systemctl enable --now tailscaled".to_string(),
        Action::Login { login_server, hostname } => {
            let mut args = vec!["up".to_string()];
            if let Some(u) = login_server.as_deref().filter(|u| !u.is_empty()) {
                args.push(format!("--login-server={u}"));
            }
            if let Some(h) = hostname.as_deref().filter(|h| !h.is_empty()) {
                args.push(format!("--hostname={h}"));
            }
            match key_file {
                Some(f) => args.push(format!("--auth-key=file:{f}")),
                None => args.push(format!("--timeout={LOGIN_WAIT_SECS}s")),
            }
            format!("tailscale {}", quoted(args))
        }
        Action::Logout => "tailscale logout".to_string(),
        Action::Connect => {
            let p = v.prefs.as_ref().ok_or("unreadable")?;
            format!("tailscale up {}", quoted(up_args(p, v)))
        }
        Action::Disconnect => "tailscale down".to_string(),
        Action::Set { settings, .. } => format!("tailscale set {}", quoted(set_args(settings, v))),
    })
}

/// `tailscale ping` to [ip], any account's: how a peer is reached.
pub fn ping_command(ip: &str) -> Option<String> {
    ip.parse::<std::net::IpAddr>().ok().map(|ip| format!("tailscale ping -c 3 --timeout 5s {ip} 2>&1"))
}

#[cfg(test)]
mod tests {
    use super::*;

    const STATUS: &str = r#"{"BackendState": "Running", "AuthURL": "", "TailscaleIPs": ["100.64.0.2", "fd7a:115c:a1e0::2"],
      "Self": {"HostName": "main", "DNSName": "main.e2e.test.", "UserID": 1},
      "CurrentTailnet": {"Name": "e2e.example", "MagicDNSSuffix": "e2e.test"},
      "Health": ["Tailscale could not connect to the 'None' relay server."],
      "User": {"1": {"ID": 1, "LoginName": "e2e"}},
      "Peer": {"nodekey:a": {"ID": "1", "HostName": "peer", "DNSName": "peer.e2e.test.", "TailscaleIPs": ["100.64.0.1"], "OS": "linux", "Online": true, "Active": true,
        "ExitNode": true, "ExitNodeOption": true, "PrimaryRoutes": ["10.99.0.0/24"], "CurAddr": "192.168.31.231:41642", "Relay": "none", "RxBytes": 10, "TxBytes": 20},
        "nodekey:b": {"ID": "2", "HostName": "laptop", "TailscaleIPs": ["100.64.0.3"], "Online": false, "CurAddr": "", "Relay": "fra"}}}"#;
    const PREFS: &str = r#"{"ControlURL": "http://127.0.0.1:8080", "RouteAll": true, "ExitNodeID": "1", "ExitNodeIP": "", "ExitNodeAllowLANAccess": true, "CorpDNS": true,
      "RunSSH": false, "WantRunning": true, "LoggedOut": false, "ShieldsUp": false, "Hostname": "main", "AdvertiseRoutes": ["0.0.0.0/0", "::/0", "10.10.0.0/16"], "OperatorUser": ""}"#;

    fn out(status: &str, prefs: &str) -> String {
        format!("### os\nubuntu\nresolute\n### version\n1.104.1\n### daemon\nactive\n### status\n{status}\n\n### prefs\n{prefs}\n\n")
    }

    #[test]
    fn reads_status_and_prefs() {
        let v = parse(&out(STATUS, PREFS));
        assert!(v.installable && v.daemon && v.version.as_deref() == Some("1.104.1"));
        assert_eq!((v.state.as_deref(), v.name.as_deref(), v.dns_name.as_deref(), v.user.as_deref()), (Some("Running"), Some("main"), Some("main.e2e.test"), Some("e2e")));
        assert_eq!(v.auth_url, None);
        let peer = &v.peers[0];
        assert_eq!((peer.name.as_str(), peer.direct.as_deref(), peer.relay.as_deref()), ("peer", Some("192.168.31.231:41642"), None));
        assert!(peer.exit_node && peer.exit_node_option && peer.routes == ["10.99.0.0/24"]);
        assert_eq!((v.peers[1].name.as_str(), v.peers[1].online, v.peers[1].relay.as_deref()), ("laptop", false, Some("fra")));
        let p = v.prefs.unwrap();
        assert!(p.advertise_exit_node && p.advertise_routes == ["10.10.0.0/16"] && p.accept_routes && p.exit_node_allow_lan);
        let waiting = parse(&out(r#"{"BackendState": "NeedsLogin", "AuthURL": "http://127.0.0.1:8080/register/hskey-authreq-x"}"#, ""));
        assert_eq!(waiting.auth_url.as_deref(), Some("http://127.0.0.1:8080/register/hskey-authreq-x"));
        assert!(parse("### os\nfedora\n\n### version\n### daemon\n").version.is_none());
    }

    #[test]
    fn refuses_what_would_cut_the_machine_off_or_does_not_fit() {
        let v = parse(&out(STATUS, PREFS));
        let set = |s: Settings, ok: bool| check(&v, &Action::Set { settings: s, lan_cut_ok: ok });
        let exit = |lan: Option<bool>| Settings { exit_node: Some("100.64.0.1".into()), exit_node_allow_lan: lan, ..Default::default() };
        assert_eq!(set(Settings { advertise_exit_node: Some(false), ..exit(Some(false)) }, false), Err("lanCut"));
        assert_eq!(set(Settings { advertise_exit_node: Some(false), ..exit(Some(false)) }, true), Ok(()));
        let mut plain = v.clone();
        plain.prefs.as_mut().unwrap().advertise_exit_node = false;
        let set_plain = |s: Settings, ok: bool| check(&plain, &Action::Set { settings: s, lan_cut_ok: ok });
        assert_eq!(set(exit(None), false), Err("exitNodeConflict"), "it advertises itself as one");
        assert_eq!(set_plain(exit(None), false), Ok(()), "LAN access is on already");
        assert_eq!(set_plain(Settings { advertise_exit_node: Some(true), ..Default::default() }, false), Err("exitNodeConflict"), "it uses one");
        assert_eq!(set(Settings { exit_node: Some("2".into()), ..Default::default() }, false), Err("notExitNode"));
        assert_eq!(set(Settings { exit_node: Some("9".into()), ..Default::default() }, false), Err("unknownPeer"));
        assert_eq!(set(Settings { exit_node: Some(String::new()), ..Default::default() }, false), Ok(()));
        assert_eq!(set(Settings { advertise_routes: Some(vec!["10.0.0.0/33".into()]), ..Default::default() }, false), Err("invalidRoute"));
        assert_eq!(set(Settings { hostname: Some("bad name".into()), ..Default::default() }, false), Err("invalidHostname"));
        assert_eq!(set(Settings::default(), false), Err("nothingChanged"));
        assert_eq!(check(&v, &Action::Login { login_server: None, hostname: None }), Err("signedIn"));
        assert_eq!(check(&v, &Action::Connect), Err("connected"));
        assert_eq!(check(&v, &Action::Disconnect), Ok(()));
        assert_eq!(check(&v, &Action::Install), Err("installed"));
        let out_ = parse(&out(r#"{"BackendState": "NeedsLogin"}"#, ""));
        assert_eq!(check(&out_, &Action::Login { login_server: Some("http://x y".into()), hostname: None }), Err("invalidServer"));
        assert_eq!(check(&out_, &Action::Logout), Err("notSignedIn"));
    }

    #[test]
    fn scripts_keep_secrets_and_settings() {
        let v = parse(&out(STATUS, PREFS));
        let mut using = v.clone();
        using.prefs.as_mut().unwrap().advertise_exit_node = false;
        let up = script(&Action::Connect, &using, "", "", None).unwrap();
        assert!(up.contains("'--login-server=http://127.0.0.1:8080'") && up.contains("'--exit-node=100.64.0.1'") && up.contains("'--advertise-routes=10.10.0.0/16'"));
        assert!(up.contains("'--advertise-exit-node=false'") && up.contains("'--exit-node-allow-lan-access=true'"));
        let login = script(&Action::Login { login_server: Some("http://127.0.0.1:8080".into()), hostname: Some("main".into()) }, &v, "", "", Some("/tmp/sbm-root-k.sh")).unwrap();
        assert_eq!(login, "tailscale 'up' '--login-server=http://127.0.0.1:8080' '--hostname=main' '--auth-key=file:/tmp/sbm-root-k.sh'");
        assert!(script(&Action::Login { login_server: None, hostname: None }, &v, "", "", None).unwrap().contains("--timeout=900s"));
        let s = Settings { exit_node: Some(String::new()), accept_routes: Some(false), ..Default::default() };
        assert_eq!(script(&Action::Set { settings: s, lan_cut_ok: false }, &v, "", "", None).unwrap(), "tailscale set '--exit-node=' '--accept-routes=false'");
        let by_id = Settings { exit_node: Some("1".into()), ..Default::default() };
        assert_eq!(script(&Action::Set { settings: by_id, lan_cut_ok: false }, &v, "", "", None).unwrap(), "tailscale set '--exit-node=100.64.0.1'");
        assert!(script(&Action::Install, &v, "ubuntu", "resolute", None).unwrap().contains("stable/ubuntu resolute main"));
        assert_eq!(script(&Action::Install, &v, "fedora", "x", None), Err("notInstallable"));
        assert!(auth_key_ok("hskey-auth-AbCdEf0123456789_xyz") && !auth_key_ok("a b"));
        assert_eq!(ping_command("100.64.0.1").as_deref(), Some("tailscale ping -c 3 --timeout 5s 100.64.0.1 2>&1"));
        assert_eq!(ping_command("100.64.0.1; reboot"), None);
    }
}
