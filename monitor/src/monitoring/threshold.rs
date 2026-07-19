//! Threshold parsing and comparison matching the Go `model/threshold.go` behavior
//!
//! Formats: `>=80.5%` (percentage), `<100m` (size), `>10m/s` (speed), `>=32c` (temperature).
//! Two deliberate divergences from Go (Go-side bugs, not replicated):
//! - Go fails to skip `=` in startIdx when parsing `=`-prefixed thresholds, so they always fail; a single `=` is supported correctly here
//! - Go temperature rules demanded Size-typed thresholds and always errored; temperature thresholds compare correctly here

use crate::monitoring::size::Size;
use crate::utils::error::{MonitorError, Result};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CompareType {
    Less,
    LessOrEqual,
    Equal,
    GreaterOrEqual,
    Greater,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ThresholdType {
    Percent,
    Size,
    Speed,
    Temperature,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Threshold {
    pub threshold_type: ThresholdType,
    pub value: f64,
    pub compare_type: CompareType,
}

impl Threshold {
    pub fn parse(s: &str) -> Result<Threshold> {
        let s = s.to_lowercase();
        let chars: Vec<char> = s.chars().collect();
        let len = chars.len();
        if len == 0 {
            return Err(MonitorError::Monitoring("empty threshold".to_string()));
        }

        // Determine the threshold type (same check order as Go)
        let (threshold_type, end_idx) = if s.contains('%') {
            (ThresholdType::Percent, len - 1)
        } else if s.ends_with("/s") {
            (ThresholdType::Speed, len - 2)
        } else if crate::monitoring::size::is_size_suffix(chars[len - 1]) {
            (ThresholdType::Size, len)
        } else if s.ends_with('c') {
            (ThresholdType::Temperature, len - 1)
        } else {
            return Err(MonitorError::Monitoring(format!("invalid threshold: {}", s)));
        };

        let (compare_type, start_idx) = match (chars[0], chars.get(1)) {
            ('<', Some('=')) => (CompareType::LessOrEqual, 2),
            ('<', _) => (CompareType::Less, 1),
            ('>', Some('=')) => (CompareType::GreaterOrEqual, 2),
            ('>', _) => (CompareType::Greater, 1),
            ('=', _) => (CompareType::Equal, 1),
            // Go zero-value behavior: no operator → Less
            _ => (CompareType::Less, 0),
        };

        if start_idx >= end_idx {
            return Err(MonitorError::Monitoring(format!("invalid threshold: {}", s)));
        }
        let value_str: String = chars[start_idx..end_idx].iter().collect();

        let value = match threshold_type {
            ThresholdType::Size | ThresholdType::Speed => Size::parse(&value_str)?.0 as f64,
            _ => value_str
                .parse()
                .map_err(|_| MonitorError::Monitoring(format!("invalid threshold: {}", s)))?,
        };

        Ok(Threshold {
            threshold_type,
            value,
            compare_type,
        })
    }

    /// Go `Threshold.True()`
    pub fn is_true(&self, now: f64) -> bool {
        match self.compare_type {
            CompareType::Less => now < self.value,
            CompareType::LessOrEqual => now <= self.value,
            CompareType::Equal => now == self.value,
            CompareType::GreaterOrEqual => now >= self.value,
            CompareType::Greater => now > self.value,
        }
    }
}
