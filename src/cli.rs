use crate::config::Config;
use crate::{database, server};
use clap::{Arg, Command};
use std::sync::Arc;
use tracing::info;

pub fn build_cli() -> Command {
    Command::new("server_box_monitor")
        .about("ServerBox Monitor - a Rust-based server monitoring application")
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
}

pub async fn handle_matches(matches: clap::ArgMatches) -> anyhow::Result<()> {
    match matches.subcommand() {
        Some(("serve", sub_matches)) => {
            handle_serve(sub_matches).await?;
        }
        Some(("config", sub_matches)) => {
            handle_config(sub_matches).await?;
        }
        _ => {
            // Default to serve if no subcommand is provided
            handle_serve(&clap::ArgMatches::default()).await?;
        }
    }
    Ok(())
}

async fn handle_serve(matches: &clap::ArgMatches) -> anyhow::Result<()> {
    tracing::debug!("Matches: {:?}", matches);

    // Load configuration
    let config = Arc::new(Config::load().await?);

    // Initialize database
    let db = database::init(&config.get_database_url()).await?;

    // Create shared state
    let app_state = server::AppState::new(config.clone(), db);

    // Start monitoring task
    let monitoring_handle = tokio::spawn({
        let state = app_state.clone();
        async move {
            if let Err(e) = crate::monitoring::run_monitoring_loop(state).await {
                tracing::error!("Monitoring loop error: {}", e);
            }
        }
    });

    // Run server and wait for shutdown signal concurrently
    tokio::select! {
        result = server::start_server(app_state) => {
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

async fn handle_config(matches: &clap::ArgMatches) -> anyhow::Result<()> {
    match matches.subcommand() {
        Some(("init", _)) => {
            info!("Initializing default configuration...");
            let config = Config::default();
            let content = toml::to_string_pretty(&config)?;
            std::fs::write("config.toml", content)?;
            println!("Default configuration written to config.json");
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
