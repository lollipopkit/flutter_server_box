//! PVE's backups and backup jobs: the answers `sbm_virt::pve::backup` reads
//! (captured from PVE 9.2.2), and `pve::Client`'s backup calls against a
//! scripted PVE API — each request's form and query, the refusals made before
//! anything is sent, and the host's own words where it refuses.
//!
//! Ported from the app's `test/unit/virt/virt_backup_job_test.dart` and
//! `test/unit/virt/pve_backend_test.dart`.

mod common;

use std::collections::{BTreeMap, BTreeSet};

use common::*;
use sbm_virt::backup::{Backup, BackupEdit, BackupJobEdit, BackupRequest, Issue};
use sbm_virt::error::{Detail, Error, ErrorKind};
use sbm_virt::model::{Guest, GuestKind, GuestState};
use sbm_virt::pve::backup::{job_fields, parse_backup_jobs, parse_backups, prune_string, vzdump_of_job};
use sbm_virt::pve::resources;
use serde_json::{Value, json};

fn refused(e: &Error) -> Option<Issue> {
    match e.detail.as_deref() {
        Some(Detail::BackupRefused { issue }) => Some(*issue),
        _ => None,
    }
}

fn create_refused(e: &Error) -> Option<sbm_virt::create::Issue> {
    match e.detail.as_deref() {
        Some(Detail::CreateRefused { issue }) => Some(*issue),
        _ => None,
    }
}

/// A property string's parts, in any order: PVE reads them as a set.
fn parts(s: &str) -> BTreeSet<&str> {
    s.split(',').collect()
}

fn map(pairs: &[(&str, &str)]) -> BTreeMap<String, String> {
    pairs.iter().map(|(k, v)| ((*k).to_owned(), (*v).to_owned())).collect()
}

fn query(fake: &Fake, key: &str) -> BTreeMap<String, String> {
    let a = fake.0.lock().unwrap();
    let i = a.paths.iter().position(|p| p == key).unwrap_or_else(|| panic!("no {key} in {:?}", a.paths));
    form_of(&a.queries[i])
}

fn sent(fake: &Fake, key: &str) -> usize {
    fake.paths().iter().filter(|p| *p == key).count()
}

const LOCAL_ID: &str = "local:backup/vzdump-qemu-9941-2026_09_26-03_11_45.vma.zst";
const NFS_ID: &str = "nfs:backup/vzdump-qemu-9941-2026_09_27-02_00_00.vma.zst";
const CT_ID: &str = "local:backup/vzdump-lxc-200-x.tar.zst";

// ---------------------------------------------------------------------------
// Backups as a storage lists them
// ---------------------------------------------------------------------------

#[test]
fn a_backup_as_pve_9_2_lists_it() {
    let b = parse_backups("pve", "local", &list("backup_content.json"));
    assert_eq!(b.len(), 1);
    let b = &b[0];
    assert_eq!(b.id, LOCAL_ID);
    assert_eq!((b.storage.as_str(), b.node.as_str(), b.vmid), ("local", "pve", Some(9941)));
    assert_eq!((b.size, b.format.as_deref(), b.notes.as_deref()), (Some(37103), Some("vma.zst"), Some("sb e2e 9941")));
    assert_eq!(b.kind, Some(GuestKind::Qemu));
    assert_eq!(b.created_at, Some(1790363505));
    assert!(!b.protected);
    assert_eq!(b.verification, None);
}

#[test]
fn backups_newest_first_other_content_and_no_volid_left_out() {
    let raw = vec![
        json!({"volid": "local:backup/a.vma.zst", "content": "backup", "ctime": 100, "size": 0}),
        json!({"volid": "local:backup/b.tar.zst", "ctime": "300", "subtype": "lxc", "protected": 1, "verification": {"state": "ok"}}),
        json!({"volid": "local:iso/x.iso", "content": "iso", "ctime": 500}),
        json!({"content": "backup", "ctime": 400}),
        json!({"volid": "local:backup/c.vma", "ctime": 200, "verification": "ok", "subtype": "openvz", "notes": ""}),
        json!("not an object"),
    ];
    let b = parse_backups("pve", "local", &raw);
    let ids: Vec<&str> = b.iter().map(|b| b.id.as_str()).collect();
    assert_eq!(ids, ["local:backup/b.tar.zst", "local:backup/c.vma", "local:backup/a.vma.zst"]);
    assert_eq!(b[0].kind, Some(GuestKind::Lxc));
    assert!(b[0].protected);
    assert_eq!(b[0].verification.as_deref(), Some("ok"));
    // `verification` is an object where a verify job has run; anything else
    // is none, and an unknown subtype is no kind.
    assert_eq!((b[1].verification.as_deref(), b[1].kind, b[1].notes.as_deref()), (None, None, None));
    assert_eq!(b[2].size, None, "a size of 0 is none");
}

// ---------------------------------------------------------------------------
// Backup jobs as PVE lists them
// ---------------------------------------------------------------------------

#[test]
fn a_job_that_names_its_guests_every_field_read() {
    let jobs = parse_backup_jobs(&list("backup_job_fields.json"));
    assert_eq!(jobs.len(), 1);
    let j = &jobs[0];
    assert_eq!(j.id, "sbxe2e-capture");
    assert_eq!(j.schedule.as_deref(), Some("mon..fri 02:30"));
    assert_eq!(j.storage.as_deref(), Some("local"));
    assert_eq!((j.mode.as_deref(), j.compress.as_deref()), (Some("snapshot"), Some("zstd")));
    assert!(j.enabled);
    assert!(!j.all);
    assert_eq!(j.vmids, [911, 912]);
    assert!(j.exclude.is_empty());
    assert_eq!(j.comment.as_deref(), Some("sb e2e capture"));
    assert_eq!(j.notes_template.as_deref(), Some("sb {{guestname}} {{vmid}}"));
    assert_eq!(j.mail_notification.as_deref(), Some("failure"));
    // PVE answers `prune-backups` as an object of strings.
    assert_eq!(parts(j.prune.as_deref().unwrap()), parts("keep-daily=4,keep-last=7"));
    // The node and the pool are not in this answer: PVE leaves them out when
    // they are unset (`next-run` and `type` are PVE's own).
    assert_eq!((j.node.as_deref(), j.pool.as_deref()), (None, None));
}

#[test]
fn a_job_that_takes_every_guest_less_what_it_excludes() {
    let jobs = parse_backup_jobs(&list("backup_jobs_all.json"));
    assert_eq!(jobs.len(), 2);
    let all = jobs.iter().find(|j| j.id == "sbxe2e-all").unwrap();
    assert!(all.all);
    assert_eq!(all.exclude, [912]);
    assert!(all.vmids.is_empty());
    assert!(!all.enabled);
    assert_eq!(all.schedule.as_deref(), Some("sat 03:00"));
    assert_eq!((all.mode.as_deref(), all.compress.as_deref()), (Some("stop"), Some("lzo")));
    // `prune-backups` is absent: neither the storage's nor the node's own.
    assert_eq!(all.prune, None);
}

#[test]
fn which_guests_a_listed_job_takes() {
    let jobs = parse_backup_jobs(&list("backup_jobs_all.json"));
    let named = jobs.iter().find(|j| j.id == "sbxe2e-capture").unwrap();
    assert!(named.takes(Some(911), None));
    assert!(named.takes(Some(912), None));
    assert!(!named.takes(Some(913), None));
    let all = jobs.iter().find(|j| j.id == "sbxe2e-all").unwrap();
    assert!(all.takes(Some(911), None));
    assert!(!all.takes(Some(912), None), "excluded");
    assert!(all.takes(Some(913), None));
    // A guest's Plan group: only the jobs that take it.
    let taking = |vmid| jobs.iter().filter(|j| j.takes(Some(vmid), None)).map(|j| j.id.as_str()).collect::<Vec<_>>();
    assert_eq!(taking(912), ["sbxe2e-capture"]);
    assert_eq!(taking(913), ["sbxe2e-all"]);

    let one = parse_backup_jobs(&list("backup_jobs.json"));
    assert_eq!(one.len(), 1);
    let j = &one[0];
    assert_eq!(
        (j.id.as_str(), j.schedule.as_deref(), j.storage.as_deref(), j.mode.as_deref(), j.compress.as_deref(), j.prune.as_deref()),
        ("sbbk-job", Some("02:00"), Some("local"), Some("snapshot"), Some("zstd"), Some("keep-last=7")),
    );
    assert!(!j.enabled);
    assert!(j.takes(Some(9941), Some("pve")));
    assert!(j.takes_only(Some(9941)));
    assert!(!j.takes(Some(100), None));
    // Every guest, less the excluded ones: `exclude` as PVE stores it.
    let all = parse_backup_jobs(&[json!({"id": "all", "type": "vzdump", "all": 1, "exclude": "101"})]);
    assert!(all[0].takes(Some(100), None));
    assert!(!all[0].takes(Some(101), None));
}

#[test]
fn a_job_by_pool_names_none_of_its_guests() {
    let jobs = parse_backup_jobs(&[json!({"id": "pool-job", "type": "vzdump", "pool": "prod", "storage": "local"})]);
    assert_eq!(jobs[0].pool.as_deref(), Some("prod"));
    // Which guests a pool holds is not in this answer, so a guest's own Plan
    // group cannot claim one takes it.
    assert!(!jobs[0].takes(Some(100), None));
}

#[test]
fn the_listings_odd_shapes() {
    let jobs = parse_backup_jobs(&[
        // Not a vzdump job, and no id: left out.
        json!({"id": "sync", "type": "sync"}),
        json!({"type": "vzdump", "all": 1}),
        // PVE before 7 kept `starttime`; a list of numbers, a list holding
        // `all` and garbage, an empty one.
        json!({"id": "old", "starttime": "02:00", "vmid": "100, x,101", "exclude": ""}),
        json!({"id": "listed", "vmid": [100, "101", "x"], "exclude": "all", "enabled": "0", "all": "1"}),
        json!({"id": "empty", "schedule": "", "vmid": null, "prune-backups": {}, "comment": ""}),
    ]);
    let ids: Vec<&str> = jobs.iter().map(|j| j.id.as_str()).collect();
    assert_eq!(ids, ["old", "listed", "empty"]);
    assert_eq!(jobs[0].schedule.as_deref(), Some("02:00"));
    assert_eq!(jobs[0].vmids, [100, 101]);
    assert!(jobs[0].exclude.is_empty());
    assert!(jobs[0].enabled, "enabled unless it says 0");
    assert_eq!(jobs[1].vmids, [100, 101]);
    assert!(jobs[1].exclude.is_empty());
    assert!(!jobs[1].enabled);
    assert!(jobs[1].all);
    assert_eq!((jobs[2].schedule.as_deref(), jobs[2].prune.as_deref(), jobs[2].comment.as_deref()), (None, None, None));
    assert!(jobs[2].vmids.is_empty());
}

#[test]
fn prune_as_one_property_string() {
    assert_eq!(prune_string(Some(&json!({"keep-last": "7"}))).as_deref(), Some("keep-last=7"));
    assert_eq!(prune_string(Some(&json!({"keep-last": 7}))).as_deref(), Some("keep-last=7"));
    assert_eq!(parts(&prune_string(Some(&json!({"keep-last": "2", "keep-daily": 4}))).unwrap()), parts("keep-last=2,keep-daily=4"));
    assert_eq!(prune_string(Some(&json!("keep-all=1"))).as_deref(), Some("keep-all=1"));
    assert_eq!(prune_string(Some(&json!({}))), None);
    assert_eq!(prune_string(Some(&json!(""))), None);
    assert_eq!(prune_string(Some(&json!(7))), None);
    assert_eq!(prune_string(None), None);
}

// ---------------------------------------------------------------------------
// What a job's edit and its "Run now" send
// ---------------------------------------------------------------------------

fn edit(v: Value) -> BackupJobEdit {
    let mut base = json!({"id": "j1", "storage": "local", "schedule": "sat 03:00"});
    base.as_object_mut().unwrap().extend(v.as_object().unwrap().clone());
    serde_json::from_value(base).unwrap()
}

fn fields(e: &BackupJobEdit) -> BTreeMap<String, String> {
    job_fields(e).into_iter().map(|(k, v)| (k.to_owned(), v)).collect()
}

#[test]
fn a_new_job_carries_its_id_and_deletes_nothing() {
    let f = fields(&edit(json!({"is_new": true, "vmids": [100], "comment": "c"})));
    assert_eq!(
        f,
        map(&[
            ("id", "j1"),
            ("storage", "local"),
            ("schedule", "sat 03:00"),
            ("mode", "snapshot"),
            ("compress", "zstd"),
            ("enabled", "1"),
            ("all", "0"),
            ("vmid", "100"),
            ("comment", "c"),
        ])
    );
    // PVE names a new job itself where it is given no id.
    let f = fields(&edit(json!({"id": null, "is_new": true, "all": true})));
    assert!(!f.contains_key("id"));
    assert!(!f.contains_key("delete"));
}

#[test]
fn an_edit_sends_every_field_it_sets_and_deletes_the_rest() {
    let f = fields(&edit(json!({
        "vmids": [100, 200],
        "node": "pve",
        "enabled": false,
        "comment": "nightly",
        "notes_template": "{{guestname}}",
        "mail_notification": "always",
        "prune": "keep-last=3",
    })));
    assert_eq!(f["enabled"], "0");
    assert_eq!(f["node"], "pve");
    assert_eq!(f["notes-template"], "{{guestname}}");
    assert_eq!(f["mailnotification"], "always");
    assert_eq!(f["prune-backups"], "keep-last=3");
    assert_eq!(parts(&f["delete"]), parts("exclude,pool"));

    let f = fields(&edit(json!({"vmids": [100]})));
    assert_eq!(parts(&f["delete"]), parts("exclude,pool,node,comment,notes-template,prune-backups"));
    // A notification setting not sent is kept, as before.
    assert!(!f.contains_key("mailnotification"));
}

#[test]
fn run_now_sends_the_job_less_its_schedule() {
    let job = json!({
        "id": "j",
        "type": "vzdump",
        "schedule": "sat 03:00",
        "starttime": "03:00",
        "dow": "sat",
        "enabled": 0,
        "next-run": 1790967600,
        "repeat-missed": 1,
        "comment": "nightly",
        "node": "pve",
        "storage": "nfs",
        "all": 1,
        "exclude": "9",
        "bwlimit": 4096,
        "ionice": 5,
        "notes-template": null,
        "performance": {"max-workers": "2"},
        "prune-backups": {"keep-last": "2", "keep-daily": "4"},
        "fleecing": {"enabled": 0},
    });
    let f: BTreeMap<String, String> = vzdump_of_job(job.as_object().unwrap()).into_iter().collect();
    let keys: BTreeSet<&str> = f.keys().map(String::as_str).collect();
    assert_eq!(keys, BTreeSet::from(["storage", "all", "exclude", "bwlimit", "ionice", "performance", "prune-backups", "fleecing"]));
    assert_eq!(f["all"], "1");
    assert_eq!(f["exclude"], "9");
    assert_eq!(f["bwlimit"], "4096");
    assert_eq!(f["performance"], "max-workers=2");
    assert_eq!(parts(&f["prune-backups"]), parts("keep-last=2,keep-daily=4"));
    assert_eq!(f["fleecing"], "enabled=0");
    // `all` as 1 or 0, whatever shape PVE answered it in.
    for (all, want) in [(json!(true), "1"), (json!("1"), "1"), (json!(0), "0"), (json!(false), "0"), (json!("0"), "0")] {
        let f: BTreeMap<String, String> = vzdump_of_job(json!({"all": all}).as_object().unwrap()).into_iter().collect();
        assert_eq!(f["all"], want, "{all}");
    }
}

// ---------------------------------------------------------------------------
// The client: storages, backups and jobs listed
// ---------------------------------------------------------------------------

fn guest(id: &str, kind: GuestKind, state: GuestState) -> Guest {
    let vmid: u32 = id.rsplit('/').next().unwrap().parse().unwrap();
    Guest {
        id: id.into(),
        name: format!("g{vmid}"),
        kind,
        state,
        state_reason: None,
        vmid: Some(vmid),
        node: Some("pve".into()),
        vcpu: None,
        mem_bytes: None,
        uptime: None,
        tags: Vec::new(),
        template: false,
        autostart: None,
        actions: Default::default(),
    }
}

fn vm() -> Guest {
    guest("qemu/9941", GuestKind::Qemu, GuestState::Stopped)
}

fn ct() -> Guest {
    guest("lxc/200", GuestKind::Lxc, GuestState::Stopped)
}

fn listed(g: &Guest, status: &str) -> Value {
    json!({"id": g.id, "type": g.kind.as_str(), "vmid": g.vmid, "node": "pve", "name": g.name, "status": status})
}

/// A node `pve` with VM 9941 and CT 200 (as `states` says them), two backup
/// storages (`local` also for ISOs, `nfs` for backups alone), `local-lvm`
/// for disks, an inactive one, and the backups each holds.
fn host(vm_state: &str, ct_state: &str) -> Fake {
    let fake = Fake::new();
    let (vm, ct) = (listed(&vm(), vm_state), listed(&ct(), ct_state));
    fake.route("GET /cluster/resources", move |_| {
        ok(json!([
            {"id": "node/pve", "type": "node", "node": "pve", "status": "online"},
            vm, ct,
            {"id": "qemu/130", "type": "qemu", "vmid": 130, "node": "pve", "status": "stopped", "name": "taken"},
        ]))
    });
    fake.route("GET /nodes/pve/storage", |_| {
        ok(json!([
            {"storage": "local", "type": "dir", "active": 1, "enabled": 1, "content": "iso,backup"},
            {"storage": "nfs", "type": "nfs", "active": 1, "enabled": 1, "content": "backup"},
            {"storage": "local-lvm", "type": "lvmthin", "active": 1, "enabled": 1, "content": "images,rootdir"},
            {"storage": "offline", "type": "nfs", "active": 0, "enabled": 1, "content": "backup"},
        ]))
    });
    // PVE filters by `vmid`; the fake answers every guest's.
    fake.route("GET /nodes/pve/storage/local/content", |_| {
        let mut l = list("backup_content.json");
        l.push(json!({"volid": CT_ID, "content": "backup", "ctime": 1790000000, "subtype": "lxc", "vmid": 200}));
        ok(Value::Array(l))
    });
    fake.route("GET /nodes/pve/storage/nfs/content", |_| {
        ok(json!([{
            "volid": NFS_ID, "content": "backup", "ctime": 1790450000, "protected": 1,
            "verification": {"state": "ok"}, "subtype": "qemu", "vmid": 9941,
        }]))
    });
    for key in ["POST /nodes/pve/vzdump", "POST /nodes/pve/qemu", "POST /nodes/pve/lxc"] {
        fake.route(key, |_| ok(json!(UPID)));
    }
    fake
}

#[tokio::test]
async fn backup_storages_active_and_holding_backups() {
    let fake = host("stopped", "stopped");
    let pools = fake.client().backup_storages("pve").await.unwrap();
    let names: Vec<&str> = pools.iter().map(|p| p.name.as_str()).collect();
    assert_eq!(names, ["local", "nfs"]);
    assert_eq!(query(&fake, "GET /nodes/pve/storage"), map(&[("content", "backup"), ("enabled", "1")]));

    // The captured node: only `local` holds backups.
    let fake = Fake::new();
    fake.route("GET /nodes/pve/storage", |_| ok(fixture("node_storage_p8.json")));
    let pools = fake.client().backup_storages("pve").await.unwrap();
    assert_eq!(pools.iter().map(|p| p.id.as_str()).collect::<Vec<_>>(), ["pve/local"]);
    // The same answer, read as every storage: the content kinds are PVE's.
    let all = resources::parse_storages("pve", &list("node_storage_p8.json"), &[]);
    assert_eq!(all.len(), 3);
}

#[tokio::test]
async fn every_nodes_backup_storages_by_name_then_node() {
    let fake = Fake::new();
    fake.route("GET /nodes", |_| {
        ok(json!([
            {"node": "pve2", "status": "online"},
            {"node": "pve", "status": "online"},
            {"node": "pve3", "status": "offline"},
        ]))
    });
    fake.route("GET /nodes/pve/storage", |_| {
        ok(json!([
            {"storage": "nfs", "type": "nfs", "active": 1, "content": "backup", "shared": 1},
            {"storage": "local", "type": "dir", "active": 1, "content": "backup"},
        ]))
    });
    fake.route("GET /nodes/pve2/storage", |_| {
        ok(json!([
            {"storage": "nfs", "type": "nfs", "active": 1, "content": "backup", "shared": 1},
            {"storage": "local", "type": "dir", "active": 1, "content": "backup"},
        ]))
    });
    let pools = fake.client().all_backup_storages().await.unwrap();
    let ids: Vec<&str> = pools.iter().map(|p| p.id.as_str()).collect();
    // A shared storage is listed by each node that sees it.
    assert_eq!(ids, ["pve/local", "pve2/local", "pve/nfs", "pve2/nfs"]);
    assert_eq!(sent(&fake, "GET /nodes/pve3/storage"), 0, "an offline node is not asked");
}

#[tokio::test]
async fn a_guests_backups_on_every_backup_storage_newest_first() {
    let fake = host("stopped", "stopped");
    let backups = fake.client().backups(&vm()).await.unwrap();
    // The fake answers the container's archive too: PVE would have left it
    // out by `vmid`.
    let ids: Vec<&str> = backups.iter().map(|b| b.id.as_str()).collect();
    assert_eq!(ids, [NFS_ID, LOCAL_ID, CT_ID]);
    assert_eq!(backups[0].storage, "nfs");
    assert!(backups[0].protected);
    assert_eq!(backups[0].verification.as_deref(), Some("ok"));
    assert_eq!(query(&fake, "GET /nodes/pve/storage/local/content"), map(&[("content", "backup"), ("vmid", "9941")]));
    assert_eq!(query(&fake, "GET /nodes/pve/storage/nfs/content"), map(&[("content", "backup"), ("vmid", "9941")]));
    assert_eq!(sent(&fake, "GET /nodes/pve/storage/offline/content"), 0, "an inactive storage is not read");
    assert_eq!(sent(&fake, "GET /nodes/pve/storage/local-lvm/content"), 0, "nor one without backups");
}

#[tokio::test]
async fn a_guests_plan_leaves_out_the_jobs_restricted_to_another_node() {
    let fake = Fake::new();
    fake.route("GET /cluster/backup", |_| {
        ok(json!([
            {"id": "on-a", "type": "vzdump", "all": 1, "node": "a"},
            {"id": "on-pve", "type": "vzdump", "all": 1, "node": "pve"},
            {"id": "any", "type": "vzdump", "vmid": "9941"},
            {"id": "listed-on-a", "type": "vzdump", "vmid": "9941", "node": "a"},
            {"id": "pool", "type": "vzdump", "pool": "prod"},
        ]))
    });
    let client = fake.client();
    let jobs = client.backup_jobs(&vm()).await.unwrap();
    assert_eq!(jobs.iter().map(|j| j.id.as_str()).collect::<Vec<_>>(), ["on-pve", "any"]);
    assert_eq!(client.all_backup_jobs().await.unwrap().len(), 5);
}

#[tokio::test]
async fn no_sys_audit_no_jobs_another_failure_said() {
    let fake = Fake::new();
    fake.route("GET /cluster/backup", |_| status(403, "Permission check failed (/, Sys.Audit)"));
    assert!(fake.client().all_backup_jobs().await.unwrap().is_empty());
    assert!(fake.client().backup_jobs(&vm()).await.unwrap().is_empty());

    let fake = Fake::new();
    fake.route("GET /cluster/backup", |_| status(500, "cfs lock timeout"));
    let e = err(fake.client().all_backup_jobs()).await;
    assert_eq!(e.message.as_deref(), Some("cfs lock timeout"));
}

// ---------------------------------------------------------------------------
// The client: a job made, edited, removed
// ---------------------------------------------------------------------------

fn job_host() -> Fake {
    let fake = host("stopped", "stopped");
    fake.route("POST /cluster/backup", |_| ok(Value::Null));
    fake.route("PUT /cluster/backup/j1", |_| ok(Value::Null));
    fake.route("DELETE /cluster/backup/j1", |_| ok(Value::Null));
    fake
}

#[tokio::test]
async fn a_job_keeps_the_one_selection_it_has_pool_all_or_a_list() {
    let fake = job_host();
    let client = fake.client();
    let put = "PUT /cluster/backup/j1";
    let deleted = |f: &BTreeMap<String, String>| f["delete"].split(',').map(str::to_owned).collect::<BTreeSet<_>>();

    // A pool job saved with only its schedule changed stays a pool job.
    client.edit_backup_job(&edit(json!({"pool": "prod", "all": true, "vmids": [1]})), false).await.unwrap();
    let f = fake.form(put);
    assert_eq!(f["pool"], "prod");
    assert_eq!(f["all"], "0");
    assert!(!f.contains_key("vmid"));
    assert!(deleted(&f).is_superset(&BTreeSet::from(["vmid".into(), "exclude".into()])));
    assert!(!deleted(&f).contains("pool"));

    client.edit_backup_job(&edit(json!({"all": true, "exclude": [101, 102]})), false).await.unwrap();
    let f = fake.form(put);
    assert_eq!(f["all"], "1");
    assert_eq!(f["exclude"], "101,102");
    assert!(deleted(&f).is_superset(&BTreeSet::from(["vmid".into(), "pool".into()])));
    assert!(!deleted(&f).contains("exclude"));

    // A list is sent and not deleted in the same request.
    client.edit_backup_job(&edit(json!({"vmids": [100, 200]})), false).await.unwrap();
    let f = fake.form(put);
    assert_eq!(f["vmid"], "100,200");
    assert_eq!(f["all"], "0");
    assert!(deleted(&f).is_superset(&BTreeSet::from(["exclude".into(), "pool".into()])));
    assert!(!deleted(&f).contains("vmid"));
}

#[tokio::test]
async fn a_new_job_is_a_post_with_its_id_a_removed_one_a_delete() {
    let fake = job_host();
    let client = fake.client();
    client.edit_backup_job(&edit(json!({"is_new": true, "vmids": [9941], "storage": "nfs"})), false).await.unwrap();
    let f = fake.form("POST /cluster/backup");
    assert_eq!(f["id"], "j1");
    assert_eq!(f["storage"], "nfs");
    assert!(!f.contains_key("delete"));
    assert_eq!(sent(&fake, "PUT /cluster/backup/j1"), 0);

    // Removed: by id alone, nothing else checked.
    client.edit_backup_job(&edit(json!({"storage": "gone", "schedule": "nope"})), true).await.unwrap();
    assert_eq!(sent(&fake, "DELETE /cluster/backup/j1"), 1);
    let e = err(client.edit_backup_job(&edit(json!({"id": null})), true)).await;
    assert_eq!(refused(&e), Some(Issue::NotFound));
    // An edit of no job: there is nothing to `PUT`.
    let e = err(client.edit_backup_job(&edit(json!({"id": "", "vmids": [1]})), false)).await;
    assert_eq!(refused(&e), Some(Issue::NotFound));
}

#[tokio::test]
async fn a_job_refused_before_it_is_sent() {
    let fake = job_host();
    let client = fake.client();
    for (e, issue) in [
        (edit(json!({"schedule": "02:30 mon", "vmids": [1]})), Issue::ScheduleInvalid),
        (edit(json!({"schedule": "", "vmids": [1]})), Issue::ScheduleEmpty),
        // A storage that is not a backup storage of any online node.
        (edit(json!({"storage": "local-lvm", "vmids": [1]})), Issue::Storage),
        (edit(json!({"storage": "offline", "vmids": [1]})), Issue::Storage),
        (edit(json!({"mode": "live", "vmids": [1]})), Issue::Mode),
        (edit(json!({"compress": "xz", "vmids": [1]})), Issue::Compress),
        // A job selecting no guests.
        (edit(json!({})), Issue::Guests),
        (edit(json!({"is_new": true})), Issue::Guests),
    ] {
        let got = err(client.edit_backup_job(&e, false)).await;
        assert_eq!(refused(&got), Some(issue), "{e:?}");
        assert_eq!(got.kind, ErrorKind::Unsupported);
    }
    assert_eq!(sent(&fake, "PUT /cluster/backup/j1") + sent(&fake, "POST /cluster/backup"), 0);
}

#[tokio::test]
async fn a_job_pve_refuses_in_its_own_words() {
    let fake = job_host();
    fake.route("PUT /cluster/backup/j1", |_| status(500, "no such vzdump job 'j1'"));
    let e = err(fake.client().edit_backup_job(&edit(json!({"vmids": [1]})), false)).await;
    assert!(matches!(e.detail.as_deref(), Some(Detail::BackupRefused { issue: Issue::NotFound })), "{e:?}");
    assert_eq!(e.message.as_deref(), Some("no such vzdump job 'j1'"));

    fake.route("POST /cluster/backup", |_| status(400, "parameter verification failed. (schedule: value does not match)"));
    let e = err(fake.client().edit_backup_job(&edit(json!({"is_new": true, "vmids": [1]})), false)).await;
    assert_eq!(e.kind, ErrorKind::ActionFailed);
    assert!(e.message.unwrap().contains("parameter verification failed"));

    // `Sys.Modify` on `/`: the privilege, where, and who.
    fake.route("DELETE /cluster/backup/j1", |_| status(403, "Permission check failed (/, Sys.Modify)"));
    let e = err(fake.client().edit_backup_job(&edit(json!({})), true)).await;
    assert_eq!(e.kind, ErrorKind::PermissionDenied);
}

// ---------------------------------------------------------------------------
// The client: the schedule put to the host
// ---------------------------------------------------------------------------

#[tokio::test]
async fn a_schedule_the_host_takes_its_next_runs() {
    let fake = Fake::new();
    fake.route("GET /cluster/jobs/schedule-analyze", |_| {
        ok(json!([{"timestamp": 1790560200, "utc": "x"}, {"timestamp": 1790646600}, {"utc": "no timestamp"}]))
    });
    let check = fake.client().check_schedule(" mon..fri 02:30 ").await.unwrap();
    assert_eq!(check.error, None);
    assert_eq!(check.next, [1790560200, 1790646600]);
    assert_eq!(query(&fake, "GET /cluster/jobs/schedule-analyze"), map(&[("schedule", "mon..fri 02:30"), ("iterations", "3")]));
}

#[tokio::test]
async fn a_schedule_the_host_refuses_in_its_words() {
    let fake = Fake::new();
    fake.route("GET /cluster/jobs/schedule-analyze", |_| status(400, "invalid calendar event 'mon 25:61' - unable to parse"));
    let check = fake.client().check_schedule("mon 25:59").await.unwrap();
    assert_eq!(check.error.as_deref(), Some("invalid calendar event 'mon 25:61' - unable to parse"));
    assert!(check.next.is_empty());
}

#[tokio::test]
async fn a_schedule_of_the_wrong_shape_is_answered_here() {
    let fake = Fake::new();
    for bad in ["nope", "--help", "$(id)", "02:30; rm -rf /", "", "mon 60:00"] {
        let check = fake.client().check_schedule(bad).await.unwrap();
        assert!(check.error.is_some(), "{bad:?}");
        assert!(check.next.is_empty());
    }
    assert_eq!(sent(&fake, "GET /cluster/jobs/schedule-analyze"), 0, "the host is never asked");
}

// ---------------------------------------------------------------------------
// The client: back up now, run a job now
// ---------------------------------------------------------------------------

#[tokio::test]
async fn back_up_now_waited_for() {
    let fake = host("stopped", "stopped");
    let client = fake.client();
    let req = BackupRequest {
        storage: "local".into(),
        mode: "stop".into(),
        compress: "zstd".into(),
        notes: Some(" n ".into()),
        protected: true,
        prune: None,
    };
    client.backup(&vm(), &req).await.unwrap();
    assert_eq!(
        fake.form("POST /nodes/pve/vzdump"),
        map(&[("vmid", "9941"), ("storage", "local"), ("mode", "stop"), ("compress", "zstd"), ("notes-template", "n"), ("protected", "1")])
    );
    assert!(fake.paths().last().unwrap().contains("/tasks/"), "the task is waited for");

    // Blank notes are none; a retention of its own.
    let req = BackupRequest { notes: Some("  ".into()), protected: false, prune: Some("keep-last=1".into()), ..req };
    client.backup(&vm(), &req).await.unwrap();
    let f = fake.form("POST /nodes/pve/vzdump");
    assert!(!f.contains_key("notes-template") && !f.contains_key("protected"));
    assert_eq!(f["prune-backups"], "keep-last=1");
}

#[tokio::test]
async fn back_up_now_refused_before_it_is_sent() {
    let fake = host("stopped", "stopped");
    let client = fake.client();
    let req = |storage: &str, mode: &str, compress: &str| BackupRequest {
        storage: storage.into(),
        mode: mode.into(),
        compress: compress.into(),
        notes: None,
        protected: false,
        prune: None,
    };
    for (r, issue) in [
        (req("local-lvm", "snapshot", "zstd"), Issue::Storage),
        (req("offline", "snapshot", "zstd"), Issue::Storage),
        (req("gone", "snapshot", "zstd"), Issue::Storage),
        (req("local", "live", "zstd"), Issue::Mode),
        (req("local", "snapshot", "xz"), Issue::Compress),
    ] {
        assert_eq!(refused(&err(client.backup(&vm(), &r)).await), Some(issue), "{r:?}");
    }
    assert_eq!(sent(&fake, "POST /nodes/pve/vzdump"), 0);
}

#[tokio::test]
async fn run_now_on_the_jobs_node_or_every_online_node() {
    let fake = Fake::new();
    fake.route("GET /nodes", |_| {
        ok(json!([
            {"node": "pve", "status": "online"},
            {"node": "pve2", "status": "online"},
            {"node": "pve3", "status": "offline"},
        ]))
    });
    for n in ["pve", "pve2", "pve3"] {
        fake.route(&format!("POST /nodes/{n}/vzdump"), |_| ok(json!(UPID)));
    }
    let runs = |fake: &Fake| {
        let mut r: Vec<String> = fake.paths().into_iter().filter(|p| p.ends_with("/vzdump")).collect();
        r.sort();
        r
    };
    let reset = |fake: &Fake| {
        let mut a = fake.0.lock().unwrap();
        a.paths.clear();
        a.bodies.clear();
        a.queries.clear();
    };
    let client = fake.client();

    // No node: vzdump takes only the guests on the node it runs on, so each
    // online node is asked — the offline one is not. The job as PVE has it,
    // read again: what the model does not carry (`bwlimit`, `performance`,
    // ...) runs with it, as PVE's own "Run now" sends it; what describes the
    // schedule does not.
    fake.route("GET /cluster/backup/j", |_| {
        ok(json!({
            "id": "j", "type": "vzdump", "schedule": "sat 03:00", "enabled": 0, "next-run": 1790967600,
            "comment": "nightly", "storage": "nfs", "all": 1, "exclude": "9", "bwlimit": 4096, "ionice": 5,
            "performance": {"max-workers": "2"}, "prune-backups": {"keep-last": "2", "keep-daily": "4"},
            "fleecing": {"enabled": 0},
        }))
    });
    client.run_backup_job("j").await.unwrap();
    assert_eq!(runs(&fake), ["POST /nodes/pve/vzdump", "POST /nodes/pve2/vzdump"]);
    let mut f = fake.form("POST /nodes/pve2/vzdump");
    assert_eq!(parts(&f.remove("prune-backups").unwrap()), parts("keep-last=2,keep-daily=4"));
    assert_eq!(
        f,
        map(&[
            ("storage", "nfs"),
            ("all", "1"),
            ("exclude", "9"),
            ("bwlimit", "4096"),
            ("ionice", "5"),
            ("performance", "max-workers=2"),
            ("fleecing", "enabled=0"),
        ])
    );
    assert_eq!(fake.forms("POST /nodes/pve/vzdump").len(), 1);

    // A node of its own: there only.
    reset(&fake);
    fake.route("GET /cluster/backup/j", |_| ok(json!({"id": "j", "type": "vzdump", "storage": "nfs", "node": "pve2", "pool": "prod"})));
    client.run_backup_job("j").await.unwrap();
    assert_eq!(runs(&fake), ["POST /nodes/pve2/vzdump"]);
    assert_eq!(fake.form("POST /nodes/pve2/vzdump").get("pool").map(String::as_str), Some("prod"));

    // An empty node is none.
    reset(&fake);
    fake.route("GET /cluster/backup/j", |_| ok(json!({"id": "j", "node": "", "vmid": "100"})));
    client.run_backup_job("j").await.unwrap();
    assert_eq!(runs(&fake), ["POST /nodes/pve/vzdump", "POST /nodes/pve2/vzdump"]);

    // Refused when its node is offline: nothing runs.
    reset(&fake);
    fake.route("GET /cluster/backup/j", |_| ok(json!({"id": "j", "type": "vzdump", "node": "pve3", "all": 1})));
    let e = err(client.run_backup_job("j")).await;
    assert_eq!(e.kind, ErrorKind::Unsupported);
    assert_eq!(refused(&e), Some(Issue::NodeOffline));
    assert_eq!(e.message.as_deref(), Some("pve3"));
    assert!(runs(&fake).is_empty());

    // No node online at all.
    reset(&fake);
    fake.route("GET /nodes", |_| ok(json!([{"node": "pve", "status": "offline"}])));
    fake.route("GET /cluster/backup/j", |_| ok(json!({"id": "j", "all": 1})));
    assert_eq!(refused(&err(client.run_backup_job("j")).await), Some(Issue::NodeOffline));
    assert!(runs(&fake).is_empty());

    // A job that is not there: PVE's answer is not an object.
    fake.route("GET /cluster/backup/j", |_| ok(Value::Null));
    assert_eq!(err(client.run_backup_job("j")).await.kind, ErrorKind::InvalidResponse);
}

#[tokio::test]
async fn run_now_a_failed_vzdump_is_the_runs_failure() {
    let fake = Fake::new();
    fake.route("GET /cluster/backup/j", |_| ok(json!({"id": "j", "all": 1})));
    fake.route("POST /nodes/pve/vzdump", |_| status(500, "storage 'nfs' is not online"));
    let e = err(fake.client().run_backup_job("j")).await;
    assert_eq!(e.kind, ErrorKind::ActionFailed);
    assert_eq!(e.message.as_deref(), Some("storage 'nfs' is not online"));
}

// ---------------------------------------------------------------------------
// The client: restore, edit, delete
// ---------------------------------------------------------------------------

#[tokio::test]
async fn restore_over_the_guest_and_as_a_new_one() {
    let fake = host("stopped", "stopped");
    let client = fake.client();

    client.restore_backup(&vm(), LOCAL_ID, None, None).await.unwrap();
    assert_eq!(fake.form("POST /nodes/pve/qemu"), map(&[("vmid", "9941"), ("archive", LOCAL_ID), ("force", "1")]));
    assert!(fake.paths().last().unwrap().contains("/tasks/"), "the task is waited for");

    client.restore_backup(&vm(), NFS_ID, Some(131), Some("local-lvm")).await.unwrap();
    assert_eq!(fake.form("POST /nodes/pve/qemu"), map(&[("vmid", "131"), ("archive", NFS_ID), ("storage", "local-lvm")]));

    // A container's archive is its template, restored.
    client.restore_backup(&ct(), CT_ID, None, None).await.unwrap();
    assert_eq!(fake.form("POST /nodes/pve/lxc"), map(&[("vmid", "200"), ("ostemplate", CT_ID), ("restore", "1"), ("force", "1")]));
}

#[tokio::test]
async fn restore_reads_the_guest_again() {
    // The caller's copy says stopped; the host says it runs: refused, not
    // forced. As a new guest it may run on.
    let fake = host("running", "stopped");
    let client = fake.client();
    let e = err(client.restore_backup(&vm(), LOCAL_ID, None, None)).await;
    assert_eq!(refused(&e), Some(Issue::NotStopped));
    assert_eq!(e.kind, ErrorKind::Unsupported);
    assert_eq!(sent(&fake, "POST /nodes/pve/qemu"), 0);
    client.restore_backup(&vm(), LOCAL_ID, Some(131), None).await.unwrap();
    assert_eq!(fake.form("POST /nodes/pve/qemu")["vmid"], "131");

    // The caller's copy says it runs; the host says stopped: restored.
    let fake = host("stopped", "stopped");
    let running = guest("qemu/9941", GuestKind::Qemu, GuestState::Running);
    fake.client().restore_backup(&running, LOCAL_ID, None, None).await.unwrap();
    assert_eq!(sent(&fake, "POST /nodes/pve/qemu"), 1);

    // A guest no longer on the host.
    let fake = host("stopped", "stopped");
    let gone = guest("qemu/9999", GuestKind::Qemu, GuestState::Stopped);
    let e = err(fake.client().restore_backup(&gone, LOCAL_ID, None, None)).await;
    assert_eq!(create_refused(&e), Some(sbm_virt::create::Issue::NotFound));
}

#[tokio::test]
async fn restore_refused_before_it_is_sent() {
    let fake = host("stopped", "stopped");
    let client = fake.client();
    // A backup the guest does not have.
    let e = err(client.restore_backup(&vm(), "local:backup/vzdump-qemu-1-x.vma.zst", None, None)).await;
    assert_eq!(refused(&e), Some(Issue::NotFound));
    // A VMID taken, by another guest or by the guest itself.
    let e = err(client.restore_backup(&vm(), LOCAL_ID, Some(130), None)).await;
    assert_eq!(create_refused(&e), Some(sbm_virt::create::Issue::VmidTaken));
    assert_eq!(e.kind, ErrorKind::Exists);
    let e = err(client.restore_backup(&vm(), LOCAL_ID, Some(9941), None)).await;
    assert_eq!(create_refused(&e), Some(sbm_virt::create::Issue::VmidTaken));
    let e = err(client.restore_backup(&vm(), LOCAL_ID, Some(99), None)).await;
    assert_eq!(create_refused(&e), Some(sbm_virt::create::Issue::VmidInvalid));
    assert_eq!(sent(&fake, "POST /nodes/pve/qemu"), 0);
}

#[tokio::test]
async fn restore_pve_refuses_in_its_words() {
    let fake = host("stopped", "stopped");
    fake.route("POST /nodes/pve/qemu", |_| status(500, "unable to create VM 131 - VM 131 already exists on node 'pve2'"));
    let e = err(fake.client().restore_backup(&vm(), LOCAL_ID, Some(131), None)).await;
    assert_eq!(e.kind, ErrorKind::Exists);
    assert!(e.message.unwrap().contains("already exists"));
}

fn local_backup() -> Backup {
    parse_backups("pve", "local", &list("backup_content.json")).remove(0)
}

const CONTENT: &str = "/nodes/pve/storage/local/content/local%3Abackup%2Fvzdump-qemu-9941-2026_09_26-03_11_45.vma.zst";

#[tokio::test]
async fn a_backups_notes_and_protection_both_sent() {
    let fake = Fake::new();
    let key = format!("PUT {CONTENT}");
    fake.route(&key, |_| ok(Value::Null));
    let client = fake.client();
    client.edit_backup(&local_backup(), &BackupEdit { notes: "keep".into(), protected: true }).await.unwrap();
    assert_eq!(fake.form(&key), map(&[("notes", "keep"), ("protected", "1")]));
    // An empty note is written as one.
    client.edit_backup(&local_backup(), &BackupEdit { notes: String::new(), protected: false }).await.unwrap();
    assert_eq!(fake.form(&key), map(&[("notes", ""), ("protected", "0")]));

    fake.route(&key, |_| status(403, "Permission check failed (/storage/local, Datastore.Allocate)"));
    let e = err(client.edit_backup(&local_backup(), &BackupEdit { notes: String::new(), protected: false })).await;
    assert_eq!(e.kind, ErrorKind::PermissionDenied);
    fake.route(&key, |_| status(500, "volume does not exist"));
    let e = err(client.edit_backup(&local_backup(), &BackupEdit { notes: String::new(), protected: false })).await;
    assert_eq!(e.kind, ErrorKind::ActionFailed);
    assert_eq!(e.message.as_deref(), Some("volume does not exist"));
}

#[tokio::test]
async fn delete_a_backup_its_task_waited_for() {
    let fake = Fake::new();
    let key = format!("DELETE {CONTENT}");
    fake.route(&key, |_| ok(json!(UPID)));
    fake.client().delete_backup(&local_backup()).await.unwrap();
    assert_eq!(sent(&fake, &key), 1);
    assert!(fake.paths().last().unwrap().starts_with("GET /nodes/pve/tasks/"));

    // A protected one: PVE refuses, in its words.
    fake.route(&key, |_| status(500, "backup is protected"));
    let e = err(fake.client().delete_backup(&local_backup())).await;
    assert_eq!(e.kind, ErrorKind::ActionFailed);
    assert_eq!(e.message.as_deref(), Some("backup is protected"));
}

#[tokio::test]
async fn a_schedule_check_the_account_may_not_make_is_an_error_not_a_refused_schedule() {
    let fake = Fake::new();
    fake.route("GET /cluster/jobs/schedule-analyze", |_| status(403, "Permission check failed (/, Sys.Audit)"));
    let e = fake.client().check_schedule("02:00").await.unwrap_err();
    assert_ne!(e.kind, ErrorKind::Unsupported, "{e:?}");
}

#[tokio::test]
async fn running_a_job_that_is_gone_says_so() {
    let fake = Fake::new();
    let body = serde_json::json!({"data": null, "message": "Parameter verification failed.", "errors": {"id": "No such job 'gone'"}});
    fake.route("GET /cluster/backup/gone", move |_| sbm_virt::pve::http::Response { status: 400, ..whole(body.clone()) });
    let e = fake.client().run_backup_job("gone").await.unwrap_err();
    assert!(matches!(e.detail.as_deref(), Some(Detail::BackupRefused { issue: Issue::NotFound })), "{e:?}");
}

#[tokio::test]
async fn removing_a_job_that_is_gone_says_so() {
    let fake = job_host();
    // PVE 9.2.2 rethrows the delete's 400 inside a 500.
    fake.route("DELETE /cluster/backup/j1", |_| status(500, "400 Parameter verification failed.\nid: No such job 'j1'\n"));
    let e = err(fake.client().edit_backup_job(&edit(json!({})), true)).await;
    assert!(matches!(e.detail.as_deref(), Some(Detail::BackupRefused { issue: Issue::NotFound })), "{e:?}");
}
