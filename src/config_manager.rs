use crate::{config::Config, error::Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use tracing::{info, warn};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfigVersion {
    pub version: u32,
    pub timestamp: DateTime<Utc>,
    pub description: Option<String>,
    pub config: Config,
    pub hash: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfigHistory {
    pub current_version: u32,
    pub versions: Vec<ConfigVersion>,
}

pub struct ConfigManager {
    config_dir: PathBuf,
    backup_dir: PathBuf,
    history_file: PathBuf,
    max_versions: usize,
}

impl ConfigManager {
    pub fn new<P: AsRef<Path>>(config_dir: P) -> Self {
        let config_dir = config_dir.as_ref().to_path_buf();
        let backup_dir = config_dir.join("backups");
        let history_file = config_dir.join("history.json");
        
        Self {
            config_dir,
            backup_dir,
            history_file,
            max_versions: 50, // Keep last 50 versions
        }
    }

    pub async fn initialize(&self) -> Result<()> {
        // Create directories if they don't exist
        fs::create_dir_all(&self.config_dir)
            .map_err(|e| crate::error::MonitorError::Io(e))?;
        fs::create_dir_all(&self.backup_dir)
            .map_err(|e| crate::error::MonitorError::Io(e))?;

        // Create history file if it doesn't exist
        if !self.history_file.exists() {
            let initial_history = ConfigHistory {
                current_version: 0,
                versions: Vec::new(),
            };
            self.save_history(&initial_history).await?;
        }

        info!("Config manager initialized at: {:?}", self.config_dir);
        Ok(())
    }

    pub async fn save_config_version(
        &self,
        config: &Config,
        description: Option<String>,
    ) -> Result<u32> {
        let mut history = self.load_history().await?;
        let next_version = history.current_version + 1;
        let timestamp = Utc::now();
        let config_hash = self.calculate_config_hash(config)?;

        let config_version = ConfigVersion {
            version: next_version,
            timestamp,
            description,
            config: config.clone(),
            hash: config_hash.clone(),
        };

        // Save config file with version
        let version_file = self.backup_dir.join(format!("config_v{}.json", next_version));
        let config_json = serde_json::to_string_pretty(&config_version)
            .map_err(|e| crate::error::MonitorError::Config(anyhow::anyhow!(e)))?;
        fs::write(&version_file, config_json)
            .map_err(|e| crate::error::MonitorError::Io(e))?;

        // Update history
        history.current_version = next_version;
        history.versions.push(config_version);

        // Cleanup old versions
        self.cleanup_old_versions(&mut history).await?;

        // Save updated history
        self.save_history(&history).await?;

        info!("Saved config version {} with hash: {}", next_version, config_hash);
        Ok(next_version)
    }

    pub async fn load_config_version(&self, version: u32) -> Result<Config> {
        let version_file = self.backup_dir.join(format!("config_v{}.json", version));
        
        if !version_file.exists() {
            return Err(crate::error::MonitorError::Config(anyhow::anyhow!(
                "Config version {} not found", version
            )));
        }

        let content = fs::read_to_string(&version_file)
            .map_err(|e| crate::error::MonitorError::Io(e))?;
        let config_version: ConfigVersion = serde_json::from_str(&content)
            .map_err(|e| crate::error::MonitorError::Config(anyhow::anyhow!(e)))?;

        Ok(config_version.config)
    }

    pub async fn get_current_version(&self) -> Result<u32> {
        let history = self.load_history().await?;
        Ok(history.current_version)
    }

    pub async fn list_versions(&self, limit: Option<usize>) -> Result<Vec<ConfigVersion>> {
        let history = self.load_history().await?;
        let mut versions = history.versions;
        
        // Sort by version descending
        versions.sort_by(|a, b| b.version.cmp(&a.version));
        
        if let Some(limit) = limit {
            versions.truncate(limit);
        }
        
        Ok(versions)
    }

    pub async fn rollback_to_version(&self, version: u32) -> Result<Config> {
        let config = self.load_config_version(version).await?;
        
        // Save current config as rollback version
        let current_config = Config::load().await?;
        let rollback_description = format!("Rollback from version {} to {}", 
            self.get_current_version().await?, version);
        self.save_config_version(&current_config, Some(rollback_description)).await?;

        // Update current config
        let config_json = serde_json::to_string_pretty(&config)
            .map_err(|e| crate::error::MonitorError::Config(anyhow::anyhow!(e)))?;
        let main_config_file = self.config_dir.join("config.json");
        fs::write(&main_config_file, config_json)
            .map_err(|e| crate::error::MonitorError::Io(e))?;

        info!("Rolled back configuration to version {}", version);
        Ok(config)
    }

    pub async fn diff_versions(&self, version_a: u32, version_b: u32) -> Result<String> {
        let config_a = self.load_config_version(version_a).await?;
        let config_b = self.load_config_version(version_b).await?;

        let json_a = serde_json::to_string_pretty(&config_a)
            .map_err(|e| crate::error::MonitorError::Config(anyhow::anyhow!(e)))?;
        let json_b = serde_json::to_string_pretty(&config_b)
            .map_err(|e| crate::error::MonitorError::Config(anyhow::anyhow!(e)))?;

        // Simple diff - in a real implementation you might use a proper diff library
        let diff = if json_a == json_b {
            "No differences found".to_string()
        } else {
            format!(
                "Version {} differs from version {}\nVersion {}:\n{}\n\nVersion {}:\n{}",
                version_a, version_b, version_a, json_a, version_b, json_b
            )
        };

        Ok(diff)
    }

    pub async fn validate_config(&self, config: &Config) -> Result<Vec<String>> {
        let mut warnings = Vec::new();

        // Validate monitoring rules
        if config.get_monitoring().rules.is_empty() {
            warnings.push("No monitoring rules defined".to_string());
        }

        for (i, rule) in config.get_monitoring().rules.iter().enumerate() {
            if rule.name.is_empty() {
                warnings.push(format!("Rule {} has empty name", i));
            }
            
            if rule.threshold.is_empty() {
                warnings.push(format!("Rule '{}' has empty threshold", rule.name));
            }

            // Validate threshold format
            if let Err(e) = self.validate_threshold_format(&rule.threshold) {
                warnings.push(format!("Rule '{}' has invalid threshold '{}': {}", 
                    rule.name, rule.threshold, e));
            }
        }

        // Validate push configurations
        if config.get_push().is_empty() {
            warnings.push("No push notification configurations defined".to_string());
        }

        for push in &config.get_push() {
            if push.name.is_empty() {
                warnings.push("Push config has empty name".to_string());
            }
            if push.push_type.is_empty() {
                warnings.push(format!("Push config '{}' has empty type", push.name));
            }
        }

        // Validate server settings
        if config.get_server().port == 0 {
            warnings.push("Server port cannot be 0".to_string());
        }

        if config.get_monitoring().interval_seconds < 1 {
            warnings.push("Monitoring interval must be at least 1 second".to_string());
        }

        Ok(warnings)
    }

    pub async fn export_config(&self, version: Option<u32>, output_path: &Path) -> Result<()> {
        let config = match version {
            Some(v) => self.load_config_version(v).await?,
            None => Config::load().await?,
        };

        let config_json = serde_json::to_string_pretty(&config)
            .map_err(|e| crate::error::MonitorError::Config(anyhow::anyhow!(e)))?;
        
        fs::write(output_path, config_json)
            .map_err(|e| crate::error::MonitorError::Io(e))?;

        info!("Exported config to: {:?}", output_path);
        Ok(())
    }

    pub async fn import_config(&self, import_path: &Path, description: Option<String>) -> Result<u32> {
        let content = fs::read_to_string(import_path)
            .map_err(|e| crate::error::MonitorError::Io(e))?;
        
        let config: Config = serde_json::from_str(&content)
            .map_err(|e| crate::error::MonitorError::Config(anyhow::anyhow!(e)))?;

        // Validate imported config
        let warnings = self.validate_config(&config).await?;
        if !warnings.is_empty() {
            warn!("Imported config has warnings: {:?}", warnings);
        }

        // Save as new version
        let import_description = description.or_else(|| 
            Some(format!("Imported from: {}", import_path.display())));
        let version = self.save_config_version(&config, import_description).await?;

        // Update main config file
        let config_json = serde_json::to_string_pretty(&config)
            .map_err(|e| crate::error::MonitorError::Config(anyhow::anyhow!(e)))?;
        let main_config_file = self.config_dir.join("config.json");
        fs::write(&main_config_file, config_json)
            .map_err(|e| crate::error::MonitorError::Io(e))?;

        info!("Imported config from: {:?} as version {}", import_path, version);
        Ok(version)
    }

    async fn load_history(&self) -> Result<ConfigHistory> {
        if !self.history_file.exists() {
            return Ok(ConfigHistory {
                current_version: 0,
                versions: Vec::new(),
            });
        }

        let content = fs::read_to_string(&self.history_file)
            .map_err(|e| crate::error::MonitorError::Io(e))?;
        let history: ConfigHistory = serde_json::from_str(&content)
            .map_err(|e| crate::error::MonitorError::Config(anyhow::anyhow!(e)))?;

        Ok(history)
    }

    async fn save_history(&self, history: &ConfigHistory) -> Result<()> {
        let content = serde_json::to_string_pretty(history)
            .map_err(|e| crate::error::MonitorError::Config(anyhow::anyhow!(e)))?;
        fs::write(&self.history_file, content)
            .map_err(|e| crate::error::MonitorError::Io(e))?;

        Ok(())
    }

    async fn cleanup_old_versions(&self, history: &mut ConfigHistory) -> Result<()> {
        if history.versions.len() <= self.max_versions {
            return Ok(());
        }

        // Sort by version and keep only the latest max_versions
        history.versions.sort_by(|a, b| b.version.cmp(&a.version));
        let versions_to_remove = history.versions.split_off(self.max_versions);

        // Delete old version files
        for version in &versions_to_remove {
            let version_file = self.backup_dir.join(format!("config_v{}.json", version.version));
            if version_file.exists() {
                if let Err(e) = fs::remove_file(&version_file) {
                    warn!("Failed to delete old config version file {:?}: {}", version_file, e);
                }
            }
        }

        info!("Cleaned up {} old config versions", versions_to_remove.len());
        Ok(())
    }

    fn calculate_config_hash(&self, config: &Config) -> Result<String> {
        let config_json = serde_json::to_string(config)
            .map_err(|e| crate::error::MonitorError::Config(anyhow::anyhow!(e)))?;
        
        // Simple hash - in production you might want to use SHA-256
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};
        
        let mut hasher = DefaultHasher::new();
        config_json.hash(&mut hasher);
        let hash = hasher.finish();
        
        Ok(format!("{:x}", hash))
    }

    fn validate_threshold_format(&self, threshold: &str) -> Result<()> {
        let re = regex::Regex::new(r"^(>=|<=|>|<|==|!=)(\d+(?:\.\d+)?)([%KMGTB]*)(/s)?$")
            .map_err(|e| crate::error::MonitorError::Config(anyhow::anyhow!(e)))?;
        
        if !re.is_match(threshold) {
            return Err(crate::error::MonitorError::Config(anyhow::anyhow!(
                "Invalid threshold format: {}", threshold
            )));
        }

        Ok(())
    }
}

// #[cfg(test)]
// mod tests {
//     use super::*;
//     use tempfile::TempDir;

//     #[tokio::test]
//     async fn test_config_manager_initialization() {
//         let temp_dir = TempDir::new().unwrap();
//         let manager = ConfigManager::new(temp_dir.path());
        
//         assert!(manager.initialize().await.is_ok());
//         assert!(manager.backup_dir.exists());
//         assert!(manager.history_file.exists());
//     }

//     #[tokio::test]
//     async fn test_config_versioning() {
//         let temp_dir = TempDir::new().unwrap();
//         let manager = ConfigManager::new(temp_dir.path());
//         manager.initialize().await.unwrap();

//         let config = Config::default();
//         let version = manager.save_config_version(&config, Some("Test version".to_string())).await.unwrap();
        
//         assert_eq!(version, 1);
//         assert_eq!(manager.get_current_version().await.unwrap(), 1);
        
//         let loaded_config = manager.load_config_version(version).await.unwrap();
//         assert_eq!(config.server.port, loaded_config.server.port);
//     }

//     #[tokio::test]
//     async fn test_config_validation() {
//         let temp_dir = TempDir::new().unwrap();
//         let manager = ConfigManager::new(temp_dir.path());
//         manager.initialize().await.unwrap();

//         let mut config = Config::default();
//         config.monitoring.rules.clear(); // Remove rules to trigger warning
        
//         let warnings = manager.validate_config(&config).await.unwrap();
//         assert!(!warnings.is_empty());
//         assert!(warnings.iter().any(|w| w.contains("No monitoring rules")));
//     }
// }