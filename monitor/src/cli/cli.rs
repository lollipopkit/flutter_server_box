use crate::core::config::Config;
use crate::core::config_file;
use crate::db;
use crate::monitoring;
use crate::db::cleanup;
use clap::{Arg, Command};
use std::sync::Arc;
use tracing::info;

pub fn build_cli() -> Command {
    Command::new("server_box_monitor")
        .about("ServerBox Monitor - a server monitoring application")
        // The crate's, not a second copy of it. `monitor-release.yml` reads
        // Cargo.toml to decide what to tag and publish, so a literal here is a
        // number that stops being the one that shipped the moment it is bumped
        // — and `--version` is where someone looks to find out what they are
        // running.
        .version(env!("CARGO_PKG_VERSION"))
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
            Command::new("password")
                .about("Set the agent's password (signs in to the app and the panel)")
                .arg(
                    Arg::new("password-env")
                        .long("password-env")
                        .value_name("ENV_VAR")
                        .help("Read the password from this environment variable instead of prompting"),
                ),
        )
        .subcommand(
            Command::new("backup")
                .about("Back up the monitor's settings to WebDAV, list and restore backups")
                .subcommand_required(true)
                .subcommand(Command::new("run").about("Back up now, with the settings the panel saved"))
                .subcommand(backup_target(Command::new("list").about("List the backups in the folder")))
                .subcommand(
                    backup_target(Command::new("restore").about("Restore a backup into this monitor (stop it first, or restart it after)"))
                        .arg(Arg::new("name").long("name").value_name("FILE").help("The backup to restore; the newest by default"))
                        .arg(
                            Arg::new("passphrase-env")
                                .long("passphrase-env")
                                .value_name("ENV_VAR")
                                .help("Read the backups' passphrase from this environment variable instead of prompting"),
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

/// Where `backup list|restore` read from: the folder the panel saved unless
/// `--url` names another.
fn backup_target(cmd: Command) -> Command {
    cmd.arg(Arg::new("url").long("url").value_name("URL").help("The WebDAV folder; the saved one by default"))
        .arg(Arg::new("user").long("user").value_name("NAME").default_value("").help("The WebDAV user name, with --url"))
        .arg(
            Arg::new("password-env")
                .long("password-env")
                .value_name("ENV_VAR")
                .help("Read the WebDAV password from this environment variable instead of prompting, with --url"),
        )
        .arg(
            Arg::new("allow-insecure")
                .long("allow-insecure")
                .action(clap::ArgAction::SetTrue)
                .help("Allow plain HTTP to another machine, with --url"),
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
        Some(("password", sub_matches)) => {
            handle_password(sub_matches).await?;
        }
        Some(("backup", sub_matches)) => {
            handle_backup(sub_matches).await?;
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

    let mut config = Config::load().await?;
    // `--addr` has a default value, so only an explicit argument or environment
    // value may override the config file.
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

    let db = db::database::init(&config.get_database_url()).await?;
    crate::monitoring::push::escape_legacy(&db, &mut config).await?;
    let config = Arc::new(config);

    // On first start, a generated password, written once beside the
    // database.
    db::bootstrap::ensure_owner(&db, &config.get_database_url()).await?;

    let app_state = crate::api::server::AppState::new(config.clone(), db);
    app_state.sealer.ready()?;
    app_state.sealer.seal_legacy(&app_state.db).await?;
    // Files kept beside the database: what an older agent kept in it moves
    // out, and what no row names any more (a write cut short) goes.
    crate::core::blobs::move_database_backups(&app_state.db, &app_state.blobs).await?;
    match app_state.blobs.collect(&app_state.db).await {
        Ok(0) => {}
        Ok(n) => tracing::info!("blobs: removed {n} unused files"),
        Err(e) => tracing::warn!("blobs: collecting unused files failed: {e:#}"),
    }
    // Tasks a stopped agent left running are failed; sessions no row names
    // go.
    if let Err(e) = app_state.agent.recover().await {
        tracing::warn!("agent mode: recovering tasks failed: {e:#}");
    }
    // Unconditional, and cheap while nothing is running: a benchmark outlives
    // the request that started it, so the party that carries it to a terminal
    // state has to be resident. See `api::benchmark::start_poller`.
    crate::api::benchmark::start_poller(app_state.clone());
    // Deployed web apps get their proxies back; a deployment a stop cut
    // short is marked failed.
    crate::stacks::resume(&app_state).await;
    // The model servers already on this machine, for Agent mode.
    crate::inference::refresh_providers(&app_state);
    tokio::spawn(crate::container_backups::start(app_state.clone()));
    tokio::spawn(crate::storage_watch::start(app_state.clone()));
    tokio::spawn(crate::monitor_backup::start(app_state.clone()));
    tokio::spawn(crate::api::update::watch(app_state.clone()));
    tokio::spawn(crate::lkc::watch(app_state.clone()));

    let monitoring_handle = tokio::spawn({
        let state = app_state.clone();
        async move {
            if let Err(e) = monitoring::run_monitoring_loop(state).await {
                tracing::error!("Monitoring loop error: {}", e);
            }
        }
    });

    if let Some(retention_config) = config.get_monitoring().data_retention
        && let Err(e) = cleanup::start_cleanup_scheduler(app_state.db.clone(), retention_config).await
    {
        tracing::error!("Failed to start cleanup scheduler: {}", e);
    }

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

    monitoring_handle.abort();

    Ok(())
}

async fn handle_password(matches: &clap::ArgMatches) -> anyhow::Result<()> {
    // The password never travels via CLI arguments (avoiding shell history /
    // ps leaks): environment variable or no-echo interactive input
    let password = match matches.get_one::<String>("password-env") {
        Some(var) => std::env::var(var)
            .map_err(|_| anyhow::anyhow!("Environment variable {var} is not set"))?,
        None => {
            let first = rpassword::prompt_password("New password: ")?;
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
    match db::bootstrap::set_password(&db, &password).await? {
        db::bootstrap::PasswordSet::Created => println!("Password set"),
        db::bootstrap::PasswordSet::Reset => {
            println!("Password updated");
            println!(
                "Tokens and watch pairings issued under the old password no longer work; \
                 restart a running agent to end its open terminals and relays."
            );
        }
    }
    Ok(())
}

/// The backup `restore` takes without `--name`: this monitor's newest, or
/// the newest in a folder only one monitor backs up to. A folder several
/// monitors share needs the name.
fn newest(found: Vec<crate::monitor_backup::Listed>, folder: &url::Url) -> anyhow::Result<String> {
    if let Some(b) = found.iter().find(|b| b.own) {
        return Ok(b.name.clone());
    }
    let monitors: std::collections::BTreeSet<&str> = found.iter().map(|b| b.instance.as_str()).collect();
    match (found.first(), monitors.len()) {
        (None, _) => anyhow::bail!("No backups in {folder}"),
        (Some(b), 1) => Ok(b.name.clone()),
        _ => anyhow::bail!("{folder} holds backups of {} monitors: pick one with --name (backup list)", monitors.len()),
    }
}

/// [env] when named, else asked without echo.
fn secret(env: Option<&String>, prompt: &str) -> anyhow::Result<String> {
    match env {
        Some(var) => std::env::var(var).map_err(|_| anyhow::anyhow!("Environment variable {var} is not set")),
        None => Ok(rpassword::prompt_password(prompt)?),
    }
}

fn refused(r: crate::stacks::Refusal) -> anyhow::Error {
    anyhow::anyhow!("refused: {}", r.error)
}

async fn handle_backup(matches: &clap::ArgMatches) -> anyhow::Result<()> {
    use crate::monitor_backup::{self, webdav};

    let config = Config::load().await?;
    let url = config.get_database_url();
    let db = db::database::init(&url).await?;
    let file = crate::api::server::sqlite_file(&url).ok_or_else(|| anyhow::anyhow!("The database is in memory"))?;
    let blobs = crate::core::blobs::Blobs::beside(&file);
    let sealer = db::sealed::Sealer::beside(&file);
    sealer.ready_existing()?;
    let work = monitor_backup::MonitorBackup::new(Some(&file));

    // The folder named on the command line.
    struct Named {
        folder: url::Url,
        user: String,
        password: Option<String>,
        insecure: bool,
    }
    let named = |m: &clap::ArgMatches| -> anyhow::Result<Option<Named>> {
        let Some(url) = m.get_one::<String>("url") else { return Ok(None) };
        let insecure = m.get_flag("allow-insecure");
        let folder = webdav::folder_url(url, insecure).map_err(|_| anyhow::anyhow!("{url}: not an HTTPS address (or plain HTTP to this machine, or --allow-insecure)"))?;
        let password = secret(m.get_one::<String>("password-env"), "WebDAV password (empty for none): ")?;
        let user = m.get_one::<String>("user").cloned().unwrap_or_default();
        Ok(Some(Named { folder, user, password: (!password.is_empty()).then_some(password), insecure }))
    };
    // The folder named, else the one saved with this monitor's
    // `(instance, recipient)`.
    type Own = Option<(String, Option<String>)>;
    let target = |named: &Option<Named>, stored: Option<monitor_backup::Row>| -> anyhow::Result<(webdav::Dav, Own)> {
        match (named, stored) {
            (Some(n), _) => Ok((webdav::Dav::new(n.folder.clone(), &n.user, n.password.as_deref()), None)),
            (None, Some(row)) => Ok((row.dav(&sealer).map_err(|e| anyhow::anyhow!("{e}"))?, Some((row.instance, row.recipient)))),
            (None, None) => anyhow::bail!("No folder: pass --url, or set one in the panel's Settings"),
        }
    };

    match matches.subcommand() {
        Some(("run", _)) => {
            let host = monitor_backup::Host { db: &db, sealer: &sealer, blobs: &blobs, work: &work, server_name: config.get_server_name() };
            match monitor_backup::back_up(&host, true).await {
                Ok(monitor_backup::Outcome::Made(name, None)) => println!("Uploaded {name}"),
                Ok(monitor_backup::Outcome::Made(name, Some(f))) => println!("Uploaded {name}; removing the oldest failed: {}", f.code),
                Ok(_) => println!("Nothing to back up to: set a folder and a passphrase in the panel's Settings first"),
                Err(f) => anyhow::bail!("Backup failed: {} ({})", f.code, f.detail),
            }
        }
        Some(("list", m)) => {
            let named = named(m)?;
            let (dav, own) = target(&named, monitor_backup::row(&db).await?)?;
            let own = own.as_ref().map(|(i, r)| (i.as_str(), r.as_deref()));
            let found = monitor_backup::list_in(&dav, own).await.map_err(|e| anyhow::anyhow!("{e}"))?;
            if found.is_empty() {
                println!("No backups in {}", dav.folder());
            }
            for b in found {
                let whose = if b.own { "this monitor" } else { "monitor " };
                let instance = if b.own { "" } else { b.instance.as_str() };
                println!("{}\t{}\t{} bytes\t{whose}{instance}", b.name, b.created_at, b.size);
            }
        }
        Some(("restore", m)) => {
            let named = named(m)?;
            let (dav, own) = target(&named, monitor_backup::row(&db).await?)?;
            let own = own.as_ref().map(|(i, r)| (i.as_str(), r.as_deref()));
            let name = match m.get_one::<String>("name") {
                Some(n) => n.clone(),
                None => newest(monitor_backup::list_in(&dav, own).await.map_err(|e| anyhow::anyhow!("{e}"))?, dav.folder())?,
            };
            let passphrase = secret(m.get_one::<String>("passphrase-env"), "Backup passphrase: ")?;
            let fetched = monitor_backup::fetch(&dav, &work, &name, &passphrase).await.map_err(refused)?;
            let restored = monitor_backup::apply(&db, &sealer, &blobs, &tokio::sync::Mutex::new(()), &fetched, false).await.map_err(refused)?;
            let adopted = match &named {
                Some(n) => monitor_backup::adopt(&db, &sealer, &n.folder, &n.user, n.password.as_deref(), n.insecure, &fetched).await?,
                None => false,
            };
            println!("Restored {name}");
            if adopted {
                println!("  backups: to {} from now on, as the monitor that made it", dav.folder());
            } else if named.is_some() {
                println!("  backups: this monitor's own settings kept");
            }
            for (table, rows) in restored.tables.iter().filter(|(_, n)| *n > 0) {
                println!("  {table}: {rows}");
            }
            if restored.config {
                println!("  config.toml: monitoring, push channels, name, allowed origins");
            } else if fetched.unpacked.config.is_some() {
                println!("  config.toml: not restored (see the log); run this in the monitor's directory, beside its config.toml");
            }
            println!("The password is the backup's. Restart a running monitor to apply the settings and end what the old password opened.");
        }
        _ => unreachable!("a subcommand is required"),
    }
    Ok(())
}

async fn handle_config(matches: &clap::ArgMatches) -> anyhow::Result<()> {
    match matches.subcommand() {
        Some(("init", _)) => {
            info!("Initializing default configuration...");
            let config = Config::default();
            config_file::write(&config)?;
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
    let config = Config::load().await?;
    
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
