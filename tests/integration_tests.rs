use server_box_monitor::{config::Config, auth};
use sqlx::Row;

#[tokio::test]
async fn test_config_load_default() {
    // Test loading default configuration
    let config = Config::default();
    
    assert_eq!(config.get_server().host, "0.0.0.0");
    assert_eq!(config.get_server().port, 3770);
    assert_eq!(config.get_monitoring().interval_seconds, 7);
    assert!(!config.get_monitoring().rules.is_empty());
    assert!(!config.get_push().is_empty());
}

#[tokio::test] 
async fn test_database_init() {
    // Test database initialization with in-memory database
    let db_url = "sqlite::memory:";
    let pool = server_box_monitor::database::init(db_url).await;
    
    assert!(pool.is_ok());
    
    let pool = pool.unwrap();
    
    // Test that tables were created
    let result = sqlx::query("SELECT name FROM sqlite_master WHERE type='table'")
        .fetch_all(&pool)
        .await;
    
    assert!(result.is_ok());
    let tables = result.unwrap();
    
    // Check that our expected tables exist
    let table_names: Vec<String> = tables
        .iter()
        .map(|row| row.get::<String, _>("name"))
        .collect();
    
    assert!(table_names.contains(&"system_metrics".to_string()));
    assert!(table_names.contains(&"alerts".to_string()));
    assert!(table_names.contains(&"users".to_string()));
}

#[tokio::test]
async fn test_jwt_auth() {
    let secret = "test-secret";
    let user_id = "testuser";
    
    // Test token generation
    let token = auth::generate_token(user_id, secret);
    assert!(token.is_ok());
    
    let token = token.unwrap();
    assert!(!token.is_empty());
    
    // Test token verification
    let claims = auth::verify_token(&token, secret);
    assert!(claims.is_ok());
    
    let claims = claims.unwrap();
    assert_eq!(claims.sub, user_id);
    
    // Test invalid token
    let invalid_claims = auth::verify_token("invalid.token", secret);
    assert!(invalid_claims.is_err());
}

#[tokio::test]
async fn test_password_hashing() {
    let password = "test_password_123";
    
    // Test password hashing
    let hash = auth::hash_password(password);
    assert!(hash.is_ok());
    
    let hash = hash.unwrap();
    assert!(!hash.is_empty());
    assert_ne!(hash, password); // Ensure password is actually hashed
    
    // Test password verification
    let verify_result = auth::verify_password(password, &hash);
    assert!(verify_result.is_ok());
    assert!(verify_result.unwrap());
    
    // Test wrong password
    let wrong_verify = auth::verify_password("wrong_password", &hash);
    assert!(wrong_verify.is_ok());
    assert!(!wrong_verify.unwrap());
}