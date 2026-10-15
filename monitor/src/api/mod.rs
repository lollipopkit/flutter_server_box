/// The value of an `Ok`, or the handler answers with the `Err`'s response:
/// `require!(authz::acting_caller(&req, &state).await)`.
macro_rules! require {
    ($result:expr) => {{
        match $result {
            Ok(value) => value,
            Err(response) => return Ok(response),
        }
    }};
}

pub mod agent;
pub mod cron;
pub mod backup;
pub mod bmc;
pub mod virt;
pub mod virt_backups;
pub mod virt_guests;
pub mod virt_hardware;
pub mod virt_resources;
pub mod desk;
pub mod desk_storage;
pub mod assets;
pub mod desk_themes;
pub mod desktops;
pub mod custom_cmds;
pub mod exec;
pub mod firewall;
pub mod fs;
pub mod machine;
pub mod power;
pub mod process;
pub mod service;
pub mod snippets;
pub mod system_users;
pub mod tmux;
pub mod update;
pub mod push;
pub mod respond;
pub mod cors;
pub mod admin;
pub mod audit_log;
pub mod app_runtime;
pub mod apps;
pub mod live;
pub mod containers;
pub mod container_backups;
pub mod stacks;
pub mod shares;
pub mod storage;
pub mod auth;
pub mod benchmark;
pub mod authz;
pub mod ratelimit;
pub mod ws;
pub mod server;