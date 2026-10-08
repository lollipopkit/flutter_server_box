//! fl_lib's `test/theme/package_test.dart`, case for case, against this
//! port: what the app installs this installs, and what it refuses this
//! refuses. Cases about the app's own storage (presets, a folder import,
//! replacing an earlier installation) are the agent's and tested there.

mod common;

use std::io::{Cursor, Write};

use common::*;
use sbm_theme::package::ColorSpec;
use sbm_theme::{Package, install};
use serde_json::{Value as Json, json};

fn ok(bytes: &[u8]) -> Package {
    install(bytes).unwrap_or_else(|e| panic!("refused: {e}"))
}

fn refused(bytes: &[u8], why: &str) {
    assert!(install(bytes).is_err(), "installed: {why}");
}

fn set_icon(data: &mut Json, key: &str, path: &str) {
    data["icons"]["images"][key] = json!(path);
}

#[test]
fn installs_a_valid_theme() {
    let bytes = bundle(&package("gradient"), &[]);
    let p = ok(&bytes);
    assert_eq!(p.name, "Amethyst");
    assert_eq!(p.id, "example.amethyst");
    assert_eq!(p.themes.len(), 1);
    let t = &p.themes[0];
    assert_eq!(t.background.blur, 8.0);
    assert!(t.palette_light.is_empty());
    assert!(t.files.background.is_none());
    // The installation id is the digest of the bytes, not the declared id.
    assert_eq!(p.installation_id.len(), 64);
    assert_ne!(p.installation_id, p.id);
    assert_eq!(ok(&bytes).installation_id, p.installation_id);
}

#[test]
fn a_manifest_needs_only_identity_modes_and_schema_and_overrides_keep_defaults() {
    let mut minimal = json!({
        "id": "example.minimal",
        "name": "Minimal",
        "modes": ["light", "dark"],
        "schema": {"min": 1, "max": 1},
    });
    let t = ok(&bundle(&minimal, &[])).themes.remove(0);
    assert_eq!(t.mode, 0);
    assert_eq!(t.seed, 0xff88_0e4f);
    assert!(!t.system_color);
    assert_eq!(t.icons.style, "classic");
    assert!(t.icons.images.is_empty());
    assert_eq!(t.background.style, "none");
    assert_eq!((t.background.opacity, t.background.blur), (0.18, 0.0));
    assert_eq!((t.shapes.card, t.shapes.tile, t.shapes.button), (12.0, 8.0, 10.0));
    assert!(t.palette_light.is_empty() && t.palette_dark.is_empty());

    minimal["shapes"] = json!({"card": 0});
    minimal["background"] = json!({"opacity": 0});
    let t = ok(&bundle(&minimal, &[])).themes.remove(0);
    assert_eq!((t.shapes.card, t.shapes.tile, t.shapes.button), (0.0, 8.0, 10.0));
    assert_eq!(t.background.opacity, 0.0);
    for invalid in [json!("bad"), json!({"card": "12"}), json!({"tile": -1}), json!({"button": 41})] {
        minimal["shapes"] = invalid.clone();
        refused(&bundle(&minimal, &[]), &invalid.to_string());
    }
}

#[test]
fn refuses_malformed_toml_and_duplicate_keys() {
    for source in ["id = [", "id = \"one\"\nid = \"two\"", "{\"id\":\"json\"}"] {
        refused(&raw_bundle(source, &[]), source);
    }
}

#[test]
fn declared_modes_survive() {
    for modes in [vec!["light"], vec!["dark"], vec!["light", "dark"]] {
        let mut m = package("gradient");
        m["modes"] = json!(modes);
        assert_eq!(ok(&bundle(&m, &[])).themes[0].modes, modes);
    }
}

#[test]
fn refuses_missing_empty_duplicate_and_unknown_modes() {
    for modes in [
        None,
        Some(json!([])),
        Some(json!(["light", "light"])),
        Some(json!(["system"])),
        Some(json!(["amoled"])),
        Some(json!(["dark", 2])),
        Some(json!("dark")),
    ] {
        let mut m = package("gradient");
        match &modes {
            None => {
                m.as_object_mut().unwrap().remove("modes");
            }
            Some(v) => m["modes"] = v.clone(),
        }
        refused(&bundle(&m, &[]), &format!("{modes:?}"));
    }
    for mode in [3, 4] {
        let mut m = package("gradient");
        m["colors"] = json!({"mode": mode});
        refused(&bundle(&m, &[]), "mode");
    }
}

#[test]
fn requires_a_compatible_schema_range() {
    let mut compatible = package("gradient");
    compatible["schema"] = json!({"min": 1, "max": 2});
    let p = ok(&bundle(&compatible, &[]));
    assert_eq!((p.schema_min, p.schema_max), (1, 2));
    for schema in [
        None,
        Some(json!({"min": 4, "max": 4})),
        Some(json!({"min": 2, "max": 1})),
        Some(json!({"min": 0, "max": 1})),
        Some(json!({"min": 1})),
    ] {
        let mut m = package("gradient");
        match &schema {
            None => {
                m.as_object_mut().unwrap().remove("schema");
            }
            Some(v) => m["schema"] = v.clone(),
        }
        refused(&bundle(&m, &[]), &format!("{schema:?}"));
    }
}

#[test]
fn installs_checked_image_assets() {
    let png = png();
    let mut data = package("image");
    data["background"]["image"] = json!("background.png");
    set_icon(&mut data, "tab.server", "icons/tab_server.png");
    let t = ok(&bundle(&data, &[("background.png", &png), ("icons/tab_server.png", &png)])).themes.remove(0);
    assert_eq!(t.files.background.as_deref(), Some(png.as_slice()));
    assert_eq!(t.files.icons["tab_server.png"], png);
    assert_eq!(t.icons.images, ["tab.server"]);
}

#[test]
fn refuses_launcher_icons_and_malformed_icon_keys() {
    let mut with_launcher = package("gradient");
    with_launcher["appIcon"] = json!("data");
    refused(&bundle(&with_launcher, &[]), "appIcon");
    for key in ["../outside", "tab/server", "tab", "Tab.server", "tab..server", "tab.server.", ".tab"] {
        let mut m = package("gradient");
        set_icon(&mut m, key, "data");
        refused(&bundle(&m, &[]), key);
    }
}

#[test]
fn keeps_icons_made_for_another_app() {
    let png = png();
    let mut data = package("gradient");
    set_icon(&mut data, "tab.chat", "icons/tab_chat.png");
    let t = ok(&bundle(&data, &[("icons/tab_chat.png", &png)])).themes.remove(0);
    assert_eq!(t.icons.images, ["tab.chat"]);
}

#[test]
fn refuses_plain_json_and_unsafe_zip_entries() {
    refused(package("gradient").to_string().as_bytes(), "json");
    for path in ["../outside.png", "icons/../outside.png"] {
        refused(&bundle(&package("gradient"), &[(path, &[1])]), path);
    }
    // A symlink entry.
    let manifest = toml::to_string(&to_toml(&package("gradient"))).unwrap();
    let mut zip = zip::ZipWriter::new(Cursor::new(Vec::new()));
    zip.start_file("manifest.toml", zip::write::SimpleFileOptions::default()).unwrap();
    zip.write_all(manifest.as_bytes()).unwrap();
    zip.add_symlink("icons/tab_server.png", "../outside", zip::write::SimpleFileOptions::default()).unwrap();
    refused(&zip.finish().unwrap().into_inner(), "symlink");
}

#[test]
fn refuses_an_asset_larger_than_its_extracted_limit() {
    let big = vec![0u8; 256 * 1024 + 1];
    refused(&bundle(&package("gradient"), &[("icons/tab_server.png", &big)]), "oversized");
}

#[test]
fn validates_palette_roles_and_keeps_their_colors() {
    let mut data = package("gradient");
    data["colors"]["palette"] = json!({"light": {"primary": 0xff12_3456u32}, "dark": {"surface": 0xff10_1010u32}});
    let t = ok(&bundle(&data, &[])).themes.remove(0);
    assert_eq!(t.palette_light["primary"], 0xff12_3456);
    assert_eq!(t.palette_dark["surface"], 0xff10_1010);
    assert_eq!(t.scheme_light["primary"], 0xff12_3456);
    assert_eq!(t.scheme_dark["surface"], 0xff10_1010);
    data["colors"]["palette"]["light"] = json!({"unknownRole": 0xff12_3456u32});
    refused(&bundle(&data, &[]), "unknown role");
}

#[test]
fn installs_svg_and_png_icons_together() {
    let png = png();
    let mut data = package2();
    set_icon(&mut data, "tab.server", "icons/tab_server.svg");
    set_icon(&mut data, "nav.settings", "icons/nav_settings.png");
    let t = ok(&bundle(
        &data,
        &[("icons/tab_server.svg", SVG_ICON.as_bytes()), ("icons/nav_settings.png", &png)],
    ))
    .themes
    .remove(0);
    assert_eq!(t.files.icons["tab_server.svg"], SVG_ICON.as_bytes());
    assert_eq!(t.files.icons["nav_settings.png"], png);
}

#[test]
fn an_svg_is_refused_as_a_png_and_a_png_as_an_svg() {
    let png = png();
    for (name, bytes) in [("icons/tab_server.png", SVG_ICON.as_bytes()), ("icons/tab_server.svg", png.as_slice())] {
        let mut data = package2();
        set_icon(&mut data, "tab.server", name);
        refused(&bundle(&data, &[(name, bytes)]), name);
    }
}

#[test]
fn refuses_svg_documents_that_are_not_drawings() {
    let body = r#"<circle cx="12" cy="12" r="10" fill="currentColor"/>"#;
    for source in [
        format!(r#"<!DOCTYPE svg SYSTEM "http://example.org/svg.dtd"><svg>{body}</svg>"#),
        format!(r#"<!DOCTYPE svg [<!ENTITY x "y">]><svg>{body}</svg>"#),
        r#"<svg xmlns:xlink="http://www.w3.org/1999/xlink"><image href="http://example.org/a.png"/></svg>"#.into(),
        "<svg><image href='http://example.org/a.png'/></svg>".into(),
        "<svg><style>@import url(http://example.org/a.css);</style></svg>".into(),
        r#"<svg><style>@import "http://example.org/a.css";</style></svg>"#.into(),
        "<svg><style>rect{fill:currentColor}</style><rect/></svg>".into(),
        "<svg><script>alert(1)</script></svg>".into(),
        "<svg><foreignObject><body/></foreignObject></svg>".into(),
        r#"<svg><image href = "http://example.org/a.png"/></svg>"#.into(),
        r#"<svg><image href="//example.org/a.png"/></svg>"#.into(),
        r#"<svg><image href="data:image/png;base64,AAAA"/></svg>"#.into(),
        r#"<svg><rect fill="url( http://example.org/a.svg#p )"/></svg>"#.into(),
        r#"<svg><rect fill='url("http://example.org/a.svg#p")'/></svg>"#.into(),
        format!(r#"<?xml-stylesheet href="http://example.org/a.css"?><svg>{body}</svg>"#),
        "<svg".into(),
        "<html><body>not a drawing</body></html>".into(),
    ] {
        let mut data = package2();
        set_icon(&mut data, "tab.server", "icons/tab_server.svg");
        refused(&bundle(&data, &[("icons/tab_server.svg", source.as_bytes())]), &source);
    }
}

#[test]
fn an_svg_may_reference_what_is_inside_itself() {
    let source = concat!(
        r#"<?xml version="1.0" encoding="UTF-8"?>"#,
        r#"<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 24 24">"#,
        r#"<defs><linearGradient id="g"><stop offset="0" stop-color="currentColor"/></linearGradient>"#,
        r#"<rect id="r" width="8" height="8"/></defs>"#,
        r##"<use xlink:href="#r" fill="url(#g)" style="opacity:0.5"/>"##,
        "</svg>"
    );
    let mut data = package2();
    set_icon(&mut data, "tab.server", "icons/tab_server.svg");
    ok(&bundle(&data, &[("icons/tab_server.svg", source.as_bytes())]));
}

#[test]
fn an_oversized_svg_is_refused() {
    let mut big = b"<svg>".to_vec();
    big.extend(vec![0u8; 256 * 1024]);
    let mut data = package2();
    set_icon(&mut data, "tab.server", "icons/tab_server.svg");
    refused(&bundle(&data, &[("icons/tab_server.svg", &big)]), "oversized svg");
}

#[test]
fn icon_colors_are_a_role_or_an_argb_integer() {
    let png = png();
    let mut data = package2();
    set_icon(&mut data, "tab.server", "icons/tab_server.svg");
    set_icon(&mut data, "nav.settings", "icons/nav_settings.png");
    data["icons"]["colors"] = json!({"tab.server": "primary", "nav.settings": 0xff12_3456u32});
    let t = ok(&bundle(
        &data,
        &[("icons/tab_server.svg", SVG_ICON.as_bytes()), ("icons/nav_settings.png", &png)],
    ))
    .themes
    .remove(0);
    assert_eq!(t.icons.colors["tab.server"], ColorSpec::Role("primary".into()));
    assert_eq!(t.icons.colors["nav.settings"], ColorSpec::Argb(0xff12_3456));
}

#[test]
fn refuses_an_icon_color_without_its_icon() {
    let mut data = package2();
    data["icons"]["colors"] = json!({"tab.server": "primary"});
    refused(&bundle(&data, &[]), "orphan color");
    data["icons"]["colors"]["tab.server"] = json!("nosuchrole");
    refused(&bundle(&data, &[("icons/tab_server.svg", SVG_ICON.as_bytes())]), "bad role");
}

#[test]
fn refuses_a_schema_2_feature_declared_readable_by_schema_1() {
    let png = png();
    let icon: &[(&str, &[u8])] = &[("icons/tab_server.svg", SVG_ICON.as_bytes())];
    let attempt = |edit: &dyn Fn(&mut Json), files: &[(&str, &[u8])], schema: Json| {
        let mut data = package("gradient");
        data["schema"] = schema;
        edit(&mut data);
        refused(&bundle(&data, files), &data.to_string());
    };
    let one = json!({"min": 1, "max": 1});
    attempt(&|d| set_icon(d, "tab.server", "icons/tab_server.svg"), icon, one.clone());
    attempt(
        &|d| {
            set_icon(d, "tab.server", "icons/tab_server.svg");
            d["icons"]["colors"] = json!({"tab.server": "primary"});
        },
        icon,
        one.clone(),
    );
    attempt(&|d| d["splash"] = json!({"logo": "splash_logo.png"}), &[("splash_logo.png", &png)], one);
    attempt(&|d| set_icon(d, "tab.server", "icons/tab_server.svg"), icon, json!({"min": 1, "max": 2}));
}

#[test]
fn refuses_a_schema_3_component_or_layout_declared_below_3() {
    let edits: [fn(&mut Json); 3] = [
        |d| d["components"] = json!({"search": {"height": 30}}),
        |d| d["components"] = json!({"button": {"minHeight": 40}}),
        |d| d["layout"] = json!({"density": "compact"}),
    ];
    for edit in edits {
        for schema in [json!({"min": 2, "max": 3}), json!({"min": 1, "max": 1})] {
            let mut data = package("gradient");
            data["schema"] = schema;
            edit(&mut data);
            refused(&bundle(&data, &[]), &data.to_string());
        }
    }
    // Schema 2's own components stay readable by 1.
    let mut old = package("gradient");
    old["components"] = json!({"button": {"radius": 4}});
    ok(&bundle(&old, &[]));
}

#[test]
fn schema_3_components_and_layout_are_kept() {
    let mut data = package("gradient");
    data["schema"] = json!({"min": 3, "max": 3});
    data["components"] = json!({
        "search": {"height": 30, "backgroundColor": "surfaceContainer"},
        "dark": {"textButton": {"hovered": {"minHeight": 30}}},
    });
    data["layout"] = json!({"density": "comfortable"});
    let t = ok(&bundle(&data, &[])).themes.remove(0);
    assert_eq!(t.density.as_deref(), Some("comfortable"));
    assert_eq!(Json::Object(t.components), data["components"]);
}

#[test]
fn a_background_tile_is_schema_3_needs_an_image_and_is_kept() {
    let png = png();
    let image: &[(&str, &[u8])] = &[("background.png", &png)];
    let tiled = |tile: Option<Json>, min: u32| {
        let mut data = package("gradient");
        data["schema"] = json!({"min": min, "max": 3});
        data["background"] = json!({"type": "image", "image": "background.png", "opacity": 0.2, "blur": 0});
        if let Some(tile) = tile {
            data["background"]["tile"] = tile;
        }
        data
    };
    let mut gradient_tile = package("gradient");
    gradient_tile["schema"] = json!({"min": 3, "max": 3});
    gradient_tile["background"] = json!({"type": "gradient", "tile": 96});
    let mut unknown = package("gradient");
    unknown["background"] = json!({"type": "gradient", "repeat": true});
    for (data, files) in [
        (tiled(Some(json!(96)), 2), image),
        (tiled(Some(json!(8)), 3), image),
        (tiled(Some(json!(2048)), 3), image),
        (tiled(Some(json!("96")), 3), image),
        (gradient_tile, &[][..]),
        (unknown, &[][..]),
    ] {
        refused(&bundle(&data, files), &data.to_string());
    }
    assert_eq!(ok(&bundle(&tiled(Some(json!(96)), 3), image)).themes[0].background.tile, 96.0);
    let mut once = tiled(None, 1);
    once["schema"] = json!({"min": 1, "max": 3});
    assert_eq!(ok(&bundle(&once, image)).themes[0].background.tile, 0.0);
}

#[test]
fn variants_install_as_one_package() {
    let png = png();
    let pride = |variants: Json, min: u32| {
        let mut data = package("none");
        data["schema"] = json!({"min": min, "max": 3});
        data["name"] = json!("Pride");
        data["variants"] = variants;
        data
    };
    let good = json!({
        "trans": {
            "name": "Trans",
            "colors": {"palette": {"light": {"primary": 0xFF5B_CEFAu32}}},
            "background": {"type": "image", "image": "background.png", "tile": 120},
        },
        "rainbow": {"name": "Rainbow", "shapes": {"card": 4}},
    });
    let files: &[(&str, &[u8])] = &[("variants/trans/background.png", &png)];
    for (data, assets) in [
        (pride(good.clone(), 2), files),
        (pride(json!({}), 3), files),
        (pride(json!({"Trans!": {"name": "x"}}), 3), &[][..]),
        (pride(json!({"trans": {"colors": {}}}), 3), &[][..]),
        (pride(json!({"trans": {"name": "x", "id": "other.id"}}), 3), &[][..]),
        (pride(json!({"trans": {"name": "x", "icons": {"images": {}}}}), 3), &[][..]),
        // A file no variant draws.
        (pride(json!({"rainbow": {"name": "Rainbow"}}), 3), files),
        // A variant naming a background nothing carries for it.
        (
            pride(
                json!({"rainbow": {"name": "Rainbow", "background": {"type": "image", "image": "background.png"}}}),
                3,
            ),
            &[][..],
        ),
    ] {
        refused(&bundle(&data, assets), &data.to_string());
    }

    let p = ok(&bundle(&pride(good, 3), files));
    assert_eq!(p.name, "Pride");
    let keys: Vec<_> = p.themes.iter().map(|t| t.variant.clone().unwrap()).collect();
    assert_eq!(keys.iter().map(|v| (v.key.as_str(), v.name.as_str())).collect::<Vec<_>>(), [
        ("trans", "Trans"),
        ("rainbow", "Rainbow")
    ]);
    let (trans, rainbow) = (&p.themes[0], &p.themes[1]);
    assert_eq!(trans.palette_light["primary"], 0xFF5B_CEFA);
    assert_eq!(trans.background.tile, 120.0);
    assert_eq!(trans.files.background.as_deref(), Some(png.as_slice()));
    assert_eq!(trans.shapes.card, 13.0, "the base's shape");
    assert!(rainbow.palette_light.is_empty());
    assert!(rainbow.files.background.is_none(), "the base's background");
    assert_eq!(rainbow.shapes.card, 4.0);
}

#[test]
fn installs_a_splash_with_its_logo() {
    let logo = png();
    let mut data = package2();
    data["splash"] = json!({"color": "surface", "logo": "splash_logo.png", "duration": 900});
    let t = ok(&bundle(&data, &[("splash_logo.png", &logo)])).themes.remove(0);
    let splash = t.splash.unwrap();
    assert_eq!(splash.duration, 900);
    assert_eq!(splash.color, ColorSpec::Role("surface".into()));
    assert_eq!(t.files.splash_logo, Some(("splash_logo.png".into(), logo)));
    assert!(ok(&bundle(&package2(), &[])).themes[0].splash.is_none());
}

#[test]
fn a_splash_logo_may_be_an_svg() {
    let mut data = package2();
    data["splash"] = json!({"logo": "splash_logo.svg"});
    let t = ok(&bundle(&data, &[("splash_logo.svg", SVG_ICON.as_bytes())])).themes.remove(0);
    let splash = t.splash.unwrap();
    assert_eq!(splash.color, ColorSpec::Role("surface".into()));
    assert_eq!(splash.duration, 600);
    for duration in [99, 3001] {
        data["splash"] = json!({"logo": "splash_logo.svg", "duration": duration});
        refused(&bundle(&data, &[("splash_logo.svg", SVG_ICON.as_bytes())]), "duration");
    }
}

#[test]
fn refuses_a_splash_the_package_cannot_honour() {
    let png = png();
    let attempt = |splash: Json, files: &[(&str, &[u8])]| {
        let mut data = package2();
        data["splash"] = splash;
        refused(&bundle(&data, files), &data.to_string());
    };
    attempt(json!({"logo": "../logo.png"}), &[("splash_logo.png", &png)]);
    attempt(json!({"logo": "logo.png"}), &[("splash_logo.png", &png)]);
    attempt(json!({"logo": "splash_logo.png"}), &[]);
    attempt(json!({"unknowable": true}), &[]);
    attempt(json!({"color": "nosuchrole"}), &[]);
    attempt(json!({"duration": "long"}), &[]);
}

#[test]
fn refuses_an_unknown_section_or_icon_field() {
    let mut misspelled = package2();
    misspelled["splas"] = json!({"color": 0xff10_2030u32});
    refused(&bundle(&misspelled, &[]), "splas");
    let mut unknown_icon = package2();
    unknown_icon["icons"]["image"] = json!({});
    refused(&bundle(&unknown_icon, &[]), "icons.image");
}

// ---- beyond fl_lib's cases: images and the packages in this repository ----

#[test]
fn image_dimensions_are_held_to_their_limits() {
    let mut data = package2();
    set_icon(&mut data, "tab.server", "icons/tab_server.png");
    refused(&bundle(&data, &[("icons/tab_server.png", &png_sized(513, 4))]), "icon too wide");
    ok(&bundle(&data, &[("icons/tab_server.png", &png_sized(512, 512))]));
    let mut bg = package("image");
    bg["background"]["image"] = json!("background.png");
    refused(&bundle(&bg, &[("background.png", &png_sized(8193, 10))]), "background too wide");
    refused(&bundle(&bg, &[("background.png", b"\x89PNG\r\n\x1a\nbroken")]), "unreadable header");
}

#[test]
fn every_store_theme_in_this_repository_installs() {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let bundled = std::fs::read(root.join("assets/store_themes/serverbox.piggy.fsbt")).unwrap();
    let p = ok(&bundled);
    assert_eq!(p.id, "serverbox.piggy");
    for dir in ["store/themes/serverbox.pride", "store/themes/serverbox.one-dark-pro", "docs/examples/aurora"] {
        let p = ok(&zip_dir(&root.join(dir)));
        assert!(!p.themes.is_empty(), "{dir}");
    }
}

/// A source folder zipped as the publisher packs it.
fn zip_dir(dir: &std::path::Path) -> Vec<u8> {
    let mut files = Vec::new();
    fn walk(base: &std::path::Path, dir: &std::path::Path, out: &mut Vec<(String, Vec<u8>)>) {
        let mut entries: Vec<_> = std::fs::read_dir(dir).unwrap().map(|e| e.unwrap().path()).collect();
        entries.sort();
        for path in entries {
            if path.is_dir() {
                walk(base, &path, out);
            } else {
                let name = path.strip_prefix(base).unwrap().to_string_lossy().replace('\\', "/");
                out.push((name, std::fs::read(&path).unwrap()));
            }
        }
    }
    walk(dir, dir, &mut files);
    let mut zip = zip::ZipWriter::new(Cursor::new(Vec::new()));
    for (name, bytes) in files {
        zip.start_file(name, zip::write::SimpleFileOptions::default()).unwrap();
        zip.write_all(&bytes).unwrap();
    }
    zip.finish().unwrap().into_inner()
}
