//! Remote desktop route rules FFI (sbm_parser::desktop)
//!
//! The rules the agent's `/desktops` endpoint applies to the panel's routes,
//! so the app's profile editor accepts exactly what the agent does. The input
//! and the refusals are `sbm_parser::desktop`'s own, mirrored.

use flutter_rust_bridge::frb;
use sbm_parser::desktop;
pub use sbm_parser::desktop::{ProfileError, ProfileInput, VncPasswordError};

#[frb(mirror(ProfileInput))]
pub struct _ProfileInput {
    pub name: String,
    pub protocol: String,
    pub host: String,
    pub port: Option<i64>,
    pub username: Option<String>,
    pub domain: Option<String>,
}

#[frb(mirror(ProfileError))]
pub enum _ProfileError {
    NameRequired,
    InvalidName,
    InvalidProtocol,
    HostRequired,
    InvalidHost,
    InvalidPort,
    UsernameRequired,
    InvalidCredential,
}

#[frb(mirror(VncPasswordError))]
pub enum _VncPasswordError {
    NotAscii,
}

/// Why a route cannot be saved, or `None`.
#[frb(sync)]
pub fn desktop_validate_profile(input: ProfileInput) -> Option<ProfileError> {
    desktop::validate_profile(&input).err()
}

/// Why a classic VNC password would not work, or `None`.
#[frb(sync)]
pub fn desktop_validate_vnc_password(password: String) -> Option<VncPasswordError> {
    desktop::validate_vnc_password(&password).err()
}
