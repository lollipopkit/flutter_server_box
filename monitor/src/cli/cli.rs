use crate::core::config::Config;
use crate::db;
use crate::monitoring::monitoring;
use crate::db::cleanup;
use clap::{Arg, Command};
use std::sync::Arc;
use tracing::info;

pub fn build_cli() -> Command {
    Command::new("server_box_monitor")
        .about("ServerBox Monitor - a server monitoring application")
        .version("0.1.0")
        .subcommand_required(false)
        .arg_required_else_help(false)
        .subcommand(
            Command::new("serve")
                .alias("s")
                .about("Start the monitoring server")
                .arg(
                    Arg::new("addr")
                        .short('a')
                        .long("addr")
                        .value_name("ADDRESS")
                        .help("Listen address")
                        .default_value("0.0.0.0:3770")
                        .env("SBM_ADDR"),
                )
                .arg(
                    Arg::new("cert")
                        .short('c')
                        .long("cert")
                        .value_name("CERT_FILE")
                        .help("TLS certificate file path")
                        .env("SBM_TLS_CERT"),
                )
                .arg(
                    Arg::new("key")
                        .short('k')
                        .long("key")
                        .value_name("KEY_FILE")
                        .help("TLS key file path")
                        .env("SBM_TLS_KEY"),
                ),
        )
        .subcommand(
            Command::new("config")
                .about("Configuration management")
                .subcommand(Command::new("init").about("Initialize default configuration"))
                .subcommand(Command::new("validate").about("Validate configuration file"))
                .subcommand(Command::new("show").about("Show current configuration")),
        )
        .subcommand(
            Command::new("user")
                .about("User management")
                .subcommand(
                    Command::new("set-password")
                        .about("Set or reset a user's password (creates the user if absent)")
                        .arg(
                            Arg::new("username")
                                .value_name("USERNAME")
                                .required(true)
                                .help("Username to set the password for"),
                        )
                        .arg(
                            Arg::new("password-env")
                                .long("password-env")
                                .value_name("ENV_VAR")
                                .help("Read the password from this environment variable instead of prompting"),
                        ),
                ),
        )
        .subcommand(
            Command::new("cleanup")
                .about("Data cleanup operations")
                .subcommand(Command::new("run").about("Run data cleanup manually"))
                .subcommand(Command::new("stats").about("Show database statistics"))
                .subcommand(Command::new("vacuum").about("Run database VACUUM")),
        )
}

pub async fn handle_matches(matches: clap::ArgMatches) -> anyhow::Result<()> {
    match matches.subcommand() {
        Some(("serve", sub_matches)) => {
            handle_serve(sub_matches).await?;
        }
        Some(("config", sub_matches)) => {
            handle_config(sub_matches).await?;
        }
        Some(("cleanup", sub_matches)) => {
            handle_cleanup(sub_matches).await?;
        }
        Some(("user", sub_matches)) => {
            handle_user(sub_matches).await?;
        }
        _ => {
            // Default to serve if no subcommand is provided;
            // build real serve matches so argument definitions and access stay consistent
            let default_matches = build_cli().get_matches_from(["server_box_monitor", "serve"]);
            let serve_matches = default_matches
                .subcommand_matches("serve")
                .expect("serve subcommand exists");
            handle_serve(serve_matches).await?;
        }
    }
    Ok(())
}

async fn handle_serve(matches: &clap::ArgMatches) -> anyhow::Result<()> {
    tracing::debug!("Matches: {:?}", matches);

    // Load configuration and apply CLI overrides
    let mut config = Config::load().await?;
    // --addr has a default_value: only explicit args/env vars override the config file
    let addr = (matches.value_source("addr") != Some(clap::parser::ValueSource::DefaultValue))
        .then(|| matches.get_one::<String>("addr"))
        .flatten();
    let cert = matches.get_one::<String>("cert");
    let key = matches.get_one::<String>("key");
    config.apply_cli_overrides(
        addr.map(String::as_str),
        cert.map(String::as_str),
        key.map(String::as_str),
    )?;
    config.resolve_jwt_secret()?;
    let config = Arc::new(config);

    // Initialize database
    let db = db::database::init(&config.get_database_url()).await?;

    // First start: create an admin with a random password when users is empty (printed once)
    db::bootstrap::ensure_admin_user(&db).await?;

    // Create shared state
    let app_state = crate::api::server::AppState::new(config.clone(), db);

    // Start monitoring task
    let monitoring_handle = tokio::spawn({
        let state = app_state.clone();
        async move {
            if let Err(e) = monitoring::run_monitoring_loop(state).await {
                tracing::error!("Monitoring loop error: {}", e);
            }
        }
    });

    // Start data cleanup scheduler if configured
    if let Some(retention_config) = config.get_monitoring().data_retention
        && let Err(e) = cleanup::start_cleanup_scheduler(app_state.db.clone(), retention_config).await
    {
        tracing::error!("Failed to start cleanup scheduler: {}", e);
    }

    // Run server and wait for shutdown signal concurrently
    tokio::select! {
        result = crate::api::server::start_server(app_state) => {
            if let Err(e) = result {
                tracing::error!("Server error: {}", e);
            }
        }
        _ = tokio::signal::ctrl_c() => {
            info!("Shutdown signal received");
        }
    }

    // Cancel monitoring task
    monitoring_handle.abort();

    Ok(())
}

async fn handle_user(matches: &clap::ArgMatches) -> anyhow::Result<()> {
    match matches.subcommand() {
        Some(("set-password", sub)) => {
            let username = sub
                .get_one::<String>("username")
                .expect("username is required");

            // The password never travels via CLI arguments (avoiding shell history / ps
            // leaks): environment variable or no-echo interactive input
            let password = match sub.get_one::<String>("password-env") {
                Some(var) => std::env::var(var)
                    .map_err(|_| anyhow::anyhow!("Environment variable {var} is not set"))?,
                None => {
                    let first = rpassword::prompt_password(format!("New password for {username}: "))?;
                    let second = rpassword::prompt_password("Confirm password: ")?;
                    if first != second {
                        anyhow::bail!("Passwords do not match");
                    }
                    first
                }
            };
            if password.len() < 8 {
                anyhow::bail!("Password must be at least 8 characters");
            }

            let config = Config::load().await?;
            let db = db::database::init(&config.get_database_url()).await?;
            db::bootstrap::set_password(&db, username, &password).await?;
            println!("Password updated for {username}");
        }
        _ => {
            eprintln!("Please specify a user subcommand. Use --help for more information.");
        }
    }
    Ok(())
}

async fn handle_config(matches: &clap::ArgMatches) -> anyhow::Result<()> {
    match matches.subcommand() {
        Some(("init", _)) => {
            info!("Initializing default configuration...");
            let config = Config::default();
            let content = toml::to_string_pretty(&config)?;
            std::fs::write("config.toml", content)?;
            println!("Default configuration written to config.toml");
        }
        Some(("validate", _)) => {
            info!("Validating configuration...");
            match Config::load().await {
                Ok(_) => println!("Configuration is valid"),
                Err(e) => {
                    eprintln!("Configuration validation failed: {}", e);
                    std::process::exit(1);
                }
            }
        }
        Some(("show", _)) => {
            info!("Loading configuration...");
            let config = Config::load().await?;
            let content = serde_json::to_string_pretty(&config)?;
            println!("{}", content);
        }
        _ => {
            eprintln!("Please specify a config subcommand. Use --help for more information.");
        }
    }
    Ok(())
}

async fn handle_cleanup(matches: &clap::ArgMatches) -> anyhow::Result<()> {
    // Load configuration
    let config = Config::load().await?;
    
    // Initialize database
    let db = db::database::init(&config.get_database_url()).await?;
    
    let retention_config = config.get_monitoring().data_retention
        .ok_or_else(|| anyhow::anyhow!("Data retention configuration not found"))?;
    
    let cleanup_service = db::cleanup::DataCleanupService::new(db, retention_config);
    
    match matches.subcommand() {
        Some(("run", _)) => {
            info!("Running data cleanup manually...");
            cleanup_service.cleanup_expired_data().await?;
            println!("Data cleanup completed successfully");
        }
        Some(("stats", _)) => {
            info!("Fetching database statistics...");
            let stats = cleanup_service.get_data_statistics().await?;
            println!("Database Statistics:");
            println!("  Metrics records: {}", stats.metrics_count);
            println!("  Alerts records: {}", stats.alerts_count);
            
            if let Some(oldest) = stats.oldest_metric {
                println!("  Oldest metric: {}", oldest);
            }
            
            if let Some(oldest) = stats.oldest_alert {
                println!("  Oldest alert: {}", oldest);
            }
        }
        Some(("vacuum", _)) => {
            info!("Running database VACUUM...");
            cleanup_service.vacuum_database().await?;
            println!("Database VACUUM completed successfully");
        }
        _ => {
            eprintln!("Please specify a cleanup subcommand. Use --help for more information.");
        }
    }
    
    Ok(())
}
