//! ServerBox virtualization, shared by the monitor agent and the app (FFI).
//!
//! - [`model`]: hosts, guests, their states, actions and usage, for either
//!   backend; [`rates`] turns counters into usage; [`error`] says why not;
//!   [`snapshot`] is what a snapshot is, and the rules for taking one;
//!   [`resource`] is storage and networks, and the rules a change is checked by;
//!   [`create`] is making, copying and deleting guests, and its rules.
//! - [`libvirt`]: `virsh` scripts and the parsers for what they print — pure,
//!   no IO; the caller runs each script through its own transport.
//! - [`pve`]: the Proxmox VE API client, over a byte stream the caller opens.

pub mod create;
pub mod error;
pub mod libvirt;
pub mod model;
pub mod pve;
pub mod rates;
pub mod resource;
pub mod snapshot;
