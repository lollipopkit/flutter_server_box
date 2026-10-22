//! Tailscale's backend (`sbm_parser::tailscale`): the status read as the
//! agent's account (tailscaled answers any account); each change checked
//! against a fresh read and run as root as a job. An auth key goes into a
//! private file the sign-in reads (`job.private-file`), removed when the job
//! ends.

wit_bindgen::generate!({ path: ["../../wit", "wit"], world: "serverbox:tailscale/tailscale", generate_all });

use exports::serverbox::tailscale::api::{self, Peer, Pong, Prefs, Status};
use exports::serverbox::tailscale::jobs::{self, Settings};
use sbm::app::types::Error;
use sbm::app::{host, job};
use sbm_parser::tailscale::{self as ts, Action};

struct App;

/// The status and the OS release it was read on (Tailscale's repository is
/// named by them).
fn read() -> Result<(ts::TailscaleView, String, String), Error> {
    let out = host::exec(&ts::read_command(), None)?;
    let text = String::from_utf8_lossy(&out.stdout);
    let mut os = text.split("### os\n").nth(1).unwrap_or("").lines().map(|l| l.trim().to_string());
    let (id, codename) = (os.next().unwrap_or_default(), os.next().unwrap_or_default());
    Ok((ts::parse(&text), id, codename))
}

fn status(v: ts::TailscaleView) -> Status {
    Status {
        installable: v.installable,
        version: v.version,
        daemon: v.daemon,
        state: v.state,
        auth_url: v.auth_url,
        name: v.name,
        dns_name: v.dns_name,
        ips: v.ips,
        tailnet: v.tailnet,
        user: v.user,
        health: v.health,
        peers: v
            .peers
            .into_iter()
            .map(|p| Peer {
                id: p.id,
                name: p.name,
                dns_name: p.dns_name,
                ips: p.ips,
                os: p.os,
                online: p.online,
                active: p.active,
                exit_node_option: p.exit_node_option,
                exit_node: p.exit_node,
                routes: p.routes,
                direct: p.direct,
                relay: p.relay,
                rx_bytes: p.rx_bytes,
                tx_bytes: p.tx_bytes,
            })
            .collect(),
        prefs: v.prefs.map(|p| Prefs {
            control_url: p.control_url,
            hostname: p.hostname,
            accept_routes: p.accept_routes,
            accept_dns: p.accept_dns,
            ssh: p.ssh,
            shields_up: p.shields_up,
            want_running: p.want_running,
            logged_out: p.logged_out,
            exit_node_id: p.exit_node_id,
            exit_node_ip: p.exit_node_ip,
            exit_node_allow_lan: p.exit_node_allow_lan,
            advertise_routes: p.advertise_routes,
            advertise_exit_node: p.advertise_exit_node,
            operator: p.operator,
        }),
    }
}

/// [action] checked against a fresh read, then run as root; [key_file] the
/// private file of a sign-in with a key.
fn act(action: Action, key_file: Option<&str>) -> Result<(), Error> {
    let (now, os, codename) = read()?;
    ts::check(&now, &action).map_err(|e| Error::FailedPrecondition(e.into()))?;
    let script = ts::script(&action, &now, &os, &codename, key_file).map_err(|e| Error::InvalidArgument(e.into()))?;
    match job::run_root(&script)? {
        0 => Ok(()),
        n => Err(Error::Internal(format!("exited with {n}"))),
    }
}

impl api::Guest for App {
    fn view() -> Result<Status, Error> {
        read().map(|(v, _, _)| status(v))
    }

    fn ping(ip: String) -> Result<Pong, Error> {
        let command = ts::ping_command(ip.trim()).ok_or_else(|| Error::InvalidArgument("invalidIp".into()))?;
        let out = host::exec(&command, None)?;
        Ok(Pong { ok: out.status == 0, output: String::from_utf8_lossy(&out.stdout).trim().to_string() })
    }
}

impl jobs::Guest for App {
    fn install() -> Result<(), Error> {
        act(Action::Install, None)
    }

    fn start_daemon() -> Result<(), Error> {
        act(Action::StartDaemon, None)
    }

    fn login(login_server: Option<String>, hostname: Option<String>, auth_key: Option<String>) -> Result<(), Error> {
        let key = auth_key.map(|k| k.trim().to_string()).filter(|k| !k.is_empty());
        if key.as_deref().is_some_and(|k| !ts::auth_key_ok(k)) {
            return Err(Error::InvalidArgument("invalidAuthKey".into()));
        }
        let file = key.map(|k| job::private_file(k.as_bytes())).transpose()?;
        act(Action::Login { login_server, hostname }, file.as_deref())
    }

    fn logout() -> Result<(), Error> {
        act(Action::Logout, None)
    }

    fn connect() -> Result<(), Error> {
        act(Action::Connect, None)
    }

    fn disconnect() -> Result<(), Error> {
        act(Action::Disconnect, None)
    }

    fn set(settings: Settings, lan_cut_ok: bool) -> Result<(), Error> {
        let settings = ts::Settings {
            exit_node: settings.exit_node,
            exit_node_allow_lan: settings.exit_node_allow_lan,
            accept_routes: settings.accept_routes,
            accept_dns: settings.accept_dns,
            ssh: settings.ssh,
            shields_up: settings.shields_up,
            hostname: settings.hostname,
            advertise_exit_node: settings.advertise_exit_node,
            advertise_routes: settings.advertise_routes,
        };
        act(Action::Set { settings, lan_cut_ok }, None)
    }
}

export!(App);
