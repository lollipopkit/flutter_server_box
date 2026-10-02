//! System accounts FFI (sbm_parser::users)
//!
//! The same command layer the monitor agent serves to its panel, so the app and
//! the panel read and change a machine's accounts by one set of rules. Scripts
//! are POSIX `sh` for `ServerExec.run(script, entry: 'sh')`; the commands that
//! change an account need root and go through `PrivilegedExec`. Accounts and
//! drafts cross as `sbm_parser::users`' serde JSON, parsed results the same
//! way, and a refusal as [`UserFfiError`], whose `code` the app phrases.

use sbm_parser::users::{self, SystemUser, UserDraft, UserError};

/// A refused account or draft. `code` is `sbm_parser::users::UserError`'s
/// (`invalidName`, `lineBreak`, `invalidPrimaryGroup`,
/// `invalidSupplementaryGroup`, `passwordLineBreak`, `renaming`,
/// `rootNotDeletable`, `currentUserUnknown`), or `malformed` for JSON the
/// app should never have sent.
#[derive(Debug, Clone)]
pub struct UserFfiError {
    pub code: String,
}

impl From<UserError> for UserFfiError {
    fn from(error: UserError) -> Self {
        UserFfiError {
            code: error.as_str().to_string(),
        }
    }
}

fn malformed(_: serde_json::Error) -> UserFfiError {
    UserFfiError {
        code: "malformed".to_string(),
    }
}

fn account(json: &str) -> Result<SystemUser, UserFfiError> {
    serde_json::from_str(json).map_err(malformed)
}

fn draft(json: &str) -> Result<UserDraft, UserFfiError> {
    serde_json::from_str(json).map_err(malformed)
}

/// The passwd and group catalogs, the current account and `UID_MIN`
#[flutter_rust_bridge::frb(sync)]
pub fn users_list_script() -> String {
    users::LIST_SCRIPT.to_string()
}

/// [`users_list_script`]'s output → `UserCatalog` JSON
pub fn parse_users_list_json(raw: String) -> Result<String, UserFfiError> {
    serde_json::to_string(&users::parse_list(&raw)?).map_err(malformed)
}

/// What shadow, `authorized_keys` and sudoers say about one account
#[flutter_rust_bridge::frb(sync)]
pub fn users_detail_script(user_json: String) -> Result<String, UserFfiError> {
    Ok(users::detail_script(&account(&user_json)?)?)
}

/// [`users_detail_script`]'s output for account `name` → `UserDetail` JSON.
/// Only rows naming `name` are read.
pub fn parse_user_detail_json(raw: String, name: String) -> Result<String, UserFfiError> {
    serde_json::to_string(&users::parse_detail(&raw, &name)).map_err(malformed)
}

#[flutter_rust_bridge::frb(sync)]
pub fn users_valid_name(name: String) -> bool {
    users::valid_name(&name)
}

/// Why a draft cannot be sent, as an error code, or `None` when it can
#[flutter_rust_bridge::frb(sync)]
pub fn users_validate_draft(draft_json: String) -> Result<Option<String>, UserFfiError> {
    Ok(users::validate_draft(&draft(&draft_json)?).map(|error| error.as_str().to_string()))
}

/// `useradd`, and `chpasswd` when the draft carries a password; needs root
#[flutter_rust_bridge::frb(sync)]
pub fn users_create_command(draft_json: String) -> Result<String, UserFfiError> {
    Ok(users::create_command(&draft(&draft_json)?)?)
}

/// `usermod` for the fields that changed, and `chpasswd`; needs root
#[flutter_rust_bridge::frb(sync)]
pub fn users_edit_command(original_json: String, draft_json: String) -> Result<String, UserFfiError> {
    Ok(users::edit_command(&account(&original_json)?, &draft(&draft_json)?)?)
}

/// `userdel`, with `-r` when the home directory goes too; needs root
#[flutter_rust_bridge::frb(sync)]
pub fn users_delete_command(user_json: String, remove_home: bool) -> Result<String, UserFfiError> {
    Ok(users::delete_command(&account(&user_json)?, remove_home)?)
}
