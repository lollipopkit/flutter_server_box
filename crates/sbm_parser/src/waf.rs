//! A web application firewall in front of the reverse proxies' sites
//! (`proxy`): the OWASP Core Rule Set, run by ModSecurity v3 in nginx, the
//! machine's packages. Traefik's sites reach the same engine: its
//! ModSecurity plugin ([`PLUGIN_MODULE`], the `sbm-waf` middleware in
//! [`TRAEFIK_FILE`]) sends each request to an nginx server on loopback
//! ([`ENGINE_PORT`], [`ENGINE_CONF`]) that only runs the rules, and refuses
//! what that refuses. (Coraza's WebAssembly plugin crashes Traefik since
//! 3.4.3.) Caddy has a firewall only in a build of its own, which this does
//! not make.
//!
//! The settings ([`Settings`]: off, detecting or blocking, the paranoia
//! level, rules left out) live in ServerBox's rules file per server, a
//! `# serverbox-waf: {…}` line first, how they are read back ([`parse`]):
//! [`NGINX_RULES`] (what each nginx site with the firewall on names in
//! `modsecurity_rules_file`) and [`TRAEFIK_RULES`] (what the engine for
//! Traefik names). A site turns it on with `proxy::Site::waf`.
//!
//! What was detected and blocked goes to each one's audit log
//! ([`NGINX_AUDIT_LOG`], [`TRAEFIK_AUDIT_LOG`]), one JSON object a line
//! ([`parse_events`]). Behind Traefik the client and host are the plugin's.

use serde::{Deserialize, Serialize};

use crate::script::replace_file_script;

pub const NGINX_RULES: &str = "/etc/nginx/modsecurity/serverbox.conf";
pub const NGINX_AUDIT_LOG: &str = "/var/log/nginx/modsec_audit.json";
/// Debian's CRS, as its `owasp-crs.load` lists it: its setup, the operator's
/// exclusions, its rules. Named one by one: ModSecurity v3 has no
/// `IncludeOptional`, which that file uses.
const CRS_INCLUDES: &[&str] = &[
    "/etc/modsecurity/crs/crs-setup.conf",
    "/etc/modsecurity/crs/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf",
    "/usr/share/modsecurity-crs/rules/*.conf",
    "/etc/modsecurity/crs/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf",
];
/// The `sbm-waf` middleware, written at install.
pub const TRAEFIK_FILE: &str = "/etc/traefik/dynamic/serverbox-waf.yml";
/// The plugin Traefik fetches, as its static configuration names it.
pub const PLUGIN_MODULE: &str = "github.com/madebymode/traefik-modsecurity-plugin";
pub const PLUGIN_VERSION: &str = "v1.6.0";
pub const TRAEFIK_RULES: &str = "/etc/nginx/modsecurity/serverbox-traefik.conf";
pub const TRAEFIK_AUDIT_LOG: &str = "/var/log/nginx/modsec_audit_traefik.json";
/// nginx's server that runs [`TRAEFIK_RULES`] on what the plugin sends.
pub const ENGINE_CONF: &str = "/etc/nginx/conf.d/serverbox-waf-traefik.conf";
pub const ENGINE_PORT: u16 = 18990;
/// What answers a request the rules let through: ModSecurity sees nothing
/// nginx answers itself with `return`, so the engine passes it on to this.
const ENGINE_OK_PORT: u16 = 18991;
/// The middleware a site's router names when its firewall is on.
pub const TRAEFIK_MIDDLEWARE: &str = "sbm-waf@file";

const META: &str = "# serverbox-waf: ";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Mode {
    Off,
    /// Rules run and what matches is logged; nothing is refused.
    Detect,
    /// What scores past the threshold is refused with 403.
    Block,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Settings {
    pub mode: Mode,
    /// CRS's paranoia level, 1 (fewest false positives) to 4.
    pub paranoia: u8,
    /// Rule ids left out, for a false positive.
    #[serde(default)]
    pub exclusions: Vec<u32>,
}

impl Default for Settings {
    fn default() -> Self {
        Settings { mode: Mode::Detect, paranoia: 1, exclusions: Vec::new() }
    }
}

pub fn check(s: &Settings) -> Result<(), &'static str> {
    if !(1..=4).contains(&s.paranoia) {
        return Err("invalidParanoia");
    }
    if s.exclusions.len() > 200 || s.exclusions.iter().any(|id| *id == 0 || *id >= 10_000_000) {
        return Err("invalidRule");
    }
    Ok(())
}

/// What is installed and ServerBox's settings, by `### <name>` sections.
pub const READ_COMMAND: &str = r####"echo '### nginxModule'; ls /etc/nginx/modules-enabled 2>/dev/null | grep -i modsecurity
echo '### crs'; [ -f /usr/share/modsecurity-crs/owasp-crs.load ] && dpkg-query -W -f='${Version}\n' modsecurity-crs 2>/dev/null
echo '### nginxRules'; head -n 1 /etc/nginx/modsecurity/serverbox.conf 2>/dev/null
echo '### traefikStatic'; grep -c 'madebymode/traefik-modsecurity-plugin' /etc/traefik/traefik.yml 2>/dev/null; grep -c 'Written by ServerBox' /etc/traefik/traefik.yml 2>/dev/null
echo '### traefikMiddleware'; [ -f /etc/traefik/dynamic/serverbox-waf.yml ] && echo yes
echo '### traefikRules'; head -n 1 /etc/nginx/modsecurity/serverbox-traefik.conf 2>/dev/null
true"####;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServerWaf {
    /// The firewall can run here (nginx's module and the rules; for
    /// Traefik also its plugin and the middleware).
    pub ready: bool,
    /// It can be made ready ([`install_script`]): Traefik only when its
    /// static configuration is ServerBox's.
    pub installable: bool,
    /// ServerBox's settings, when written.
    pub settings: Option<Settings>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WafView {
    pub nginx: ServerWaf,
    pub traefik: ServerWaf,
    /// The Core Rule Set's version, from its package.
    pub crs: Option<String>,
}

fn sections(out: &str) -> std::collections::HashMap<&str, Vec<&str>> {
    let mut map: std::collections::HashMap<&str, Vec<&str>> = std::collections::HashMap::new();
    let mut current = "";
    for line in out.lines() {
        if let Some(name) = line.strip_prefix("### ") {
            current = name.trim();
            map.entry(current).or_default();
        } else if !line.trim().is_empty() {
            map.entry(current).or_default().push(line.trim());
        }
    }
    map
}

fn settings_of(line: Option<&&str>) -> Option<Settings> {
    serde_json::from_str(line?.strip_prefix(META.trim_end())?.trim()).ok()
}

/// [`READ_COMMAND`]'s output.
pub fn parse(out: &str) -> WafView {
    let s = sections(out);
    let get = |k: &str| s.get(k).cloned().unwrap_or_default();
    let crs = get("crs").first().map(|v| v.to_string());
    let traefik_static = get("traefikStatic");
    let count = |i: usize| traefik_static.get(i).and_then(|v| v.parse::<u32>().ok()).unwrap_or(0);
    let engine = !get("nginxModule").is_empty() && crs.is_some();
    WafView {
        nginx: ServerWaf { ready: engine, installable: true, settings: settings_of(get("nginxRules").first()) },
        traefik: ServerWaf {
            ready: engine && count(0) > 0 && !get("traefikMiddleware").is_empty(),
            installable: count(1) > 0,
            settings: settings_of(get("traefikRules").first()),
        },
        crs,
    }
}

fn meta(s: &Settings) -> String {
    format!("{META}{}\n", serde_json::to_string(s).unwrap_or_default())
}

/// nginx's rules file for [s]: the engine's own settings (Debian ships
/// none for nginx), the paranoia level, the Core Rule Set, the rules left
/// out.
pub fn render_nginx(s: &Settings) -> Result<String, &'static str> {
    render_rules(s, NGINX_AUDIT_LOG)
}

/// The rules the engine for Traefik runs: [`render_nginx`]'s, its own log,
/// and without 920350: the plugin sends every request with the engine's
/// address as its Host, which that rule scores as a numeric host.
pub fn render_traefik(s: &Settings) -> Result<String, &'static str> {
    Ok(render_rules(s, TRAEFIK_AUDIT_LOG)? + "SecRuleRemoveById 920350\n")
}

fn render_rules(s: &Settings, audit_log: &str) -> Result<String, &'static str> {
    check(s)?;
    let engine = match s.mode {
        Mode::Off => "Off",
        Mode::Detect => "DetectionOnly",
        Mode::Block => "On",
    };
    let mut out = meta(s);
    out.push_str(&format!(
        "# Written by ServerBox. Rewritten by it: changes here are lost.\n\
         SecRuleEngine {engine}\n\
         SecRequestBodyAccess On\n\
         SecRequestBodyLimit 13107200\n\
         SecRequestBodyNoFilesLimit 131072\n\
         SecRequestBodyLimitAction ProcessPartial\n\
         SecResponseBodyAccess Off\n\
         SecTmpDir /tmp\n\
         SecDataDir /tmp\n\
         SecArgumentSeparator &\n\
         SecCookieFormat 0\n\
         SecAuditEngine RelevantOnly\n\
         SecAuditLogRelevantStatus \"^(?:5|4(?!04))\"\n\
         SecAuditLogParts ABHZ\n\
         SecAuditLogType Serial\n\
         SecAuditLogFormat JSON\n\
         SecAuditLog {audit_log}\n\
         SecAction \"id:900000,phase:1,nolog,pass,t:none,setvar:tx.paranoia_level={p}\"\n\
         SecAction \"id:900001,phase:1,nolog,pass,t:none,setvar:tx.executing_paranoia_level={p}\"\n",
        p = s.paranoia
    ));
    for file in CRS_INCLUDES {
        out.push_str(&format!("Include {file}\n"));
    }
    for id in &s.exclusions {
        out.push_str(&format!("SecRuleRemoveById {id}\n"));
    }
    Ok(out)
}

/// The `sbm-waf` middleware: each request to the engine first.
fn traefik_middleware() -> String {
    format!(
        "# Written by ServerBox when it installed the firewall.\nhttp:\n  middlewares:\n    sbm-waf:\n      plugin:\n        modsecurity:\n          modSecurityUrl: http://127.0.0.1:{ENGINE_PORT}\n          timeoutMillis: 10000\n"
    )
}

/// The engine for Traefik: the rules on loopback, then an empty 200.
fn engine_conf() -> String {
    format!(
        "# Written by ServerBox: the firewall for Traefik's sites.\n\
         server {{ listen 127.0.0.1:{ENGINE_PORT}; access_log off; client_max_body_size 0; modsecurity on; modsecurity_rules_file {TRAEFIK_RULES}; \
         location / {{ proxy_pass http://127.0.0.1:{ENGINE_OK_PORT}; proxy_pass_request_body off; proxy_set_header Content-Length \"\"; }} }}\n\
         server {{ listen 127.0.0.1:{ENGINE_OK_PORT}; access_log off; location / {{ return 200; }} }}\n"
    )
}

/// Reloads nginx, or starts it when [start] and it is not running.
fn nginx_reload(start: bool) -> String {
    let otherwise = if start { "if [ -d /run/systemd/system ]; then systemctl enable --now nginx; else nginx; fi" } else { "true" };
    format!(
        "if pgrep -x nginx >/dev/null; then if [ -d /run/systemd/system ] && systemctl is-active -q nginx; then systemctl reload nginx; else nginx -s reload; fi; else {otherwise}; fi"
    )
}

/// Exit code of [`write_script`]: the server refused the rules and has the
/// previous ones back.
pub const EXIT_REFUSED: i32 = 4;

/// Root's script that writes [s] for nginx or Traefik and has nginx check
/// and reload them (the previous rules back on refusal). For Traefik the
/// engine's server is written with them, and taken away again when the
/// first rules are refused; nginx is started when it is not running.
pub fn write_script(server: crate::proxy::Server, s: &Settings) -> Result<String, &'static str> {
    use crate::proxy::Server;
    let tag = "SrvBoxWaf";
    match server {
        Server::Nginx => Ok(format!("{}\n{}", replace_file_script(NGINX_RULES, &render_nginx(s)?, "nginx -t", tag, EXIT_REFUSED), nginx_reload(false))),
        Server::Traefik => {
            let check = format!(
                "{{ cat > {ENGINE_CONF} <<'SrvBoxEngine'\n{}SrvBoxEngine\nnginx -t; }} || {{ [ -f {TRAEFIK_RULES}.sbm-bak ] || rm -f {ENGINE_CONF}; false; }}",
                engine_conf()
            );
            Ok(format!("{}\n{}", replace_file_script(TRAEFIK_RULES, &render_traefik(s)?, &check, tag, EXIT_REFUSED), nginx_reload(true)))
        }
        Server::Caddy => Err("unsupported"),
    }
}

const ENGINE_PACKAGES: &str = "libnginx-mod-http-modsecurity modsecurity-crs";

/// Root's script that makes the firewall able to run: nginx's ModSecurity
/// module and the Core Rule Set from the machine's packages; for Traefik
/// also nginx itself (kept from starting, its default site, which would
/// take Traefik's port 80, taken away when it was not installed before),
/// the plugin added to ServerBox's static configuration, the middleware
/// written and Traefik started again.
pub fn install_script(server: crate::proxy::Server) -> Result<String, &'static str> {
    use crate::proxy::{Server, TRAEFIK_STATIC};
    let apt = "command -v apt-get >/dev/null || { echo 'the ModSecurity module for nginx is packaged for Debian and Ubuntu alone' >&2; exit 1; }";
    match server {
        Server::Nginx => Ok(format!("set -e\n{apt}\nDEBIAN_FRONTEND=noninteractive apt-get install -y {ENGINE_PACKAGES}")),
        Server::Traefik => Ok(format!(
            r#"set -e
f={TRAEFIK_STATIC}
grep -q 'Written by ServerBox' "$f" || {{ echo "$f is not ServerBox's: add the plugin to it by hand" >&2; exit 1; }}
{apt}
if command -v nginx >/dev/null; then DEBIAN_FRONTEND=noninteractive apt-get install -y {ENGINE_PACKAGES}
else
  if [ ! -e /usr/sbin/policy-rc.d ]; then printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d; chmod 755 /usr/sbin/policy-rc.d; trap 'rm -f /usr/sbin/policy-rc.d' EXIT; fi
  DEBIAN_FRONTEND=noninteractive apt-get install -y nginx {ENGINE_PACKAGES}
  rm -f /etc/nginx/sites-enabled/default
fi
if ! grep -q '{PLUGIN_MODULE}' "$f"; then
cat >> "$f" <<'SrvBoxWaf'
experimental:
  plugins:
    modsecurity:
      moduleName: {PLUGIN_MODULE}
      version: {PLUGIN_VERSION}
SrvBoxWaf
fi
mkdir -p "$(dirname {TRAEFIK_FILE})"
cat > {TRAEFIK_FILE} <<'SrvBoxWaf'
{middleware}SrvBoxWaf
if [ -d /run/systemd/system ] && systemctl list-unit-files traefik.service >/dev/null 2>&1; then systemctl restart traefik
else pkill -x traefik || true; sleep 1; nohup traefik --configFile=$f </dev/null >>/var/log/traefik.log 2>&1 & fi"#,
            middleware = traefik_middleware()
        )),
        Server::Caddy => Err("unsupported"),
    }
}

/// The last lines of [server]'s audit log: what the firewall detected or
/// refused, newest last. Root's: the log is not world-readable.
pub fn events_command(server: crate::proxy::Server) -> Result<String, &'static str> {
    use crate::proxy::Server;
    let log = match server {
        Server::Nginx => NGINX_AUDIT_LOG,
        Server::Traefik => TRAEFIK_AUDIT_LOG,
        Server::Caddy => return Err("unsupported"),
    };
    Ok(format!("tail -n 300 {log} 2>/dev/null; true"))
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Event {
    pub time: String,
    pub client: String,
    pub host: String,
    pub method: String,
    pub uri: String,
    /// The response's status: 403 when it was refused.
    pub status: Option<u16>,
    /// The rules that matched: id and message.
    pub rules: Vec<(String, String)>,
}

/// [`events_command`]'s output, newest first.
pub fn parse_events(out: &str) -> Vec<Event> {
    let mut events: Vec<Event> = out
        .lines()
        .filter_map(|l| serde_json::from_str::<serde_json::Value>(l).ok())
        .filter_map(|v| {
            let t = &v["transaction"];
            if !t.is_object() {
                return None;
            }
            let rules = t["messages"]
                .as_array()
                .into_iter()
                .flatten()
                .map(|m| (m["details"]["ruleId"].as_str().unwrap_or("").to_string(), m["message"].as_str().unwrap_or("").to_string()))
                .filter(|(id, _)| !id.is_empty())
                .collect();
            Some(Event {
                time: t["time_stamp"].as_str().unwrap_or("").to_string(),
                client: t["client_ip"].as_str().unwrap_or("").to_string(),
                host: t["request"]["headers"]["Host"].as_str().or(t["request"]["headers"]["host"].as_str()).unwrap_or("").to_string(),
                method: t["request"]["method"].as_str().unwrap_or("").to_string(),
                uri: t["request"]["uri"].as_str().unwrap_or("").to_string(),
                status: t["response"]["http_code"].as_u64().and_then(|c| u16::try_from(c).ok()),
                rules,
            })
        })
        .collect();
    events.reverse();
    events
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::proxy::Server;

    #[test]
    fn writes_and_reads_back_settings() {
        let s = Settings { mode: Mode::Block, paranoia: 2, exclusions: vec![920350, 942100] };
        let nginx = render_nginx(&s).unwrap();
        assert!(nginx.contains("SecRuleEngine On\n") && nginx.contains("tx.paranoia_level=2") && nginx.contains("SecRuleRemoveById 942100\n"));
        assert!(nginx.contains("Include /usr/share/modsecurity-crs/rules/*.conf\n") && !nginx.contains("IncludeOptional"));
        let traefik = render_traefik(&Settings { mode: Mode::Detect, ..s.clone() }).unwrap();
        assert!(traefik.contains("SecRuleEngine DetectionOnly\n") && traefik.contains(TRAEFIK_AUDIT_LOG) && traefik.ends_with("SecRuleRemoveById 920350\n"), "{traefik}");
        let out = format!(
            "### nginxModule\n50-mod-http-modsecurity.conf\n### crs\n3.3.8-1\n### nginxRules\n{}### traefikStatic\n0\n1\n### traefikMiddleware\nyes\n### traefikRules\n",
            nginx.lines().next().unwrap().to_string() + "\n"
        );
        let v = parse(&out);
        assert!(v.nginx.ready && v.nginx.settings.as_ref() == Some(&s));
        assert_eq!(v.crs.as_deref(), Some("3.3.8-1"));
        assert!(!v.traefik.ready && v.traefik.installable && v.traefik.settings.is_none());
    }

    #[test]
    fn refuses_what_does_not_fit() {
        assert_eq!(check(&Settings { paranoia: 5, ..Default::default() }), Err("invalidParanoia"));
        assert_eq!(check(&Settings { exclusions: vec![0], ..Default::default() }), Err("invalidRule"));
        assert_eq!(write_script(Server::Caddy, &Settings::default()), Err("unsupported"));
        let nginx = write_script(Server::Nginx, &Settings::default()).unwrap();
        assert!(nginx.contains("nginx -t") && nginx.contains(NGINX_RULES));
        let traefik = write_script(Server::Traefik, &Settings::default()).unwrap();
        assert!(traefik.contains(ENGINE_CONF) && traefik.contains(&format!("listen 127.0.0.1:{ENGINE_PORT}")) && traefik.contains("systemctl enable --now nginx"));
        let install = install_script(Server::Traefik).unwrap();
        assert!(install.contains(PLUGIN_VERSION) && install.contains(&format!("modSecurityUrl: http://127.0.0.1:{ENGINE_PORT}")));
        assert!(events_command(Server::Traefik).unwrap().contains(TRAEFIK_AUDIT_LOG));
    }

    #[test]
    fn reads_the_audit_log() {
        let line = r#"{"transaction":{"client_ip":"10.0.0.9","time_stamp":"Sat Oct 17 01:02:03 2026","request":{"method":"GET","uri":"/?q=<script>","headers":{"Host":"e2e.test"}},"response":{"http_code":403},"messages":[{"message":"XSS Attack Detected via libinjection","details":{"ruleId":"941100"}}]}}"#;
        let events = parse_events(&format!("{line}\nnot json\n"));
        assert_eq!(events.len(), 1);
        let e = &events[0];
        assert_eq!((e.client.as_str(), e.host.as_str(), e.status), ("10.0.0.9", "e2e.test", Some(403)));
        assert_eq!(e.rules, [("941100".to_string(), "XSS Attack Detected via libinjection".to_string())]);
    }
}
