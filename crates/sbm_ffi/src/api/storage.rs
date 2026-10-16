//! Disks, RAID arrays, ZFS pools FFI (sbm_parser::storage)
//!
//! The command layer the monitor agent's Storage app runs, so the app reads
//! and changes a machine's storage by the same rules: the view and every
//! check (what is in use, the system's mounts) are decided in Rust, and the
//! app only runs the scripts. Reading needs no root; a change goes through
//! `PrivilegedExec` (scripts are POSIX `sh`, sent on stdin, so the LUKS
//! passphrase [`storage_action_script`] writes into one is on no command
//! line). Values cross as `sbm_parser::storage`'s serde JSON; a refusal as
//! [`StorageFfiError`].

use sbm_parser::storage::{self as st, StorageAction, StorageView};

/// `code`: `sbm_parser::storage::StorageError`'s (`invalidDevice`,
/// `keyRequired`, `invalidPassphrase`, …), `unreadable` when lsblk answered
/// nothing, or `malformed` for JSON the app should never have sent.
#[derive(Debug, Clone)]
pub struct StorageFfiError {
    pub code: String,
}

fn error(code: &str) -> StorageFfiError {
    StorageFfiError { code: code.to_string() }
}

fn malformed(_: serde_json::Error) -> StorageFfiError {
    error("malformed")
}

fn action(json: &str) -> Result<StorageAction, StorageFfiError> {
    serde_json::from_str(json).map_err(malformed)
}

/// Everything the Storage page draws, readable without root
#[flutter_rust_bridge::frb(sync)]
pub fn storage_view_script() -> String {
    st::view_command()
}

/// [`storage_view_script`]'s output → `StorageView` JSON (`disks`, `busy`,
/// `system`, `arrays`, `pools`, `tools`)
pub fn parse_storage_view_json(raw: String) -> Result<String, StorageFfiError> {
    let view = st::parse_view(&raw).ok_or_else(|| error("unreadable"))?;
    serde_json::to_string(&view).map_err(malformed)
}

/// Why `action` is refused on the machine `view` describes (`Refusal` JSON:
/// `status`, `error`, `device`, `why`), or `None` when it may run. Check
/// against a view read just before, not the one a page drew earlier.
#[flutter_rust_bridge::frb(sync)]
pub fn storage_check_json(view_json: String, action_json: String) -> Result<Option<String>, StorageFfiError> {
    let view: StorageView = serde_json::from_str(&view_json).map_err(malformed)?;
    match st::check(&view, &action(&action_json)?) {
        Ok(()) => Ok(None),
        Err(r) => Ok(Some(serde_json::to_string(&r).map_err(malformed)?)),
    }
}

/// The root script that makes `action`; `passphrase` for an encrypted format
/// or an unlock (written into a key file the script makes and removes)
#[flutter_rust_bridge::frb(sync)]
pub fn storage_action_script(action_json: String, passphrase: Option<String>) -> Result<String, StorageFfiError> {
    let a = action(&action_json)?;
    let script = match passphrase {
        Some(p) if a.needs_key() => a.script_with_passphrase(&p),
        _ => a.script(),
    };
    script.map_err(|e| error(e.code()))
}

/// Whether `action` needs a LUKS passphrase
#[flutter_rust_bridge::frb(sync)]
pub fn storage_action_needs_key(action_json: String) -> Result<bool, StorageFfiError> {
    Ok(action(&action_json)?.needs_key())
}

/// Every disk's SMART, as root (or with a `NOPASSWD` sudoers rule)
#[flutter_rust_bridge::frb(sync)]
pub fn storage_health_script() -> String {
    st::HEALTH_COMMAND.to_string()
}

/// [`storage_health_script`]'s output → `[DiskHealth]` JSON
pub fn parse_storage_health_json(raw: String) -> Result<String, StorageFfiError> {
    serde_json::to_string(&st::parse_health(&raw)).map_err(malformed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_change_is_checked_and_scripted_by_the_parser() {
        assert!(storage_view_script().contains("lsblk -J"));
        assert_eq!(parse_storage_view_json("nothing".into()).unwrap_err().code, "unreadable");
        let unlock = r#"{"action":"unlock","device":"/dev/sdb1"}"#.to_string();
        assert!(storage_action_needs_key(unlock.clone()).unwrap());
        assert_eq!(storage_action_script(unlock.clone(), None).unwrap_err().code, "keyRequired");
        assert!(storage_action_script(unlock, Some("a passphrase".into())).unwrap().starts_with("k=$(mktemp)"));
        assert_eq!(storage_action_script("{".into(), None).unwrap_err().code, "malformed");
        let view = r#"{"disks":[],"busy":{},"system":[],"arrays":[],"pools":[],"tools":[]}"#.to_string();
        let refusal = storage_check_json(view, r#"{"action":"partition","device":"/dev/sdz"}"#.into()).unwrap().unwrap();
        assert!(refusal.contains("\"inUse\"") && refusal.contains("notFound"), "{refusal}");
    }
}
