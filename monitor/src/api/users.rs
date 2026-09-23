//! `/api/v1/users` — the accounts of the machine the agent runs on, one
//! account's own records, and the create, change or removal of one.
//!
//! # Why this is not `/exec`
//!
//! Which files an account is, how a group membership is derived from two of
//! them, what a shadow field means, what a name `useradd` accepts and which
//! flags each of the four commands takes — all of that is one model, and it
//! lives in [`sbm_parser::users`]. The app reads and edits the same accounts
//! over SSH through the same module, so the panel and the app agree about a
//! machine, and the panel composes no command line and parses nothing.
//!
//! # Linux only
//!
//! [`UserReason::UnsupportedPlatform`] on anything else, and for both of the
//! other platforms for a reason of its own. macOS keeps accounts in a
//! directory service, and `/etc/passwd` there is a legacy file that names no
//! real account — listing it would draw a machine that is not this one. BSD's
//! `useradd` takes different flags from the ones here, so a create on one would
//! either fail or quietly do something else; the module is written against
//! Linux's and refuses to guess.
//!
//! # The account is resolved against a listing, never taken from the client
//!
//! A write names an account and, for a change, sends the fields it wants. The
//! account as it *is* comes from a listing this endpoint runs at the moment of
//! the request — [`edit_command`](sbm_parser::users::edit_command) diffs against
//! that, so a client that sent back a copy it was given minutes ago cannot
//! revert a change made in between, and one that sent the whole account back is
//! not the thing deciding which fields differ. A name that is not in the
//! current listing is refused before the machine is touched.
//!
//! # Privilege
//!
//! Reading needs only the panel login: the listing script and the detail script
//! run as the agent's own user, and what they can read is what that user can
//! read — an unprivileged session sees every account and its own shadow record,
//! and the detail says which parts it could not read rather than answering them
//! empty. **Every write is `full_access`**, the same grant as the shell and
//! `/exec`: anyone who can open a shell can run `useradd` in it, so a switch of
//! its own would withhold nothing. Two passwords travel in the body and neither
//! reaches a command line: the `sudo` one in its own field like every other
//! endpoint, and the account's own as part of the script, which
//! [`sbm_parser::users`] writes into a `chpasswd` heredoc on stdin.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use super::privileged;
use super::server::AppState;
use super::server::verify_auth;
use super::ws;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::monitoring::system_type;
use crate::utils::command::Limits;
use sbm_parser::SystemType;
use sbm_parser::users::{
    LIST_SCRIPT, SystemUser, UserCatalog, UserDetail, UserDraft, create_command, delete_command,
    detail_script, edit_command, parse_detail, parse_list,
};

/// The listing reads both catalogs whole, and on a machine wired to a directory
/// service they are not small. The 1 MiB default would cost the reader the
/// whole page rather than the one row that went over.
const LIST_LIMITS: Limits = Limits {
    max_output_bytes: 4 * 1024 * 1024,
    ..Limits::DEFAULT
};

/// Which of the account's own records a request wants. The catalog is the
/// default; the detail is about one account and needs [`UserQuery::name`].
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum UserPart {
    /// The accounts themselves.
    #[default]
    List,
    /// What `/etc/shadow`, the account's `authorized_keys` and sudoers say.
    Detail,
}

impl UserPart {
    fn needs_name(self) -> bool {
        self != Self::List
    }
}

#[derive(Serialize)]
struct UserListResponse {
    part: UserPart,
    /// Whether the machine's accounts could be read. `false` is a state of the
    /// machine or of this build's knowledge of it, never a failure of a
    /// request's syntax, so the panel draws one page either way.
    available: bool,
    /// Which of the known reasons it was, so the panel phrases it in its own
    /// language. `None` alongside `available: false` means the machine said
    /// something this endpoint does not classify, and `reason` is it.
    reason_kind: Option<UserReason>,
    /// What the machine said, verbatim. Never translated and never classified
    /// away: it is the only thing that distinguishes one failure from another.
    reason: Option<String>,
    /// Whether this caller may change anything. The page asks so it can draw a
    /// read-only view instead of failing on a click; the answer is re-checked
    /// on the write itself, since a UI hint is not a boundary.
    editable: bool,
    /// The account the agent itself runs as, which is the one account it must
    /// not remove: it is a process on this machine, `userdel -r` would take the
    /// home the service reads its config from, and nothing would be left to
    /// answer the next request. `None` when the catalog could not be read —
    /// which is also why the panel is never told a name it may delete when the
    /// listing did not answer.
    agent_account: Option<String>,
    /// The uid below which this machine counts an account as a system one, from
    /// `/etc/login.defs`. Sent because the panel cannot derive it and a page
    /// that assumed 1000 would misdraw every distribution that sets another.
    uid_min: Option<u32>,
    users: Vec<UserRow>,
    /// The account the detail part is about, echoed for the same reason the
    /// part is: a response is read beside a request that may be older.
    name: Option<String>,
    /// What that account's own records hold, for [`UserPart::Detail`].
    detail: Option<UserDetail>,
}

#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "snake_case")]
enum UserReason {
    /// Not Linux. See the module doc for what each of the other platforms
    /// would answer with instead and why none of them is right.
    UnsupportedPlatform,
    /// The listing script could not be run, or printed nothing this build could
    /// read — including an output with no current-user line, since everything
    /// below that line could be about another machine.
    Unreadable,
    /// The account named is not in the current listing. One removed between the
    /// page being drawn and the request, and nothing the caller can retry.
    NoSuchUser,
}

/// One account as the panel draws it.
#[derive(Serialize)]
struct UserRow {
    #[serde(flatten)]
    user: SystemUser,
    /// `uid == 0`. Here rather than derived in the panel so that the rule has
    /// one implementation, the same one [`delete_command`] refuses on.
    is_root: bool,
    /// Below the machine's own threshold, from [`UserListResponse::uid_min`].
    system: bool,
    /// The shell is `nologin` or `false`, so no password or key login. About
    /// the shell only: a locked password is the detail's `password_state`.
    login_disabled: bool,
    /// The account the agent runs as. Sent per row as well as once at the top
    /// so that marking it is not a second lookup of the same fact.
    agent_account: bool,
    /// Whether this endpoint would remove it: false for root and for the
    /// agent's own account, which are the two refusals `act` makes. Whether
    /// *this caller* may is [`UserListResponse::editable`], which is a
    /// different question and is re-checked on the write.
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

/// Creates, changes or removes one account.
pub async fn act(
    req: HttpRequest,
    body: web::types::Json<UserActRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }

    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    // Re-checked at the moment of use rather than trusted from the `editable`
    // the client was told earlier: that answer is a UI hint, and the UI is not
    // a boundary.
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::User, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    let request = body.into_inner();
    let subject = request.subject();
    let deny = |detail: &'static str| {
        Event::new(Kind::User, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip.clone())
            .subject(subject.clone())
            .detail(detail)
    };

    if system_type() != SystemType::Linux {
        deny("unsupported platform").record(&app_state.db).await;
        return Ok(Refusal::of("unsupportedPlatform").http());
    }

    // The listing this write is resolved against is run here, so a name that
    // the machine no longer has cannot be acted on through a stale one.
    let catalog = match read_catalog().await {
        Ok(catalog) => catalog,
        Err(_) => {
            deny("unreadable catalog").record(&app_state.db).await;
            return Ok(Refusal::of("unreadable").http());
        }
    };

    let (command_text, target) = match request.command(&catalog) {
        Ok(built) => built,
        // The refusal's own code is what the row holds: an operator reading the
        // log later has the same word the caller was given, which is what tells
        // a name the machine does not have from a name it will not accept.
        Err(refusal) => {
            deny(refusal.code).record(&app_state.db).await;
            return Ok(refusal.http());
        }
    };

    // Every one of these four commands changes the account database, so every
    // one of them is run as root.
    let output = privileged::as_root(
        &command_text,
        "user act",
        Limits::DEFAULT,
        request.password.as_deref(),
    )
    .await;
    let sudo_rejected = privileged::sudo_rejected(output.as_ref());
    let succeeded = output
        .as_ref()
        .is_some_and(|output| output.status.success());

    // One row per write, after the outcome is known. A listing is not recorded
    // at all, so a row here is always a change.
    let (action, result, detail) = match (succeeded, sudo_rejected) {
        (true, _) => (Action::Write, Outcome::Ok, None),
        (false, true) => (Action::Write, Outcome::Error, Some("sudo password rejected")),
        (false, false) => (Action::Write, Outcome::Error, Some("command failed")),
    };
    let mut event = Event::new(Kind::User, action, result)
        .remote_ip(remote_ip)
        .subject(format!("{} {target}", request.action.as_str()));
    if let Some(detail) = detail {
        event = event.detail(detail);
    }
    event.record(&app_state.db).await;

    let (stdout, stderr, exit_code) = match &output {
        Some(output) => (
            String::from_utf8_lossy(&output.stdout).into_owned(),
            String::from_utf8_lossy(&output.stderr).into_owned(),
            output.status.code(),
        ),
        None => (String::new(), String::new(), None),
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
    /// The whole account as the caller wants it, for a create or a change.
    #[serde(default)]
    draft: Option<UserDraft>,
    /// Which account a change or a removal is about. The account as it is comes
    /// from a listing this endpoint runs, never from here.
    #[serde(default)]
    name: Option<String>,
    /// Whether a removal takes the home directory with it. `userdel -r` is not
    /// undoable, so it is asked separately rather than assumed.
    #[serde(default)]
    remove_home: bool,
    /// The `sudo` password, when the caller has one. Its own field so it never
    /// reaches a command line: see `api::privileged`. The account's own
    /// password is [`UserActRequest::draft`]'s, and it travels inside the
    /// script down the same pipe.
    #[serde(default)]
    password: Option<String>,
}

impl UserActRequest {
    /// The listing's `subject` half: what was asked of which account.
    fn subject(&self) -> String {
        let target = self
            .draft
            .as_ref()
            .map(|draft| draft.name.clone())
            .or_else(|| self.name.clone())
            .unwrap_or_default();
        format!("{} {target}", self.action.as_str())
    }

    /// The command this write runs, and the account it names.
    ///
    /// `Err` is a refusal already classified: what the caller sent is the
    /// caller's to get right, and every refusal that does not depend on the
    /// machine is made before it is touched. The account is looked up in the
    /// catalog for the same reason — a name the machine does not have is not
    /// one to run a command about, and `usermod`'s own error for it is a
    /// localized sentence this endpoint would have to parse.
    fn command(&self, catalog: &UserCatalog) -> Result<(String, String), Refusal> {
        let agent_account = catalog.current_user.as_str();
        match self.action {
            UserAction::Create => {
                let Some(draft) = &self.draft else {
                    return Err(Refusal::of("missingDraft"));
                };
                // Before the machine is touched: `useradd` would refuse it too,
                // in its own language, and the panel would have nothing to
                // phrase. Looked up by name so a duplicate is answered as one
                // rather than as whatever `useradd` says about a uid.
                if catalog.find(&draft.name).is_some() {
                    return Err(Refusal::of("userExists"));
                }
                let command =
                    create_command(draft).map_err(|error| Refusal::of(error.as_str()))?;
                Ok((command, draft.name.clone()))
            }
            UserAction::Edit => {
                let Some(draft) = &self.draft else {
                    return Err(Refusal::of("missingDraft"));
                };
                let user = self.target(catalog)?;
                let command =
                    edit_command(user, draft).map_err(|error| Refusal::of(error.as_str()))?;
                Ok((command, user.name.clone()))
            }
            UserAction::Delete => {
                let user = self.target(catalog)?;
                // The one account that must not be removed: the agent is a
                // process on this machine, and `userdel -r` would take the home
                // it reads its own config from.
                if user.name == agent_account {
                    return Err(Refusal::of("agentAccount"));
                }
                let command = delete_command(user, self.remove_home)
                    .map_err(|error| Refusal::of(error.as_str()))?;
                Ok((command, user.name.clone()))
            }
        }
    }

    /// The account this write names, as the catalog has it.
    fn target<'a>(&self, catalog: &'a UserCatalog) -> Result<&'a SystemUser, Refusal> {
        let Some(name) = self.name.as_deref().filter(|name| !name.is_empty()) else {
            return Err(Refusal::of("missingName"));
        };
        let Some(user) = catalog.find(name) else {
            return Err(Refusal::absent());
        };
        Ok(user)
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
    /// Whether the command exited zero. What the machine said about it is in
    /// `stderr`, and it is the only thing that distinguishes one failure from
    /// another.
    succeeded: bool,
    /// `sudo` refused the password that was sent, or was not given one and
    /// needed it. Told apart from any other failure because the caller's next
    /// move is to ask for a password and send the same request again.
    sudo_rejected: bool,
    exit_code: Option<i32>,
    stdout: String,
    stderr: String,
}

#[derive(Deserialize)]
pub struct UserQuery {
    /// Which of the account's records to read. Defaults to the catalog.
    part: Option<UserPart>,
    /// The account name, for the parts that are about one account.
    name: Option<String>,
}

/// Reads the machine's accounts, or one account's own records.
pub async fn list(
    req: HttpRequest,
    query: web::types::Query<UserQuery>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    let editable = app_state.full_access_allowed(secure);
    let part = query.part.unwrap_or_default();
    let name = query.name.as_deref();
    // A part that is about one account and was not told which is a request that
    // cannot be answered, not one to guess a default for. Refused before
    // anything runs, so a malformed request costs nothing on the machine.
    if part.needs_name() && name.is_none_or(str::is_empty) {
        return Ok(HttpResponse::BadRequest().finish());
    }

    if system_type() != SystemType::Linux {
        return Ok(HttpResponse::Ok().json(&empty_response(
            part,
            editable,
            UserReason::UnsupportedPlatform,
            None,
        )));
    }

    let catalog = match read_catalog().await {
        Ok(catalog) => catalog,
        Err(reason) => {
            return Ok(HttpResponse::Ok().json(&empty_response(
                part,
                editable,
                UserReason::Unreadable,
                reason,
            )));
        }
    };

    let mut response = UserListResponse {
        part,
        available: true,
        reason_kind: None,
        reason: None,
        editable,
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

    // Resolved against the catalog rather than read back from the request: the
    // name is the request's, everything else about the account is the
    // machine's, and a name that is not in the listing is not one to read.
    let name = name.unwrap_or_default();
    let Some(user) = catalog.find(name).cloned() else {
        return Ok(HttpResponse::Ok().json(&empty_response(
            part,
            editable,
            UserReason::NoSuchUser,
            Some(name.to_string()),
        )));
    };

    response.name = Some(user.name.clone());
    response.detail = Some(read_detail(&user).await);
    Ok(HttpResponse::Ok().json(&response))
}

// ---------------------------------------------------------------------------
// Reading the machine
// ---------------------------------------------------------------------------

/// Runs the catalog script and reads both catalogs out of it.
///
/// `Err` carries what the machine said, which is what
/// [`UserReason::Unreadable`] is phrased around. The script is run through `sh`
/// rather than as a command — see [`LIST_SCRIPT`] — which is what
/// [`privileged::as_self`] does with the text it is given.
async fn read_catalog() -> Result<UserCatalog, Option<String>> {
    let output = privileged::as_self(LIST_SCRIPT, "user catalog", LIST_LIMITS).await;
    let output = privileged::read(output.as_ref(), "the command could not be run");
    match parse_list(&output.stdout) {
        Ok(catalog) => Ok(catalog),
        // The stderr when there is one, and otherwise what the script printed:
        // a listing that did not run and a listing that ran and made no sense
        // are different failures, and the machine's own words are the only
        // thing that tells them apart.
        Err(_) => Err(output.detail().or_else(|| {
            output
                .stderr
                .lines()
                .find(|line| !line.trim().is_empty())
                .map(str::to_string)
        })),
    }
}

/// Reads one account's own records.
///
/// Never an error: every field of [`UserDetail`] may be unreadable on its own,
/// and the shape says which of them were. An unprivileged session is the
/// ordinary case — the machine answers about its own account.
async fn read_detail(user: &SystemUser) -> UserDetail {
    let Some(script) = detail_script(user).ok() else {
        // Only a name that is not one, which the catalog this came from could
        // not hold. Nothing readable is the right answer for it.
        return UserDetail {
            password_state: None,
            password_changed_millis: None,
            expires_millis: None,
            never_expires: false,
            ssh_key_types: None,
            sudo_rule: None,
        };
    };
    let output = privileged::as_self(&script, "user detail", Limits::DEFAULT).await;
    parse_detail(&privileged::read(output.as_ref(), "").combined())
}

// ---------------------------------------------------------------------------
// Responses
// ---------------------------------------------------------------------------

#[derive(Serialize)]
struct ErrorResponse {
    /// The stable code the panel phrases: a
    /// [`UserError`](sbm_parser::users::UserError) case, or one of this
    /// endpoint's own. Never a sentence — an agent that answered with English
    /// would be one the panel could not translate.
    error: String,
}

/// A request refused before the machine was touched.
///
/// 400 rather than the 200-with-a-reason the read path answers with: an
/// unreadable machine is a state, and a draft with a line break in it is a
/// mistake. The two are told apart by this status, which is what lets the panel
/// stop and phrase the code instead of redrawing a page.
#[derive(Debug)]
struct Refusal {
    code: &'static str,
    /// The account is not in the machine's catalog, which is a state of the
    /// machine rather than a mistake in the request: 404 rather than 400.
    absent: bool,
}

impl Refusal {
    fn of(code: &'static str) -> Self {
        Self {
            code,
            absent: false,
        }
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

/// A response with no accounts and a reason, which is what every "this machine
/// cannot be listed" answer is.
fn empty_response(
    part: UserPart,
    editable: bool,
    reason_kind: UserReason,
    reason: Option<String>,
) -> UserListResponse {
    UserListResponse {
        part,
        available: false,
        reason_kind: Some(reason_kind),
        reason,
        editable,
        // Deliberately none of them: with no listing there is no account this
        // endpoint could name as the one not to remove, and the panel draws no
        // rows to mark.
        agent_account: None,
        uid_min: None,
        users: Vec::new(),
        name: None,
        detail: None,
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    /// A catalog from a machine that is not this one, so the two halves that
    /// are not the machine's are exercised on every platform the suite runs on:
    /// of a row, which flags the panel draws from, and of a request, which
    /// decides what runs and what is refused before it does.
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

    /// Which of a row's four flags is what decides the button the panel draws.
    #[test]
    fn a_row_carries_the_flags_the_panel_draws_from() {
        let catalog = catalog();
        let row = |name: &str| {
            let user = catalog.find(name).expect("the fixture has it");
            UserRow::of(user, catalog.uid_min, &catalog.current_user)
        };

        let root = row("root");
        assert!(root.is_root && !root.deletable && !root.agent_account);
        assert!(!root.login_disabled);

        let daemon = row("daemon");
        assert!(daemon.system && daemon.login_disabled && daemon.deletable);

        let agent = row("admin");
        assert!(agent.agent_account && !agent.deletable && !agent.is_root);
        // `uid_min` is the machine's, not a constant: an account at the
        // threshold is not a system one.
        assert!(!agent.system);
        assert_eq!(agent.user.uid, catalog.uid_min);
    }

    /// The account as it is comes from the listing, so a change names only what
    /// differs — and a client that sent the whole account back does not get to
    /// decide that.
    #[test]
    fn a_change_is_diffed_against_the_catalogs_account() {
        let catalog = catalog();
        let original = catalog.find("deploy").expect("the fixture has it");

        // The whole account as the catalog has it, with one field changed.
        let mut wanted = draft("deploy");
        wanted.comment = original.comment.clone();
        wanted.home = original.home.clone();
        wanted.primary_group = original.primary_group.clone().unwrap_or_default();
        wanted.supplementary_groups = original.supplementary_groups.clone();
        wanted.shell = "/bin/bash".to_string();

        let mut request = request(UserAction::Edit);
        request.name = Some("deploy".to_string());
        request.draft = Some(wanted);

        let (command, target) = request.command(&catalog).expect("a valid change");
        assert_eq!(target, "deploy");
        // Everything else is the catalog's and is unchanged, so only the shell
        // appears.
        assert_eq!(command, "usermod -s '/bin/bash' 'deploy'");
    }

    /// The five fields are not symmetric about an empty one, and the difference
    /// is what a draft has to carry. `home` and `primary_group` are left alone
    /// when empty — neither can be cleared, since `usermod -d ''` and `-g ''`
    /// name no directory and no group — while an empty `comment` and an empty
    /// group list *are* the values, and clear what was there.
    #[test]
    fn an_empty_field_means_two_different_things() {
        let catalog = catalog();
        let mut request = request(UserAction::Edit);
        request.name = Some("deploy".to_string());
        // Nothing but the name: every field empty.
        request.draft = Some(draft("deploy"));

        let (command, _) = request.command(&catalog).expect("a valid change");
        assert_eq!(
            command,
            // The gecos and the group list are cleared; the home, the shell
            // and the primary group are the catalog's and stay.
            "usermod -c '' -G '' 'deploy'"
        );
    }

    /// Every refusal that does not depend on the machine, and the account it
    /// names is looked up in the same catalog the listing was built from.
    #[test]
    fn a_write_is_refused_before_a_command_is_built() {
        let catalog = catalog();
        let code = |request: UserActRequest| match request.command(&catalog) {
            Err(refusal) => refusal.code.to_string(),
            Ok((command, _)) => panic!("not refused: {command}"),
        };

        let mut create = request(UserAction::Create);
        assert_eq!(code(request(UserAction::Create)), "missingDraft");
        // `admin` is the account this catalog was read as.
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
    }

    /// `remove_home` is the caller's, and it is the whole difference between
    /// the two removals.
    #[test]
    fn a_removal_says_whether_the_home_goes_with_it() {
        let catalog = catalog();
        let mut request = request(UserAction::Delete);
        request.name = Some("deploy".to_string());
        assert_eq!(
            request.command(&catalog).expect("a valid removal").0,
            "userdel 'deploy'"
        );

        request.remove_home = true;
        assert_eq!(
            request.command(&catalog).expect("a valid removal").0,
            "userdel -r 'deploy'"
        );
    }
}
