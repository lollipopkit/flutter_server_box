use server_box_monitor::core::config::Config;

#[cfg(test)]
mod test_file_loading {
    use super::*;

    #[tokio::test]
    async fn test_toml_file_loading() {
        // This test assumes config.toml exists
        let config = Config::load().await.expect("Failed to load config from file");
        
        // Basic validation - these should work with both JSON and TOML configs
        let server = config.get_server();
        assert!(!server.host.is_empty());
        assert!(server.port > 0);
        
        let monitoring = config.get_monitoring();
        assert!(monitoring.interval_seconds > 0);
        
        println!("✓ Config loaded from file successfully!");
        println!("Host: {}, Port: {}", server.host, server.port);
        println!("Monitoring interval: {} seconds", monitoring.interval_seconds);
    }
}
