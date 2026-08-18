//! Size type matching the Go `model/size.go` behavior: base 1024, lowercase suffixes b/k/m/g/t

use crate::utils::error::{MonitorError, Result};
use std::fmt;

const KILO: f64 = 1024.0;
const SUFFIXES: [&str; 5] = ["b", "k", "m", "g", "t"];

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Default)]
pub struct Size(pub u64);

pub fn is_size_suffix(c: char) -> bool {
    SUFFIXES.iter().any(|s| s.starts_with(c))
}

impl fmt::Display for Size {
    /// Go `Size.String()`: `%.1f%s`, e.g. `7.0b`, `1.0m`, `26.0g`
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut temp = self.0 as f64;
        let mut nth = 0;
        while temp >= KILO && nth < SUFFIXES.len() - 1 {
            temp /= KILO;
            nth += 1;
        }
        write!(f, "{:.1}{}", temp, SUFFIXES[nth])
    }
}

impl Size {
    /// Go `ParseToSize()`: case-insensitive, finds the first suffix in b/k/m/g/t
    /// order, strips that suffix character and scales by 1024^n; `"0"` special-cased to 0
    pub fn parse(s: &str) -> Result<Size> {
        let s = s.to_lowercase();
        if s == "0" {
            return Ok(Size(0));
        }
        let Some(nth) = SUFFIXES.iter().position(|suf| s.contains(suf)) else {
            return Err(MonitorError::Monitoring(format!("invalid size: {}", s)));
        };
        let number: f64 = s
            .replace(SUFFIXES[nth], "")
            .parse()
            .map_err(|_| MonitorError::Monitoring(format!("invalid size: {}", s)))?;
        Ok(Size((number * KILO.powi(nth as i32)) as u64))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Ported from Go model/size_test.go TestParseToSize
    #[test]
    fn test_parse_to_size() {
        assert_eq!(Size::parse("1m").unwrap(), Size(1024 * 1024));
        assert_eq!(Size::parse("1M").unwrap(), Size(1024 * 1024));
        assert_eq!(Size::parse("3k").unwrap(), Size(3 * 1024));
        assert_eq!(Size::parse("7b").unwrap(), Size(7));
    }

    #[test]
    fn test_parse_special() {
        assert_eq!(Size::parse("0").unwrap(), Size(0));
        assert_eq!(Size::parse("1.5g").unwrap(), Size((1.5 * 1024.0 * 1024.0 * 1024.0) as u64));
        // Go: no suffix / invalid characters → error
        assert!(Size::parse("100").is_err());
        assert!(Size::parse("abc").is_err());
    }

    #[test]
    fn test_display_go_format() {
        assert_eq!(Size(0).to_string(), "0.0b");
        assert_eq!(Size(7).to_string(), "7.0b");
        assert_eq!(Size(1024).to_string(), "1.0k");
        assert_eq!(Size(1024 * 1024).to_string(), "1.0m");
        assert_eq!(Size(26 * 1024 * 1024 * 1024).to_string(), "26.0g");
        assert_eq!(Size(1536).to_string(), "1.5k");
    }
}
