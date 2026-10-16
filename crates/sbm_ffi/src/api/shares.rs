//! SMB and NFS shares FFI (sbm_parser::shares)
//!
//! What the monitor agent's Sharing app runs, for the app: ServerBox's shares
//! are written whole into files of its own and checked before they take
//! effect (`testparm`, `exportfs -ra`), the previous file put back when they
//! do not. Reading needs no root (connections do); a change goes through
//! `PrivilegedExec`. Values cross as `sbm_parser::shares`' serde JSON; a
//! refusal as [`SharesFfiError`].

use sbm_parser::shares::{self as sh, NfsExport, SmbShare};

/// `code`: `sbm_parser::shares::ShareError`'s (`invalidName`, `invalidPath`,
/// `invalidComment`, `invalidUser`, `invalidClient`, `invalidSquash`,
/// `duplicate`, `invalidPassword`), or `malformed`.
#[derive(Debug, Clone)]
pub struct SharesFfiError {
    pub code: String,
}

fn malformed(_: serde_json::Error) -> SharesFfiError {
    SharesFfiError { code: "malformed".to_string() }
}

impl From<sh::ShareError> for SharesFfiError {
    fn from(e: sh::ShareError) -> Self {
        SharesFfiError { code: e.code().to_string() }
    }
}

/// What is installed and running, every share and export
#[flutter_rust_bridge::frb(sync)]
pub fn shares_read_script() -> String {
    sh::READ_COMMAND.to_string()
}

/// [`shares_read_script`]'s output → `Shares` JSON
pub fn parse_shares_json(raw: String) -> Result<String, SharesFfiError> {
    serde_json::to_string(&sh::parse(&raw)).map_err(malformed)
}

/// Root's script making `shares_json` (every share ServerBox keeps) the SMB
/// shares
#[flutter_rust_bridge::frb(sync)]
pub fn shares_smb_script(shares_json: String) -> Result<String, SharesFfiError> {
    let shares: Vec<SmbShare> = serde_json::from_str(&shares_json).map_err(malformed)?;
    Ok(sh::smb_script(&shares)?)
}

/// Root's script making `exports_json` (every export ServerBox keeps) the
/// NFS exports
#[flutter_rust_bridge::frb(sync)]
pub fn shares_nfs_script(exports_json: String) -> Result<String, SharesFfiError> {
    let exports: Vec<NfsExport> = serde_json::from_str(&exports_json).map_err(malformed)?;
    Ok(sh::nfs_script(&exports)?)
}

/// Root's script setting `user`'s SMB password (in its text: send on stdin)
#[flutter_rust_bridge::frb(sync)]
pub fn shares_smb_password_script(user: String, password: String) -> Result<String, SharesFfiError> {
    Ok(sh::smb_password_script(&user, &password)?)
}

/// Root's script installing Samba (`nfs` false) or the NFS server
#[flutter_rust_bridge::frb(sync)]
pub fn shares_install_script(nfs: bool) -> String {
    sh::install_script(nfs)
}

/// Who is connected now; root (for `smbstatus`)
#[flutter_rust_bridge::frb(sync)]
pub fn shares_connections_script() -> String {
    sh::CONNECTIONS_COMMAND.to_string()
}

/// [`shares_connections_script`]'s output → `Connections` JSON
pub fn parse_shares_connections_json(raw: String) -> Result<String, SharesFfiError> {
    serde_json::to_string(&sh::parse_connections(&raw)).map_err(malformed)
}

/// The exit code of a write script whose path is not a folder (stderr names
/// it)
#[flutter_rust_bridge::frb(sync)]
pub fn shares_exit_not_a_folder() -> i32 {
    sh::EXIT_NOT_A_FOLDER
}

/// The exit code of a write script whose result Samba or `exportfs` refused
/// (the previous file is back)
#[flutter_rust_bridge::frb(sync)]
pub fn shares_exit_refused() -> i32 {
    sh::EXIT_REFUSED
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shares_cross_as_json() {
        assert!(shares_read_script().contains("testparm"));
        assert_eq!(shares_smb_script(r#"[{"name":"global","path":"/srv"}]"#.into()).unwrap_err().code, "invalidName");
        assert!(shares_smb_script(r#"[{"name":"media","path":"/srv/media","time_machine":true}]"#.into()).unwrap().contains("fruit:time machine = yes"));
        assert_eq!(shares_nfs_script("[".into()).unwrap_err().code, "malformed");
        assert_eq!(shares_exit_not_a_folder(), 3);
    }
}
