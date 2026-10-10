//! `/api/v1/storage*` on a real machine, with loop devices standing in for
//! disks: partition, format, mount with `/etc/fstab`, refusing what is in use,
//! unmount; a RAID 1 built, degraded, mended and deleted (with mdadm); a ZFS
//! mirror built, scrubbed and destroyed (with zpool).
//!
//! Opt-in and root only: it makes loop devices and changes `/etc/fstab`
//! (restored after). Never on a machine whose disks matter more than a test.
//!
//!     SBM_E2E_STORAGE=1 cargo test -p server_box_monitor --test storage_e2e -- --ignored --nocapture

mod common;

use std::process::Command;
use std::sync::Arc;
use std::time::{Duration, Instant};

use ntex::http::Method;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::AppState;
use server_box_monitor::api::storage;
use server_box_monitor::core::config::Config;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";
const MOUNT: &str = "/mnt/sbm-e2e";

async fn setup() -> TestServer {
    let db = common::database().await;
    let config = Config { jwt_secret: Some(SECRET.to_string()), ..Default::default() };
    common::seed_as_upgrade(&db, &config).await;
    let state: Arc<AppState> = AppState::new(Arc::new(config), db);
    web_test::server(move || {
        let state = state.clone();
        async move {
            App::new().state(state).service(
                web::scope("/api/v1")
                    .service(web::resource("/storage").route(web::get().to(storage::view)))
                    .service(web::resource("/storage/act").route(web::post().to(storage::act)))
                    .service(web::resource("/storage/job").route(web::get().to(storage::job))),
            )
        }
    })
    .await
}

async fn call(srv: &TestServer, method: Method, path: &str, body: Option<Value>) -> (u16, Value) {
    let req = srv
        .request(method, srv.url(path))
        .header("Authorization", format!("Bearer {}", generate_token("admin", SECRET).unwrap()))
        .timeout(Duration::from_secs(60));
    let resp = match body {
        Some(body) => req.send_json(&body).await.unwrap(),
        None => req.send().await.unwrap(),
    };
    let bytes = resp.body().limit(16 << 20).await.unwrap_or_default();
    (resp.status().as_u16(), serde_json::from_slice(&bytes).unwrap_or(Value::Null))
}

/// Starts [action] and waits for it; its state, the log on failure.
async fn act(srv: &TestServer, action: Value) -> String {
    let (status, body) = call(srv, Method::POST, "/api/v1/storage/act", Some(action.clone())).await;
    assert_eq!(status, 202, "{action}: {body}");
    let deadline = Instant::now() + Duration::from_secs(300);
    loop {
        let (_, job) = call(srv, Method::GET, "/api/v1/storage/job", None).await;
        let state = job["state"].as_str().unwrap_or_default().to_string();
        if state != "running" {
            if state != "succeeded" {
                eprintln!("{action}: {state}\n{}", job["lines"].as_array().unwrap().iter().filter_map(|l| l["text"].as_str()).collect::<Vec<_>>().join("\n"));
            }
            return state;
        }
        assert!(Instant::now() < deadline, "{action} did not end");
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
}

async fn view(srv: &TestServer) -> Value {
    let (status, body) = call(srv, Method::GET, "/api/v1/storage", None).await;
    assert_eq!(status, 200, "{body}");
    body
}

fn find<'a>(disks: &'a Value, path: &str) -> Option<&'a Value> {
    for d in disks.as_array()? {
        if d["path"] == path {
            return Some(d);
        }
        if let Some(found) = find(&d["children"], path) {
            return Some(found);
        }
    }
    None
}

fn sh(script: &str) -> String {
    let out = Command::new("sh").arg("-c").arg(script).output().unwrap();
    String::from_utf8_lossy(&out.stdout).trim().to_string()
}

fn has(tool: &str) -> bool {
    !sh(&format!("command -v {tool}")).is_empty()
}

/// The loop devices and the fstab as they were, put back whatever happens.
struct Lab {
    loops: Vec<String>,
    files: tempfile::TempDir,
    fstab: String,
}

impl Lab {
    fn new(n: usize) -> Self {
        let files = tempfile::tempdir().unwrap();
        let loops = (0..n)
            .map(|i| {
                let file = files.path().join(format!("disk{i}.img"));
                sh(&format!("truncate -s 256M '{}' && losetup -fP --show '{}'", file.display(), file.display()))
            })
            .collect();
        Self { loops, files, fstab: std::fs::read_to_string("/etc/fstab").unwrap() }
    }
}

impl Drop for Lab {
    fn drop(&mut self) {
        sh(&format!("umount {MOUNT} 2>/dev/null; rmdir {MOUNT} 2>/dev/null"));
        sh("for p in $(zpool list -H -o name 2>/dev/null | grep '^sbme2e'); do zpool destroy -f $p; done");
        for md in sh("ls /dev/md* 2>/dev/null").lines() {
            let members = sh(&format!("mdadm --detail {md} 2>/dev/null | grep -o '/dev/loop[0-9]*'"));
            if self.loops.iter().any(|l| members.contains(l.as_str())) {
                sh(&format!("mdadm --stop {md}"));
            }
        }
        for l in &self.loops {
            sh(&format!("wipefs -a {l} >/dev/null 2>&1; losetup -d {l}"));
        }
        std::fs::write("/etc/fstab", &self.fstab).unwrap();
        let _ = &self.files;
    }
}

#[ntex::test]
#[ignore = "changes real block devices: SBM_E2E_STORAGE=1, as root"]
async fn a_machines_disks_are_managed_end_to_end() {
    if std::env::var("SBM_E2E_STORAGE").is_err() || sh("id -u") != "0" {
        eprintln!("SBM_E2E_STORAGE is not set, or not root");
        return;
    }
    let lab = Lab::new(3);
    let (a, b, c) = (lab.loops[0].clone(), lab.loops[1].clone(), lab.loops[2].clone());
    let srv = setup().await;

    // Free disks, listed and not in use.
    let v = view(&srv).await;
    assert!(find(&v["disks"], &a).is_some(), "{v}");
    assert!(v["busy"].get(&a).is_none());

    // One partition, a filesystem on it, mounted for the agent and kept in fstab.
    assert_eq!(act(&srv, json!({ "action": "partition", "device": a })).await, "succeeded");
    let part = format!("{a}p1");
    assert!(find(&view(&srv).await["disks"], &part).is_some(), "the partition shows");
    assert_eq!(act(&srv, json!({ "action": "format", "device": part, "fstype": "ext4", "label": "sbme2e" })).await, "succeeded");
    assert_eq!(find(&view(&srv).await["disks"], &part).unwrap()["fstype"], "ext4");
    assert_eq!(act(&srv, json!({ "action": "mount", "device": part, "mountpoint": MOUNT, "persist": true, "own": true })).await, "succeeded");
    let v = view(&srv).await;
    assert_eq!(find(&v["disks"], &part).unwrap()["mountpoints"], json!([MOUNT]));
    assert_eq!(v["busy"][&a], "mounted");
    assert!(std::fs::read_to_string("/etc/fstab").unwrap().contains(&format!(" {MOUNT} ext4 defaults,nofail 0 2")));

    // In use: not formatted, not built on.
    let (status, body) = call(&srv, Method::POST, "/api/v1/storage/act", Some(json!({ "action": "format", "device": a, "fstype": "ext4" }))).await;
    assert_eq!((status, body["error"].as_str()), (409, Some("inUse")), "{body}");

    assert_eq!(act(&srv, json!({ "action": "unmount", "mountpoint": MOUNT })).await, "succeeded");
    assert!(!std::fs::read_to_string("/etc/fstab").unwrap().contains(MOUNT));

    if has("mdadm") {
        let md = "md91";
        assert_eq!(act(&srv, json!({ "action": "createRaid", "name": md, "level": 1, "devices": [b, c] })).await, "succeeded");
        let v = view(&srv).await;
        let array = v["arrays"].as_array().unwrap().iter().find(|x| x["name"] == md).expect("the array").clone();
        assert_eq!(array["level"], "raid1");
        assert_eq!(v["busy"][&b], "raidMember");
        assert_eq!(act(&srv, json!({ "action": "removeFromRaid", "array": md, "device": c })).await, "succeeded");
        let v = view(&srv).await;
        let array = v["arrays"].as_array().unwrap().iter().find(|x| x["name"] == md).unwrap().clone();
        assert_eq!((array["raid_disks"].as_u64(), array["working_disks"].as_u64()), (Some(2), Some(1)), "{array}");
        sh(&format!("wipefs -a {c}"));
        assert_eq!(act(&srv, json!({ "action": "addToRaid", "array": md, "device": c })).await, "succeeded");
        assert_eq!(act(&srv, json!({ "action": "deleteRaid", "array": md })).await, "succeeded");
        let v = view(&srv).await;
        assert!(!v["arrays"].as_array().unwrap().iter().any(|x| x["name"] == md));
        assert!(v["busy"].get(&b).is_none(), "its members are free again: {}", v["busy"]);
    } else {
        eprintln!("mdadm is not installed: RAID not tried");
    }

    if has("zpool") {
        assert_eq!(act(&srv, json!({ "action": "createPool", "name": "sbme2e", "layout": "mirror", "devices": [b, c] })).await, "succeeded");
        let v = view(&srv).await;
        let pool = v["pools"].as_array().unwrap().iter().find(|p| p["name"] == "sbme2e").expect("the pool").clone();
        assert_eq!(pool["health"], "ONLINE");
        assert_eq!(pool["vdevs"][0]["name"], "mirror-0");
        assert_eq!(act(&srv, json!({ "action": "scrubPool", "name": "sbme2e" })).await, "succeeded");
        assert_eq!(act(&srv, json!({ "action": "destroyPool", "name": "sbme2e" })).await, "succeeded");
        assert!(!view(&srv).await["pools"].as_array().unwrap().iter().any(|p| p["name"] == "sbme2e"));
    } else {
        eprintln!("zpool is not installed: ZFS not tried");
    }
    drop(lab);
}
