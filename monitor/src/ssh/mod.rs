//! SSH client used by the browser terminal — see `client` for why the
//! terminal goes through sshd instead of spawning a shell directly.

pub mod client;
pub mod local_pty;
pub mod known_hosts;
