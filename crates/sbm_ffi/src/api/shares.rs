//! SMB and NFS shares FFI (sbm_parser::shares)
//!
//! What the monitor agent's Sharing app runs, for the app: ServerBox's shares
//! are written whole into files of its own and checked before they take
//! effect (`testparm`, `exportfs -ra`), the previous file put back when they
//! do not. Reading needs no root (connections do); a change goes through
//! `PrivilegedExec`. The models are `sbm_parser::shares`' own, mirrored; a
//! refusal is its [`ShareError`].

use flutter_rust_bridge::frb;
use sbm_parser::shares as sh;
pub use sbm_parser::shares::{Connections, NfsClient, NfsExport, ShareError, Shares, SmbConnection, SmbShare};

// --- Mirrors -----------------------------------------------------------------

#[frb(mirror(SmbShare))]
pub struct _SmbShare {
    pub name: String,
    pub path: String,
    pub comment: Option<String>,
    pub read_only: bool,
    pub guest: bool,
    pub users: Vec<String>,
    pub time_machine: bool,
    pub recycle: bool,
    pub managed: bool,
}

#[frb(mirror(NfsExport))]
pub struct _NfsExport {
    pub path: String,
    pub clients: Vec<NfsClient>,
    pub managed: bool,
}

#[frb(mirror(NfsClient))]
pub struct _NfsClient {
    pub host: String,
    pub read_only: bool,
    pub squash: String,
    pub options: Vec<String>,
}

#[frb(mirror(Shares))]
pub struct _Shares {
    pub tools: Vec<String>,
    pub smb_active: bool,
    pub nfs_active: bool,
    pub smb: Vec<SmbShare>,
    pub nfs: Vec<NfsExport>,
}

#[frb(mirror(Connections))]
pub struct _Connections {
    pub smb: Vec<SmbConnection>,
    pub nfs: Vec<String>,
}

#[frb(mirror(SmbConnection))]
pub struct _SmbConnection {
    pub share: String,
    pub user: Option<String>,
    pub machine: String,
    pub since: Option<String>,
}

#[frb(mirror(ShareError))]
pub enum _ShareError {
    InvalidName,
    InvalidPath,
    InvalidComment,
    InvalidUser,
    InvalidClient,
    InvalidSquash,
    Duplicate,
    InvalidPassword,
}

// --- Functions ---------------------------------------------------------------

/// What is installed and running, every share and export
#[frb(sync)]
pub fn shares_read_script() -> String {
    sh::READ_COMMAND.to_string()
}

/// [`shares_read_script`]'s output
pub fn shares_parse(raw: String) -> Shares {
    sh::parse(&raw)
}

/// Root's script making `shares` (every share ServerBox keeps) the SMB shares
#[frb(sync)]
pub fn shares_smb_script(shares: Vec<SmbShare>) -> Result<String, ShareError> {
    sh::smb_script(&shares)
}

/// Root's script making `exports` (every export ServerBox keeps) the NFS
/// exports
#[frb(sync)]
pub fn shares_nfs_script(exports: Vec<NfsExport>) -> Result<String, ShareError> {
    sh::nfs_script(&exports)
}

/// Root's script setting `user`'s SMB password (in its text: send on stdin)
#[frb(sync)]
pub fn shares_smb_password_script(user: String, password: String) -> Result<String, ShareError> {
    sh::smb_password_script(&user, &password)
}

/// Root's script installing Samba (`nfs` false) or the NFS server
#[frb(sync)]
pub fn shares_install_script(nfs: bool) -> String {
    sh::install_script(nfs)
}

/// Who is connected now; root (for `smbstatus`)
#[frb(sync)]
pub fn shares_connections_script() -> String {
    sh::CONNECTIONS_COMMAND.to_string()
}

/// [`shares_connections_script`]'s output
pub fn shares_parse_connections(raw: String) -> Connections {
    sh::parse_connections(&raw)
}

/// The exit code of a write script whose path is not a folder (stderr names
/// it)
#[frb(sync)]
pub fn shares_exit_not_a_folder() -> i32 {
    sh::EXIT_NOT_A_FOLDER
}

/// The exit code of a write script whose result Samba or `exportfs` refused
/// (the previous file is back)
#[frb(sync)]
pub fn shares_exit_refused() -> i32 {
    sh::EXIT_REFUSED
}

#[cfg(test)]
mod tests {
    use super::*;

    fn share(name: &str, path: &str, time_machine: bool) -> SmbShare {
        SmbShare {
            name: name.into(),
            path: path.into(),
            comment: None,
            read_only: false,
            guest: false,
            users: vec![],
            time_machine,
            recycle: false,
            managed: false,
        }
    }

    #[test]
    fn shares_are_checked_and_scripted_by_the_parser() {
        assert!(shares_read_script().contains("testparm"));
        assert_eq!(shares_smb_script(vec![share("global", "/srv", false)]).unwrap_err(), ShareError::InvalidName);
        assert!(shares_smb_script(vec![share("media", "/srv/media", true)]).unwrap().contains("fruit:time machine = yes"));
        assert_eq!(shares_exit_not_a_folder(), 3);
    }
}
