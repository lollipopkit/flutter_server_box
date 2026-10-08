//! Building packages for the tests, as fl_lib's `package_test.dart` does.

#![allow(dead_code)]

use std::io::{Cursor, Write};

use serde_json::{Value as Json, json};
use zip::write::SimpleFileOptions;

/// fl_lib's `package()`: a complete schema 1 manifest.
pub fn package(background: &str) -> Json {
    json!({
        "format": 1,
        "schema": {"min": 1, "max": 1},
        "id": "example.amethyst",
        "name": "Amethyst",
        "modes": ["light", "dark"],
        "colors": {"mode": 0, "seed": 4287106639u32, "systemColor": false},
        "icons": {"style": "classic", "images": {}},
        "background": {"type": background, "opacity": 0.18, "blur": 8},
        "shapes": {"card": 13, "tile": 9, "button": 30},
    })
}

/// The same at schema 2, which an SVG icon, an icon color or a splash needs.
pub fn package2() -> Json {
    let mut p = package("gradient");
    p["schema"] = json!({"min": 2, "max": 2});
    p
}

pub const SVG_ICON: &str = r#"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="currentColor"/></svg>"#;

/// A PNG header saying [w] × [h]: all a size check reads.
pub fn png_sized(w: u32, h: u32) -> Vec<u8> {
    let mut ihdr = Vec::new();
    ihdr.extend_from_slice(b"IHDR");
    ihdr.extend_from_slice(&w.to_be_bytes());
    ihdr.extend_from_slice(&h.to_be_bytes());
    ihdr.extend_from_slice(&[8, 6, 0, 0, 0]);
    let mut crc = flate2::Crc::new();
    crc.update(&ihdr);
    let mut out = vec![137, 80, 78, 71, 13, 10, 26, 10];
    out.extend_from_slice(&13u32.to_be_bytes());
    out.extend_from_slice(&ihdr);
    out.extend_from_slice(&crc.sum().to_be_bytes());
    out.extend_from_slice(&[0, 0, 0, 0, b'I', b'E', b'N', b'D', 0xAE, 0x42, 0x60, 0x82]);
    out
}

pub fn png() -> Vec<u8> {
    png_sized(4, 4)
}

pub fn to_toml(value: &Json) -> toml::Value {
    match value {
        Json::Bool(b) => toml::Value::Boolean(*b),
        Json::Number(n) => match n.as_i64() {
            Some(i) => toml::Value::Integer(i),
            None => toml::Value::Float(n.as_f64().unwrap()),
        },
        Json::String(s) => toml::Value::String(s.clone()),
        Json::Array(a) => toml::Value::Array(a.iter().map(to_toml).collect()),
        Json::Object(o) => toml::Value::Table(o.iter().map(|(k, v)| (k.clone(), to_toml(v))).collect()),
        Json::Null => unreachable!("TOML has no null"),
    }
}

/// A ZIP holding [manifest] as TOML and [files].
pub fn bundle(manifest: &Json, files: &[(&str, &[u8])]) -> Vec<u8> {
    let source = toml::to_string(&to_toml(manifest)).unwrap();
    raw_bundle(&source, files)
}

pub fn raw_bundle(manifest: &str, files: &[(&str, &[u8])]) -> Vec<u8> {
    let mut zip = zip::ZipWriter::new(Cursor::new(Vec::new()));
    let options = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Deflated);
    zip.start_file("manifest.toml", options).unwrap();
    zip.write_all(manifest.as_bytes()).unwrap();
    for (name, bytes) in files {
        zip.start_file(*name, options).unwrap();
        zip.write_all(bytes).unwrap();
    }
    zip.finish().unwrap().into_inner()
}
