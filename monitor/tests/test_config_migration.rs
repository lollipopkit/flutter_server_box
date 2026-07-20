use server_box_monitor::core::config::Config;
use std::fs;

// Own test binary (own process) so mutating the process-wide CWD here can't
// race with other test files' `Config::load()` calls, which read whatever
// config.toml/config.json happens to be in the CWD at the time.
#[tokio::test]
async fn config_json_migrates_to_toml() {
    let dir = std::env::temp_dir().join("sbm_monitor_config_migration_test");
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

    unsafe {
        std::env::remove_var("JWT_SECRET");
    }
    std::env::set_current_dir(original_cwd).unwrap();
    fs::remove_dir_all(&dir).ok();
}
