use thiserror::Error;

#[derive(Error, Debug)]
pub enum MonitorError {
    #[error("Configuration error: {0}")]
    Config(#[from] anyhow::Error),
    
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),
    
    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),
    
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
    
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    
    #[error("Regex error: {0}")]
    Regex(#[from] regex::Error),
    
    #[error("Parse error: {0}")]
    Parse(String),
    
    #[error("Authentication error: {0}")]
    Auth(String),
    
    #[error("Monitoring error: {0}")]
    Monitoring(String),
    
    #[error("Push notification error: {0}")]
    Push(String),
}

impl From<std::num::ParseFloatError> for MonitorError {
    fn from(err: std::num::ParseFloatError) -> Self {
        MonitorError::Parse(err.to_string())
    }
}

impl From<std::num::ParseIntError> for MonitorError {
    fn from(err: std::num::ParseIntError) -> Self {
        MonitorError::Parse(err.to_string())
    }
}

// Web response error implementation for ntex
impl ntex::web::WebResponseError for MonitorError {
    fn status_code(&self) -> ntex::http::StatusCode {
        match *self {
            MonitorError::Auth(_) => ntex::http::StatusCode::UNAUTHORIZED,
            MonitorError::Config(_) => ntex::http::StatusCode::INTERNAL_SERVER_ERROR,
            MonitorError::Parse(_) => ntex::http::StatusCode::BAD_REQUEST,
            _ => ntex::http::StatusCode::INTERNAL_SERVER_ERROR,
        }
    }

    fn error_response(&self, _req: &ntex::web::HttpRequest) -> ntex::web::HttpResponse {
        ntex::web::HttpResponse::build(self.status_code())
            .json(&serde_json::json!({
                "error": self.to_string()
            }))
    }
}

pub type Result<T> = std::result::Result<T, MonitorError>;