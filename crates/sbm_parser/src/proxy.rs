//! Reverse proxies on Linux: nginx, Caddy and Traefik, the sites each sends
//! on to a service (a deployed app's port, another machine).
//!
//! ServerBox keeps the sites it makes in a file of its own per server and
//! rewrites it whole: [`NGINX_FILE`] (`conf.d`, which `nginx.conf` includes),
//! [`CADDY_FILE`] (imported once at the end of the Caddyfile) and
//! [`TRAEFIK_FILE`] (the file provider's folder, which Traefik watches).
//! Each site there is preceded by a `# serverbox: {…}` line holding it as
//! JSON, which is how it is read back ([`parse`]). Sites written anywhere
//! else are listed and left alone ([`Site::managed`]).
//!
//! Every value is checked before it is written ([`check_site`]): none holds
//! a line break, a quote, a brace or a semicolon, so none can close a block
//! or start a directive of its own. A change is checked by the server
//! before it takes effect (`nginx -t`, `caddy validate`) and the previous
//! file put back when it fails.

use serde::{Deserialize, Serialize};

use crate::script::{replace_file_script, shell_quote_unix as q};

pub const NGINX_FILE: &str = "/etc/nginx/conf.d/serverbox.conf";
pub const CADDY_FILE: &str = "/etc/caddy/serverbox.caddy";
pub const CADDYFILE: &str = "/etc/caddy/Caddyfile";
pub const TRAEFIK_STATIC: &str = "/etc/traefik/traefik.yml";
pub const TRAEFIK_DIR: &str = "/etc/traefik/dynamic";
pub const TRAEFIK_FILE: &str = "/etc/traefik/dynamic/serverbox.yml";

/// The Traefik release [`install_script`] fetches, by its archive's SHA-256.
pub const TRAEFIK_VERSION: &str = "3.7.13";
const TRAEFIK_ASSETS: &[(&str, &str)] = &[
    ("x86_64", "52cd039a34258dd61c617a95d69252bc6bcae27c520f338186c31c7fef8f6394"),
    ("aarch64", "9155048abd64c59000d2f3c07dc6d6919bc6be9b618e6a554bc3808338aaf8b8"),
];

/// Traefik's certificate resolver [`install_script`] sets up (Let's Encrypt,
/// HTTP challenge), when an e-mail address is given.
pub const TRAEFIK_RESOLVER: &str = "serverbox";

/// Traefik's file with no site (see [`render`]).
const TRAEFIK_NONE: &str = "http:\n  middlewares:\n    sbm-none:\n      headers:\n        customResponseHeaders:\n          X-Serverbox-None: \"\"\n";

/// A managed site's line, before its block.
const META: &str = "# serverbox: ";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Server {
    Nginx,
    Caddy,
    Traefik,
}

impl Server {
    pub const ALL: [Server; 3] = [Server::Nginx, Server::Caddy, Server::Traefik];

    pub fn id(self) -> &'static str {
        match self {
            Server::Nginx => "nginx",
            Server::Caddy => "caddy",
            Server::Traefik => "traefik",
        }
    }

    pub fn from_id(id: &str) -> Option<Server> {
        Server::ALL.into_iter().find(|s| s.id() == id)
    }
}

/// A site: requests for [domains] sent on to [upstream].
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Site {
    /// Lowercase letters, digits and `-`: the site's name in the files.
    pub name: String,
    /// Host names (`app.example.com`, `*.example.com`); for Caddy also an
    /// address (`:8081`).
    pub domains: Vec<String>,
    /// `http://127.0.0.1:2283`, `https://10.0.0.5`.
    pub upstream: String,
    /// HTTPS: Caddy's automatic certificate, Traefik's resolver, nginx's
    /// [cert] and [key].
    #[serde(default)]
    pub tls: bool,
    /// nginx: the certificate and key files (absolute paths).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cert: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub key: Option<String>,
    /// nginx: the largest request body in MiB (its default is 1).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub max_body_mb: Option<u32>,
    /// The web application firewall (`waf`) in front of it: nginx and
    /// Traefik.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub waf: bool,
    /// ServerBox's to change.
    #[serde(default)]
    pub managed: bool,
}

/// One server as read.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServerView {
    pub server: Server,
    pub installed: bool,
    pub version: Option<String>,
    pub active: bool,
    /// Traefik reads [`TRAEFIK_DIR`] (its static configuration names it):
    /// otherwise ServerBox's sites there would not be served.
    pub writable: bool,
    /// Traefik's resolver for HTTPS is set up.
    #[serde(default)]
    pub tls_resolver: bool,
    pub sites: Vec<Site>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProxyView {
    pub servers: Vec<ServerView>,
    /// Ports 80 and 443 when something listens there.
    pub listening: Vec<u16>,
}

/// What is installed and running, and every site; sections by `### <name>`
/// lines ([`parse`]). Readable without root (the configurations are
/// world-readable; a key file is never read). Running is this machine's
/// own server, not a container's process of the same name.
pub fn read_command() -> String {
    format!("{}\n{READ_BODY}", crate::script::HOST_RUNNING_FN)
}

const READ_BODY: &str = r####"echo '### tools'; for t in nginx caddy traefik; do command -v $t >/dev/null 2>&1 && echo $t; done
echo '### versions'; command -v nginx >/dev/null 2>&1 && nginx -v 2>&1; command -v caddy >/dev/null 2>&1 && echo "caddy $(caddy version 2>/dev/null)"; command -v traefik >/dev/null 2>&1 && echo "traefik $(traefik version 2>/dev/null | awk '/^Version/ {print $2}')"
echo '### active'; for s in nginx caddy traefik; do if [ "$(systemctl is-active $s 2>/dev/null)" = active ] || host_running $s; then echo $s; fi; done
echo '### listening'; ss -ltnH 2>/dev/null | awk '{print $4}' | grep -E ':(80|443)$'
echo '### nginxManaged'; cat /etc/nginx/conf.d/serverbox.conf 2>/dev/null
echo '### nginxOther'; for f in /etc/nginx/nginx.conf /etc/nginx/conf.d/*.conf /etc/nginx/sites-enabled/* /etc/nginx/http.d/*.conf; do [ -f "$f" ] && [ "$f" != /etc/nginx/conf.d/serverbox.conf ] && cat "$f" 2>/dev/null; done
echo '### caddyfile'; cat /etc/caddy/Caddyfile 2>/dev/null
echo '### caddyManaged'; cat /etc/caddy/serverbox.caddy 2>/dev/null
echo '### traefikStatic'; cat /etc/traefik/traefik.yml 2>/dev/null
echo '### traefikManaged'; cat /etc/traefik/dynamic/serverbox.yml 2>/dev/null
true"####;

fn sections(out: &str) -> std::collections::HashMap<&str, String> {
    let mut map = std::collections::HashMap::new();
    let mut current: Option<&str> = None;
    for line in out.lines() {
        if let Some(name) = line.strip_prefix("### ") {
            current = Some(name.trim());
            map.entry(name.trim()).or_insert_with(String::new);
            continue;
        }
        if let Some(c) = current {
            let s = map.get_mut(c).expect("an entry");
            s.push_str(line);
            s.push('\n');
        }
    }
    map
}

/// [`read_command`]'s output.
pub fn parse(out: &str) -> ProxyView {
    let s = sections(out);
    let get = |k: &str| s.get(k).map(String::as_str).unwrap_or("");
    let tools: Vec<&str> = get("tools").lines().map(str::trim).collect();
    let active: Vec<&str> = get("active").lines().map(str::trim).collect();
    let versions = get("versions");
    let version_of = |word: &str| {
        versions
            .lines()
            .find(|l| l.to_ascii_lowercase().contains(word))
            .and_then(|l| l.split(|c: char| c.is_whitespace() || c == '/').map(|w| w.trim_start_matches('v')).find(|w| w.chars().next().is_some_and(|c| c.is_ascii_digit()) && w.contains('.')))
            .map(str::to_string)
    };
    let traefik_static = get("traefikStatic");
    let servers = Server::ALL
        .into_iter()
        .map(|server| {
            let id = server.id();
            let mut sites = managed_sites(match server {
                Server::Nginx => get("nginxManaged"),
                Server::Caddy => get("caddyManaged"),
                Server::Traefik => get("traefikManaged"),
            });
            sites.extend(match server {
                Server::Nginx => nginx_sites(get("nginxOther")),
                Server::Caddy => caddy_sites(get("caddyfile")),
                Server::Traefik => Vec::new(),
            });
            ServerView {
                server,
                installed: tools.contains(&id),
                version: version_of(id),
                // Nothing of this machine's runs when it is not installed.
                active: tools.contains(&id) && active.contains(&id),
                writable: server != Server::Traefik || traefik_static.contains(TRAEFIK_DIR),
                tls_resolver: server == Server::Traefik && traefik_static.contains(&format!("{TRAEFIK_RESOLVER}:")),
                sites,
            }
        })
        .collect();
    let mut listening: Vec<u16> =
        get("listening").lines().filter_map(|l| l.rsplit(':').next()?.trim().parse().ok()).filter(|p| *p == 80 || *p == 443).collect();
    listening.sort_unstable();
    listening.dedup();
    ProxyView { servers, listening }
}

/// The sites of a file ServerBox wrote: each `# serverbox:` line.
fn managed_sites(text: &str) -> Vec<Site> {
    text.lines()
        .filter_map(|l| l.trim().strip_prefix(META.trim_end()))
        .filter_map(|json| serde_json::from_str::<Site>(json.trim()).ok())
        .map(|s| Site { managed: true, ..s })
        .collect()
}

/// nginx's `server` blocks in [text]: their names, and where `location /`
/// (or the first location) proxies to. A rough read, for listing only.
fn nginx_sites(text: &str) -> Vec<Site> {
    let mut out = Vec::new();
    // Comments out, braces and semicolons apart.
    let clean: String = text.lines().map(|l| l.split('#').next().unwrap_or("")).collect::<Vec<_>>().join("\n");
    let mut tokens: Vec<String> = Vec::new();
    let mut word = String::new();
    for c in clean.chars() {
        match c {
            '{' | '}' | ';' => {
                if !word.trim().is_empty() {
                    tokens.push(word.trim().to_string());
                }
                word.clear();
                tokens.push(c.to_string());
            }
            _ => word.push(c),
        }
    }
    let mut i = 0;
    while i < tokens.len() {
        if tokens[i] == "server" && tokens.get(i + 1).is_some_and(|t| t == "{") {
            let mut depth = 0;
            let mut names: Vec<String> = Vec::new();
            let mut upstream = String::new();
            let mut tls = false;
            let mut j = i + 1;
            while j < tokens.len() {
                match tokens[j].as_str() {
                    "{" => depth += 1,
                    "}" => {
                        depth -= 1;
                        if depth == 0 {
                            break;
                        }
                    }
                    t => {
                        let mut parts = t.split_whitespace();
                        match parts.next() {
                            Some("server_name") => names.extend(parts.map(str::to_string)),
                            Some("proxy_pass") if upstream.is_empty() => upstream = parts.next().unwrap_or("").to_string(),
                            Some("listen") if t.contains("ssl") || t.contains("443") => tls = true,
                            _ => {}
                        }
                    }
                }
                j += 1;
            }
            names.retain(|n| n != "_" && !n.is_empty());
            if !names.is_empty() {
                out.push(Site {
                    name: names[0].clone(),
                    domains: names,
                    upstream,
                    tls,
                    cert: None,
                    key: None,
                    max_body_mb: None,
                    waf: false,
                    managed: false,
                });
            }
            i = j;
        }
        i += 1;
    }
    out
}

/// The Caddyfile's site blocks (top-level `address… {`), each with its
/// first `reverse_proxy` target. The global options block and snippets are
/// left out.
fn caddy_sites(text: &str) -> Vec<Site> {
    let mut out = Vec::new();
    let mut depth = 0i32;
    let mut current: Option<Site> = None;
    for raw in text.lines() {
        let line = raw.split('#').next().unwrap_or("").trim();
        if line.is_empty() {
            continue;
        }
        if depth == 0 && line.ends_with('{') {
            let head = line.trim_end_matches('{').trim();
            if !head.is_empty() && !head.starts_with('(') && !head.starts_with("import") {
                let domains: Vec<String> = head.split([',', ' ']).filter(|d| !d.is_empty()).map(str::to_string).collect();
                current = Some(Site {
                    name: domains[0].clone(),
                    tls: !domains.iter().all(|d| d.starts_with("http://") || d.starts_with(':')),
                    domains,
                    upstream: String::new(),
                    cert: None,
                    key: None,
                    max_body_mb: None,
                    waf: false,
                    managed: false,
                });
            }
        }
        if depth >= 1
            && let Some(site) = current.as_mut()
            && site.upstream.is_empty()
            && let Some(rest) = line.strip_prefix("reverse_proxy")
        {
            site.upstream = rest.split_whitespace().find(|w| !w.starts_with('/') && *w != "{").unwrap_or("").to_string();
        }
        depth += line.matches('{').count() as i32 - line.matches('}').count() as i32;
        if depth == 0
            && let Some(site) = current.take()
        {
            out.push(site);
        }
    }
    out
}

/// Why a site is refused: a code a client words, and which site.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SiteError {
    pub error: &'static str,
    pub site: String,
}

fn safe(s: &str) -> bool {
    !s.is_empty() && s.len() <= 2048 && !s.chars().any(|c| c.is_control() || c.is_whitespace() || matches!(c, '"' | '\'' | '`' | '\\' | '{' | '}' | ';' | '$' | '#'))
}

fn domain_ok(d: &str, server: Server) -> bool {
    if server == Server::Caddy && d.starts_with(':') {
        return d[1..].parse::<u16>().is_ok_and(|p| p > 0);
    }
    let host = d.strip_prefix("*.").unwrap_or(d);
    (1..=253).contains(&host.len())
        && host.split('.').all(|l| (1..=63).contains(&l.len()) && !l.starts_with('-') && !l.ends_with('-'))
        && host.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-' || b == b'.')
}

/// Whether [site] can be written for [server]: every value fits the files.
pub fn check_site(site: &Site, server: Server) -> Result<(), &'static str> {
    if !(1..=40).contains(&site.name.len()) || !site.name.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-') {
        return Err("invalidName");
    }
    if site.domains.is_empty() || site.domains.len() > 16 || !site.domains.iter().all(|d| domain_ok(d, server)) {
        return Err("invalidDomain");
    }
    let upstream_ok = safe(&site.upstream)
        && (site.upstream.starts_with("http://") || site.upstream.starts_with("https://"))
        && site.upstream.split("://").nth(1).is_some_and(|rest| !rest.is_empty() && !rest.starts_with('/'));
    if !upstream_ok {
        return Err("invalidUpstream");
    }
    if server == Server::Nginx && site.tls {
        let path_ok = |p: &Option<String>| p.as_deref().is_some_and(|p| p.starts_with('/') && safe(p) && !p.split('/').any(|x| x == ".."));
        if !path_ok(&site.cert) || !path_ok(&site.key) {
            return Err("needsCertificate");
        }
    }
    if site.max_body_mb.is_some_and(|m| m == 0 || m > 100_000) {
        return Err("invalidBodySize");
    }
    if site.waf && server == Server::Caddy {
        return Err("wafUnsupported");
    }
    Ok(())
}

/// [server]'s file holding [sites] (each checked; names one each).
pub fn render(server: Server, sites: &[Site], tls_resolver: bool) -> Result<String, SiteError> {
    let mut names = std::collections::HashSet::new();
    for s in sites {
        check_site(s, server).map_err(|error| SiteError { error, site: s.name.clone() })?;
        if !names.insert(s.name.as_str()) {
            return Err(SiteError { error: "duplicate", site: s.name.clone() });
        }
        if server == Server::Traefik && s.tls && !tls_resolver {
            return Err(SiteError { error: "needsResolver", site: s.name.clone() });
        }
    }
    let meta = |s: &Site| format!("{META}{}\n", serde_json::to_string(&Site { managed: false, ..s.clone() }).unwrap_or_default());
    let mut out = String::from("# Sites made in ServerBox. Rewritten by it: changes here are lost.\n");
    match server {
        Server::Nginx => {
            for s in sites {
                out.push_str(&meta(s));
                out.push_str("server {\n");
                if s.tls {
                    out.push_str(&format!(
                        "    listen 443 ssl;\n    listen [::]:443 ssl;\n    ssl_certificate {};\n    ssl_certificate_key {};\n",
                        s.cert.as_deref().unwrap_or_default(),
                        s.key.as_deref().unwrap_or_default()
                    ));
                } else {
                    out.push_str("    listen 80;\n    listen [::]:80;\n");
                }
                out.push_str(&format!("    server_name {};\n", s.domains.join(" ")));
                if let Some(m) = s.max_body_mb {
                    out.push_str(&format!("    client_max_body_size {m}m;\n"));
                }
                if s.waf {
                    out.push_str(&format!("    modsecurity on;\n    modsecurity_rules_file {};\n", crate::waf::NGINX_RULES));
                }
                out.push_str(&format!(
                    "    location / {{\n        proxy_pass {};\n        proxy_http_version 1.1;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto $scheme;\n        proxy_set_header Upgrade $http_upgrade;\n        proxy_set_header Connection $http_connection;\n        proxy_read_timeout 1h;\n    }}\n}}\n",
                    s.upstream
                ));
            }
        }
        Server::Caddy => {
            for s in sites {
                out.push_str(&meta(s));
                let addrs: Vec<String> =
                    s.domains.iter().map(|d| if s.tls || d.starts_with(':') { d.clone() } else { format!("http://{d}") }).collect();
                out.push_str(&format!("{} {{\n    reverse_proxy {}\n}}\n", addrs.join(", "), s.upstream));
            }
        }
        Server::Traefik => {
            let mut routers = String::new();
            let mut services = String::new();
            for s in sites {
                let rule = s.domains.iter().map(|d| format!("Host(`{d}`)")).collect::<Vec<_>>().join(" || ");
                routers.push_str(&format!("    {}", meta(s)));
                routers.push_str(&format!(
                    "    sbm-{n}:\n      rule: \"{rule}\"\n      entryPoints: [\"{ep}\"]\n      service: sbm-{n}\n{waf}{tls}",
                    n = s.name,
                    ep = if s.tls { "websecure" } else { "web" },
                    tls = if s.tls { format!("      tls:\n        certResolver: {TRAEFIK_RESOLVER}\n") } else { String::new() },
                    waf = if s.waf { format!("      middlewares: [\"{}\"]\n", crate::waf::TRAEFIK_MIDDLEWARE) } else { String::new() },
                ));
                services.push_str(&format!("    sbm-{}:\n      loadBalancer:\n        servers:\n          - url: \"{}\"\n", s.name, s.upstream));
            }
            if sites.is_empty() {
                // Traefik skips an empty configuration, and refuses an empty
                // middleware, keeping the last one either way: a valid one
                // that does nothing, so the routers before go.
                out.push_str(TRAEFIK_NONE);
            } else {
                out.push_str(&format!("http:\n  routers:\n{routers}  services:\n{services}"));
            }
        }
    }
    Ok(out)
}

/// Exit code of [`write_script`]: the server refused the new file and has
/// the previous one back.
pub const EXIT_REFUSED: i32 = 4;

/// Starts [server] when it is not running, else has it read its files
/// again: through systemd where it runs, else the server's own command.
fn reload(server: Server) -> String {
    let own = match server {
        Server::Nginx => "if host_running nginx; then nginx -s reload; else nginx </dev/null >/dev/null 2>&1; fi",
        // What `caddy start` leaves running keeps its output: not the
        // script's, which a job reads to its end.
        Server::Caddy => {
            "if host_running caddy; then caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile; else caddy start --config /etc/caddy/Caddyfile --adapter caddyfile </dev/null >>/var/log/caddy-start.log 2>&1; fi"
        }
        // It watches its folder; started when it is not running.
        Server::Traefik => {
            "host_running traefik || { nohup traefik --configFile=/etc/traefik/traefik.yml </dev/null >>/var/log/traefik.log 2>&1 & }"
        }
    };
    let id = server.id();
    format!(
        "{}\nif [ -d /run/systemd/system ] && systemctl list-unit-files {id}.service >/dev/null 2>&1; then \
         if systemctl is-active -q {id}; then {}; else systemctl enable --now {id}; fi; else {own}; fi",
        crate::script::HOST_RUNNING_FN,
        if server == Server::Traefik { "true".to_string() } else { format!("systemctl reload {id}") }
    )
}

/// Root's script that makes [sites] ServerBox's for [server]: its file
/// written and checked by the server (the previous file back on refusal,
/// [`EXIT_REFUSED`]), Caddy's Caddyfile told to import it once, the server
/// reloaded or started.
pub fn write_script(server: Server, sites: &[Site], tls_resolver: bool) -> Result<String, SiteError> {
    let content = render(server, sites, tls_resolver)?;
    let tag = "SrvBoxProxy";
    Ok(match server {
        Server::Nginx => format!("{}\n{}", replace_file_script(NGINX_FILE, &content, "nginx -t", tag, EXIT_REFUSED), reload(server)),
        Server::Caddy => format!(
            "c={cf}; [ -f \"$c\" ] || printf '' > \"$c\"; grep -qxF 'import {CADDY_FILE}' \"$c\" || printf '\\n# ServerBox sites\\nimport {CADDY_FILE}\\n' >> \"$c\"\n{}\n{}",
            replace_file_script(CADDY_FILE, &content, "caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null", tag, EXIT_REFUSED),
            reload(server),
            cf = q(CADDYFILE),
        ),
        Server::Traefik => format!("{}\n{}", replace_file_script(TRAEFIK_FILE, &content, "true", tag, EXIT_REFUSED), reload(server)),
    })
}

/// Root's script that installs [server]: nginx and Caddy from the machine's
/// packages; Traefik's release ([`TRAEFIK_VERSION`], checked by SHA-256)
/// into `/usr/local/bin` with a static configuration reading
/// [`TRAEFIK_DIR`] (Let's Encrypt for HTTPS when [acme_email] is given)
/// and a systemd service.
pub fn install_script(server: Server, acme_email: Option<&str>) -> Result<String, &'static str> {
    let pkg = |name: &str| {
        format!(
            "if command -v apt-get >/dev/null; then DEBIAN_FRONTEND=noninteractive apt-get install -y {name}; \
             elif command -v dnf >/dev/null; then dnf install -y {name}; \
             elif command -v apk >/dev/null; then apk add {name}; \
             else echo 'no package manager this knows (apt, dnf, apk)' >&2; exit 1; fi"
        )
    };
    match server {
        Server::Nginx => Ok(format!("{}\n{}", pkg("nginx"), reload(server))),
        Server::Caddy => Ok(format!("{}\n{}", pkg("caddy"), reload(server))),
        Server::Traefik => {
            if let Some(e) = acme_email
                && !(e.len() <= 254 && e.contains('@') && e.bytes().all(|b| b.is_ascii_alphanumeric() || b"@.-_+".contains(&b)))
            {
                return Err("invalidEmail");
            }
            let mut cases = String::new();
            for (arch, sha) in TRAEFIK_ASSETS {
                let a = if *arch == "x86_64" { "amd64" } else { "arm64" };
                cases.push_str(&format!("  {arch}) a={a}; sha={sha};;\n"));
            }
            let resolver = match acme_email {
                Some(e) => format!(
                    "  websecure:\n    address: \":443\"\ncertificatesResolvers:\n  {TRAEFIK_RESOLVER}:\n    acme:\n      email: {e}\n      storage: /etc/traefik/acme.json\n      httpChallenge:\n        entryPoint: web\n"
                ),
                None => "  websecure:\n    address: \":443\"\n".to_string(),
            };
            Ok(format!(
                r#"set -e
case "$(uname -m)" in
{cases}  *) echo "no Traefik release for $(uname -m)" >&2; exit 1;;
esac
v={TRAEFIK_VERSION}
t=$(mktemp -d)
curl -fsSL -o "$t/traefik.tgz" "https://github.com/traefik/traefik/releases/download/v$v/traefik_v${{v}}_linux_$a.tar.gz"
echo "$sha  $t/traefik.tgz" | sha256sum -c -
tar -xzf "$t/traefik.tgz" -C "$t" traefik
install -m 755 "$t/traefik" /usr/local/bin/traefik
rm -rf "$t"
mkdir -p {TRAEFIK_DIR}
[ -f {TRAEFIK_FILE} ] || cat > {TRAEFIK_FILE} <<'SrvBoxTraefik'
{TRAEFIK_NONE}SrvBoxTraefik
if [ ! -f {TRAEFIK_STATIC} ]; then
cat > {TRAEFIK_STATIC} <<'SrvBoxTraefik'
# Written by ServerBox when it installed Traefik.
entryPoints:
  web:
    address: ":80"
{resolver}providers:
  file:
    directory: {TRAEFIK_DIR}
    watch: true
SrvBoxTraefik
fi
touch /etc/traefik/acme.json; chmod 600 /etc/traefik/acme.json
if [ -d /run/systemd/system ]; then
cat > /etc/systemd/system/traefik.service <<'SrvBoxTraefik'
[Unit]
Description=Traefik
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/traefik --configFile={TRAEFIK_STATIC}
Restart=on-failure
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
SrvBoxTraefik
systemctl daemon-reload
fi
{}"#,
                reload(server)
            ))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn site(name: &str, tls: bool) -> Site {
        Site {
            name: name.into(),
            domains: vec![format!("{name}.example.com")],
            upstream: "http://127.0.0.1:2283".into(),
            tls,
            cert: None,
            key: None,
            max_body_mb: None,
            waf: false,
            managed: true,
        }
    }

    #[test]
    fn writes_and_reads_back_each_server() {
        for server in Server::ALL {
            let sites = vec![site("photos", false), Site { max_body_mb: Some(512), ..site("files", false) }];
            let text = render(server, &sites, false).unwrap();
            let back = managed_sites(&text);
            assert_eq!(back, sites, "{server:?}:\n{text}");
        }
        let nginx = render(Server::Nginx, &[Site { max_body_mb: Some(512), ..site("files", false) }], false).unwrap();
        assert!(nginx.contains("server_name files.example.com;") && nginx.contains("client_max_body_size 512m;") && nginx.contains("proxy_pass http://127.0.0.1:2283;"));
        let caddy = render(Server::Caddy, &[site("a", false), site("b", true)], false).unwrap();
        assert!(caddy.contains("http://a.example.com {\n    reverse_proxy http://127.0.0.1:2283\n}"), "{caddy}");
        assert!(caddy.contains("\nb.example.com {"), "{caddy}");
        let traefik = render(Server::Traefik, &[site("a", true)], true).unwrap();
        assert!(traefik.contains("rule: \"Host(`a.example.com`)\"") && traefik.contains("certResolver: serverbox"), "{traefik}");
        assert!(render(Server::Traefik, &[], false).unwrap().contains("sbm-none:"), "an empty file would keep the old routers");
    }

    #[test]
    fn refuses_what_could_break_out() {
        let bad = |f: fn(&mut Site)| {
            let mut s = site("a", false);
            f(&mut s);
            Server::ALL.iter().all(|sv| check_site(&s, *sv).is_err())
        };
        assert!(bad(|s| s.upstream = "http://x;}\nserver {".into()));
        assert!(bad(|s| s.upstream = "file:///etc/passwd".into()));
        assert!(bad(|s| s.domains = vec!["a.com {".into()]));
        assert!(bad(|s| s.domains = vec!["A.com".into()]));
        assert!(bad(|s| s.name = "Has Space".into()));
        assert!(bad(|s| s.domains = vec![]));
        // nginx serves HTTPS with a certificate it is given.
        assert_eq!(check_site(&site("a", true), Server::Nginx), Err("needsCertificate"));
        let with = Site { cert: Some("/etc/ssl/a.pem".into()), key: Some("/etc/ssl/a.key".into()), ..site("a", true) };
        assert_eq!(check_site(&with, Server::Nginx), Ok(()));
        assert!(render(Server::Nginx, &[with], false).unwrap().contains("ssl_certificate /etc/ssl/a.pem;"));
        // Traefik needs its resolver for HTTPS; names are one each.
        assert_eq!(render(Server::Traefik, &[site("a", true)], false).unwrap_err().error, "needsResolver");
        assert_eq!(render(Server::Caddy, &[site("a", false), site("a", false)], false).unwrap_err().error, "duplicate");
        assert_eq!(check_site(&Site { domains: vec![":8081".into()], ..site("a", false) }, Server::Caddy), Ok(()));
        assert_eq!(check_site(&Site { waf: true, ..site("a", false) }, Server::Caddy), Err("wafUnsupported"));
        assert!(render(Server::Nginx, &[Site { waf: true, ..site("a", false) }], false).unwrap().contains("modsecurity_rules_file /etc/nginx/modsecurity/serverbox.conf;"));
        assert!(render(Server::Traefik, &[Site { waf: true, ..site("a", false) }], false).unwrap().contains("middlewares: [\"sbm-waf@file\"]"));
        assert!(check_site(&Site { domains: vec!["*.example.com".into()], ..site("a", false) }, Server::Traefik).is_ok());
    }

    #[test]
    fn reads_the_machine() {
        let out = format!(
            "### tools\nnginx\ncaddy\n### versions\nnginx version: nginx/1.28.0\ncaddy v2.10.2 h1:abc\n### active\ncaddy\ntraefik\n### listening\n0.0.0.0:80\n[::]:80\n0.0.0.0:3770\n\
             ### nginxManaged\n### nginxOther\nserver {{\n  listen 80 default_server;\n  server_name _;\n  root /var/www/html;\n}}\n\
             server {{ listen 443 ssl; server_name blog.example.com www.example.com; # x\n  location / {{ proxy_pass http://127.0.0.1:8080; }} }}\n\
             ### caddyfile\n{{\n  email a@b.c\n}}\n:80 {{\n  root * /usr/share/caddy\n  file_server\n}}\n(snip) {{\n}}\nimport /etc/caddy/serverbox.caddy\nnotes.example.com {{\n  reverse_proxy /api/* localhost:9000\n}}\n\
             ### caddyManaged\n{}### traefikStatic\n### traefikManaged\n",
            render(Server::Caddy, &[site("photos", true)], false).unwrap()
        );
        let v = parse(&out);
        let nginx = &v.servers[0];
        assert!(nginx.installed && !nginx.active);
        assert_eq!(nginx.version.as_deref(), Some("1.28.0"));
        assert_eq!(nginx.sites.len(), 1);
        assert_eq!(nginx.sites[0].domains, ["blog.example.com", "www.example.com"]);
        assert_eq!((nginx.sites[0].upstream.as_str(), nginx.sites[0].tls), ("http://127.0.0.1:8080", true));
        let caddy = &v.servers[1];
        assert_eq!(caddy.version.as_deref(), Some("2.10.2"));
        assert!(caddy.active);
        let names: Vec<(&str, bool)> = caddy.sites.iter().map(|s| (s.name.as_str(), s.managed)).collect();
        assert_eq!(names, [("photos", true), (":80", false), ("notes.example.com", false)]);
        assert_eq!(caddy.sites[2].upstream, "localhost:9000");
        assert!(!v.servers[2].installed && !v.servers[2].writable);
        assert!(!v.servers[2].active, "what runs without being installed is not this machine's");
        assert_eq!(v.listening, [80]);
    }

    #[test]
    fn scripts_check_before_they_keep() {
        let s = write_script(Server::Nginx, &[site("a", false)], false).unwrap();
        assert!(s.contains("nginx -t") && s.contains(NGINX_FILE) && s.contains("exit 4"));
        let s = write_script(Server::Caddy, &[], false).unwrap();
        assert!(s.contains("import /etc/caddy/serverbox.caddy") && s.contains("caddy validate"));
        let s = install_script(Server::Traefik, Some("ops@example.com")).unwrap();
        assert!(s.contains("sha256sum -c") && s.contains("certificatesResolvers") && s.contains(TRAEFIK_DIR));
        assert_eq!(install_script(Server::Traefik, Some("x'; rm -rf /")), Err("invalidEmail"));
        assert!(install_script(Server::Nginx, None).unwrap().contains("apt-get install -y nginx"));
    }
}
