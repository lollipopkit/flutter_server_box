use anyhow::Result;
use sqlx::{sqlite::SqlitePool, migrate::MigrateDatabase, Sqlite};
use tracing::info;

pub async fn init(database_url: &str) -> Result<SqlitePool> {
    // Create database if it doesn't exist
    if !Sqlite::database_exists(database_url).await? {
        info!("Creating database {}", database_url);
        Sqlite::create_database(database_url).await?;
    }
    
    let pool = SqlitePool::connect(database_url).await?;
    
    // Run migrations
    sqlx::migrate!("./migrations").run(&pool).await?;
    
    info!("Database initialized");
    Ok(pool)
}