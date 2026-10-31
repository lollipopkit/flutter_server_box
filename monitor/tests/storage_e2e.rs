//! `/api/v1/storage*` on a real machine, with loop devices standing in for
//! disks: partition, format, mount with `/etc/fstab`, refusing what is in use,
//! the system's mounts and a disk picked with its own partition, unmount; a
//! RAID 1 built, degraded, mended and deleted (with mdadm); a ZFS mirror
//! built, scrubbed, given a mirror more and destroyed (with zpool); an array
//! grown and its filesystem expanded; a RAID 5 grown by a disk and its
//! filesystem expanded into the room; the scheduled scrub run; the watch
//! saying an array degraded and a pool unhealthy (on the desk and through a
//! push channel) and both back; a pool's spare added and removed, a device
//! replaced, a mirror side attached; a partition grown with its disk; a LUKS
//! filesystem made, locked and unlocked (with cryptsetup); SMART read (with
//! smartctl).
//! The panel's side of the same: `frontend/e2e/storage.e2e.ts`.
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
use ntex::service::map_state_factory;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{Agent, AppState};
use server_box_monitor::api::storage;
use server_box_monitor::core::config::Config;
use server_box_monitor::storage_watch;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";
const MOUNT: &str = "/mnt/sbm-e2e";

/// What a push channel received: a webhook on loopback answering 200.
struct Hook {
    url: String,
    got: Arc<std::sync::Mutex<Vec<String>>>,
}

async fn hook() -> Hook {
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/hook", listener.local_addr().unwrap());
    let got = Arc::new(std::sync::Mutex::new(Vec::new()));
    let seen = got.clone();
    tokio::spawn(async move {
        while let Ok((mut socket, _)) = listener.accept().await {
            let mut buf = vec![0u8; 64 << 10];
            let n = socket.read(&mut buf).await.unwrap_or(0);
            seen.lock().unwrap().push(String::from_utf8_lossy(&buf[..n]).into_owned());
            let _ = socket.write_all(b"HTTP/1.1 200 OK\r\ncontent-length: 2\r\nconnection: close\r\n\r\nok").await;
        }
    });
    Hook { url, got }
}

async fn setup(hook: &Hook) -> (TestServer, Arc<AppState>) {
    let db = common::database().await;
    let mut webhook = toml::Table::new();
    webhook.insert("url".into(), toml::Value::String(hook.url.clone()));
    webhook.insert("body".into(), toml::Value::Table(toml::Table::from_iter([("text".to_string(), toml::Value::String("{{msg}}".into()))])));
    let mut config = Config { jwt_secret: Some(SECRET.to_string()), ..Default::default() };
    config.push = Some(vec![server_box_monitor::core::config::PushConfig { name: "e2e".into(), push_type: "webhook".into(), config: webhook }]);
    config.monitoring.get_or_insert_default().push_rate = Some("20/1m".into());
    common::add_owner(&db).await;
    let state: Arc<AppState> = AppState::new(Arc::new(config), db);
    let served = state.clone();
    let srv = web_test::server(async move |_| {
        let state = state.clone();
        map_state_factory(Agent(state), App::<Agent>::new().service(
                web::scope("/api/v1")
                    .service(web::resource("/storage").route(web::get().to(storage::view)))
                    .service(web::resource("/storage/health").route(web::post().to(storage::health)))
                    .service(web::resource("/storage/maintenance").route(web::put().to(storage::set_maintenance)))
                    .service(web::resource("/storage/maintenance/{task}/run").route(web::post().to(storage::run_maintenance)))
                    .service(web::resource("/storage/act").route(web::post().to(storage::act)))
                    .service(web::resource("/storage/job").route(web::get().to(storage::job))),
            ))
    });
    (srv, served)
}

/// The kinds of desk notification said so far.
async fn notices(state: &AppState) -> Vec<String> {
    sqlx::query_scalar("SELECT kind FROM desk_notification WHERE kind LIKE 'storage.%' ORDER BY id").fetch_all(&state.db).await.unwrap()
}

/// Waits until no array is syncing or reshaping.
async fn settled(srv: &TestServer) {
    let deadline = Instant::now() + Duration::from_secs(600);
    while view(srv).await["arrays"].as_array().unwrap().iter().any(|a| !a["sync"].is_null()) {
        assert!(Instant::now() < deadline, "an array did not settle");
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
}

async fn call(srv: &TestServer, method: Method, path: &str, body: Option<Value>) -> (u16, Value) {
    let req = srv
        .request(method, srv.url(path))
        .header("Authorization", format!("Bearer {}", generate_token(SECRET).unwrap()))
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
    /// md's resync floor, raised so a reshape of loop devices ends in time.
    speed_min: String,
}

impl Lab {
    /// Loop device [i]'s disk made [size] large (as a VM's disk grows).
    fn grow(&self, i: usize, size: &str) {
        let file = self.files.path().join(format!("disk{i}.img"));
        sh(&format!("truncate -s {size} '{}' && losetup -c {}", file.display(), self.loops[i]));
    }

    /// One more loop device, dropped with the others.
    fn extra(&mut self) -> String {
        let file = self.files.path().join(format!("disk{}.img", self.loops.len()));
        let l = sh(&format!("truncate -s 256M '{}' && losetup -fP --show '{}'", file.display(), file.display()));
        self.loops.push(l.clone());
        l
    }

    fn new(n: usize) -> Self {
        // On disk: `/tmp` may be a small tmpfs, and arrays fill their members.
        let files = tempfile::tempdir_in("/var/tmp").unwrap();
        let loops = (0..n)
            .map(|i| {
                let file = files.path().join(format!("disk{i}.img"));
                sh(&format!("truncate -s 256M '{}' && losetup -fP --show '{}'", file.display(), file.display()))
            })
            .collect();
        let speed_min = sh("cat /proc/sys/dev/raid/speed_limit_min");
        sh("echo 200000 > /proc/sys/dev/raid/speed_limit_min");
        Self { loops, files, fstab: std::fs::read_to_string("/etc/fstab").unwrap(), speed_min }
    }
}

impl Drop for Lab {
    fn drop(&mut self) {
        sh(&format!("umount {MOUNT} 2>/dev/null; rmdir {MOUNT} 2>/dev/null"));
        sh("for m in /dev/mapper/luks-*; do [ -e \"$m\" ] && cryptsetup close \"$(basename \"$m\")\"; done 2>/dev/null");
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
        if !self.speed_min.is_empty() {
            sh(&format!("echo {} > /proc/sys/dev/raid/speed_limit_min", self.speed_min));
        }
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
    let mut lab = Lab::new(3);
    let (a, b, c) = (lab.loops[0].clone(), lab.loops[1].clone(), lab.loops[2].clone());
    let hook = hook().await;
    let (srv, state) = setup(&hook).await;

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

    // The system's mounts stay; nothing is mounted inside its trees; a disk
    // never goes into an array with its own partition.
    for (action, refusal) in [
        (json!({ "action": "unmount", "mountpoint": "/" }), (400, "invalidMountpoint")),
        (json!({ "action": "unmount", "mountpoint": "/mnt/sbm-e2e-nothing" }), (409, "notMounted")),
        (json!({ "action": "mount", "device": part, "mountpoint": "/boot/efi", "persist": false }), (400, "invalidMountpoint")),
        (json!({ "action": "createRaid", "name": "md92", "level": 1, "devices": [a, part] }), (400, "overlapping")),
    ] {
        let (status, body) = call(&srv, Method::POST, "/api/v1/storage/act", Some(action.clone())).await;
        assert_eq!((status, body["error"].as_str().unwrap_or_default()), refusal, "{action}: {body}");
    }

    // The disk grows (a VM's disk resized): the partition takes the free
    // space, then its filesystem does, mounted.
    let size_of = |v: &Value, p: &str| find(&v["disks"], p).unwrap()["size"].as_u64().unwrap();
    let fs_of = |v: &Value, p: &str| find(&v["disks"], p).unwrap()["fs_size"].as_u64().unwrap();
    let v = view(&srv).await;
    let (part_before, fs_before) = (size_of(&v, &part), fs_of(&v, &part));
    lab.grow(0, "512M");
    assert_eq!(act(&srv, json!({ "action": "growPartition", "device": part })).await, "succeeded");
    assert!(size_of(&view(&srv).await, &part) > part_before * 18 / 10, "the partition grew");
    assert_eq!(act(&srv, json!({ "action": "expandFilesystem", "device": part })).await, "succeeded");
    assert!(fs_of(&view(&srv).await, &part) > fs_before * 18 / 10, "the filesystem grew");
    let (status, body) = call(&srv, Method::POST, "/api/v1/storage/act", Some(json!({ "action": "growPartition", "device": a }))).await;
    assert_eq!((status, body["error"].as_str()), (409, Some("notGrowable")), "a whole disk is not a partition: {body}");

    assert_eq!(act(&srv, json!({ "action": "unmount", "mountpoint": MOUNT })).await, "succeeded");
    assert!(!std::fs::read_to_string("/etc/fstab").unwrap().contains(MOUNT));

    if has("cryptsetup") {
        // An encrypted filesystem: made, locked, refused a wrong passphrase,
        // unlocked with the right one.
        let l = lab.extra();
        let opened = |v: &Value| find(&v["disks"], &l).unwrap()["children"].as_array().unwrap().iter().find(|c| c["kind"] == "crypt").cloned();
        let (status, body) = call(&srv, Method::POST, "/api/v1/storage/act", Some(json!({ "action": "format", "device": l, "fstype": "ext4", "encrypt": true }))).await;
        assert_eq!((status, body["error"].as_str()), (400, Some("invalidPassphrase")), "{body}");
        let phrase = "e2e passphrase";
        assert_eq!(act(&srv, json!({ "action": "format", "device": l, "fstype": "ext4", "encrypt": true, "passphrase": phrase })).await, "succeeded");
        let v = view(&srv).await;
        assert_eq!(find(&v["disks"], &l).unwrap()["fstype"], "crypto_LUKS");
        let inner = opened(&v).expect("opened after the format");
        assert_eq!(inner["fstype"], "ext4");
        let mapper = inner["path"].as_str().unwrap().to_string();
        assert_eq!(act(&srv, json!({ "action": "mount", "device": mapper, "mountpoint": MOUNT, "persist": false })).await, "succeeded");
        let (status, body) = call(&srv, Method::POST, "/api/v1/storage/act", Some(json!({ "action": "lock", "device": l }))).await;
        assert_eq!((status, body["error"].as_str()), (409, Some("mounted")), "{body}");
        assert_eq!(act(&srv, json!({ "action": "unmount", "mountpoint": MOUNT })).await, "succeeded");
        assert_eq!(act(&srv, json!({ "action": "lock", "device": l })).await, "succeeded");
        assert!(opened(&view(&srv).await).is_none(), "locked");
        assert_eq!(act(&srv, json!({ "action": "unlock", "device": l, "passphrase": "not the passphrase" })).await, "failed");
        assert_eq!(act(&srv, json!({ "action": "unlock", "device": l, "passphrase": phrase })).await, "succeeded");
        assert!(opened(&view(&srv).await).is_some(), "unlocked");
        assert_eq!(act(&srv, json!({ "action": "lock", "device": l })).await, "succeeded");
        let leftover = sh("ls /tmp | grep -c '^sbm-root-' || true");
        assert_eq!(leftover, "0", "no key file is left behind");
    } else {
        eprintln!("cryptsetup is not installed: LUKS not tried");
    }

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
        // The watch says so, on the desk and through the push channel.
        storage_watch::check(&state).await;
        assert_eq!(notices(&state).await, ["storage.arrayDegraded"]);
        assert!(hook.got.lock().unwrap().iter().any(|r| r.contains(&format!("/dev/{md} is degraded"))), "pushed");
        sh(&format!("wipefs -a {c}"));
        assert_eq!(act(&srv, json!({ "action": "addToRaid", "array": md, "device": c })).await, "succeeded");
        settled(&srv).await;
        storage_watch::check(&state).await;
        assert_eq!(notices(&state).await, ["storage.arrayDegraded", "storage.arrayBack"]);

        // Its filesystem, mounted, grown into a third mirror and expanded
        // (a no-op for RAID 1, which gains no room, but run all the same).
        let dev = format!("/dev/{md}");
        assert_eq!(act(&srv, json!({ "action": "format", "device": dev, "fstype": "ext4" })).await, "succeeded");
        assert_eq!(act(&srv, json!({ "action": "mount", "device": dev, "mountpoint": MOUNT, "persist": false })).await, "succeeded");
        assert_eq!(act(&srv, json!({ "action": "expandFilesystem", "device": dev })).await, "succeeded");
        let (status, body) = call(&srv, Method::POST, "/api/v1/storage/act", Some(json!({ "action": "expandFilesystem", "device": a }))).await;
        assert_eq!((status, body["error"].as_str()), (409, Some("notGrowable")), "nothing mounted on it: {body}");
        assert_eq!(act(&srv, json!({ "action": "unmount", "mountpoint": MOUNT })).await, "succeeded");
        sh(&format!("wipefs -a {a}"));
        assert_eq!(act(&srv, json!({ "action": "growRaid", "array": md, "device": a })).await, "succeeded");
        let v = view(&srv).await;
        let array = v["arrays"].as_array().unwrap().iter().find(|x| x["name"] == md).unwrap().clone();
        assert_eq!(array["raid_disks"].as_u64(), Some(3), "{array}");

        // The schedule's scrub checks it, unattended.
        let (status, body) = call(&srv, Method::PUT, "/api/v1/storage/maintenance", Some(json!({ "task": "scrub", "every": "weekly", "at": "03:00", "day": 6 }))).await;
        assert_eq!(status, 200, "{body}");
        tokio::time::sleep(Duration::from_secs(2)).await;
        let (status, body) = call(&srv, Method::POST, "/api/v1/storage/maintenance/scrub/run", None).await;
        assert_eq!(status, 200, "{body}");
        assert_eq!(body["maintenance"][0]["last_error"], Value::Null, "{body}");
        let (status, _) = call(&srv, Method::PUT, "/api/v1/storage/maintenance", Some(json!({ "task": "scrub", "every": null }))).await;
        assert_eq!(status, 200);
        assert_eq!(view(&srv).await["maintenance"], json!([]));

        assert_eq!(act(&srv, json!({ "action": "deleteRaid", "array": md })).await, "succeeded");
        let v = view(&srv).await;
        assert!(!v["arrays"].as_array().unwrap().iter().any(|x| x["name"] == md));
        assert!(v["busy"].get(&b).is_none(), "its members are free again: {}", v["busy"]);

        // A RAID 5 of three, grown by a fourth: room once the reshape ends,
        // which its filesystem then takes.
        let d = lab.extra();
        let md5 = "md95";
        sh(&format!("wipefs -a {a} {b} {c}"));
        assert_eq!(act(&srv, json!({ "action": "createRaid", "name": md5, "level": 5, "devices": [a, b, c] })).await, "succeeded");
        settled(&srv).await;
        let dev = format!("/dev/{md5}");
        assert_eq!(act(&srv, json!({ "action": "format", "device": dev, "fstype": "ext4" })).await, "succeeded");
        assert_eq!(act(&srv, json!({ "action": "mount", "device": dev, "mountpoint": MOUNT, "persist": false })).await, "succeeded");
        let fs_size = |v: &Value| find(&v["disks"], &dev).unwrap()["fs_size"].as_u64().unwrap();
        let before = fs_size(&view(&srv).await);
        assert_eq!(act(&srv, json!({ "action": "growRaid", "array": md5, "device": d })).await, "succeeded");
        settled(&srv).await;
        let v = view(&srv).await;
        let array = v["arrays"].as_array().unwrap().iter().find(|x| x["name"] == md5).unwrap().clone();
        assert_eq!(array["raid_disks"].as_u64(), Some(4), "{array}");
        assert!(find(&v["disks"], &dev).unwrap()["size"].as_u64().unwrap() > before * 13 / 10, "the array grew");
        assert_eq!(act(&srv, json!({ "action": "expandFilesystem", "device": dev })).await, "succeeded");
        let after = fs_size(&view(&srv).await);
        assert!(after > before * 13 / 10, "the filesystem took the room: {before} -> {after}");
        assert_eq!(act(&srv, json!({ "action": "unmount", "mountpoint": MOUNT })).await, "succeeded");
        assert_eq!(act(&srv, json!({ "action": "deleteRaid", "array": md5 })).await, "succeeded");
    } else {
        eprintln!("mdadm is not installed: RAID not tried");
    }

    if has("smartctl") {
        let (status, reading) = call(&srv, Method::POST, "/api/v1/storage/health", Some(json!({}))).await;
        assert_eq!(status, 200, "{reading}");
        let disks = reading["disks"].as_array().unwrap();
        assert!(disks.iter().all(|d| d["device"].as_str().is_some_and(|p| !p.contains("loop"))), "loop devices have no SMART: {reading}");
        assert_eq!(view(&srv).await["health"]["at"], reading["at"], "kept for the page");
    } else {
        eprintln!("smartctl is not installed: SMART not read");
    }

    if has("zpool") {
        assert_eq!(act(&srv, json!({ "action": "createPool", "name": "sbme2e", "layout": "mirror", "devices": [b, c] })).await, "succeeded");
        let v = view(&srv).await;
        let pool = v["pools"].as_array().unwrap().iter().find(|p| p["name"] == "sbme2e").expect("the pool").clone();
        assert_eq!(pool["health"], "ONLINE");
        assert_eq!(pool["vdevs"][0]["name"], "mirror-0");
        // A device taken offline: the watch says the pool is unhealthy, then back.
        let before = notices(&state).await.len();
        sh(&format!("zpool offline sbme2e {c}"));
        storage_watch::check(&state).await;
        assert_eq!(notices(&state).await[before..], ["storage.poolUnhealthy"]);
        assert!(hook.got.lock().unwrap().iter().any(|r| r.contains("Pool sbme2e is DEGRADED")), "pushed");
        assert_eq!(act(&srv, json!({ "action": "onlineInPool", "name": "sbme2e", "device": c })).await, "succeeded");
        storage_watch::check(&state).await;
        assert_eq!(notices(&state).await[before..], ["storage.poolUnhealthy", "storage.poolBack"]);
        assert_eq!(act(&srv, json!({ "action": "scrubPool", "name": "sbme2e" })).await, "succeeded");
        // A mirror more: zpool add (two disks of one size: zpool refuses a
        // mirror of different sizes).
        let (d1, d2) = (lab.extra(), lab.extra());
        assert_eq!(act(&srv, json!({ "action": "addToPool", "name": "sbme2e", "layout": "mirror", "devices": [d1, d2] })).await, "succeeded");
        let v = view(&srv).await;
        let pool = v["pools"].as_array().unwrap().iter().find(|p| p["name"] == "sbme2e").unwrap().clone();
        assert!(pool["vdevs"].as_array().unwrap().iter().any(|x| x["name"] == "mirror-1"), "{pool}");

        // A spare added and taken out; a device replaced; a third mirror side.
        let vdevs = |v: &Value| v["pools"].as_array().unwrap().iter().find(|p| p["name"] == "sbme2e").unwrap()["vdevs"].as_array().unwrap().clone();
        let (spare, new, side) = (lab.extra(), lab.extra(), lab.extra());
        assert_eq!(act(&srv, json!({ "action": "addSpare", "name": "sbme2e", "devices": [spare] })).await, "succeeded");
        assert!(vdevs(&view(&srv).await).iter().any(|x| x["name"] == spare && x["section"] == "spares"));
        let (status, body) = call(&srv, Method::POST, "/api/v1/storage/act", Some(json!({ "action": "removeFromPool", "name": "sbme2e", "device": b }))).await;
        assert_eq!((status, body["error"].as_str()), (409, Some("notRemovable")), "a data device stays: {body}");
        assert_eq!(act(&srv, json!({ "action": "removeFromPool", "name": "sbme2e", "device": spare })).await, "succeeded");
        assert!(!vdevs(&view(&srv).await).iter().any(|x| x["name"] == spare));
        assert_eq!(act(&srv, json!({ "action": "replaceInPool", "name": "sbme2e", "old": c, "new": new })).await, "succeeded");
        sh("zpool wait -t resilver sbme2e 2>/dev/null; sleep 1");
        let v = vdevs(&view(&srv).await);
        assert!(v.iter().any(|x| x["name"] == new) && !v.iter().any(|x| x["name"] == c), "{v:?}");
        assert_eq!(act(&srv, json!({ "action": "attachToPool", "name": "sbme2e", "existing": b, "new": side })).await, "succeeded");
        sh("zpool wait -t resilver sbme2e 2>/dev/null");
        let v = vdevs(&view(&srv).await);
        let mirror0 = v.iter().position(|x| x["name"] == "mirror-0").unwrap();
        let sides = v[mirror0 + 1..].iter().take_while(|x| x["depth"] == 1).count();
        assert_eq!(sides, 3, "{v:?}");
        assert_eq!(act(&srv, json!({ "action": "destroyPool", "name": "sbme2e" })).await, "succeeded");
        assert!(!view(&srv).await["pools"].as_array().unwrap().iter().any(|p| p["name"] == "sbme2e"));
    } else {
        eprintln!("zpool is not installed: ZFS not tried");
    }
    drop(lab);
}
