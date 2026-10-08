//! The panel's built assets (`frontend/dist/assets`): every name carries a
//! content hash, so each is cached for good, and a script or style goes out as
//! the copy `scripts/compress.mjs` compressed at build time (`.br`, else
//! `.gz`) when the browser takes one. The rest of `dist` (`index.html`) is
//! `ntex_files`'s.
//!
//! `/desk-app/{name}`: the desk's design system (`dist/desk-app`: `desk.css`
//! and its fonts), which an installed app's frame loads to be drawn like the
//! desk (`lkui`) without carrying any of it. One URL for
//! every app and launch, so the browser keeps one copy; open to any origin,
//! since the frame's is opaque and fonts load with CORS.

use ntex::http::header;
use ntex::web::{self, HttpRequest, HttpResponse};
use std::path::Path;

const DIR: &str = "frontend/dist/assets";
const DESK_APP_DIR: &str = "frontend/dist/desk-app";

/// Hashed names change with their content.
const CACHE: &str = "public, max-age=31536000, immutable";

#[web::get("/assets/{name}")]
pub async fn asset(req: HttpRequest, name: web::types::Path<String>) -> HttpResponse {
    match read(Path::new(DIR), &name, offered(&req)).await {
        Some(file) => {
            let mut res = HttpResponse::Ok();
            res.content_type(file.content_type)
                .header(header::VARY, "accept-encoding")
                .header(header::CACHE_CONTROL, CACHE);
            if let Some(coding) = file.coding {
                res.header(header::CONTENT_ENCODING, coding);
            }
            res.body(file.bytes)
        }
        None => HttpResponse::NotFound().finish(),
    }
}

#[web::get("/desk-app/{name}")]
pub async fn desk_app(req: HttpRequest, name: web::types::Path<String>) -> HttpResponse {
    let Some(file) = read(Path::new(DESK_APP_DIR), &name, offered(&req)).await else {
        return HttpResponse::NotFound().finish();
    };
    let mut res = HttpResponse::Ok();
    res.content_type(file.content_type)
        .header(header::VARY, "accept-encoding")
        .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
        .header("cross-origin-resource-policy", "cross-origin")
        .header(header::X_CONTENT_TYPE_OPTIONS, "nosniff")
        // `desk.css` keeps its name across releases; its fonts are hashed.
        .header(header::CACHE_CONTROL, if name.as_str() == "desk.css" { "public, no-cache" } else { CACHE });
    if let Some(coding) = file.coding {
        res.header(header::CONTENT_ENCODING, coding);
    }
    res.body(file.bytes)
}

/// A built file as it goes out.
pub struct Built {
    pub bytes: Vec<u8>,
    pub content_type: &'static str,
    /// `br` or `gzip` when [bytes] is the precompressed copy.
    pub coding: Option<&'static str>,
}

/// The request's `Accept-Encoding`.
pub fn offered(req: &HttpRequest) -> &str {
    req.headers().get(header::ACCEPT_ENCODING).and_then(|v| v.to_str().ok()).unwrap_or("")
}

/// [name] in [dir] (a built output directory), as the precompressed copy
/// [offered] takes when there is one; None for a name that is not a plain
/// file name of a type the build emits, or that is not there.
pub async fn read(dir: &Path, name: &str, offered: &str) -> Option<Built> {
    // One plain file name: no separator, no dot-leading name, so nothing
    // outside the directory is ever named.
    if !is_asset_name(name) {
        return None;
    }
    let content_type = content_type(name)?;
    for (coding, suffix) in [("br", "br"), ("gzip", "gz")] {
        if !accepts(offered, coding) {
            continue;
        }
        if let Ok(bytes) = tokio::fs::read(dir.join(format!("{name}.{suffix}"))).await {
            return Some(Built { bytes, content_type, coding: Some(coding) });
        }
    }
    let bytes = tokio::fs::read(dir.join(name)).await.ok()?;
    Some(Built { bytes, content_type, coding: None })
}

/// A name vite gives a built file: letters, digits, `.`, `_`, `-`, not
/// starting with a dot.
fn is_asset_name(name: &str) -> bool {
    !name.is_empty()
        && name.len() <= 255
        && !name.starts_with('.')
        && name.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-'))
}

/// What the panel's build emits; anything else is not served from here.
fn content_type(name: &str) -> Option<&'static str> {
    let ext = name.rsplit_once('.')?.1;
    Some(match ext {
        "js" | "mjs" => "text/javascript; charset=utf-8",
        "css" => "text/css; charset=utf-8",
        "json" | "map" => "application/json",
        "svg" => "image/svg+xml",
        "html" => "text/html; charset=utf-8",
        "txt" => "text/plain; charset=utf-8",
        "wasm" => "application/wasm",
        "woff2" => "font/woff2",
        "woff" => "font/woff",
        "ttf" => "font/ttf",
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "webp" => "image/webp",
        "gif" => "image/gif",
        "ico" => "image/x-icon",
        "mp3" => "audio/mpeg",
        "wav" => "audio/wav",
        _ => return None,
    })
}

/// Whether `Accept-Encoding` [offered] takes [coding] (`q=0` refuses it; `*`
/// takes any).
fn accepts(offered: &str, coding: &str) -> bool {
    offered.split(',').any(|item| {
        let mut parts = item.split(';');
        let token = parts.next().unwrap_or("").trim();
        let refused = parts.any(|p| {
            p.trim()
                .strip_prefix("q=")
                .and_then(|q| q.trim().parse::<f32>().ok())
                .is_some_and(|q| q <= 0.0)
        });
        !refused && (token.eq_ignore_ascii_case(coding) || token == "*")
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names_stay_in_the_directory() {
        assert!(is_asset_name("index-BqPoV99G.js"));
        assert!(is_asset_name("zh-CN-kjqtQ9TD.js"));
        assert!(!is_asset_name(""));
        assert!(!is_asset_name(".."));
        assert!(!is_asset_name(".env"));
        assert!(!is_asset_name("../index.html"));
        assert!(!is_asset_name("a/b.js"));
        assert!(!is_asset_name("a\\b.js"));
        assert!(!is_asset_name("a%2fb.js"));
    }

    #[test]
    fn only_what_the_build_emits_has_a_type() {
        assert_eq!(content_type("a.js"), Some("text/javascript; charset=utf-8"));
        assert_eq!(content_type("a.woff2"), Some("font/woff2"));
        assert_eq!(content_type("a.js.br"), None);
        assert_eq!(content_type("noext"), None);
    }

    #[test]
    fn reads_accept_encoding() {
        assert!(accepts("gzip, deflate, br, zstd", "br"));
        assert!(accepts("gzip, deflate", "gzip"));
        assert!(!accepts("gzip, deflate", "br"));
        assert!(!accepts("br;q=0, gzip", "br"));
        assert!(accepts("br;q=0.5", "br"));
        assert!(accepts("*", "gzip"));
        assert!(!accepts("", "gzip"));
        assert!(accepts("GZIP", "gzip"));
    }
}
