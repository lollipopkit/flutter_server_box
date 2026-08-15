use server_box_monitor::core::config::Config;

#[cfg(test)]
mod test_toml_config {
    use super::*;
    use tokio;

    #[tokio::test]
    async fn test_toml_config_loading() {
        let toml_content = r#"
database_url = "sqlite:test.db"
jwt_secret = "test-secret"

[server]
host = "127.0.0.1"
port = 8080

[monitoring]
interval_seconds = 10

[[monitoring.rules]]
name = "Test CPU Rule"
monitor_type = "cpu"
threshold = ">=50%"
matcher = "cpu"

[[push]]
name = "test_webhook"
push_type = "webhook"
url = "http://localhost:3000/webhook"
method = "POST"

[push.headers]
"Content-Type" = "application/json"

[push.body_template]
message = "Alert: {{message}}"
        "#;

        let config: Config = toml::from_str(&toml_content).expect("Failed to parse TOML");
        
        // Test the parsed config
        let server = config.get_server();
        assert_eq!(server.host, "127.0.0.1");
        assert_eq!(server.port, 8080);
        
        let monitoring = config.get_monitoring();
        assert_eq!(monitoring.interval_seconds, 10);
        assert_eq!(monitoring.rules.len(), 1);
        assert_eq!(monitoring.rules[0].name, "Test CPU Rule");
        
        let push_configs = config.get_push();
        assert_eq!(push_configs.len(), 1);
        assert_eq!(push_configs[0].name, "test_webhook");
        
        println!("✓ TOML configuration loaded and validated successfully!");
    }

    /// The shipped example is the first thing anyone copies, so a key that no
    /// longer deserializes there is a broken first run rather than a typo in
    /// a comment.
    #[test]
    fn example_config_still_parses() {
        let example = include_str!("../config.example.toml");
        let config: Config = toml::from_str(example).expect("config.example.toml must parse");

        // Every switch must ship off: the example is copied verbatim, and
        // neither shell nor file access should be something a user turns on by
        // accident.
        let remote = config.get_remote_access();
        assert!(!remote.tunnel.enabled);
        assert!(!remote.terminal.enabled);
        assert!(!remote.terminal.allow_insecure);
        assert!(!remote.fs.enabled);
    }

    /// Every config written before remote access existed lacks the section
    /// entirely; it must keep loading, with the feature off.
    #[test]
    fn a_config_without_the_remote_access_section_loads_with_it_disabled() {
        let config: Config = toml::from_str("database_url = \"sqlite:test.db\"").unwrap();
        assert!(config.remote_access.is_none());

        let remote = config.get_remote_access().resolve(None);
        assert!(!remote.any_enabled());
    }
}