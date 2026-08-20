use server_box_monitor::core::config::Config;
use std::fs;
use std::sync::OnceLock;

fn cwd_lock() -> &'static tokio::sync::Mutex<()> {
    static LOCK: OnceLock<tokio::sync::Mutex<()>> = OnceLock::new();
    LOCK.get_or_init(|| tokio::sync::Mutex::new(()))
}

// Own test binary (own process) so mutating the process-wide CWD here can't
// race with other test files' `Config::load()` calls, which read whatever
// config.toml/config.json happens to be in the CWD at the time.
#[tokio::test]
async fn config_json_migrates_to_toml() {
    let _guard = cwd_lock().lock().await;
    let dir = std::env::temp_dir().join(format!(
        "sbm_monitor_config_migration_test_{}_{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let original_cwd = std::env::current_dir().unwrap();
    std::env::set_current_dir(&dir).unwrap();

    // Go-format config.json (the legacy format `Config::normalize` converts)
    fs::write(
        dir.join("config.json"),
        r#"{
            "interval": "5s",
            "name": "migrate-test-server",
            "rules": [{"type": "cpu", "threshold": ">=80%", "matcher": "cpu"}]
        }"#,
    )
    .unwrap();
    // A valid, sufficiently long JWT secret so `resolve_jwt_secret`-adjacent
    // paths aren't exercised by this test
    unsafe {
        std::env::set_var("JWT_SECRET", "test-secret-at-least-32-characters-long");
    }

    let config = Config::load().await.expect("load should migrate config.json");

    // In-memory result reflects the migrated config
    assert_eq!(config.get_monitoring().interval_seconds, 5);
    assert_eq!(config.get_monitoring().rules[0].threshold, ">=80%");

    // On-disk: config.toml now exists and config.json was renamed, not deleted
    assert!(dir.join("config.toml").exists(), "migration should write config.toml");
    assert_private(&dir.join("config.toml"));
    assert!(
        dir.join("config.json.migrated").exists(),
        "original config.json should be kept, renamed"
    );
    assert!(!dir.join("config.json").exists(), "config.json should no longer be present under its original name");

    let toml_content = fs::read_to_string(dir.join("config.toml")).unwrap();
    let migrated: Config = toml::from_str(&toml_content).unwrap();
    assert_eq!(migrated.get_monitoring().interval_seconds, 5);

    // A subsequent load now takes the config.toml branch directly
    let reloaded = Config::load().await.expect("reload from migrated config.toml");
    assert_eq!(reloaded.get_monitoring().interval_seconds, 5);

    fs::remove_file(dir.join("config.toml")).unwrap();
    fs::remove_file(dir.join("config.json.migrated")).unwrap();
    Config::load().await.expect("load should create the default config.toml");
    assert_private(&dir.join("config.toml"));

    unsafe {
        std::env::remove_var("JWT_SECRET");
    }
    std::env::set_current_dir(original_cwd).unwrap();
    fs::remove_dir_all(&dir).ok();
}

#[tokio::test]
async fn a_go_config_in_its_historical_home_is_migrated() {
    let _guard = cwd_lock().lock().await;
    let root = std::env::temp_dir().join(format!(
        "sbm_monitor_go_home_migration_test_{}_{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let workdir = root.join("current-install");
    let old_config = root.join("home/.config/server_box/config.json");
    fs::create_dir_all(old_config.parent().unwrap()).unwrap();
    fs::create_dir_all(&workdir).unwrap();
    fs::write(
        &old_config,
        r#"{
            "name": "go-home-server",
            "interval": "9s",
            "pushes": [{
                "type": "server_chan",
                "name": "legacy channel",
                "iface": {"sckey": "SCT123", "desp": "{{msg}}"}
            }]
        }"#,
    )
    .unwrap();

    let original_cwd = std::env::current_dir().unwrap();
    let original_home = std::env::var_os("HOME");
    std::env::set_current_dir(&workdir).unwrap();
    unsafe {
        std::env::set_var("HOME", root.join("home"));
        std::env::set_var("JWT_SECRET", "test-secret-at-least-32-characters-long");
    }

    let config = Config::load().await.unwrap();

    assert_eq!(config.get_server_name(), "go-home-server");
    assert_eq!(config.get_monitoring().interval_seconds, 9);
    assert!(workdir.join("config.toml").exists());
    assert!(!old_config.exists());
    assert!(root.join("home/.config/server_box/config.json.migrated").exists());
    let push = &config.get_push()[0];
    assert_eq!(push.push_type, "serverchan");
    assert_eq!(push.config.get("sc_key").and_then(|v| v.as_str()), Some("SCT123"));

    unsafe {
        std::env::remove_var("JWT_SECRET");
        if let Some(home) = original_home {
            std::env::set_var("HOME", home);
        } else {
            std::env::remove_var("HOME");
        }
    }
    std::env::set_current_dir(original_cwd).unwrap();
    fs::remove_dir_all(root).ok();
}

#[cfg(unix)]
fn assert_private(path: &std::path::Path) {
    use std::os::unix::fs::PermissionsExt;
    assert_eq!(fs::metadata(path).unwrap().permissions().mode() & 0o777, 0o600);
}

#[cfg(not(unix))]
fn assert_private(path: &std::path::Path) {
    assert!(path.is_file());
}
