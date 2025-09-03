use anyhow::Result;
use dotenvy::dotenv;
use server_box_monitor::cli::{build_cli, handle_matches};

#[ntex::main]
async fn main() -> Result<()> {
    // Load .env file
    dotenv().ok();
    
    // Initialize tracing
    tracing_subscriber::fmt::init();
    
    // Parse CLI arguments
    let matches = build_cli().get_matches();
    
    // Handle the CLI command
    handle_matches(matches).await?;
    
    Ok(())
}