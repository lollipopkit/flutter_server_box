//! `/api/v1/system-users` — the accounts of the machine the agent runs on, one
//! account's own records, and the create, change or removal of one.
//!
//! Not `/users`, which is this agent's own accounts (`api/admin.rs`).
//!
//! # Why this is not `/exec`
//!
//! Which files an account is, how a group membership is derived from two of
//! them, what a shadow field means, what name `useradd` accepts and which flags
//! each command takes — all of that is one model, and it lives in
//! [`sbm_parser::users`]. The app reads and edits the same accounts through the
//! same module over FFI, so the panel and the app agree about a machine, and
//! the panel composes no command line and parses nothing.
//!
//! # Linux only
//!
//! macOS keeps accounts in a directory service, and `/etc/passwd` there is a
//! legacy file that names no real account; BSD's `useradd` takes different
//! flags from the ones the module builds. Both are answered as
//! [`UserReason::UnsupportedPlatform`] rather than guessed at.
//!
//! # The account is resolved against a listing, never taken from the client
//!
//! A write names an account and, for a change, sends the fields it wants. The
//! account as it *is* comes from a listing this endpoint runs for the request:
//! [`edit_command`] diffs against that, so a client that sends back a copy it
//! was given minutes ago cannot revert a change made in between. A name that
//! is not in the current listing is refused before the machine is touched.
//!
//! # Privilege
//!
//! The `shell` grant for both halves (`api::machine::gate`): a listing shows
//! every account and the shadow records the agent's user can read, and anyone
//! who can open a shell can run `useradd` in it. The reads run as the agent's
//! own user, and the detail says which parts it could not read rather than
//! answering them empty. Every write runs as root. Two passwords travel in the
//! body and neither reaches a command line: the `sudo` one in its own field,
//! written to sudo's stdin, and the account's own inside the script, which
//! then goes through `machine::as_root_private` rather than a command line.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use sbm_parser::SystemType;
use sbm_parser::users::{
    LIST_SCRIPT, SystemUser, UserCatalog, UserDetail, UserDraft, create_command, delete_command,
    detail_script, edit_command, parse_detail, parse_list,
};

use super::machine;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome};
use crate::core::permissions::Grant;
use crate::monitoring::system_type;

/// The listing reads both catalogs whole, and on a machine wired to a directory
/// service they are not small.
const LIST_BYTES: usize = 4 * 1024 * 1024;

/// Which of the machine's account records a request wants.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UserPart {
    /// The accounts themselves.
    #[default]
    List,
    /// What `/etc/shadow`, the account's `authorized_keys` and sudoers say
    /// about one account, named by [`UserQuery::name`].
    Detail,
}

#[derive(Serialize)]
struct UserListResponse {
    part: UserPart,
    /// Whether the machine's accounts could be read. `false` is a state of the
    /// machine, never a failure of the request, so the panel draws one page
    /// either way.
    available: bool,
    /// Which of the known reasons it was, phrased by the panel.
    reason_kind: Option<UserReason>,
    /// What the machine said, verbatim: the only thing that tells one failure
    /// from another.
    reason: Option<String>,
    /// The account the agent runs as, the one account it will not remove: it
    /// is a process on this machine, and `userdel -r` would take the home it
    /// reads its own configuration from. `None` when the catalog did not
    /// answer, so no name is ever offered as safe to delete without one.
    agent_account: Option<String>,
    /// The uid below which this machine counts an account as a system one,
    /// from `/etc/login.defs`. A page that assumed 1000 would misdraw every
    /// distribution that sets another.
    uid_min: Option<u32>,
    users: Vec<UserRow>,
    /// The account [`UserPart::Detail`] is about, echoed because a response is
    /// read beside a request that may be older.
    name: Option<String>,
    detail: Option<UserDetail>,
}

#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "snake_case")]
enum UserReason {
    /// Not Linux. See the module doc.
    UnsupportedPlatform,
    /// The listing script could not be run, or printed nothing this build could
    /// read — including an output with no current-user line, since everything
    /// below that line could be about another machine.
    Unreadable,
    /// The account named is not in the current listing.
    NoSuchUser,
}

/// One account as the panel draws it.
#[derive(Serialize)]
struct UserRow {
    #[serde(flatten)]
    user: SystemUser,
    /// `uid == 0`. Here rather than derived in the panel, so the rule has one
    /// implementation — the one [`delete_command`] refuses on.
    is_root: bool,
    /// Below [`UserListResponse::uid_min`].
    system: bool,
    /// The shell is `nologin` or `false`. About the shell only: a locked
    /// password is the detail's `password_state`.
    login_disabled: bool,
    agent_account: bool,
    /// Whether this endpoint would remove it: not root, not the agent's own.
    deletable: bool,
}

impl UserRow {
    fn of(user: &SystemUser, uid_min: u32, agent_account: &str) -> Self {
        let is_root = user.is_root();
        let is_agent = user.name == agent_account;
        Self {
            is_root,
            system: user.is_system(uid_min),
            login_disabled: user.login_disabled(),
            agent_account: is_agent,
            deletable: !is_root && !is_agent,
            user: user.clone(),
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct UserQuery {
    part: Option<UserPart>,
    /// The account name, for [`UserPart::Detail`].
    name: Option<String>,
}

/// Reads the machine's accounts, or one account's own records.
pub async fn list(
    req: HttpRequest,
    query: web::types::Query<UserQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Shell, "system-users list").await {
        return Ok(refused);
    }
    let part = query.part.unwrap_or_default();
    let name = query.name.as_deref().filter(|name| !name.is_empty());
    // A part about one account that was not told which is a request that
    // cannot be answered, refused before anything runs on the machine.
    if part == UserPart::Detail && name.is_none() {
        return Ok(HttpResponse::BadRequest().finish());
    }
    let exec = &state.remote_access.exec;

    if system_type() != SystemType::Linux {
        return Ok(HttpResponse::Ok().json(&empty_response(part, UserReason::UnsupportedPlatform, None)));
    }
    let catalog = match read_catalog(exec).await {
        Ok(catalog) => catalog,
        Err(reason) => {
            return Ok(HttpResponse::Ok().json(&empty_response(part, UserReason::Unreadable, reason)));
        }
    };

    let mut response = UserListResponse {
        part,
        available: true,
        reason_kind: None,
        reason: None,
        agent_account: Some(catalog.current_user.clone()),
        uid_min: Some(catalog.uid_min),
        users: catalog
            .users
            .iter()
            .map(|user| UserRow::of(user, catalog.uid_min, &catalog.current_user))
            .collect(),
        name: None,
        detail: None,
    };
    if part == UserPart::List {
        return Ok(HttpResponse::Ok().json(&response));
    }

    // Resolved against the catalog: the name is the request's, everything else
    // about the account is the machine's.
    let name = name.unwrap_or_default();
    let Some(user) = catalog.find(name).cloned() else {
        return Ok(HttpResponse::Ok().json(&empty_response(
            part,
            UserReason::NoSuchUser,
            Some(name.to_string()),
        )));
    };
    match read_detail(&user, exec).await {
        Ok(detail) => {
            response.name = Some(user.name.clone());
            response.detail = Some(detail);
            Ok(HttpResponse::Ok().json(&response))
        }
        Err(reason) => Ok(HttpResponse::Ok().json(&empty_response(part, UserReason::Unreadable, reason))),
    }
}

/// Creates, changes or removes one account.
pub async fn act(
    req: HttpRequest,
    body: web::types::Json<UserActRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    // The action and the account, never a field's value or a password.
    let what = format!("system-users {}", request.subject());
    let gated = match machine::gate(&req, &state, Grant::Shell, &what).await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };
    let exec = &state.remote_access.exec;
    let record = |action, outcome, detail: Option<&str>| {
        Event::new(Kind::Machine, action, outcome)
            .subject(&gated.caller.username)
            .remote_ip(gated.remote_ip.clone())
            .detail(match detail {
                Some(detail) => format!("{what}: {detail}"),
                None => what.clone(),
            })
    };

    if system_type() != SystemType::Linux {
        record(Action::Denied, Outcome::Denied, Some("unsupported platform")).record(&state.db).await;
        return Ok(Refusal::of("unsupportedPlatform").http());
    }
    // Run now, so a name the machine no longer has cannot be acted on through
    // a stale one.
    let Ok(catalog) = read_catalog(exec).await else {
        record(Action::Denied, Outcome::Denied, Some("unreadable catalog")).record(&state.db).await;
        return Ok(Refusal::of("unreadable").http());
    };
    let command_text = match request.command(&catalog) {
        Ok(command_text) => command_text,
        // The refusal's own code is what the row holds, so an operator reading
        // the log has the word the caller was given.
        Err(refusal) => {
            record(Action::Denied, Outcome::Denied, Some(refusal.code)).record(&state.db).await;
            return Ok(refusal.http());
        }
    };

    // Recorded before it runs: what was asked of the machine is on file
    // whatever happens next.
    record(Action::Open, Outcome::Ok, None).record(&state.db).await;
    let sudo = request.password.as_deref();
    let out = if request.carries_secret() {
        machine::as_root_private(&command_text, sudo, exec).await
    } else {
        machine::as_root(&command_text, sudo, exec).await
    };
    let sudo_rejected = out
        .as_ref()
        .is_ok_and(|out| sbm_parser::script::sudo_password_rejected(&out.stderr));
    let succeeded = out
        .as_ref()
        .is_ok_and(|out| out.exit_code == Some(0) && !out.timed_out);
    if !succeeded {
        let why = if sudo_rejected { "sudo password rejected" } else { "command failed" };
        record(Action::Close, Outcome::Error, Some(why)).record(&state.db).await;
    }

    let (stdout, stderr, exit_code) = match out {
        Ok(out) => (out.stdout, out.stderr, out.exit_code),
        Err(e) => (String::new(), e.to_string(), None),
    };
    Ok(HttpResponse::Ok().json(&UserActResponse {
        succeeded,
        sudo_rejected,
        exit_code,
        stdout,
        stderr,
    }))
}

/// One write, as the client describes it.
#[derive(Debug, Deserialize)]
pub struct UserActRequest {
    action: UserAction,
    /// The account as the caller wants it, for a create or a change.
    #[serde(default)]
    draft: Option<UserDraft>,
    /// Which account a change or a removal is about. The account as it is comes
    /// from a listing this endpoint runs, never from here.
    #[serde(default)]
    name: Option<String>,
    /// Whether a removal takes the home directory with it. `userdel -r` is not
    /// undoable, so it is asked rather than assumed.
    #[serde(default)]
    remove_home: bool,
    /// The `sudo` password, when the caller has one: see `machine::as_root`.
    /// The account's own password is [`UserDraft::password`].
    #[serde(default)]
    password: Option<String>,
}

impl UserActRequest {
    /// What was asked of which account, for the audit row.
    fn subject(&self) -> String {
        let target = self
            .draft
            .as_ref()
            .map(|draft| draft.name.clone())
            .or_else(|| self.name.clone())
            .unwrap_or_default();
        format!("{} {target}", self.action.as_str())
    }

    /// Whether the command will hold the account's new password.
    fn carries_secret(&self) -> bool {
        self.action != UserAction::Delete
            && self
                .draft
                .as_ref()
                .is_some_and(|draft| draft.password.as_deref().is_some_and(|p| !p.is_empty()))
    }

    /// The command this write runs. `Err` is a refusal made before the machine
    /// is touched: what the caller sent is theirs to get right, and a name the
    /// machine does not have is not one to run a command about.
    fn command(&self, catalog: &UserCatalog) -> Result<String, Refusal> {
        match self.action {
            UserAction::Create => {
                let draft = self.draft.as_ref().ok_or(Refusal::of("missingDraft"))?;
                // Answered as a duplicate rather than as whatever `useradd`
                // says, in its own language, about a uid.
                if catalog.find(&draft.name).is_some() {
                    return Err(Refusal::of("userExists"));
                }
                create_command(draft).map_err(|error| Refusal::of(error.as_str()))
            }
            UserAction::Edit => {
                let draft = self.draft.as_ref().ok_or(Refusal::of("missingDraft"))?;
                edit_command(self.target(catalog)?, draft).map_err(|error| Refusal::of(error.as_str()))
            }
            UserAction::Delete => {
                let user = self.target(catalog)?;
                if user.name == catalog.current_user {
                    return Err(Refusal::of("agentAccount"));
                }
                delete_command(user, self.remove_home).map_err(|error| Refusal::of(error.as_str()))
            }
        }
    }

    /// The account this write names, as the catalog has it.
    fn target<'a>(&self, catalog: &'a UserCatalog) -> Result<&'a SystemUser, Refusal> {
        let name = self
            .name
            .as_deref()
            .filter(|name| !name.is_empty())
            .ok_or(Refusal::of("missingName"))?;
        catalog.find(name).ok_or(Refusal::absent())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
enum UserAction {
    Create,
    Edit,
    Delete,
}

impl UserAction {
    fn as_str(self) -> &'static str {
        match self {
            Self::Create => "create",
            Self::Edit => "edit",
            Self::Delete => "delete",
        }
    }
}

#[derive(Serialize)]
struct UserActResponse {
    /// Whether the command exited zero. What the machine said is in `stderr`.
    succeeded: bool,
    /// `sudo` refused the password that was sent, or was not given one and
    /// needed it: the caller's next move is to ask for one and send the same
    /// request again.
    sudo_rejected: bool,
    exit_code: Option<i32>,
    stdout: String,
    stderr: String,
}

// ---------------------------------------------------------------------------
// Reading the machine
// ---------------------------------------------------------------------------

/// Runs the catalog script and reads both catalogs out of it. `Err` carries
/// what the machine said.
async fn read_catalog(exec: &super::exec::Limits) -> Result<UserCatalog, Option<String>> {
    let output = machine::command_output(
        machine::as_self(LIST_SCRIPT, &machine::at_least(exec, LIST_BYTES)).await,
    );
    parse_list(&output.stdout).map_err(|_| {
        output
            .stderr
            .lines()
            .map(str::trim)
            .find(|line| !line.is_empty())
            .map(str::to_string)
    })
}

/// One account's own records. Every field may be unreadable on its own and
/// the shape says which were, so `Err` is only the run itself failing —
/// every read in the script may fail and the last is `|| true`, so a non-zero
/// exit, a timeout or a spawn that failed is not an account with unreadable
/// records. It carries what was said about it.
async fn read_detail(user: &SystemUser, exec: &super::exec::Limits) -> Result<UserDetail, Option<String>> {
    let Ok(script) = detail_script(user) else {
        // A name the catalog lists but `valid_name` will not put in a script —
        // an uppercase one from LDAP or sssd, say. Nothing was read about it,
        // and a detail with every field unreadable is exactly that.
        return Ok(parse_detail("", &user.name));
    };
    let output = machine::command_output(machine::as_self(&script, exec).await);
    if !output.succeeded {
        return Err(output.detail());
    }
    Ok(parse_detail(&output.stdout, &user.name))
}

// ---------------------------------------------------------------------------
// Responses
// ---------------------------------------------------------------------------

#[derive(Serialize)]
struct ErrorResponse {
    /// A [`UserError`](sbm_parser::users::UserError) code or one of this
    /// endpoint's own. Never a sentence: the panel phrases it.
    error: String,
}

/// A request refused before the machine was touched: 400, or 404 for an
/// account the machine does not have, which is a state rather than a mistake.
#[derive(Debug)]
struct Refusal {
    code: &'static str,
    absent: bool,
}

impl Refusal {
    fn of(code: &'static str) -> Self {
        Self { code, absent: false }
    }

    fn absent() -> Self {
        Self {
            code: "noSuchUser",
            absent: true,
        }
    }

    fn http(&self) -> HttpResponse {
        let mut builder = if self.absent {
            HttpResponse::NotFound()
        } else {
            HttpResponse::BadRequest()
        };
        builder.json(&ErrorResponse {
            error: self.code.to_string(),
        })
    }
}

fn empty_response(part: UserPart, reason_kind: UserReason, reason: Option<String>) -> UserListResponse {
    UserListResponse {
        part,
        available: false,
        reason_kind: Some(reason_kind),
        reason,
        // None of them: with no listing there is no account this endpoint
        // could name as the one not to remove.
        agent_account: None,
        uid_min: None,
        users: Vec::new(),
        name: None,
        detail: None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A catalog from a machine that is not this one, so the halves that are
    /// not the machine's run on every platform the suite does.
    const LISTING: &str = "SrvBoxUsers.Current\tadmin\n\
SrvBoxUsers.UidMin\t1000\n\
SrvBoxUsers.Passwd\n\
root:x:0:0:root:/root:/bin/bash\n\
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin\n\
admin:x:1000:1000:Admin User:/home/admin:/bin/bash\n\
deploy:x:1001:1000:Deploy:/srv/deploy:/bin/sh\n\
SrvBoxUsers.Group\n\
root:x:0:\n\
users:x:1000:admin\n\
docker:x:998:admin,deploy\n";

    fn catalog() -> UserCatalog {
        parse_list(LISTING).expect("the fixture parses")
    }

    fn request(action: UserAction) -> UserActRequest {
        UserActRequest {
            action,
            draft: None,
            name: None,
            remove_home: false,
            password: None,
        }
    }

    fn draft(name: &str) -> UserDraft {
        UserDraft {
            name: name.to_string(),
            comment: String::new(),
            home: String::new(),
            shell: String::new(),
            primary_group: String::new(),
            supplementary_groups: Vec::new(),
            create_home: true,
            move_home: false,
            system: false,
            password: None,
        }
    }

    #[test]
    fn a_row_carries_the_flags_the_panel_draws_from() {
        let catalog = catalog();
        let row = |name: &str| {
            let user = catalog.find(name).expect("the fixture has it");
            UserRow::of(user, catalog.uid_min, &catalog.current_user)
        };
        let root = row("root");
        assert!(root.is_root && !root.deletable && !root.agent_account);
        let daemon = row("daemon");
        assert!(daemon.system && daemon.login_disabled && daemon.deletable);
        let agent = row("admin");
        assert!(agent.agent_account && !agent.deletable && !agent.is_root);
        // At the threshold is not below it.
        assert!(!agent.system);
    }

    /// The account as it is comes from the listing, so a change names only
    /// what differs from it.
    #[test]
    fn a_change_is_diffed_against_the_catalogs_account() {
        let catalog = catalog();
        let original = catalog.find("deploy").expect("the fixture has it");
        let mut wanted = draft("deploy");
        wanted.comment = original.comment.clone();
        wanted.home = original.home.clone();
        wanted.primary_group = original.primary_group.clone().unwrap_or_default();
        wanted.supplementary_groups = original.supplementary_groups.clone();
        wanted.shell = "/bin/bash".to_string();
        let mut request = request(UserAction::Edit);
        request.name = Some("deploy".to_string());
        request.draft = Some(wanted);
        assert_eq!(request.command(&catalog).unwrap(), "usermod -s '/bin/bash' 'deploy'");
    }

    #[test]
    fn a_write_is_refused_before_a_command_is_built() {
        let catalog = catalog();
        let code = |request: UserActRequest| match request.command(&catalog) {
            Err(refusal) => refusal.code,
            Ok(command) => panic!("not refused: {command}"),
        };
        assert_eq!(code(request(UserAction::Create)), "missingDraft");
        let mut create = request(UserAction::Create);
        create.draft = Some(draft("admin"));
        assert_eq!(code(create), "userExists");
        let mut bad = request(UserAction::Create);
        bad.draft = Some(draft("bad;touch /tmp/pwned"));
        assert_eq!(code(bad), "invalidName");
        let mut root = request(UserAction::Delete);
        root.name = Some("root".to_string());
        assert_eq!(code(root), "rootNotDeletable");
        let mut agent = request(UserAction::Delete);
        agent.name = Some("admin".to_string());
        assert_eq!(code(agent), "agentAccount");
        let mut unknown = request(UserAction::Delete);
        unknown.name = Some("nobody".to_string());
        assert_eq!(code(unknown), "noSuchUser");
        let mut rename = request(UserAction::Edit);
        rename.name = Some("deploy".to_string());
        rename.draft = Some(draft("deploy2"));
        assert_eq!(code(rename), "renaming");
        assert_eq!(code(request(UserAction::Delete)), "missingName");
    }

    #[test]
    fn a_removal_says_whether_the_home_goes_with_it() {
        let catalog = catalog();
        let mut request = request(UserAction::Delete);
        request.name = Some("deploy".to_string());
        assert_eq!(request.command(&catalog).unwrap(), "userdel 'deploy'");
        request.remove_home = true;
        assert_eq!(request.command(&catalog).unwrap(), "userdel -r 'deploy'");
    }

    /// A command that holds the account's password goes through a private
    /// file rather than the root shell's command line; one that does not, or
    /// a removal, has nothing to hide.
    #[test]
    fn only_a_command_holding_a_password_is_kept_off_the_command_line() {
        let mut create = request(UserAction::Create);
        create.draft = Some(draft("svc"));
        assert!(!create.carries_secret());
        create.draft.as_mut().unwrap().password = Some("hunter2".into());
        assert!(create.carries_secret());
        let command = create.command(&catalog()).unwrap();
        assert!(command.contains("hunter2"), "the password is in the script itself");
        create.draft.as_mut().unwrap().password = Some(String::new());
        assert!(!create.carries_secret());

        let mut delete = request(UserAction::Delete);
        delete.name = Some("deploy".into());
        delete.draft = Some(UserDraft {
            password: Some("ignored".into()),
            ..draft("deploy")
        });
        assert!(!delete.carries_secret());
    }

    /// The sudo password and the account's are never part of what is
    /// recorded.
    #[test]
    fn the_audit_subject_is_the_action_and_the_account() {
        let mut create = request(UserAction::Create);
        create.draft = Some(UserDraft {
            password: Some("hunter2".into()),
            ..draft("svc")
        });
        create.password = Some("sudo-secret".into());
        assert_eq!(create.subject(), "create svc");
    }
}
