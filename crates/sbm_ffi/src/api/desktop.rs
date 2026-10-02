//! Remote desktop route rules FFI (sbm_parser::desktop)
//!
//! The rules the agent's `/desktops` endpoint applies to the panel's routes,
//! so the app's profile editor accepts exactly what the agent does. Answers
//! are error codes the app phrases, or `None`.

use sbm_parser::desktop::{self, ProfileInput};

/// Why a route cannot be saved, as `ProfileError`'s code, or `None`. The
/// input is `ProfileInput` JSON; JSON the app should never send is
/// `malformed`.
#[flutter_rust_bridge::frb(sync)]
pub fn desktop_validate_profile(input_json: String) -> Option<String> {
    match serde_json::from_str::<ProfileInput>(&input_json) {
        Ok(input) => desktop::validate_profile(&input).err().map(|e| e.as_str().to_string()),
        Err(_) => Some("malformed".to_string()),
    }
}

/// Why a classic VNC password would not work, or `None`.
#[flutter_rust_bridge::frb(sync)]
pub fn desktop_validate_vnc_password(password: String) -> Option<String> {
    desktop::validate_vnc_password(&password).err().map(|e| e.as_str().to_string())
}
