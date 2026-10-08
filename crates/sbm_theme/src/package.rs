//! Installing a package: fl_lib `ThemePackages._installAssets` and
//! `_prepare`, check for check and in the same order, so a refusal reads the
//! same in the app and the panel.

use std::collections::HashSet;

use indexmap::IndexMap;
use serde::Serialize;
use serde_json::Map;
use sha2::{Digest, Sha256};
use toml::{Table, Value};

use crate::archive::{self, Assets};
use crate::components::{self, Components};
use crate::error::{Result, ThemeError, fail};
use crate::palette::{self, Scheme, is_role};
use crate::{image, svg};

pub const SUPPORTED_SCHEMA_MIN: u32 = 1;
pub const SUPPORTED_SCHEMA_MAX: u32 = 3;
/// What schema 2 added: SVG icons, per-icon colors, the splash.
const FEATURE_SCHEMA: u32 = 2;
/// What schema 3 added: components beyond schema 2's, `[layout]`,
/// `background.tile`, `[variants]`.
const COMPONENT_SCHEMA: u32 = 3;

pub const MAX_PACKAGE_BYTES: usize = 16 * 1024 * 1024;
pub(crate) const MAX_BACKGROUND_BYTES: usize = 8 * 1024 * 1024;
pub(crate) const MAX_SPLASH_LOGO_BYTES: usize = 512 * 1024;
pub(crate) const MAX_ICON_BYTES: usize = 256 * 1024;
pub(crate) const MAX_MANIFEST_BYTES: usize = 64 * 1024;
const MAX_ICONS: usize = 48;
pub const MAX_VARIANTS: usize = 8;
/// The manifest, its icons, a background and a splash logo, and for each
/// variant a background, a splash logo and its directory entry.
pub(crate) const MAX_ASSETS: usize = MAX_ICONS + 3 + MAX_VARIANTS * 3;
const MAX_NAME_LENGTH: usize = 80;
const MAX_BACKGROUND_OPACITY: f64 = 0.6;
const MAX_BACKGROUND_BLUR: f64 = 30.0;
const MIN_BACKGROUND_TILE: f64 = 16.0;
const MAX_BACKGROUND_TILE: f64 = 1024.0;

const SECTIONS: [&str; 13] = [
    "format",
    "schema",
    "id",
    "name",
    "modes",
    "colors",
    "icons",
    "background",
    "shapes",
    "components",
    "layout",
    "splash",
    "variants",
];
const VARIANT_FIELDS: [&str; 8] = ["name", "colors", "icons", "background", "splash", "shapes", "components", "layout"];
const ICON_FIELDS: [&str; 3] = ["style", "images", "colors"];
const BACKGROUND_FIELDS: [&str; 5] = ["type", "image", "opacity", "blur", "tile"];
const SPLASH_FIELDS: [&str; 3] = ["color", "logo", "duration"];
pub const BACKGROUND_IMAGES: [&str; 3] = ["background.png", "background.jpg", "background.jpeg"];
const SPLASH_LOGOS: [&str; 4] = ["splash_logo.png", "splash_logo.jpg", "splash_logo.jpeg", "splash_logo.svg"];
const SPLASH_MIN_DURATION: i64 = 100;
const SPLASH_MAX_DURATION: i64 = 3000;
const SPLASH_DEFAULT_DURATION: i64 = 600;

/// A theme's id, and therefore the file a repository describes it in.
pub fn is_id(id: &str) -> bool {
    matches_pattern(id, 64, |c| c.is_ascii_lowercase() || c.is_ascii_digit() || matches!(c, '.' | '_' | '-'))
}

/// A `[variants.<key>]` key, and the directory the variant installs to.
pub fn is_variant_key(key: &str) -> bool {
    matches_pattern(key, 32, |c| c.is_ascii_lowercase() || c.is_ascii_digit() || matches!(c, '_' | '-'))
}

/// `^[a-z0-9][rest]{0,max-1}$`.
fn matches_pattern(s: &str, max: usize, rest: impl Fn(char) -> bool) -> bool {
    let mut chars = s.chars();
    let Some(first) = chars.next() else { return false };
    (first.is_ascii_lowercase() || first.is_ascii_digit()) && s.len() <= max && chars.all(rest)
}

/// `^[a-z][a-z0-9]*(\.[a-z][a-zA-Z0-9]*)+$`: dotted lowercase words.
fn is_icon_key(key: &str) -> bool {
    let mut parts = key.split('.');
    let Some(head) = parts.next() else { return false };
    let word = |w: &str, rest: &dyn Fn(char) -> bool| {
        let mut c = w.chars();
        c.next().is_some_and(|f| f.is_ascii_lowercase()) && c.all(rest)
    };
    if !word(head, &|c| c.is_ascii_lowercase() || c.is_ascii_digit()) {
        return false;
    }
    let mut more = 0;
    for part in parts {
        if !word(part, &|c| c.is_ascii_alphanumeric()) {
            return false;
        }
        more += 1;
    }
    more > 0
}

/// A directory entry an archive may carry: `icons/`, `variants/` and
/// `variants/<key>/`.
pub(crate) fn is_directory_entry(path: &str) -> bool {
    path == "icons/"
        || path == "variants/"
        || path
            .strip_prefix("variants/")
            .and_then(|rest| rest.strip_suffix('/'))
            .is_some_and(is_variant_key)
}

// ---- the installed model ---------------------------------------------------

/// A color as a manifest writes one: an ARGB integer or a palette role.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(untagged)]
pub enum ColorSpec {
    Argb(u32),
    Role(String),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Variant {
    pub key: String,
    pub name: String,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Icons {
    /// `classic` or `mingcute`.
    pub style: String,
    /// The keys the package carries an image for.
    pub images: Vec<String>,
    pub colors: IndexMap<String, ColorSpec>,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Background {
    /// `none`, `gradient` or `image`.
    pub style: String,
    pub opacity: f64,
    pub blur: f64,
    /// The logical width one repeat of the image takes, or 0 for one copy.
    pub tile: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Shapes {
    pub card: f64,
    pub tile: f64,
    pub button: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Splash {
    pub color: ColorSpec,
    pub duration: u32,
    pub logo: Option<String>,
}

/// The files a theme installs, by kind.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Files {
    pub background: Option<Vec<u8>>,
    /// File name inside `icons/` to its bytes.
    pub icons: IndexMap<String, Vec<u8>>,
    /// The logo's file name to its bytes.
    pub splash_logo: Option<(String, Vec<u8>)>,
}

/// One theme: a package, or one of its variants drawn over its base.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Theme {
    pub variant: Option<Variant>,
    /// `light`, `dark` or both. One locks the brightness.
    pub modes: Vec<String>,
    /// The initial preference: 0 system, 1 light, 2 dark.
    pub mode: u8,
    pub seed: u32,
    pub system_color: bool,
    pub palette_light: IndexMap<String, u32>,
    pub palette_dark: IndexMap<String, u32>,
    /// What the app draws in each brightness: the seed's scheme with the
    /// palette over it.
    pub scheme_light: Scheme,
    pub scheme_dark: Scheme,
    /// The accent and neutral palettes, by tone (`palette::tones`).
    pub accent_tones: palette::Tones,
    pub neutral_tones: palette::Tones,
    pub icons: Icons,
    pub background: Background,
    pub shapes: Shapes,
    pub splash: Option<Splash>,
    pub components: Map<String, serde_json::Value>,
    pub density: Option<String>,
    #[serde(skip)]
    pub files: Files,
}

/// A checked package.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Package {
    /// SHA-256 of the package bytes, lowercase hex: what one installation is
    /// called, and what a store listing's digest is compared with.
    pub installation_id: String,
    pub id: String,
    pub name: String,
    pub schema_min: u32,
    pub schema_max: u32,
    /// One theme, or one per variant in the manifest's order.
    pub themes: Vec<Theme>,
}

// ---- installing ------------------------------------------------------------

/// Reads and checks a `.fsbt`.
pub fn install(bytes: &[u8]) -> Result<Package> {
    if bytes.is_empty() || bytes.len() > MAX_PACKAGE_BYTES {
        return fail("Invalid theme package size");
    }
    let assets = archive::read(bytes)?;
    let installation_id = hex(&Sha256::digest(bytes));
    install_assets(&assets, installation_id)
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn install_assets(assets: &Assets, installation_id: String) -> Result<Package> {
    let source = std::str::from_utf8(&assets["manifest.toml"]).map_err(|_| ThemeError::new("Invalid TOML manifest"))?;
    let data = decode_manifest(source)?;
    if !matches!(data.get("format"), Some(Value::Integer(1))) && data.get("format") != Some(&Value::Float(1.0))
        || data.contains_key("appIcon")
        || data.contains_key("font")
    {
        return fail("Unsupported theme package");
    }
    if !data.keys().all(|k| SECTIONS.contains(&k.as_str())) {
        return fail("Unknown theme section");
    }
    let (schema_min, schema_max) = schema_range(data.get("schema"))?;

    let mut used: HashSet<String> = HashSet::from(["manifest.toml".to_string()]);
    let mut themes = Vec::new();
    if let Some(raw) = data.get("variants") {
        if schema_min < COMPONENT_SCHEMA {
            return fail(format!("This theme needs schema {COMPONENT_SCHEMA}"));
        }
        let table = map(Some(raw), "variants")?;
        if table.is_empty() || table.len() > MAX_VARIANTS {
            return fail("Invalid theme variants");
        }
        let mut base = data.clone();
        base.remove("variants");
        for (key, value) in table {
            if !is_variant_key(key) {
                return fail("Invalid variant key");
            }
            let overrides = map(Some(value), "variant")?;
            if !overrides.keys().all(|k| VARIANT_FIELDS.contains(&k.as_str())) {
                return fail("Unknown variant field");
            }
            // One set of icon files for the package.
            if let Some(Value::Table(icons)) = overrides.get("icons")
                && icons.contains_key("images")
            {
                return fail("A variant cannot carry icon images");
            }
            let variant_name = label(overrides.get("name"), "variant name")?;
            let (view, origin) = variant_assets(assets, key);
            let mut overrides = overrides.clone();
            overrides.remove("name");
            let (mut theme, theme_used) = prepare(&merge(&base, &overrides), &view)?;
            used.extend(theme_used.into_iter().map(|p| origin.get(&p).cloned().unwrap_or(p)));
            theme.variant = Some(Variant { key: key.clone(), name: variant_name });
            themes.push(theme);
        }
    } else {
        let (theme, theme_used) = prepare(&data, assets)?;
        used.extend(theme_used);
        themes.push(theme);
    }
    if assets.keys().any(|path| !is_directory_entry(path) && !used.contains(path)) {
        return fail("Unexpected theme asset");
    }
    // Checked by every theme it was prepared as.
    let id = match data.get("id") {
        Some(Value::String(id)) => id.clone(),
        _ => return fail("Invalid theme id"),
    };
    let name = label(data.get("name"), "name")?;
    Ok(Package { installation_id, id, name, schema_min, schema_max, themes })
}

/// Checks one theme — a package, or one variant drawn over its base — and
/// answers it with the package paths it used.
fn prepare(data: &Table, assets: &Assets) -> Result<(Theme, HashSet<String>)> {
    let (schema_min, _) = schema_range(data.get("schema"))?;
    match data.get("id") {
        Some(Value::String(id)) if is_id(id) => {}
        _ => return fail("Invalid theme id"),
    }
    label(data.get("name"), "name")?;
    let colors = map(data.get("colors"), "colors")?;
    let mode = integer(colors.get("mode"), 0, 2)? as u8;
    let modes = theme_modes(data.get("modes"))?;
    let seed = integer(colors.get("seed"), 0, 0xffff_ffff)? as u32;
    let Some(Value::Boolean(system_color)) = colors.get("systemColor") else {
        return fail("Invalid color mode");
    };
    let empty = Table::new();
    let palette = match colors.get("palette") {
        None => &empty,
        raw => map(raw, "palette")?,
    };
    if palette.keys().any(|k| k != "light" && k != "dark") {
        return fail("Invalid palette brightness");
    }
    let palette_light = palette_roles(palette.get("light"))?;
    let palette_dark = palette_roles(palette.get("dark"))?;
    let components = Components::parse(data.get("components"), data.get("layout"))?;
    let icons = map(data.get("icons"), "icons")?;
    if !icons.keys().all(|k| ICON_FIELDS.contains(&k.as_str())) {
        return fail("Unknown icon field");
    }
    let style = match icons.get("style") {
        Some(Value::String(s)) if s == "classic" || s == "mingcute" => s.clone(),
        _ => return fail("Invalid icon style"),
    };
    let images = match icons.get("images") {
        None => &empty,
        raw => map(raw, "icon images")?,
    };
    if images.len() > MAX_ICONS || !images.keys().all(|k| is_icon_key(k)) {
        return fail("Invalid icon keys");
    }
    let icon_colors = icon_colors(
        match icons.get("colors") {
            None => &empty,
            raw => map(raw, "icon colors")?,
        },
        images,
    )?;
    let splash = splash(data.get("splash"))?;
    let background = map(data.get("background"), "background")?;
    if !background.keys().all(|k| BACKGROUND_FIELDS.contains(&k.as_str())) {
        return fail("Unknown background field");
    }
    let background_style = match background.get("type") {
        Some(Value::String(s)) if matches!(s.as_str(), "none" | "gradient" | "image") => s.clone(),
        _ => return fail("Invalid background type"),
    };
    let opacity = fraction(background.get("opacity"), MAX_BACKGROUND_OPACITY)?;
    let blur = fraction(background.get("blur"), MAX_BACKGROUND_BLUR)?;
    let tile = background_tile(background, &background_style)?;
    let shapes = map(data.get("shapes"), "shapes")?;
    let shapes = Shapes {
        card: fraction(shapes.get("card"), components::MAX_RADIUS)?,
        tile: fraction(shapes.get("tile"), components::MAX_RADIUS)?,
        button: fraction(shapes.get("button"), components::MAX_RADIUS)?,
    };

    let mut used = HashSet::new();
    let mut files = Files::default();
    if background_style == "image" {
        let path = match background.get("image") {
            Some(Value::String(p)) if BACKGROUND_IMAGES.contains(&p.as_str()) => p.clone(),
            _ => return fail("Invalid background path"),
        };
        let bytes = image_asset(assets, &path, MAX_BACKGROUND_BYTES)?;
        image::verify(bytes, 8192, 64 * 1024 * 1024)?;
        files.background = Some(bytes.to_vec());
        used.insert(path);
    } else if background.contains_key("image") {
        return fail("Unexpected background image");
    }
    let mut icon_files = Vec::new();
    for (key, value) in images {
        let path = icon_asset_path(key, value)?;
        let name = path["icons/".len()..].to_string();
        let bytes = if path.ends_with(".svg") {
            let bytes = asset_bytes(assets, &path, MAX_ICON_BYTES)?;
            svg::check(bytes)?;
            bytes
        } else {
            let bytes = image_asset(assets, &path, MAX_ICON_BYTES)?;
            if !image::is_png(bytes) {
                return fail("Icons must be PNG or SVG");
            }
            image::verify(bytes, 512, 512 * 512)?;
            bytes
        };
        files.icons.insert(name.clone(), bytes.to_vec());
        icon_files.push(name);
        used.insert(path);
    }
    if let Some(Splash { logo: Some(logo), .. }) = &splash {
        let bytes = if logo.ends_with(".svg") {
            let bytes = asset_bytes(assets, logo, MAX_SPLASH_LOGO_BYTES)?;
            svg::check(bytes)?;
            bytes
        } else {
            let bytes = image_asset(assets, logo, MAX_SPLASH_LOGO_BYTES)?;
            image::verify(bytes, 2048, 2048 * 2048)?;
            bytes
        };
        files.splash_logo = Some((logo.clone(), bytes.to_vec()));
        used.insert(logo.clone());
    }
    require_feature_schema(schema_min, &icon_files, &icon_colors, splash.as_ref(), &components, tile)?;

    let (accent_tones, neutral_tones) = palette::tones(seed, &palette_light);
    let theme = Theme {
        variant: None,
        accent_tones,
        neutral_tones,
        scheme_light: palette::scheme(seed, false, &palette_light),
        scheme_dark: palette::scheme(seed, true, &palette_dark),
        modes,
        mode,
        seed,
        system_color: *system_color,
        palette_light,
        palette_dark,
        icons: Icons { style, images: images.keys().cloned().collect(), colors: icon_colors },
        background: Background { style: background_style, opacity, blur, tile },
        shapes,
        splash,
        components: components.tables,
        density: components.density,
        files,
    };
    Ok((theme, used))
}

/// The files one variant sees: the package's own, with any its directory
/// carries in their place, and where each replacement came from.
fn variant_assets(assets: &Assets, key: &str) -> (Assets, IndexMap<String, String>) {
    let prefix = format!("variants/{key}/");
    let mut view: Assets = assets
        .iter()
        .filter(|(path, _)| !path.starts_with("variants/"))
        .map(|(p, b)| (p.clone(), b.clone()))
        .collect();
    let mut origin = IndexMap::new();
    for (path, bytes) in assets {
        let Some(name) = path.strip_prefix(&prefix) else { continue };
        if name.is_empty() {
            continue;
        }
        view.insert(name.to_string(), bytes.clone());
        origin.insert(name.to_string(), path.clone());
    }
    (view, origin)
}

/// [base] with [overrides] over it: a table merges key by key, anything else
/// replaces.
fn merge(base: &Table, overrides: &Table) -> Table {
    let mut out = base.clone();
    for (key, value) in overrides {
        let merged = match (base.get(key), value) {
            (Some(Value::Table(a)), Value::Table(b)) => Value::Table(merge(a, b)),
            _ => value.clone(),
        };
        out.insert(key.clone(), merged);
    }
    out
}

/// What an omitted field is read as.
fn decode_manifest(source: &str) -> Result<Table> {
    let mut data: Table = source.parse().map_err(|_| ThemeError::new("Invalid TOML manifest"))?;
    data.entry("format").or_insert(Value::Integer(1));
    let defaults: [(&str, Table); 4] = [
        (
            "colors",
            Table::from_iter([
                ("mode".into(), Value::Integer(0)),
                ("seed".into(), Value::Integer(0xFF88_0E4F)),
                ("systemColor".into(), Value::Boolean(false)),
            ]),
        ),
        (
            "icons",
            Table::from_iter([
                ("style".into(), Value::String("classic".into())),
                ("images".into(), Value::Table(Table::new())),
            ]),
        ),
        (
            "background",
            Table::from_iter([
                ("type".into(), Value::String("none".into())),
                ("opacity".into(), Value::Float(0.18)),
                ("blur".into(), Value::Integer(0)),
            ]),
        ),
        (
            "shapes",
            Table::from_iter([
                ("card".into(), Value::Integer(12)),
                ("tile".into(), Value::Integer(8)),
                ("button".into(), Value::Integer(10)),
            ]),
        ),
    ];
    for (key, mut values) in defaults {
        if let Some(given) = data.get(key) {
            for (k, v) in map(Some(given), key)? {
                values.insert(k.clone(), v.clone());
            }
        }
        data.insert(key.to_string(), Value::Table(values));
    }
    Ok(data)
}

fn map<'a>(value: Option<&'a Value>, field: &str) -> Result<&'a Table> {
    match value {
        Some(Value::Table(t)) => Ok(t),
        _ => fail(format!("Invalid {field}")),
    }
}

fn label(value: Option<&Value>, field: &str) -> Result<String> {
    match value {
        Some(Value::String(s))
            if !s.trim().is_empty()
                // UTF-16 code units, as the app counts a string's length.
                && s.encode_utf16().count() <= MAX_NAME_LENGTH
                && !s.chars().any(|c| (c as u32) < 0x20) =>
        {
            Ok(s.trim().to_string())
        }
        _ => fail(format!("Invalid {field}")),
    }
}

fn integer(value: Option<&Value>, min: i64, max: i64) -> Result<i64> {
    match value {
        Some(Value::Integer(i)) if (min..=max).contains(i) => Ok(*i),
        _ => fail("Invalid number"),
    }
}

fn fraction(value: Option<&Value>, max: f64) -> Result<f64> {
    match value.and_then(components::number) {
        Some(n) if (0.0..=max).contains(&n) => Ok(n),
        _ => fail("Invalid number"),
    }
}

fn theme_modes(raw: Option<&Value>) -> Result<Vec<String>> {
    const MESSAGE: &str = "Declare supported theme modes: light, dark";
    let Some(Value::Array(items)) = raw else { return fail(MESSAGE) };
    let unique: HashSet<String> = items.iter().map(|v| format!("{v:?}")).collect();
    if items.is_empty() || items.len() > 2 || unique.len() != items.len() {
        return fail(MESSAGE);
    }
    items
        .iter()
        .map(|v| match v {
            Value::String(s) if s == "light" || s == "dark" => Ok(s.clone()),
            _ => fail(MESSAGE),
        })
        .collect()
}

fn schema_range(raw: Option<&Value>) -> Result<(u32, u32)> {
    let schema = map(raw, "schema")?;
    if schema.len() != 2 || !schema.contains_key("min") || !schema.contains_key("max") {
        return fail("Invalid theme schema range");
    }
    let min = integer(schema.get("min"), 1, 0x7fff_ffff)? as u32;
    let max = integer(schema.get("max"), 1, 0x7fff_ffff)? as u32;
    if min > max || max < SUPPORTED_SCHEMA_MIN || min > SUPPORTED_SCHEMA_MAX {
        return fail("Unsupported theme schema range");
    }
    Ok((min, max))
}

fn background_tile(background: &Table, style: &str) -> Result<f64> {
    let Some(raw) = background.get("tile") else { return Ok(0.0) };
    if style != "image" {
        return fail("A background tile needs an image");
    }
    let tile = fraction(Some(raw), MAX_BACKGROUND_TILE)?;
    if tile < MIN_BACKGROUND_TILE {
        return fail("Invalid background tile");
    }
    Ok(tile)
}

fn palette_roles(raw: Option<&Value>) -> Result<IndexMap<String, u32>> {
    let Some(raw) = raw else { return Ok(IndexMap::new()) };
    let values = map(Some(raw), "palette")?;
    if !values.keys().all(|k| is_role(k)) {
        return fail("Invalid palette role");
    }
    values.iter().map(|(k, v)| Ok((k.clone(), integer(Some(v), 0, 0xffff_ffff)? as u32))).collect()
}

fn color_spec(value: &Value) -> Result<ColorSpec> {
    match value {
        Value::Integer(i) if (0..=0xffff_ffff).contains(i) => Ok(ColorSpec::Argb(*i as u32)),
        Value::String(s) if is_role(s) => Ok(ColorSpec::Role(s.clone())),
        _ => fail("Invalid color"),
    }
}

fn icon_colors(raw: &Table, images: &Table) -> Result<IndexMap<String, ColorSpec>> {
    raw.iter()
        .map(|(key, value)| {
            if !images.contains_key(key) {
                return fail("Icon color without an image");
            }
            Ok((key.clone(), color_spec(value)?))
        })
        .collect()
}

fn splash(raw: Option<&Value>) -> Result<Option<Splash>> {
    let Some(raw) = raw else { return Ok(None) };
    let table = map(Some(raw), "splash")?;
    if !table.keys().all(|k| SPLASH_FIELDS.contains(&k.as_str())) {
        return fail("Unknown splash field");
    }
    let logo = match table.get("logo") {
        None => None,
        Some(Value::String(l)) if SPLASH_LOGOS.contains(&l.as_str()) => Some(l.clone()),
        Some(_) => return fail("Invalid splash logo path"),
    };
    let duration = match table.get("duration") {
        None => SPLASH_DEFAULT_DURATION,
        raw => integer(raw, SPLASH_MIN_DURATION, SPLASH_MAX_DURATION)?,
    } as u32;
    let color = match table.get("color") {
        None => ColorSpec::Role("surface".into()),
        Some(v) => color_spec(v)?,
    };
    Ok(Some(Splash { color, duration, logo }))
}

/// Refuses a package that reaches for a newer schema's feature while saying
/// an older schema can read it: that build would install the bytes and drop
/// the feature without saying so.
fn require_feature_schema(
    min: u32,
    icon_files: &[String],
    icon_colors: &IndexMap<String, ColorSpec>,
    splash: Option<&Splash>,
    components: &Components,
    tile: f64,
) -> Result<()> {
    if min < COMPONENT_SCHEMA && (components.needed_schema() >= COMPONENT_SCHEMA || tile > 0.0) {
        return fail(format!("This theme needs schema {COMPONENT_SCHEMA}"));
    }
    let uses = icon_files.iter().any(|n| n.ends_with(".svg")) || !icon_colors.is_empty() || splash.is_some();
    if uses && min < FEATURE_SCHEMA {
        return fail(format!("This theme needs schema {FEATURE_SCHEMA}"));
    }
    Ok(())
}

/// The only two names a package may give an icon, both derived from its key.
fn icon_asset_path(key: &str, value: &Value) -> Result<String> {
    let stem = key.replace('.', "_");
    match value {
        Value::String(v) if *v == format!("icons/{stem}.png") || *v == format!("icons/{stem}.svg") => Ok(v.clone()),
        _ => fail("Invalid icon path"),
    }
}

fn asset_bytes<'a>(assets: &'a Assets, path: &str, max: usize) -> Result<&'a [u8]> {
    match assets.get(path) {
        Some(b) if !b.is_empty() && b.len() <= max => Ok(b),
        _ => fail("Theme asset exceeds size limit"),
    }
}

fn image_asset<'a>(assets: &'a Assets, path: &str, max: usize) -> Result<&'a [u8]> {
    let bytes = asset_bytes(assets, path, max)?;
    if !(image::is_png(bytes) || image::is_jpeg(bytes)) {
        return fail("Use a PNG or JPEG image");
    }
    Ok(bytes)
}
