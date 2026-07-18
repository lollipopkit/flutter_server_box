//! 与 Go 版 `model/threshold.go` 行为一致的阈值解析与比较
//!
//! 格式:`>=80.5%`(百分比)、`<100m`(大小)、`>10m/s`(速度)、`>=32c`(温度)。
//! 与 Go 的两处刻意不一致(Go 端 bug,不复刻):
//! - Go 解析 `=` 开头阈值时 startIdx 未跳过 `=`,导致必然解析失败;此处正确支持单个 `=`
//! - Go 温度规则要求 Size 类型阈值导致永远报错;此处温度阈值可正常比较

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

        // 判断阈值类型(与 Go 相同的判断顺序)
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
            // Go 的零值行为:无操作符 → Less
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
