//! System accounts FFI (sbm_parser::users)
//!
//! The same command layer the monitor agent serves to its panel, so the app and
//! the panel read and change a machine's accounts by one set of rules. Scripts
//! are POSIX `sh` for `CommandExec.run(script, entry: 'sh')`; the commands that
//! change an account need root and go through `PrivilegedExec`. The models are
//! `sbm_parser::users`' own, mirrored; a refusal is its [`UserError`], which
//! the app phrases.

use flutter_rust_bridge::frb;
pub use sbm_parser::users::{GroupDraft, PasswordState, SystemGroup, SystemUser, UserCatalog, UserDetail, UserDraft, UserError};
use sbm_parser::users;

// --- Mirrors -----------------------------------------------------------------

#[frb(mirror(SystemUser))]
pub struct _SystemUser {
    pub name: String,
    pub uid: u32,
    pub gid: u32,
    pub comment: String,
    pub home: String,
    pub shell: String,
    pub primary_group: Option<String>,
    pub supplementary_groups: Vec<String>,
}

#[frb(mirror(SystemGroup))]
pub struct _SystemGroup {
    pub name: String,
    pub gid: u32,
    pub members: Vec<String>,
    pub primary_members: Vec<String>,
    pub local: bool,
}

#[frb(mirror(UserCatalog))]
pub struct _UserCatalog {
    pub current_user: String,
    pub uid_min: u32,
    pub gid_min: u32,
    pub users: Vec<SystemUser>,
    pub groups: Vec<SystemGroup>,
}

#[frb(mirror(PasswordState))]
pub enum _PasswordState {
    Set,
    Locked,
    None,
}

#[frb(mirror(UserDetail))]
pub struct _UserDetail {
    pub password_state: Option<PasswordState>,
    pub password_changed_millis: Option<i64>,
    pub expires_millis: Option<i64>,
    pub never_expires: bool,
    pub ssh_key_types: Option<Vec<String>>,
    pub sudo_rule: Option<String>,
}

#[frb(mirror(UserDraft))]
pub struct _UserDraft {
    pub name: String,
    pub comment: String,
    pub home: String,
    pub shell: String,
    pub primary_group: String,
    pub supplementary_groups: Vec<String>,
    pub create_home: bool,
    pub move_home: bool,
    pub system: bool,
    pub password: Option<String>,
}

#[frb(mirror(GroupDraft))]
pub struct _GroupDraft {
    pub name: String,
    pub members: Vec<String>,
    pub system: bool,
}

#[frb(mirror(UserError))]
pub enum _UserError {
    InvalidName,
    LineBreak,
    InvalidPrimaryGroup,
    InvalidSupplementaryGroup,
    PasswordLineBreak,
    Renaming,
    RootNotDeletable,
    CurrentUserNotDeletable,
    CurrentUserUnknown,
    UnknownMember,
    RootGroupNotDeletable,
    GroupInUse,
    GroupNotLocal,
}

// --- Functions ---------------------------------------------------------------

/// The passwd and group catalogs, the current account and `UID_MIN`
#[frb(sync)]
pub fn users_list_script() -> String {
    users::LIST_SCRIPT.to_string()
}

/// [`users_list_script`]'s output
pub fn users_parse_list(raw: String) -> Result<UserCatalog, UserError> {
    users::parse_list(&raw)
}

/// What shadow, `authorized_keys` and sudoers say about one account
#[frb(sync)]
pub fn users_detail_script(user: SystemUser) -> Result<String, UserError> {
    users::detail_script(&user)
}

/// [`users_detail_script`]'s output for account `name`. Only rows naming
/// `name` are read.
pub fn users_parse_detail(raw: String, name: String) -> UserDetail {
    users::parse_detail(&raw, &name)
}

#[frb(sync)]
pub fn users_valid_name(name: String) -> bool {
    users::valid_name(&name)
}

/// Why a draft cannot be sent, or `None` when it can
#[frb(sync)]
pub fn users_validate_draft(draft: UserDraft) -> Option<UserError> {
    users::validate_draft(&draft)
}

/// `useradd`, and `chpasswd` when the draft carries a password; needs root
#[frb(sync)]
pub fn users_create_command(draft: UserDraft) -> Result<String, UserError> {
    users::create_command(&draft)
}

/// `usermod` for the fields that changed, and `chpasswd`; needs root
#[frb(sync)]
pub fn users_edit_command(original: SystemUser, draft: UserDraft) -> Result<String, UserError> {
    users::edit_command(&original, &draft)
}

/// `userdel`, with `-r` when the home directory goes too; needs root
#[frb(sync)]
pub fn users_delete_command(user: SystemUser, remove_home: bool) -> Result<String, UserError> {
    users::delete_command(&user, remove_home)
}

/// A login shell as `user`, for a terminal opened from the account's page
#[frb(sync)]
pub fn users_login_shell_command(user: String) -> String {
    users::login_shell_command(&user)
}

/// Why a group draft cannot be sent, or `None` when it can. `original` is the
/// group being changed, absent for a new one; `accounts` every account's name.
#[frb(sync)]
pub fn groups_validate_draft(draft: GroupDraft, original: Option<SystemGroup>, accounts: Vec<String>) -> Option<UserError> {
    users::validate_group_draft(&draft, original.as_ref(), &accounts)
}

/// `groupadd`, and `gpasswd -M` when the draft names members; needs root
#[frb(sync)]
pub fn groups_create_command(draft: GroupDraft, accounts: Vec<String>) -> Result<String, UserError> {
    users::group_create_command(&draft, &accounts)
}

/// `gpasswd -M` for a member list that changed; needs root
#[frb(sync)]
pub fn groups_edit_command(original: SystemGroup, draft: GroupDraft, accounts: Vec<String>) -> Result<String, UserError> {
    users::group_edit_command(&original, &draft, &accounts)
}

/// Why `userdel` would be refused for `current` (the account the catalog was
/// read as), or `None`
#[frb(sync)]
pub fn users_delete_refusal(user: SystemUser, current: Option<String>) -> Option<UserError> {
    user.delete_refusal(current.as_deref())
}

/// Why `groupdel` would be refused, or `None`
#[frb(sync)]
pub fn groups_delete_refusal(group: SystemGroup) -> Option<UserError> {
    group.delete_refusal()
}

/// `groupdel`; refused for root and for a group that is an account's primary
/// group
#[frb(sync)]
pub fn groups_delete_command(group: SystemGroup) -> Result<String, UserError> {
    users::group_delete_command(&group)
}
