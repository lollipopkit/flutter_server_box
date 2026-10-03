//! ServerBox virtualization, shared by the monitor agent and the app (FFI).
//!
//! - [`model`]: hosts, guests, their states, actions and usage, for either
//!   backend; [`rates`] turns counters into usage; [`error`] says why not;
//!   [`snapshot`] is what a snapshot is, and the rules for taking one.
//! - [`libvirt`]: `virsh` scripts and the parsers for what they print — pure,
//!   no IO; the caller runs each script through its own transport.
//! - [`pve`]: the Proxmox VE API client, over a byte stream the caller opens.

pub mod error;
pub mod libvirt;
pub mod model;
pub mod pve;
pub mod rates;
pub mod snapshot;
