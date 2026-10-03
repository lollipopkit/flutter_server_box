//! ServerBox virtualization, shared by the monitor agent and the app (FFI).
//!
//! - [`libvirt`]: `virsh` scripts and the parsers for what they print — pure,
//!   no IO; the caller runs each script through its own transport.

pub mod libvirt;
