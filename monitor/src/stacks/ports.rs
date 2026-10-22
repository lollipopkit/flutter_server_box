//! Which host ports a stack may publish, TCP and UDP apart: one is free when
//! no other container publishes it (running or not: a stopped one takes it
//! back when it starts) and either nothing holds it now or the stack's own
//! running containers do.
//!
//! "Nothing holds it" is a bind of the port. A port below 1024 the agent may
//! not bind (it is not root): then the kernel's socket tables are read
//! instead, so a DNS resolver on 53 (`systemd-resolved`) still counts.
//!
//! Both see this machine's network as the agent does: inside a container
//! (unless on the host's network) or under WSL (Windows' own ports) they may
//! miss ports in use; [`partial`] says so.

use std::path::Path;

use sbm_parser::container::ContainerType;
pub use sbm_parser::stack::PortProtocol;
use sbm_parser::stack::PublishedPort;

use crate::api::server::AppState;

#[derive(Debug, Clone)]
pub struct Ports {
    published: Vec<PublishedPort>,
    /// The compose project of the stack asking.
    own: String,
    bind: fn(u16, PortProtocol) -> bool,
}

impl Ports {
    pub fn new(published: Vec<PublishedPort>, own: impl Into<String>, bind: fn(u16, PortProtocol) -> bool) -> Self {
        Self { published, own: own.into(), bind }
    }

    /// What the container runtime publishes, read now; nothing when it
    /// cannot be asked.
    pub async fn read(state: &AppState, runtime: Option<ContainerType>, own: String) -> Self {
        let mut published = Vec::new();
        if let Some(runtime) = runtime {
            let cmd = sbm_parser::stack::published_ports_command(runtime);
            let limits = crate::api::machine::at_least(&state.remote_access.exec, 4 << 20);
            match crate::api::exec::run(&cmd, None, None, &limits).await {
                Ok(out) if out.exit_code == Some(0) => published = sbm_parser::stack::parse_published_ports(&out.stdout),
                Ok(out) => tracing::debug!("published ports: exit {:?}", out.exit_code),
                Err(e) => tracing::debug!("published ports: {e}"),
            }
        }
        Self::new(published, own, bindable)
    }

    pub fn free(&self, port: u16, protocol: PortProtocol) -> bool {
        let mine = |p: &&PublishedPort| p.project.as_deref() == Some(self.own.as_str());
        let here = self.published.iter().filter(|p| p.port == port && p.protocol == protocol);
        if here.clone().any(|p| !mine(&p)) {
            return false;
        }
        (self.bind)(port, protocol) || here.filter(mine).any(|p| p.running)
    }
}

/// Whether [port] can be bound on every interface now; for a port the agent
/// may not bind, whether no socket of this machine holds it.
pub fn bindable(port: u16, protocol: PortProtocol) -> bool {
    let bound = match protocol {
        PortProtocol::Tcp => std::net::TcpListener::bind(("0.0.0.0", port)).map(drop),
        PortProtocol::Udp => std::net::UdpSocket::bind(("0.0.0.0", port)).map(drop),
    };
    match bound {
        Ok(()) => true,
        Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => !held(port, protocol),
        Err(_) => false,
    }
}

/// Whether a socket in the kernel's tables holds [port]: a listening TCP
/// socket, or any bound UDP one. False where there are no such tables.
fn held(port: u16, protocol: PortProtocol) -> bool {
    let (files, listening) = match protocol {
        PortProtocol::Tcp => (["/proc/net/tcp", "/proc/net/tcp6"], Some("0A")),
        PortProtocol::Udp => (["/proc/net/udp", "/proc/net/udp6"], None),
    };
    files.iter().filter_map(|f| std::fs::read_to_string(f).ok()).any(|table| holds(&table, port, listening))
}

/// Whether a `/proc/net/{tcp,udp}[6]` [table] has a socket bound to [port],
/// in state [listening] when given.
fn holds(table: &str, port: u16, listening: Option<&str>) -> bool {
    table.lines().skip(1).any(|line| {
        let mut cols = line.split_whitespace();
        let local = cols.nth(1);
        let state = cols.nth(1);
        local.and_then(|l| l.rsplit_once(':')).and_then(|(_, p)| u16::from_str_radix(p, 16).ok()) == Some(port)
            && listening.is_none_or(|s| state == Some(s))
    })
}

/// Whether [`Ports::free`] may miss ports in use: the agent runs in a
/// container or under WSL.
pub fn partial(wsl: bool) -> bool {
    wsl || Path::new("/.dockerenv").exists() || Path::new("/run/.containerenv").exists()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn published(port: u16, project: Option<&str>, running: bool) -> PublishedPort {
        PublishedPort { port, protocol: PortProtocol::Tcp, project: project.map(String::from), running }
    }

    const TCP: PortProtocol = PortProtocol::Tcp;
    const UDP: PortProtocol = PortProtocol::Udp;

    #[test]
    fn a_port_is_free_unless_another_container_or_program_has_it() {
        let ports = Ports::new(
            vec![published(8080, None, false), published(2283, Some("sbm-futo-immich"), true), published(9000, Some("sbm-futo-immich"), false)],
            "sbm-futo-immich",
            |p, _| p != 2283 && p != 9000 && p != 7000,
        );
        // A stopped container of someone else's.
        assert!(!ports.free(8080, TCP));
        // Its own running container holds it.
        assert!(ports.free(2283, TCP));
        // Its own container is stopped and something else took the port.
        assert!(!ports.free(9000, TCP));
        // A program, no container.
        assert!(!ports.free(7000, TCP));
        assert!(ports.free(7001, TCP));
        // Another stack's view of the same ports.
        let other = Ports::new(ports.published.clone(), "sbm-acme-x", |_, _| true);
        assert!(!other.free(2283, TCP));
    }

    #[test]
    fn tcp_and_udp_are_apart() {
        let mut dns = published(53, None, true);
        dns.protocol = UDP;
        let ports = Ports::new(vec![dns], "sbm-adguard-x", |p, proto| !(p == 853 && proto == TCP));
        assert!(!ports.free(53, UDP));
        assert!(ports.free(53, TCP));
        assert!(!ports.free(853, TCP));
        assert!(ports.free(853, UDP));
    }

    #[test]
    fn socket_tables_are_read() {
        // systemd-resolved: 127.0.0.53:53 listening (TCP), bound (UDP); a
        // TCP connection from port 53 that is not listening.
        let tcp = "  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode\n\
                      0: 3500007F:0035 00000000:0000 0A 00000000:00000000 00:00000000 00000000   991        0 1 1\n\
                      1: 0100007F:1F90 0100007F:0035 01 00000000:00000000 00:00000000 00000000  1000        0 2 1\n";
        assert!(holds(tcp, 53, Some("0A")));
        assert!(!holds(tcp, 8080, Some("0A")), "8080 is a connection, not a listener");
        let udp = "  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode ref pointer drops\n\
                      0: 3500007F:0035 00000000:0000 07 00000000:00000000 00:00000000 00000000   991        0 3 2 0 0\n";
        assert!(holds(udp, 53, None));
        assert!(!holds(udp, 5353, None));
    }
}
