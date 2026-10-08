//! An SVG icon or splash logo is checked as a document rather than rendered
//! (fl_lib `_svgAsset` / `_checkSvg`): it must be UTF-8, well formed, rooted
//! at `svg`, and nothing in it may make it a document instead of a drawing —
//! a DTD, a script, a style sheet, foreign content, or a reference to
//! anything outside the file.

use quick_xml::events::{BytesStart, Event};
use quick_xml::Reader;

use crate::error::{Result, fail};

pub fn check(bytes: &[u8]) -> Result<()> {
    let Ok(source) = std::str::from_utf8(bytes) else {
        return fail("SVG must be UTF-8");
    };
    // Before the parse: entities are how a document describes itself instead
    // of drawing, and neither expansion nor an external entity is anything an
    // icon wants.
    let lower = source.to_ascii_lowercase();
    if lower.contains("<!doctype") || lower.contains("<!entity") {
        return fail("Unsupported SVG content");
    }

    let mut reader = Reader::from_str(source);
    reader.config_mut().check_end_names = true;
    let mut depth = 0usize;
    let mut rooted = false;
    loop {
        let event = match reader.read_event() {
            Ok(event) => event,
            Err(_) => return fail("Invalid SVG document"),
        };
        match event {
            Event::Start(e) => {
                element(&e, depth, &mut rooted)?;
                depth += 1;
            }
            Event::Empty(e) => element(&e, depth, &mut rooted)?,
            Event::End(_) => depth = depth.saturating_sub(1),
            // `<?xml-stylesheet href="…"?>` fetches; the XML declaration is
            // `Decl`, a node of its own.
            Event::PI(_) if depth == 0 => return fail("Unsupported SVG content"),
            Event::Text(t) if depth == 0 => {
                if !t.iter().all(u8::is_ascii_whitespace) {
                    return fail("Invalid SVG document");
                }
            }
            Event::CData(_) if depth == 0 => return fail("Invalid SVG document"),
            Event::DocType(_) => return fail("Unsupported SVG content"),
            Event::Eof => break,
            _ => {}
        }
    }
    if depth != 0 || !rooted {
        return fail("Invalid SVG document");
    }
    Ok(())
}

fn element(e: &BytesStart<'_>, depth: usize, rooted: &mut bool) -> Result<()> {
    let name = e.local_name();
    let local = String::from_utf8_lossy(name.as_ref()).into_owned();
    if depth == 0 {
        // One root, and it is the drawing.
        if *rooted {
            return fail("Invalid SVG document");
        }
        *rooted = true;
        if local != "svg" {
            return fail("An SVG must have svg as its root element");
        }
    }
    if matches!(local.to_ascii_lowercase().as_str(), "script" | "style" | "foreignobject") {
        return fail("Unsupported SVG content");
    }
    for attribute in e.attributes() {
        let Ok(attribute) = attribute else {
            return fail("Invalid SVG document");
        };
        let Ok(value) = attribute.unescape_value() else {
            return fail("Invalid SVG document");
        };
        if attribute.key.local_name().as_ref() == b"href" && !value.starts_with('#') {
            return fail("Unsupported SVG content");
        }
        if has_foreign_url(&value) {
            return fail("Unsupported SVG content");
        }
    }
    Ok(())
}

/// Whether a value reaches outside the file through a `url(…)`; one naming
/// something in this same document (`url(#gradient)`) is what a drawing is
/// made of.
fn has_foreign_url(value: &str) -> bool {
    let lower = value.to_ascii_lowercase();
    let mut from = 0;
    while let Some(at) = lower[from..].find("url(") {
        let start = from + at;
        let mut target = value[start + 4..].trim_start();
        if let Some(rest) = target.strip_prefix(['"', '\'']) {
            target = rest;
        }
        if !target.starts_with('#') {
            return true;
        }
        from = start + 4;
    }
    false
}
