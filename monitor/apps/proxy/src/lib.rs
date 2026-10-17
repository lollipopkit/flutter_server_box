//! Reverse proxy's backend: nginx, Caddy and Traefik and their sites
//! (`sbm_parser::proxy`), and the firewall (`sbm_parser::waf`). Reads run as
//! the agent's account; a change of sites or firewall settings is written as
//! root in the call (the server checks it, the previous file comes back on a
//! refusal); installs are jobs.

wit_bindgen::generate!({ path: ["../../wit", "wit"], world: "serverbox:proxy/proxy", generate_all });

use exports::serverbox::proxy::api::{self, Mode, Proxies, Server, ServerView, ServerWaf, Site, Firewall, WafEvent, WafSettings, WebApp};
use exports::serverbox::proxy::jobs;
use sbm::app::types::Error;
use sbm::app::{agent, host, job};
use sbm_parser::{proxy as px, waf as wf};

struct App;

fn server(s: Server) -> px::Server {
    match s {
        Server::Nginx => px::Server::Nginx,
        Server::Caddy => px::Server::Caddy,
        Server::Traefik => px::Server::Traefik,
    }
}

fn server_back(s: px::Server) -> Server {
    match s {
        px::Server::Nginx => Server::Nginx,
        px::Server::Caddy => Server::Caddy,
        px::Server::Traefik => Server::Traefik,
    }
}

fn site(s: px::Site) -> Site {
    Site { name: s.name, domains: s.domains, upstream: s.upstream, tls: s.tls, cert: s.cert, key: s.key, max_body_mb: s.max_body_mb, waf: s.waf, managed: s.managed }
}

fn site_in(s: Site) -> px::Site {
    px::Site { name: s.name, domains: s.domains, upstream: s.upstream, tls: s.tls, cert: s.cert, key: s.key, max_body_mb: s.max_body_mb, waf: s.waf, managed: s.managed }
}

fn read() -> Result<px::ProxyView, Error> {
    let out = host::exec(&px::read_command(), None)?;
    Ok(px::parse(&String::from_utf8_lossy(&out.stdout)))
}

fn proxies(v: px::ProxyView) -> Proxies {
    Proxies {
        servers: v
            .servers
            .into_iter()
            .map(|s| ServerView {
                server: server_back(s.server),
                installed: s.installed,
                version: s.version,
                active: s.active,
                writable: s.writable,
                tls_resolver: s.tls_resolver,
                sites: s.sites.into_iter().map(site).collect(),
            })
            .collect(),
        listening: v.listening,
    }
}

fn read_waf() -> Result<wf::WafView, Error> {
    let out = host::exec(wf::READ_COMMAND, None)?;
    Ok(wf::parse(&String::from_utf8_lossy(&out.stdout)))
}

fn settings(s: wf::Settings) -> WafSettings {
    WafSettings {
        mode: match s.mode {
            wf::Mode::Off => Mode::Off,
            wf::Mode::Detect => Mode::Detect,
            wf::Mode::Block => Mode::Block,
        },
        paranoia: s.paranoia,
        exclusions: s.exclusions,
    }
}

fn server_waf(s: wf::ServerWaf) -> ServerWaf {
    ServerWaf { ready: s.ready, installable: s.installable, settings: s.settings.map(settings) }
}

fn waf(v: wf::WafView) -> Firewall {
    Firewall { nginx: server_waf(v.nginx), traefik: server_waf(v.traefik), crs: v.crs }
}

/// A script that writes and checks a file as root: `refused` and the
/// server's last words when it put the previous file back.
fn write_as_root(script: &str, refused_exit: i32) -> Result<(), Error> {
    let out = host::exec_root(script)?;
    if out.status == 0 {
        return Ok(());
    }
    let stderr = String::from_utf8_lossy(&out.stderr);
    let detail: String = stderr.lines().rev().find(|l| !l.trim().is_empty()).unwrap_or("").trim().chars().take(300).collect();
    if out.status == refused_exit {
        return Err(Error::FailedPrecondition(format!("refused\n{detail}")));
    }
    Err(Error::Internal(format!("exited with {}: {detail}", out.status)))
}

impl api::Guest for App {
    fn view() -> Result<Proxies, Error> {
        read().map(proxies)
    }

    fn waf() -> Result<Firewall, Error> {
        read_waf().map(waf)
    }

    fn web_apps() -> Result<Vec<WebApp>, Error> {
        Ok(agent::web_apps().into_iter().map(|a| WebApp { title: a.title, url: format!("http://127.0.0.1:{}", a.port) }).collect())
    }

    fn set_sites(which: Server, sites: Vec<Site>) -> Result<Proxies, Error> {
        let which = server(which);
        let now = read()?;
        let found = now.servers.iter().find(|s| s.server == which).ok_or_else(|| Error::Internal("unread server".into()))?;
        if !found.installed {
            return Err(Error::FailedPrecondition("notInstalled".into()));
        }
        if !found.writable {
            return Err(Error::FailedPrecondition("notWritable".into()));
        }
        let sites: Vec<px::Site> = sites.into_iter().map(site_in).collect();
        // A site behind the firewall needs its rules written first: nginx
        // would refuse the file it names, Traefik route to a middleware not
        // there.
        if sites.iter().any(|s| s.waf) {
            let w = read_waf()?;
            let set = if which == px::Server::Nginx { w.nginx.settings.is_some() } else { w.traefik.settings.is_some() };
            if !set {
                return Err(Error::FailedPrecondition("wafNotSet".into()));
            }
        }
        let script = px::write_script(which, &sites, found.tls_resolver).map_err(|e| Error::InvalidArgument(format!("{}\n{}", e.error, e.site)))?;
        write_as_root(&script, px::EXIT_REFUSED)?;
        read().map(proxies)
    }

    fn set_waf(which: Server, s: WafSettings) -> Result<Firewall, Error> {
        let which = server(which);
        if which == px::Server::Caddy {
            return Err(Error::FailedPrecondition("unsupported".into()));
        }
        let now = read_waf()?;
        let ready = if which == px::Server::Nginx { now.nginx.ready } else { now.traefik.ready };
        if !ready {
            return Err(Error::FailedPrecondition("notReady".into()));
        }
        let s = wf::Settings {
            mode: match s.mode {
                Mode::Off => wf::Mode::Off,
                Mode::Detect => wf::Mode::Detect,
                Mode::Block => wf::Mode::Block,
            },
            paranoia: s.paranoia,
            exclusions: s.exclusions,
        };
        let script = wf::write_script(which, &s).map_err(|e| Error::InvalidArgument(e.into()))?;
        write_as_root(&script, wf::EXIT_REFUSED)?;
        read_waf().map(waf)
    }

    fn waf_events(which: Server) -> Result<Vec<WafEvent>, Error> {
        let command = wf::events_command(server(which)).map_err(|e| Error::InvalidArgument(e.into()))?;
        let out = host::exec_root(&command)?;
        Ok(wf::parse_events(&String::from_utf8_lossy(&out.stdout))
            .into_iter()
            .map(|e| WafEvent { time: e.time, client: e.client, host: e.host, method: e.method, uri: e.uri, status: e.status, rules: e.rules })
            .collect())
    }
}

impl jobs::Guest for App {
    fn install(which: Server, acme_email: Option<String>) -> Result<(), Error> {
        let script = px::install_script(server(which), acme_email.as_deref().filter(|e| !e.is_empty())).map_err(|e| Error::InvalidArgument(e.into()))?;
        match job::run_root(&script)? {
            0 => Ok(()),
            n => Err(Error::Internal(format!("exited with {n}"))),
        }
    }

    fn install_waf(which: Server) -> Result<(), Error> {
        let which = server(which);
        if which == px::Server::Caddy {
            return Err(Error::FailedPrecondition("unsupported".into()));
        }
        let script = wf::install_script(which).map_err(|e| Error::InvalidArgument(e.into()))?;
        match job::run_root(&script)? {
            0 => Ok(()),
            n => Err(Error::Internal(format!("exited with {n}"))),
        }
    }
}

export!(App);
