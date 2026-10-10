//! Which host ports a stack may publish: one is free when no other
//! container publishes it (running or not: a stopped one takes it back when
//! it starts) and either it can be bound now or the stack's own running
//! containers hold it.
//!
//! Binding sees this machine's network as the agent does: inside a container
//! (unless on the host's network) or under WSL (Windows' own ports) it may
//! miss ports in use; [`partial`] says so.

use std::path::Path;

use sbm_parser::container::ContainerType;
use sbm_parser::stack::PublishedPort;

use crate::api::server::AppState;

#[derive(Debug, Clone)]
pub struct Ports {
    published: Vec<PublishedPort>,
    /// The compose project of the stack asking.
    own: String,
    bind: fn(u16) -> bool,
}

impl Ports {
    pub fn new(published: Vec<PublishedPort>, own: impl Into<String>, bind: fn(u16) -> bool) -> Self {
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

    pub fn free(&self, port: u16) -> bool {
        let mine = |p: &&PublishedPort| p.project.as_deref() == Some(self.own.as_str());
        let here = self.published.iter().filter(|p| p.port == port);
        if here.clone().any(|p| !mine(&p)) {
            return false;
        }
        (self.bind)(port) || here.filter(mine).any(|p| p.running)
    }
}

/// Whether [port] can be bound on every interface now.
pub fn bindable(port: u16) -> bool {
    std::net::TcpListener::bind(("0.0.0.0", port)).is_ok()
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
        PublishedPort { port, project: project.map(String::from), running }
    }

    #[test]
    fn a_port_is_free_unless_another_container_or_program_has_it() {
        let ports = Ports::new(
            vec![published(8080, None, false), published(2283, Some("sbm-futo-immich"), true), published(9000, Some("sbm-futo-immich"), false)],
            "sbm-futo-immich",
            |p| p != 2283 && p != 9000 && p != 7000,
        );
        // A stopped container of someone else's.
        assert!(!ports.free(8080));
        // Its own running container holds it.
        assert!(ports.free(2283));
        // Its own container is stopped and something else took the port.
        assert!(!ports.free(9000));
        // A program, no container.
        assert!(!ports.free(7000));
        assert!(ports.free(7001));
        // Another stack's view of the same ports.
        let other = Ports::new(ports.published.clone(), "sbm-acme-x", |_| true);
        assert!(!other.free(2283));
    }
}
