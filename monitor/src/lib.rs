// Deep ntex service/middleware generics (TLS + CORS + Logger stacks) exceed
// the default query depth during layout computation
#![recursion_limit = "256"]

pub mod api;
pub mod cli;
pub mod core;
pub mod db;
pub mod monitoring;
pub mod utils;