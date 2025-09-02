use crate::{
    error::Result,
    timeseries::{TimeSeries, NetworkTimeSeries, CpuTimeSeries, CpuCoreTime, VelocityMetrics},
};
use chrono::{DateTime, Utc};
use std::sync::Arc;
use std::collections::HashMap;
use tokio::sync::RwLock;
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VelocityData {
    pub timestamp: DateTime<Utc>,
    pub network_rx_speed: Option<f64>, // bytes per second
    pub network_tx_speed: Option<f64>, // bytes per second
    pub cpu_usage_percent: Option<f32>,
}

#[derive(Debug, Clone)]
pub struct VelocityProcessor {
    network_series: NetworkTimeSeries,
    cpu_series: CpuTimeSeries,
    metrics_history: TimeSeries<VelocityData>,
    db_pool: Arc<SqlitePool>,
}

impl VelocityProcessor {
    fn new(db_pool: Arc<SqlitePool>, cpu_core_count: usize) -> Self {
        Self {
            network_series: NetworkTimeSeries::new(),
            cpu_series: CpuTimeSeries::new(cpu_core_count),
            metrics_history: TimeSeries::new(1000), // Keep last 1000 velocity metrics
            db_pool,
        }
    }

    pub async fn update_network_metrics(
        &mut self,
        rx_bytes: u64,
        tx_bytes: u64,
        timestamp: DateTime<Utc>,
        interval_seconds: f64,
    ) -> Result<()> {
        self.network_series.update(rx_bytes, tx_bytes, timestamp);
        
        let rx_speed = self.network_series.get_rx_speed(interval_seconds);
        let tx_speed = self.network_series.get_tx_speed(interval_seconds);
        
        let velocity_data = VelocityData {
            timestamp,
            network_rx_speed: rx_speed,
            network_tx_speed: tx_speed,
            cpu_usage_percent: self.cpu_series.get_average_usage_percent(),
        };
        
        self.store_velocity_data(&velocity_data).await?;
        self.metrics_history.add_point(velocity_data, timestamp);
        
        Ok(())
    }

    pub async fn update_cpu_metrics(
        &mut self,
        core_times: Vec<CpuCoreTime>,
        timestamp: DateTime<Utc>,
        interval_seconds: f64,
    ) -> Result<()> {
        self.cpu_series.update(core_times, timestamp);
        
        let velocity_data = VelocityData {
            timestamp,
            network_rx_speed: self.network_series.get_rx_speed(interval_seconds),
            network_tx_speed: self.network_series.get_tx_speed(interval_seconds),
            cpu_usage_percent: self.cpu_series.get_average_usage_percent(),
        };
        
        self.store_velocity_data(&velocity_data).await?;
        self.metrics_history.add_point(velocity_data, timestamp);
        
        Ok(())
    }

    pub async fn get_current_velocity(&self, interval_seconds: f64) -> Result<VelocityMetrics> {
        let rx_speed = self.network_series.get_rx_speed(interval_seconds);
        let tx_speed = self.network_series.get_tx_speed(interval_seconds);
        let cpu_usage = self.cpu_series.get_average_usage_percent();
        
        Ok(VelocityMetrics::new()
            .with_network_speed(rx_speed, tx_speed)
            .with_cpu_usage(cpu_usage))
    }

    pub fn get_velocity_history(&self, limit: Option<usize>) -> Vec<&VelocityData> {
        let data = self.metrics_history.get_data();
        let velocity_data: Vec<&VelocityData> = data.iter().map(|ts| &ts.value).collect();
        
        match limit {
            Some(lim) => {
                if velocity_data.len() > lim {
                    velocity_data[velocity_data.len() - lim..].to_vec()
                } else {
                    velocity_data
                }
            }
            None => velocity_data,
        }
    }

    pub fn get_network_totals(&self) -> Option<(u64, u64)> {
        match (self.network_series.get_total_rx(), self.network_series.get_total_tx()) {
            (Some(rx), Some(tx)) => Some((rx, tx)),
            _ => None,
        }
    }

    pub fn is_ready(&self) -> bool {
        self.network_series.is_ready() && self.cpu_series.is_ready()
    }

    async fn store_velocity_data(&self, data: &VelocityData) -> Result<()> {
        sqlx::query!(
            r#"
            INSERT INTO velocity_metrics (
                timestamp, network_rx_speed, network_tx_speed, cpu_usage_percent
            ) VALUES (?, ?, ?, ?)
            "#,
            data.timestamp,
            data.network_rx_speed,
            data.network_tx_speed,
            data.cpu_usage_percent
        )
        .execute(&*self.db_pool)
        .await
        .map_err(crate::error::MonitorError::Database)?;
        
        Ok(())
    }
}

pub struct VelocityManager {
    processors: HashMap<String, Arc<RwLock<VelocityProcessor>>>,
    db_pool: Arc<SqlitePool>,
}

impl VelocityManager {
    pub fn new(db_pool: Arc<SqlitePool>) -> Self {
        Self {
            processors: HashMap::new(),
            db_pool,
        }
    }

    pub async fn get_network_totals(&self, server_name: &str) -> Option<(u64, u64)> {
        if let Some(processor) = self.processors.get(server_name) {
            let processor = processor.read().await;
            processor.get_network_totals()
        } else {
            None
        }
    }

    pub async fn is_ready(&self, server_name: &str) -> bool {
        if let Some(processor) = self.processors.get(server_name) {
            let processor = processor.read().await;
            processor.is_ready()
        } else {
            false
        }
    }


    pub async fn update_server_metrics(
        &mut self,
        server_name: &str,
        rx_bytes: u64,
        tx_bytes: u64,
        core_times: Vec<CpuCoreTime>,
        interval_seconds: f64,
    ) -> Result<()> {
        let processor = if let Some(processor) = self.processors.get(server_name) {
            processor.clone()
        } else {
            let processor = Arc::new(RwLock::new(VelocityProcessor::new(self.db_pool.clone(), core_times.len())));
            self.processors.insert(server_name.to_string(), processor.clone());
            processor
        };
        
        let mut processor_lock = processor.write().await;
        let timestamp = Utc::now();
        
        processor_lock.update_network_metrics(rx_bytes, tx_bytes, timestamp, interval_seconds).await?;
        processor_lock.update_cpu_metrics(core_times, timestamp, interval_seconds).await?;
        
        Ok(())
    }

    pub async fn get_server_velocity(&self, server_name: &str, interval_seconds: f64) -> Result<VelocityMetrics> {
        if let Some(processor) = self.processors.get(server_name) {
            let processor = processor.read().await;
            processor.get_current_velocity(interval_seconds).await
        } else {
            Ok(VelocityMetrics::new())
        }
    }

    pub async fn get_server_velocity_history(
        &self,
        server_name: &str,
        limit: Option<usize>,
    ) -> Result<Vec<VelocityData>> {
        if let Some(processor) = self.processors.get(server_name) {
            let processor = processor.read().await;
            let history = processor.get_velocity_history(limit);
            
            Ok(history.into_iter().cloned().collect())
        } else {
            Ok(Vec::new())
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkSpeedInfo {
    pub rx_speed: Option<f64>,
    pub tx_speed: Option<f64>,
    pub rx_speed_formatted: Option<String>,
    pub tx_speed_formatted: Option<String>,
    pub rx_total: Option<u64>,
    pub tx_total: Option<u64>,
}

impl NetworkSpeedInfo {
    pub fn new(rx_speed: Option<f64>, tx_speed: Option<f64>, rx_total: Option<u64>, tx_total: Option<u64>) -> Self {
        Self {
            rx_speed_formatted: rx_speed.map(format_speed),
            tx_speed_formatted: tx_speed.map(format_speed),
            rx_speed,
            tx_speed,
            rx_total,
            tx_total,
        }
    }
}

fn format_speed(bytes_per_sec: f64) -> String {
    const KB: f64 = 1024.0;
    const MB: f64 = 1024.0 * 1024.0;
    const GB: f64 = 1024.0 * 1024.0 * 1024.0;

    if bytes_per_sec >= GB {
        format!("{:.2} GB/s", bytes_per_sec / GB)
    } else if bytes_per_sec >= MB {
        format!("{:.2} MB/s", bytes_per_sec / MB)
    } else if bytes_per_sec >= KB {
        format!("{:.2} KB/s", bytes_per_sec / KB)
    } else {
        format!("{:.2} B/s", bytes_per_sec)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VelocityAnalysisResponse {
    pub timestamp: DateTime<Utc>,
    pub network: NetworkSpeedInfo,
    pub cpu_usage_percent: Option<f32>,
    pub is_ready: bool,
}

impl VelocityAnalysisResponse {
    pub fn new(
        network_info: NetworkSpeedInfo,
        cpu_usage_percent: Option<f32>,
        is_ready: bool,
    ) -> Self {
        Self {
            timestamp: Utc::now(),
            network: network_info,
            cpu_usage_percent,
            is_ready,
        }
    }
}