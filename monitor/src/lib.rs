// Deep ntex service/middleware generics (TLS + CORS + Logger stacks) exceed
// the default query depth during layout computation
#![recursion_limit = "256"]

pub mod monitor_backup;
pub mod agent_mode;
pub mod api;
pub mod apps;
pub mod cli;
pub mod container_backups;
pub mod core;
pub mod db;
pub mod inference;
pub mod lkc;
pub mod monitoring;
pub mod pty;
pub mod stacks;
pub mod storage_watch;
pub mod utils;