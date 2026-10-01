// See lib.rs: deep ntex service generics exceed the default query depth
#![recursion_limit = "256"]

use anyhow::Result;
use server_box_monitor::cli::{build_cli, handle_matches};

#[ntex::main]
async fn main() -> Result<()> {
    // Load .env file
    server_box_monitor::core::config::load_dotenv();
    
    // Initialize tracing
    tracing_subscriber::fmt::init();
    
    // Parse CLI arguments
    let matches = build_cli().get_matches();
    
    // Handle the CLI command
    handle_matches(matches).await?;
    
    Ok(())
}
