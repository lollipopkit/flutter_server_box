//! The Streamable HTTP contract every ServerBox MCP endpoint answers before
//! it reads a body: stateless JSON, so `POST` only, a JSON body, a JSON
//! answer and a protocol version this server speaks. The HTTP framework and
//! the credential are the host's; what a refusal is called is here.

/// A request refused before its body was read: the status, and the
/// `{"error": …}` code the monitor's API answers with.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Refusal {
    pub status: u16,
    pub error: &'static str,
}

/// `GET` (a standalone SSE stream) and `DELETE` (ending a session) are
/// `405` on a stateless JSON server, as every other method is.
pub const METHOD_NOT_ALLOWED: Refusal = Refusal { status: 405, error: "method_not_allowed" };

/// The headers of a `POST`.
///
/// [accept] is every `Accept` value, [content_type] the `Content-Type` and
/// [protocol_version] the `MCP-Protocol-Version`, each as sent.
pub fn check_post(protocol_version: Option<&str>, accept: &[&str], content_type: Option<&str>) -> Result<(), Refusal> {
    if let Some(version) = protocol_version
        && !crate::speaks_version(version.trim())
    {
        return Err(Refusal { status: 400, error: "unsupported_protocol_version" });
    }
    if !accept.iter().any(|a| a.to_ascii_lowercase().contains("application/json")) {
        return Err(Refusal { status: 406, error: "not_acceptable" });
    }
    let json = content_type.is_some_and(|c| {
        c.split(';').next().unwrap_or("").trim().eq_ignore_ascii_case("application/json")
    });
    if !json {
        return Err(Refusal { status: 415, error: "unsupported_media_type" });
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn each_header_is_refused_in_its_own_words() {
        let json = Some("application/json; charset=utf-8");
        let accept = ["application/json, text/event-stream"];
        assert_eq!(check_post(None, &accept, json), Ok(()));
        assert_eq!(check_post(Some("2025-06-18"), &accept, json), Ok(()));
        assert_eq!(check_post(Some("2024-01-01"), &accept, json).unwrap_err().status, 400);
        assert_eq!(check_post(None, &["text/event-stream"], json).unwrap_err().status, 406);
        assert_eq!(check_post(None, &[], json).unwrap_err().status, 406);
        assert_eq!(check_post(None, &accept, Some("text/plain")).unwrap_err().status, 415);
        assert_eq!(check_post(None, &accept, None).unwrap_err().status, 415);
    }
}
