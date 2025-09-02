use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimeSeriesData<T> {
    pub timestamp: DateTime<Utc>,
    pub value: T,
}

#[derive(Debug, Clone)]
pub struct TimeSeries<T> {
    data: VecDeque<TimeSeriesData<T>>,
    max_points: usize,
}

impl<T> TimeSeries<T> 
where
    T: Clone,
{
    pub fn new(max_points: usize) -> Self {
        Self {
            data: VecDeque::with_capacity(max_points),
            max_points,
        }
    }

    pub fn add_point(&mut self, value: T, timestamp: DateTime<Utc>) {
        let point = TimeSeriesData { timestamp, value };
        
        // Remove oldest point if we're at capacity
        if self.data.len() >= self.max_points {
            self.data.pop_front();
        }
        
        self.data.push_back(point);
    }

    pub fn get_data(&self) -> Vec<&TimeSeriesData<T>> {
        self.data.iter().collect()
    }

    pub fn len(&self) -> usize {
        self.data.len()
    }

    pub fn is_empty(&self) -> bool {
        self.data.is_empty()
    }

    pub fn clear(&mut self) {
        self.data.clear();
    }
}

#[derive(Debug, Clone)]
pub struct TimeSequence<T> {
    pub old: Option<T>,
    pub new: Option<T>,
}

impl<T> TimeSequence<T> {
    pub fn new() -> Self {
        Self {
            old: None,
            new: None,
        }
    }

    pub fn update(&mut self, value: T) {
        self.old = self.new.take();
        self.new = Some(value);
    }


    pub fn is_ready(&self) -> bool {
        self.old.is_some() && self.new.is_some()
    }
}

impl<T> Default for TimeSequence<T> {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, Clone)]
pub struct NetworkTimeSeries {
    rx_bytes: TimeSequence<u64>,
    tx_bytes: TimeSequence<u64>,
    last_update: Option<DateTime<Utc>>,
}

impl NetworkTimeSeries {
    pub fn new() -> Self {
        Self {
            rx_bytes: TimeSequence::new(),
            tx_bytes: TimeSequence::new(),
            last_update: None,
        }
    }

    pub fn update(&mut self, rx_bytes: u64, tx_bytes: u64, timestamp: DateTime<Utc>) {
        self.rx_bytes.update(rx_bytes);
        self.tx_bytes.update(tx_bytes);
        self.last_update = Some(timestamp);
    }


    pub fn get_rx_speed(&self, interval_seconds: f64) -> Option<f64> {
        match (self.rx_bytes.old, self.rx_bytes.new) {
            (Some(old), Some(new)) => {
                let diff = new.saturating_sub(old) as f64;
                Some(diff / interval_seconds)
            }
            _ => None,
        }
    }

    pub fn get_tx_speed(&self, interval_seconds: f64) -> Option<f64> {
        match (self.tx_bytes.old, self.tx_bytes.new) {
            (Some(old), Some(new)) => {
                let diff = new.saturating_sub(old) as f64;
                Some(diff / interval_seconds)
            }
            _ => None,
        }
    }

    pub fn get_total_rx(&self) -> Option<u64> {
        self.rx_bytes.new
    }

    pub fn get_total_tx(&self) -> Option<u64> {
        self.tx_bytes.new
    }

    pub fn is_ready(&self) -> bool {
        self.rx_bytes.is_ready() && self.tx_bytes.is_ready()
    }
}

impl Default for NetworkTimeSeries {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, Clone)]
pub struct CpuTimeSeries {
    cores: Vec<TimeSequence<CpuCoreTime>>,
    last_update: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct CpuCoreTime {
    pub used: u64,
    pub total: u64,
}

impl CpuTimeSeries {
    pub fn new(core_count: usize) -> Self {
        Self {
            cores: vec![TimeSequence::new(); core_count],
            last_update: None,
        }
    }

    pub fn update(&mut self, core_times: Vec<CpuCoreTime>, timestamp: DateTime<Utc>) {
        for (i, time) in core_times.into_iter().enumerate() {
            if i < self.cores.len() {
                self.cores[i].update(time);
            }
        }
        self.last_update = Some(timestamp);
    }


    pub fn get_core_usage_percent(&self, core_index: usize) -> Option<f32> {
        if core_index >= self.cores.len() {
            return None;
        }

        let core = &self.cores[core_index];
        match (core.old, core.new) {
            (Some(old), Some(new)) => {
                let used_diff = new.used.saturating_sub(old.used);
                let total_diff = new.total.saturating_sub(old.total);
                
                if total_diff == 0 {
                    return Some(0.0);
                }
                
                Some((used_diff as f32 / total_diff as f32) * 100.0)
            }
            _ => None,
        }
    }

    pub fn get_average_usage_percent(&self) -> Option<f32> {
        if self.cores.is_empty() {
            return None;
        }

        let mut sum = 0.0;
        let mut count = 0;

        for i in 0..self.cores.len() {
            if let Some(usage) = self.get_core_usage_percent(i) {
                sum += usage;
                count += 1;
            }
        }

        if count > 0 {
            Some(sum / count as f32)
        } else {
            None
        }
    }

    pub fn is_ready(&self) -> bool {
        self.cores.iter().all(|core| core.is_ready())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VelocityMetrics {
    pub timestamp: DateTime<Utc>,
    pub network_rx_speed: Option<f64>, // bytes per second
    pub network_tx_speed: Option<f64>, // bytes per second
    pub cpu_usage_percent: Option<f32>,
}

impl VelocityMetrics {
    pub fn new() -> Self {
        Self {
            timestamp: Utc::now(),
            network_rx_speed: None,
            network_tx_speed: None,
            cpu_usage_percent: None,
        }
    }

    pub fn with_network_speed(mut self, rx_speed: Option<f64>, tx_speed: Option<f64>) -> Self {
        self.network_rx_speed = rx_speed;
        self.network_tx_speed = tx_speed;
        self
    }

    pub fn with_cpu_usage(mut self, cpu_usage: Option<f32>) -> Self {
        self.cpu_usage_percent = cpu_usage;
        self
    }
}

impl Default for VelocityMetrics {
    fn default() -> Self {
        Self::new()
    }
}