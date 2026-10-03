//! `pve::Client` against a scripted PVE API: parsing, auth (ticket, TOTP,
//! token), the session dropped on 401 and not on 403, the generation guard,
//! ticket renewal, UPID polling and the state overlay after an action.
//!
//! Ported from the app's `test/unit/virt/pve_backend_test.dart`, which these
//! replace. TLS is `pve_tls.rs`, against a real TLS server.

use std::collections::HashMap;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use sbm_virt::error::{Detail, Error, ErrorKind};
use sbm_virt::model::{Guest, GuestKind, GuestState, HostView, PowerAction};
use sbm_virt::pve::client::{FRESH_STATUS_FOR_MS, TICKET_LIFETIME_MS};
use sbm_virt::pve::http::{BoxFuture, Connector, Http, Request, Response, TransportError};
use sbm_virt::pve::{Auth, Client, Clock, Config, Options, resources};
use serde_json::{Value, json};
use tokio::sync::{Notify, oneshot};

const UPID: &str = "UPID:pve:0001:0002:0003:qmstart:101:root@pam:";
const MIN: i64 = 60_000;

/// `/cluster/resources` from a one-node PVE 8, plus a locked guest and a
/// template.
fn resources_fixture() -> Vec<Value> {
    serde_json::from_value(json!([
        {"maxmem": 12884901888u64, "type": "lxc", "cpu": 0.0544631947461575, "netin": 65412250538u64,
         "template": 0, "diskread": 324033204224u64, "maxcpu": 8, "disk": 29767077888u64,
         "diskwrite": 707866570752u64, "node": "pve", "vmid": 100, "mem": 5389254656u64,
         "status": "running", "netout": 66898114418u64, "uptime": 1204757, "id": "lxc/100",
         "maxdisk": 134145380352u64, "name": "Jellyfin", "tags": "media;prod"},
        {"vmid": 101, "node": "pve", "uptime": 0, "netout": 0, "status": "stopped", "mem": 0,
         "id": "qemu/101", "name": "ubuntu", "maxdisk": 137438953472u64, "maxmem": 6442450944u64,
         "cpu": 0, "netin": 0, "type": "qemu", "disk": 0, "diskread": 0, "template": 0,
         "maxcpu": 8, "diskwrite": 0},
        {"maxcpu": 4, "template": 0, "diskread": 23287297536u64, "disk": 0,
         "diskwrite": 39555984896u64, "maxmem": 4294967296u64, "type": "qemu",
         "netin": 2190678599u64, "cpu": 0.0516426831961466, "id": "qemu/102", "maxdisk": 0,
         "name": "win", "node": "pve", "vmid": 102, "mem": 1791827968u64, "status": "running",
         "netout": 213292068u64, "uptime": 1013075},
        {"id": "qemu/103", "type": "qemu", "vmid": 103, "node": "pve", "name": "db",
         "status": "running", "lock": "backup", "maxcpu": 2, "maxmem": 2147483648u64,
         "cpu": 0.25, "mem": 1073741824u64},
        {"id": "qemu/9000", "type": "qemu", "vmid": 9000, "node": "pve", "name": "tmpl",
         "status": "stopped", "template": 1},
        {"id": "qemu/104", "type": "qemu", "vmid": 104, "node": "pve", "name": "paused-vm",
         "status": "paused"},
        {"maxcpu": 12, "id": "node/pve", "disk": 358415503360u64, "maxdisk": 998011547648u64,
         "node": "pve", "maxmem": 29287632896u64, "type": "node", "status": "online",
         "mem": 11522887680u64, "cpu": 0.0451634094268353, "uptime": 1204771},
        {"id": "storage/pve/local", "type": "storage", "node": "pve", "storage": "local",
         "status": "available"},
        {"id": "sdn/pve/localnetwork", "type": "sdn", "node": "pve"}
    ]))
    .unwrap()
}

// ---------------------------------------------------------------------------
// The scripted API
// ---------------------------------------------------------------------------

type Route = Box<dyn Fn(&str) -> Value + Send>;

struct Api {
    resources: Vec<Value>,
    resources_status: u16,
    version_status: u16,
    version: String,
    action_status: u16,
    ticket_status: u16,
    tfa_status: u16,
    renew_status: u16,
    /// How many `/cluster/resources` answer 401 before the rest answer
    /// `resources_status` — an expired ticket.
    resources_401: u32,
    need_tfa: bool,
    routes: HashMap<String, Route>,
    task_states: Vec<&'static str>,
    task_exit: String,
    /// `GET .../status/current`; None answers 404.
    current: Option<Value>,
    current_first: Vec<Value>,
    ticket_gate: Option<Arc<Notify>>,
    ticket_requested: Option<oneshot::Sender<()>>,

    paths: Vec<String>,
    hosts: Vec<String>,
    bodies: Vec<String>,
    headers: Vec<HashMap<String, String>>,
    tickets: u32,
    in_flight: u32,
    max_concurrent_tickets: u32,
    task_polls: usize,
}

impl Default for Api {
    fn default() -> Self {
        Self {
            resources: Vec::new(),
            resources_status: 200,
            version_status: 200,
            version: "8.2.4".into(),
            action_status: 200,
            ticket_status: 200,
            tfa_status: 200,
            renew_status: 200,
            resources_401: 0,
            need_tfa: false,
            routes: HashMap::new(),
            task_states: vec!["stopped"],
            task_exit: "OK".into(),
            current: None,
            current_first: Vec::new(),
            ticket_gate: None,
            ticket_requested: None,
            paths: Vec::new(),
            hosts: Vec::new(),
            bodies: Vec::new(),
            headers: Vec::new(),
            tickets: 0,
            in_flight: 0,
            max_concurrent_tickets: 0,
            task_polls: 0,
        }
    }
}

#[derive(Clone, Default)]
struct Fake(Arc<Mutex<Api>>);

impl Fake {
    fn with(f: impl FnOnce(&mut Api)) -> Self {
        let fake = Fake::default();
        f(&mut fake.0.lock().unwrap());
        fake
    }

    fn api(&self) -> std::sync::MutexGuard<'_, Api> {
        self.0.lock().unwrap()
    }

    fn count(&self, path: &str) -> usize {
        self.api().paths.iter().filter(|p| *p == path).count()
    }

    fn client(&self, config: Config) -> Client {
        self.client_with(config, Arc::new(ManualClock::default()), Duration::from_secs(600))
    }

    fn client_with(&self, config: Config, clock: Arc<dyn Clock>, task_timeout: Duration) -> Client {
        let opts = Options { task_poll: Duration::from_millis(1), task_timeout, clock };
        Client::new(config, Arc::new(self.clone()), opts)
    }
}

impl Connector for Fake {
    fn http(&self, config: &Config) -> Result<Arc<dyn Http>, Error> {
        let host = config.base_uri()?.host().unwrap_or_default().to_owned();
        Ok(Arc::new(FakeHttp { api: self.clone(), host }))
    }
}

struct FakeHttp {
    api: Fake,
    host: String,
}

fn ok(data: Value) -> Response {
    Response { status: 200, reason: None, body: json!({ "data": data }).to_string().into_bytes() }
}

fn status(code: u16, message: Option<&str>) -> Response {
    let mut body = json!({ "data": null });
    if let Some(m) = message {
        body["message"] = json!(m);
    }
    Response { status: code, reason: None, body: body.to_string().into_bytes() }
}

impl Http for FakeHttp {
    fn send(&self, req: Request) -> BoxFuture<'_, Result<Response, TransportError>> {
        Box::pin(async move {
            let path = req.path.trim_start_matches("/api2/json").split('?').next().unwrap().to_owned();
            let method = req.method.as_str();
            let key = format!("{method} {path}");
            let body = req.body.as_ref().map(|b| String::from_utf8_lossy(&b.bytes).into_owned()).unwrap_or_default();
            let gate = {
                let mut a = self.api.api();
                a.paths.push(key.clone());
                a.hosts.push(self.host.clone());
                a.bodies.push(body.clone());
                a.headers.push(req.headers.iter().cloned().collect());
                if let Some(route) = a.routes.get(&key) {
                    return Ok(ok(route(&body)));
                }
                if key != "POST /access/ticket" {
                    None
                } else {
                    a.in_flight += 1;
                    a.max_concurrent_tickets = a.max_concurrent_tickets.max(a.in_flight);
                    if let Some(tx) = a.ticket_requested.take() {
                        let _ = tx.send(());
                    }
                    Some(a.ticket_gate.clone())
                }
            };
            if let Some(gate) = gate {
                if let Some(gate) = gate {
                    gate.notified().await;
                }
                let mut a = self.api.api();
                a.in_flight -= 1;
                return Ok(ticket_answer(&mut a, &body));
            }
            let mut a = self.api.api();
            Ok(answer(&mut a, method, &path, &key))
        })
    }
}

fn ticket_answer(a: &mut Api, body: &str) -> Response {
    if a.ticket_status != 200 {
        return status(a.ticket_status, None);
    }
    if body.contains("tfa-challenge") {
        if a.tfa_status != 200 {
            return status(a.tfa_status, None);
        }
        a.tickets += 1;
        return ok(json!({"ticket": format!("T{}", a.tickets), "CSRFPreventionToken": "C"}));
    }
    // A renewal: a full ticket as the password, which asks no second factor.
    let renewal = body.split('&').any(|f| {
        f.strip_prefix("password=T").is_some_and(|n| !n.is_empty() && n.bytes().all(|b| b.is_ascii_digit()))
    });
    if renewal {
        if a.renew_status != 200 {
            return status(a.renew_status, None);
        }
    } else if a.need_tfa {
        a.tickets += 1;
        return ok(json!({"ticket": format!("CHALLENGE{}", a.tickets), "NeedTFA": 1}));
    }
    a.tickets += 1;
    let n = a.tickets;
    ok(json!({"ticket": format!("T{n}"), "CSRFPreventionToken": format!("C{n}")}))
}

fn answer(a: &mut Api, method: &str, path: &str, key: &str) -> Response {
    match key {
        "GET /version" if a.version_status != 200 => status(a.version_status, None),
        "GET /version" => ok(json!({"version": a.version, "release": a.version})),
        "GET /cluster/resources" => {
            if a.resources_401 > 0 {
                a.resources_401 -= 1;
                return status(401, None);
            }
            if a.resources_status != 200 {
                return status(a.resources_status, None);
            }
            ok(Value::Array(a.resources.clone()))
        }
        _ if method == "GET" && path.ends_with("/status/current") => {
            if !a.current_first.is_empty() {
                return ok(a.current_first.remove(0));
            }
            match &a.current {
                Some(c) => ok(c.clone()),
                None => status(404, None),
            }
        }
        _ if path.contains("/status/") => {
            if a.action_status != 200 {
                return status(a.action_status, Some("Permission check failed (/vms/101, VM.PowerMgmt)\n"));
            }
            ok(json!(UPID))
        }
        _ if path.contains("/tasks/") => {
            let i = a.task_polls.min(a.task_states.len() - 1);
            a.task_polls += 1;
            let state = a.task_states[i];
            if state == "stopped" {
                ok(json!({"status": state, "exitstatus": a.task_exit}))
            } else {
                ok(json!({"status": state}))
            }
        }
        _ => status(404, None),
    }
}

#[derive(Default)]
struct ManualClock(AtomicI64);

impl ManualClock {
    fn advance(&self, ms: i64) {
        self.0.fetch_add(ms, Ordering::SeqCst);
    }
}

impl Clock for ManualClock {
    fn now_ms(&self) -> i64 {
        self.0.load(Ordering::SeqCst)
    }
}

/// Moves on by a second every time it is read.
#[derive(Default)]
struct TickingClock(AtomicI64);

impl Clock for TickingClock {
    fn now_ms(&self) -> i64 {
        self.0.fetch_add(1000, Ordering::SeqCst) + 1000
    }
}

fn token() -> Config {
    Config {
        addr: "https://pve.lan:8006".into(),
        auth: Auth::Token { id: "root@pam!sb".into(), secret: "s3cret".into() },
        cert_sha256: None,
    }
}

fn password(pw: &str) -> Config {
    Config {
        addr: "https://pve.lan:8006".into(),
        auth: Auth::Password { user: "root".into(), password: pw.into() },
        cert_sha256: None,
    }
}

fn standard() -> Fake {
    Fake::with(|a| a.resources = resources_fixture())
}

fn guest<'a>(view: &'a HostView, id: &str) -> &'a Guest {
    view.guests.iter().find(|g| g.id == id).unwrap()
}

fn actions(a: &[PowerAction]) -> std::collections::BTreeSet<PowerAction> {
    a.iter().copied().collect()
}

// ---------------------------------------------------------------------------
// Resources
// ---------------------------------------------------------------------------

#[test]
fn parses_nodes_and_guests_skipping_storage_and_sdn() {
    let r = resources::parse(&resources_fixture(), 0);
    assert_eq!(r.nodes.iter().map(|n| n.name.as_str()).collect::<Vec<_>>(), ["pve"]);
    assert_eq!(r.nodes[0].mem_total, Some(29287632896));
    let ids: Vec<&str> = r.guests.iter().map(|g| g.id.as_str()).collect();
    assert_eq!(ids, ["lxc/100", "qemu/101", "qemu/102", "qemu/103", "qemu/9000", "qemu/104"]);
    let lxc = &r.guests[0];
    assert_eq!(lxc.kind, GuestKind::Lxc);
    assert_eq!(lxc.state, GuestState::Running);
    assert_eq!(lxc.tags, ["media", "prod"]);
    assert_eq!(lxc.uptime, Some(1204757));
    use PowerAction::*;
    // No suspend for a container.
    assert_eq!(lxc.actions, actions(&[Shutdown, Reboot, ForceStop]));
    assert_eq!(r.guests[1].actions, actions(&[Start]));
    assert!(r.guests[2].actions.contains(&Suspend));

    let locked = &r.guests[3];
    assert_eq!(locked.state, GuestState::Backup);
    assert_eq!(locked.state_reason.as_deref(), Some("backup"));
    // PVE lets a VM under backup be paused, and nothing else.
    assert_eq!(locked.actions, actions(&[Suspend]));
    // Still running: the lock does not hide its counters.
    assert!((r.samples["qemu/103"].cpu_percent.unwrap() - 25.0).abs() < 0.001);
    assert_eq!(r.samples["qemu/103"].mem_used, Some(1073741824));

    assert!(r.guests[4].template && r.guests[4].actions.is_empty());
    assert_eq!(r.guests[5].state, GuestState::Paused);
    assert_eq!(r.guests[5].actions, actions(&[Resume, ForceStop]));

    // CPU is a fraction of the guest's own CPUs; a stopped guest has none.
    assert!((r.samples["lxc/100"].cpu_percent.unwrap() - 5.446).abs() < 0.001);
    assert_eq!(r.samples["qemu/101"].cpu_percent, None);
    // QEMU without the guest agent reports disk 0: not measured.
    assert_eq!(r.samples["qemu/102"].disk_used, None);
}

#[test]
fn a_lock_leaves_only_what_pve_allows_under_it() {
    let of = |status: &str, lock: Option<&str>, kind: GuestKind| {
        resources::actions_of(Some(status), lock, kind, resources::state_of(Some(status), lock))
    };
    use PowerAction::*;
    let q = GuestKind::Qemu;
    assert_eq!(of("running", Some("backup"), q), actions(&[Suspend]));
    assert_eq!(of("paused", Some("backup"), q), actions(&[Resume]));
    assert!(of("stopped", Some("backup"), q).is_empty());
    assert!(of("running", Some("backup"), GuestKind::Lxc).is_empty());
    for lock in ["snapshot", "clone", "rollback", "migrate"] {
        assert!(of("running", Some(lock), q).is_empty(), "{lock}");
        assert!(of("paused", Some(lock), q).is_empty(), "{lock}");
    }
    // A hibernated VM: `start` resumes it.
    assert_eq!(of("stopped", Some("suspended"), q), actions(&[Start]));
    assert_eq!(of("paused", None, q), actions(&[Resume, ForceStop]));
}

#[test]
fn status_and_lock_map_to_one_state() {
    let of = |s: Option<&str>, l: Option<&str>| resources::state_of(s, l);
    assert_eq!(of(Some("running"), Some("migrate")), GuestState::Migrating);
    assert_eq!(of(Some("stopped"), Some("suspended")), GuestState::Stopped);
    assert_eq!(of(Some("running"), Some("suspending")), GuestState::Stopping);
    assert_eq!(of(Some("prelaunch"), None), GuestState::Starting);
    assert_eq!(of(Some("io-error"), None), GuestState::Paused);
    assert_eq!(of(Some("guest-panicked"), None), GuestState::Unknown);
    assert_eq!(of(None, None), GuestState::Unknown);
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

#[tokio::test]
async fn an_api_token_goes_in_every_request_with_no_login() {
    let api = standard();
    let view = api.client(token()).load().await.unwrap();
    assert_eq!(view.guests.len(), 6);
    assert_eq!(view.host.version.as_deref(), Some("8.2.4"));
    assert!(view.capabilities.network_edit_existing);
    assert_eq!(api.api().paths, ["GET /version", "GET /cluster/resources"]);
    for h in &api.api().headers {
        assert_eq!(h["Authorization"], "PVEAPIToken=root@pam!sb=s3cret");
        assert!(!h.contains_key("Cookie") && !h.contains_key("CSRFPreventionToken"));
    }
}

#[tokio::test]
async fn a_token_that_may_see_nothing_says_so_with_the_acl_to_grant() {
    // Privilege separation on and no ACL of its own: PVE answers with the
    // node's bare name and nothing else, not a refusal (PVE 9.2).
    let api = Fake::with(|a| {
        a.resources = vec![json!({"id": "node/pve", "node": "pve", "type": "node", "status": "online"})];
        a.routes.insert("GET /access/permissions".into(), Box::new(|_| json!({})));
    });
    let e = api.client(token()).load().await.unwrap_err();
    assert_eq!(e.kind, ErrorKind::PermissionDenied);
    match e.detail.as_deref() {
        Some(Detail::NoPrivileges { token: true, account, command }) => {
            assert_eq!(account, "root@pam!sb");
            assert_eq!(command, "pveum acl modify / --tokens 'root@pam!sb' --roles PVEAuditor,PVEVMAdmin");
        }
        other => panic!("{other:?}"),
    }
    assert!(!format!("{e:?}").contains("s3cret"));

    // An empty host that may be audited is only empty.
    let empty = Fake::with(|a| {
        a.routes.insert("GET /access/permissions".into(), Box::new(|_| json!({"/": {"Sys.Audit": 1, "VM.Audit": 1}})));
    });
    assert!(empty.client(token()).load().await.unwrap().guests.is_empty());
}

#[tokio::test]
async fn a_refused_token_is_auth_failed_naming_the_id_not_the_secret() {
    let api = Fake::with(|a| a.version_status = 401);
    let e = api.client(token()).load().await.unwrap_err();
    assert_eq!(e.kind, ErrorKind::AuthFailed);
    assert_eq!(e.message.as_deref(), Some("root@pam!sb"));
    assert!(!format!("{e:?}").contains("s3cret"));
}

#[tokio::test]
async fn a_password_login_carries_its_ticket_and_csrf_token() {
    let api = standard();
    api.client(password("sshpw")).load().await.unwrap();
    let a = api.api();
    assert_eq!(a.paths[0], "POST /access/ticket");
    for part in ["username=root", "realm=pam", "password=sshpw"] {
        assert!(a.bodies[0].contains(part), "{}", a.bodies[0]);
    }
    let last = a.headers.last().unwrap();
    assert_eq!(last["Cookie"], "PVEAuthCookie=T1");
    assert_eq!(last["CSRFPreventionToken"], "C1");
}

#[tokio::test]
async fn a_user_with_a_realm_sends_no_realm_field() {
    let api = standard();
    let mut cfg = password("pw");
    cfg.auth = Auth::Password { user: "ops@pve".into(), password: "pw".into() };
    api.client(cfg).load().await.unwrap();
    assert!(api.api().bodies[0].starts_with("username=ops%40pve&password="), "{}", api.api().bodies[0]);
}

#[tokio::test]
async fn totp_need_tfa_then_the_code_logs_in() {
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        a.need_tfa = true;
    });
    let pve = api.client(password("pvepw"));
    let e = pve.load().await.unwrap_err();
    assert_eq!(e.kind, ErrorKind::NeedTfa);
    assert_eq!(e.detail.as_deref(), Some(&Detail::OtpRequired));
    assert!(api.api().bodies[0].contains("password=pvepw"));

    pve.submit_tfa("123456").await.unwrap();
    let answer = api.api().bodies.iter().rfind(|b| b.contains("tfa-challenge")).cloned().unwrap();
    assert!(answer.contains("tfa-challenge=CHALLENGE1"), "{answer}");
    assert!(answer.contains("password=totp%3A123456"), "{answer}");
    assert!(!pve.load().await.unwrap().guests.is_empty());
    assert_eq!(api.api().headers.last().unwrap()["Cookie"], "PVEAuthCookie=T2");
}

#[tokio::test]
async fn a_password_is_sent_as_stored_spaces_included() {
    let api = standard();
    api.client(password(" pw ")).load().await.unwrap();
    assert!(api.api().bodies[0].contains("password=+pw+&"), "{}", api.api().bodies[0]);
}

#[tokio::test]
async fn a_refused_login_without_pve_text_carries_no_made_up_sentence() {
    let api = Fake::with(|a| a.ticket_status = 401);
    let e = api.client(password("pw")).load().await.unwrap_err();
    assert_eq!(e.kind, ErrorKind::AuthFailed);
    assert_eq!(e.message, None);
}

#[tokio::test]
async fn missing_credentials_are_not_configured_and_ask_nothing() {
    for (cfg, detail) in [
        (
            Config { auth: Auth::Password { user: " ".into(), password: "pw".into() }, ..password("") },
            Detail::NoUser,
        ),
        (password(""), Detail::PasswordRequired),
        (
            Config { auth: Auth::Token { id: "root@pam!sb".into(), secret: String::new() }, ..token() },
            Detail::TokenIncomplete,
        ),
    ] {
        let api = Fake::default();
        let e = api.client(cfg).load().await.unwrap_err();
        assert_eq!((e.kind, e.detail.as_deref()), (ErrorKind::NotConfigured, Some(&detail)));
        assert!(api.api().paths.is_empty());
    }
}

// ---------------------------------------------------------------------------
// Expired sessions
// ---------------------------------------------------------------------------

#[tokio::test]
async fn a_refused_ticket_one_new_login_and_the_request_repeated() {
    let api = standard();
    let pve = api.client(password("pw"));
    pve.load().await.unwrap();
    api.api().resources_401 = 1;
    assert_eq!(pve.load().await.unwrap().guests.len(), 6);
    assert_eq!(api.count("POST /access/ticket"), 2);
    assert_eq!(api.api().headers.last().unwrap()["Cookie"], "PVEAuthCookie=T2");
}

#[tokio::test]
async fn a_401_a_new_login_does_not_fix_is_auth_failed_and_drops_the_session() {
    let api = standard();
    let pve = api.client(password("pw"));
    pve.load().await.unwrap();
    api.api().resources_status = 401;
    assert_eq!(pve.load().await.unwrap_err().kind, ErrorKind::AuthFailed);
    // the first load, the refused one, and one repeat
    assert_eq!(api.count("GET /cluster/resources"), 3);
    api.api().resources_status = 200;
    pve.load().await.unwrap();
    assert_eq!(api.count("POST /access/ticket"), 3, "the next call logs in again");
}

#[tokio::test]
async fn a_401_in_the_session_the_call_logged_in_is_not_repeated() {
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        a.resources_status = 401;
    });
    assert_eq!(api.client(password("pw")).load().await.unwrap_err().kind, ErrorKind::AuthFailed);
    assert_eq!(api.count("POST /access/ticket"), 1);
}

#[tokio::test]
async fn a_refused_token_is_not_retried() {
    let api = standard();
    let pve = api.client(token());
    pve.load().await.unwrap();
    api.api().resources_401 = 1;
    assert_eq!(pve.load().await.unwrap_err().kind, ErrorKind::AuthFailed);
    assert_eq!(api.count("GET /cluster/resources"), 2);
}

// PVE answers 403 only from its permission check, after it has accepted the
// ticket or token: the session is good. Dropping it threw away a valid ticket
// and made a TOTP account type a code again to be refused the same way.
#[tokio::test]
async fn a_refused_action_keeps_the_session_and_says_why() {
    let api = standard();
    let pve = api.client(password("pw"));
    let view = pve.load().await.unwrap();
    api.api().action_status = 403;
    let e = pve.power(&view.guests[1], PowerAction::Start).await.unwrap_err();
    assert_eq!(e.kind, ErrorKind::ActionFailed);
    assert!(e.message.unwrap().contains("Permission check failed"));
    api.api().action_status = 200;
    pve.load().await.unwrap();
    assert_eq!(api.count("POST /access/ticket"), 1, "no second login");
}

#[tokio::test]
async fn a_403_on_a_listing_is_auth_failed_and_keeps_the_session() {
    let api = standard();
    let pve = api.client(password("pw"));
    pve.load().await.unwrap();
    api.api().resources_status = 403;
    assert_eq!(pve.load().await.unwrap_err().kind, ErrorKind::AuthFailed);
    api.api().resources_status = 200;
    pve.load().await.unwrap();
    assert_eq!(api.count("POST /access/ticket"), 1);
}

#[tokio::test]
async fn a_401_on_an_action_drops_the_session_and_is_sent_again_once_after_a_new_login() {
    let api = standard();
    let pve = api.client(password("pw"));
    let view = pve.load().await.unwrap();
    api.api().action_status = 401;
    let e = pve.power(&view.guests[1], PowerAction::Start).await.unwrap_err();
    assert_eq!(e.kind, ErrorKind::AuthFailed);
    assert_eq!(api.count("POST /nodes/pve/qemu/101/status/start"), 2);
    assert_eq!(api.count("POST /access/ticket"), 2);
}

#[tokio::test]
async fn a_reset_during_a_login_waits_for_it_and_the_stale_one_never_becomes_the_session() {
    let gate = Arc::new(Notify::new());
    let (tx, rx) = oneshot::channel();
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        a.ticket_gate = Some(gate.clone());
        a.ticket_requested = Some(tx);
    });
    let pve = Arc::new(api.client(password("pw")));
    let first = tokio::spawn({
        let pve = pve.clone();
        async move { pve.load().await }
    });
    tokio::time::timeout(Duration::from_secs(2), rx).await.unwrap().unwrap();
    pve.reset();
    let second = tokio::spawn({
        let pve = pve.clone();
        async move { pve.load().await }
    });
    tokio::time::sleep(Duration::from_millis(50)).await;
    assert_eq!(api.count("POST /access/ticket"), 1, "the new login must not overlap the stale one");

    api.api().ticket_gate = None;
    gate.notify_one();
    first.await.unwrap().unwrap();
    second.await.unwrap().unwrap();
    assert_eq!(api.count("POST /access/ticket"), 2);
    assert_eq!(api.api().max_concurrent_tickets, 1);
    assert_eq!(api.api().headers.last().unwrap()["Cookie"], "PVEAuthCookie=T2");
}

#[tokio::test]
async fn an_address_change_during_a_login_sends_none_of_its_credentials_to_the_new_address() {
    let gate = Arc::new(Notify::new());
    let (tx, rx) = oneshot::channel();
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        a.ticket_gate = Some(gate.clone());
        a.ticket_requested = Some(tx);
    });
    let old = Config { addr: "https://old.lan:8006".into(), ..password("pvepw") };
    let pve = Arc::new(api.client(old.clone()));
    let first = tokio::spawn({
        let pve = pve.clone();
        async move { pve.load().await }
    });
    tokio::time::timeout(Duration::from_secs(2), rx).await.unwrap().unwrap();
    pve.update_config(Config { addr: "https://new.lan:8006".into(), ..old });
    api.api().ticket_gate = None;
    gate.notify_one();
    first.await.unwrap().unwrap();

    let a = api.api();
    assert_eq!(a.hosts[0], "old.lan");
    for i in 0..a.paths.len() {
        if a.hosts[i] == "new.lan" {
            assert_ne!(a.headers[i].get("Cookie").map(String::as_str), Some("PVEAuthCookie=T1"), "{}", a.paths[i]);
        } else {
            assert_eq!(a.paths[i], "POST /access/ticket");
        }
    }
    assert_eq!(a.hosts.last().unwrap(), "new.lan");
}

// ---------------------------------------------------------------------------
// Ticket lifetime
// ---------------------------------------------------------------------------

async fn logged_in_with_totp(api: &Fake, clock: Arc<ManualClock>) -> Client {
    let pve = api.client_with(password("pvepw"), clock, Duration::from_secs(600));
    assert_eq!(pve.load().await.unwrap_err().kind, ErrorKind::NeedTfa);
    pve.submit_tfa("123456").await.unwrap();
    pve.load().await.unwrap();
    pve
}

fn logins(api: &Fake) -> usize {
    api.api().bodies.iter().filter(|b| b.contains("password=pvepw")).count()
}

fn totp_api() -> Fake {
    Fake::with(|a| {
        a.resources = resources_fixture();
        a.need_tfa = true;
    })
}

#[tokio::test]
async fn an_hour_on_the_ticket_is_renewed_with_itself_no_code_asked() {
    let clock = Arc::new(ManualClock::default());
    let api = totp_api();
    let pve = logged_in_with_totp(&api, clock.clone()).await;
    assert_eq!(api.api().headers.last().unwrap()["Cookie"], "PVEAuthCookie=T2");

    clock.advance(59 * MIN);
    pve.load().await.unwrap();
    assert_eq!(api.count("POST /access/ticket"), 2);

    clock.advance(2 * MIN);
    assert!(!pve.load().await.unwrap().guests.is_empty());
    let renewal = api.api().bodies.iter().rfind(|b| b.contains("password=T")).cloned().unwrap();
    assert!(renewal.contains("password=T2") && !renewal.contains("tfa-challenge"), "{renewal}");
    assert_eq!(api.api().headers.last().unwrap()["Cookie"], "PVEAuthCookie=T3");
    assert_eq!(logins(&api), 1, "no new login");

    // Renewed: the clock starts again.
    clock.advance(30 * MIN);
    pve.load().await.unwrap();
    assert_eq!(api.api().headers.last().unwrap()["Cookie"], "PVEAuthCookie=T3");
}

#[tokio::test]
async fn renewals_running_together_are_one_request() {
    let clock = Arc::new(ManualClock::default());
    let api = standard();
    let pve = api.client_with(password("pw"), clock.clone(), Duration::from_secs(600));
    pve.load().await.unwrap();
    clock.advance(61 * MIN);
    let (a, b, c) = tokio::join!(pve.load(), pve.load(), pve.load());
    a.unwrap();
    b.unwrap();
    c.unwrap();
    assert_eq!(api.count("POST /access/ticket"), 2);
}

#[tokio::test]
async fn a_refused_renewal_logs_in_again_which_asks_for_a_code() {
    let clock = Arc::new(ManualClock::default());
    let api = totp_api();
    let pve = logged_in_with_totp(&api, clock.clone()).await;
    api.api().renew_status = 401;
    clock.advance(61 * MIN);
    assert_eq!(pve.load().await.unwrap_err().kind, ErrorKind::NeedTfa);
    assert_eq!(logins(&api), 2);
}

#[tokio::test]
async fn past_the_lifetime_nothing_is_renewed_a_new_login() {
    let clock = Arc::new(ManualClock::default());
    let api = totp_api();
    let pve = logged_in_with_totp(&api, clock.clone()).await;
    clock.advance(TICKET_LIFETIME_MS);
    assert_eq!(pve.load().await.unwrap_err().kind, ErrorKind::NeedTfa);
    assert!(!api.api().bodies.iter().any(|b| b.contains("password=T")));
    assert_eq!(logins(&api), 2);
}

#[tokio::test]
async fn a_failed_renewal_that_is_not_a_refusal_keeps_the_ticket() {
    let clock = Arc::new(ManualClock::default());
    let api = standard();
    let pve = api.client_with(password("pw"), clock.clone(), Duration::from_secs(600));
    pve.load().await.unwrap();
    api.api().renew_status = 500;
    clock.advance(61 * MIN);
    pve.load().await.unwrap();
    assert_eq!(api.api().headers.last().unwrap()["Cookie"], "PVEAuthCookie=T1");
}

// ---------------------------------------------------------------------------
// TOTP challenges
// ---------------------------------------------------------------------------

#[tokio::test]
async fn a_wrong_code_keeps_the_challenge_for_the_next_one() {
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        a.need_tfa = true;
        a.tfa_status = 401;
    });
    let pve = api.client(password("pvepw"));
    pve.load().await.unwrap_err();
    let wrong = pve.submit_tfa("000000").await.unwrap_err();
    assert_eq!((wrong.kind, wrong.detail.as_deref()), (ErrorKind::NeedTfa, Some(&Detail::OtpRejected)));
    api.api().tfa_status = 200;
    pve.submit_tfa("123456").await.unwrap();
    let a = api.api();
    assert!(a.bodies.iter().filter(|b| b.contains("tfa-challenge")).all(|b| b.contains("tfa-challenge=CHALLENGE1")));
    assert_eq!(a.bodies.iter().filter(|b| b.contains("password=pvepw")).count(), 1);
}

#[tokio::test]
async fn a_challenge_past_its_lifetime_is_replaced_before_the_code_answers() {
    // PVE answers an expired challenge as it answers a wrong code.
    let clock = Arc::new(ManualClock::default());
    let api = totp_api();
    let pve = api.client_with(password("pvepw"), clock.clone(), Duration::from_secs(600));
    pve.load().await.unwrap_err();
    clock.advance(TICKET_LIFETIME_MS);
    pve.submit_tfa("123456").await.unwrap();
    let answer = api.api().bodies.iter().rfind(|b| b.contains("tfa-challenge")).cloned().unwrap();
    assert!(answer.contains("tfa-challenge=CHALLENGE2") && answer.contains("password=totp%3A123456"), "{answer}");
    assert!(!pve.load().await.unwrap().guests.is_empty());
}

#[tokio::test]
async fn a_challenge_dropped_by_a_reset_is_replaced_not_reported() {
    let api = totp_api();
    let pve = api.client(password("pvepw"));
    pve.load().await.unwrap_err();
    pve.reset();
    pve.submit_tfa("123456").await.unwrap();
    let answer = api.api().bodies.iter().rfind(|b| b.contains("tfa-challenge")).cloned().unwrap();
    assert!(answer.contains("tfa-challenge=CHALLENGE2"), "{answer}");
    assert!(!pve.load().await.unwrap().guests.is_empty());
}

#[tokio::test]
async fn an_empty_code_asks_nothing_of_pve() {
    let api = totp_api();
    let pve = api.client(password("pvepw"));
    pve.load().await.unwrap_err();
    let before = api.api().paths.len();
    let e = pve.submit_tfa("  ").await.unwrap_err();
    assert_eq!((e.kind, e.detail.as_deref()), (ErrorKind::NeedTfa, Some(&Detail::OtpEmpty)));
    assert_eq!(api.api().paths.len(), before);
}

// ---------------------------------------------------------------------------
// Power
// ---------------------------------------------------------------------------

#[tokio::test]
async fn power_waits_for_the_upid_task_to_stop() {
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        a.task_states = vec!["running", "running", "stopped"];
    });
    let pve = api.client(password("pw"));
    let view = pve.load().await.unwrap();
    pve.power(&view.guests[2], PowerAction::Suspend).await.unwrap();
    let a = api.api();
    assert!(a.paths.contains(&"POST /nodes/pve/qemu/102/status/suspend".to_owned()));
    let polls: Vec<&String> = a.paths.iter().filter(|p| p.contains("/tasks/")).collect();
    assert_eq!(polls.len(), 3);
    assert!(polls[0].contains("UPID%3Apve%3A0001"), "{}", polls[0]);
}

#[tokio::test]
async fn a_task_still_running_at_the_deadline_is_not_reported_as_done() {
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        a.task_states = vec!["running"];
    });
    let pve = api.client_with(password("pw"), Arc::new(TickingClock::default()), Duration::from_millis(20));
    let view = pve.load().await.unwrap();
    let e = pve.power(&view.guests[2], PowerAction::Suspend).await.unwrap_err();
    assert_eq!(e.kind, ErrorKind::ActionFailed);
    assert!(e.message.unwrap().contains(UPID));
    assert!(matches!(e.detail.as_deref(), Some(Detail::TaskStillRunning { .. })));
    // The status read that follows a completed action never ran.
    assert!(api.api().paths.last().unwrap().contains("/tasks/"));
}

#[tokio::test]
async fn a_task_ending_in_an_error_is_action_failed_with_its_text() {
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        a.task_exit = "can't lock file '/var/lock/qemu-server/lock-101.conf'".into();
    });
    let pve = api.client(password("pw"));
    let view = pve.load().await.unwrap();
    let e = pve.power(&view.guests[1], PowerAction::Start).await.unwrap_err();
    assert_eq!(e.kind, ErrorKind::ActionFailed);
    assert!(e.message.unwrap().contains("can't lock file"));
}

#[tokio::test]
async fn the_state_after_an_action_shows_before_the_listing_catches_up() {
    let clock = Arc::new(ManualClock::default());
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        // What PVE 9.2 answered: status/current already `stopped` while the
        // listing still said `running`.
        a.current = Some(json!({"status": "stopped", "qmpstatus": "stopped"}));
    });
    let pve = api.client_with(password("pw"), clock.clone(), Duration::from_secs(600));
    let view = pve.load().await.unwrap();
    let running = guest(&view, "qemu/102").clone();
    assert_eq!(running.state, GuestState::Running);
    pve.power(&running, PowerAction::ForceStop).await.unwrap();
    assert_eq!(api.api().paths.last().unwrap(), "GET /nodes/pve/qemu/102/status/current");

    clock.advance(2000);
    let view = pve.load().await.unwrap();
    assert_eq!(guest(&view, "qemu/102").state, GuestState::Stopped);
    assert_eq!(guest(&view, "qemu/102").actions, actions(&[PowerAction::Start]));
    assert_eq!(view.stats["qemu/102"].cpu, None, "not running");

    // The listing still lags past the window: it is believed again.
    clock.advance(FRESH_STATUS_FOR_MS);
    assert_eq!(guest(&pve.load().await.unwrap(), "qemu/102").state, GuestState::Running);
}

#[tokio::test]
async fn force_stop_overrules_a_pending_shutdown_where_pve_knows_how() {
    async fn stop_body(version: &str) -> String {
        let api = Fake::with(|a| {
            a.resources = resources_fixture();
            a.version = version.into();
            a.current = Some(json!({"status": "stopped", "qmpstatus": "stopped"}));
        });
        let pve = api.client(password("pw"));
        let view = pve.load().await.unwrap();
        pve.power(guest(&view, "qemu/102"), PowerAction::ForceStop).await.unwrap();
        let a = api.api();
        let at = a.paths.iter().position(|p| p == "POST /nodes/pve/qemu/102/status/stop").unwrap();
        a.bodies[at].clone()
    }
    assert!(stop_body("9.2.2").await.contains("overrule-shutdown=1"));
    assert!(stop_body("8.1.3").await.contains("overrule-shutdown=1"));
    // Older releases refuse a parameter they do not know.
    assert!(!stop_body("8.0.4").await.contains("overrule-shutdown"));
    assert!(!stop_body("7.4-3").await.contains("overrule-shutdown"));
}

#[tokio::test]
async fn the_listing_agreeing_ends_the_overlay() {
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        a.current = Some(json!({"status": "running", "qmpstatus": "paused"}));
    });
    let pve = api.client(password("pw"));
    let view = pve.load().await.unwrap();
    pve.power(guest(&view, "qemu/102"), PowerAction::Suspend).await.unwrap();
    // The QEMU run state wins over `status`, as pvestatd reports it.
    assert_eq!(guest(&pve.load().await.unwrap(), "qemu/102").state, GuestState::Paused);
    let paused: Vec<Value> = resources_fixture()
        .into_iter()
        .map(|mut r| {
            if r["id"] == "qemu/102" {
                r["status"] = json!("paused");
            }
            r
        })
        .collect();
    api.api().resources = paused;
    assert_eq!(guest(&pve.load().await.unwrap(), "qemu/102").state, GuestState::Paused);
    // Caught up, so a later change in the listing is taken as it is.
    api.api().resources = resources_fixture();
    assert_eq!(guest(&pve.load().await.unwrap(), "qemu/102").state, GuestState::Running);
}

#[tokio::test]
async fn after_a_reboot_the_old_uptime_is_not_believed() {
    let clock = Arc::new(ManualClock::default());
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        a.current = Some(json!({"status": "running", "uptime": 3}));
    });
    let pve = api.client_with(password("pw"), clock.clone(), Duration::from_secs(600));
    let before = guest(&pve.load().await.unwrap(), "qemu/102").clone();
    assert!(before.uptime.unwrap() > 60);
    pve.power(&before, PowerAction::Reboot).await.unwrap();
    clock.advance(4000);
    assert_eq!(guest(&pve.load().await.unwrap(), "qemu/102").uptime, Some(7));
    // pvestatd has caught up.
    let caught: Vec<Value> = resources_fixture()
        .into_iter()
        .map(|mut r| {
            if r["id"] == "qemu/102" {
                r["uptime"] = json!(12);
            }
            r
        })
        .collect();
    api.api().resources = caught;
    clock.advance(6000);
    assert_eq!(guest(&pve.load().await.unwrap(), "qemu/102").uptime, Some(12));
}

#[tokio::test]
async fn an_uptime_of_0_read_right_after_a_reboot_counts_up() {
    let clock = Arc::new(ManualClock::default());
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        a.current = Some(json!({"status": "running", "uptime": 0}));
    });
    let pve = api.client_with(password("pw"), clock.clone(), Duration::from_secs(600));
    let vm = guest(&pve.load().await.unwrap(), "qemu/102").clone();
    pve.power(&vm, PowerAction::Reboot).await.unwrap();
    clock.advance(5000);
    let after = guest(&pve.load().await.unwrap(), "qemu/102").clone();
    assert_eq!(after.state, GuestState::Running);
    assert_eq!(after.uptime, Some(5));
}

#[tokio::test]
async fn a_vm_read_as_stopped_right_after_its_reboot_task_is_asked_again_until_it_runs() {
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        // PVE 9.2: `qmreboot` ends once the guest is down, and `qmeventd`
        // starts it again a moment later.
        a.current_first = vec![
            json!({"status": "stopped", "qmpstatus": "stopped"}),
            json!({"status": "stopped", "qmpstatus": "stopped"}),
        ];
        a.current = Some(json!({"status": "running", "qmpstatus": "running", "uptime": 1}));
    });
    let pve = api.client(password("pw"));
    let vm = guest(&pve.load().await.unwrap(), "qemu/102").clone();
    pve.power(&vm, PowerAction::Reboot).await.unwrap();
    assert_eq!(api.api().paths.iter().filter(|p| p.ends_with("/status/current")).count(), 3);
    let after = guest(&pve.load().await.unwrap(), "qemu/102").clone();
    assert_eq!(after.state, GuestState::Running);
    assert!(after.actions.contains(&PowerAction::Reboot));
}

#[tokio::test]
async fn a_guest_that_stays_down_after_a_reboot_is_believed_in_the_end() {
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        a.current = Some(json!({"status": "stopped", "qmpstatus": "stopped"}));
    });
    let pve = api.client_with(password("pw"), Arc::new(TickingClock::default()), Duration::from_secs(600));
    let vm = guest(&pve.load().await.unwrap(), "qemu/102").clone();
    pve.power(&vm, PowerAction::Reboot).await.unwrap();
    let reads = api.api().paths.iter().filter(|p| p.ends_with("/status/current")).count();
    assert!(reads > 1 && reads < 40, "{reads}");
}

#[tokio::test]
async fn other_actions_read_the_state_once() {
    let api = Fake::with(|a| {
        a.resources = resources_fixture();
        a.current = Some(json!({"status": "stopped", "qmpstatus": "stopped"}));
    });
    let pve = api.client(password("pw"));
    let vm = guest(&pve.load().await.unwrap(), "qemu/102").clone();
    pve.power(&vm, PowerAction::Shutdown).await.unwrap();
    assert_eq!(api.api().paths.iter().filter(|p| p.ends_with("/status/current")).count(), 1);
}

#[tokio::test]
async fn an_action_the_guest_does_not_offer_is_not_sent() {
    let api = standard();
    let pve = api.client(password("pw"));
    let view = pve.load().await.unwrap();
    let e = pve.power(&view.guests[0], PowerAction::Suspend).await.unwrap_err();
    assert_eq!((e.kind, e.detail.as_deref()), (ErrorKind::Unsupported, Some(&Detail::NotOffered)));
    assert!(!api.api().paths.iter().any(|p| p.contains("/status/")));
}

#[tokio::test]
async fn rates_come_from_successive_samples_held_between_pve_updates() {
    let clock = Arc::new(ManualClock::default());
    let api = standard();
    let pve = api.client_with(password("pw"), clock.clone(), Duration::from_secs(600));
    assert_eq!(pve.load().await.unwrap().stats["lxc/100"].net_in, None, "nothing to diff");

    clock.advance(10_000);
    let mut moved = resources_fixture();
    moved[0]["netin"] = json!(65412250538u64 + 10_000);
    api.api().resources = moved;
    let view = pve.load().await.unwrap();
    assert_eq!(view.stats["lxc/100"].net_in, Some(1000.0));
    assert_eq!(view.stats["lxc/100"].disk_read, Some(0.0));

    // pvestatd has not updated yet: the rate holds rather than dropping to 0.
    clock.advance(3000);
    assert_eq!(pve.load().await.unwrap().stats["lxc/100"].net_in, Some(1000.0));
}

#[tokio::test]
async fn a_closed_client_answers_closed() {
    let api = standard();
    let pve = api.client(token());
    pve.load().await.unwrap();
    pve.close();
    assert_eq!(pve.load().await.unwrap_err().kind, ErrorKind::Closed);
}

#[tokio::test]
async fn a_raw_request_answers_as_the_host_did_and_keeps_the_session_rules() {
    use sbm_virt::pve::http::Method;
    let api = standard();
    let pve = api.client(password("pw"));
    pve.load().await.unwrap();
    // A refusal is the caller's to read: answered, not an error.
    api.api().action_status = 403;
    let resp = pve.raw(Method::Post, "/api2/json/nodes/pve/qemu/101/status/start", None).await.unwrap();
    assert_eq!(resp.status, 403);
    assert!(String::from_utf8_lossy(&resp.body).contains("Permission check failed"));
    assert_eq!(api.count("POST /access/ticket"), 1, "a 403 keeps the session");
    // A refused ticket is replaced once and the request sent again.
    api.api().action_status = 200;
    api.api().resources_401 = 1;
    let resp = pve.raw(Method::Get, "/api2/json/cluster/resources", None).await.unwrap();
    assert_eq!(resp.status, 200);
    assert_eq!(api.count("POST /access/ticket"), 2);
}
