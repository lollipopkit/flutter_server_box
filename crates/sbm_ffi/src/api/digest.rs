//! Content digests the app names things by.

/// BLAKE3 of [data], as 64 lowercase hex digits.
#[flutter_rust_bridge::frb(sync)]
pub fn blake3_hex(data: Vec<u8>) -> String {
    blake3::hash(&data).to_hex().to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_input_is_the_reference_digest() {
        assert_eq!(
            blake3_hex(Vec::new()),
            "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262"
        );
    }
}
