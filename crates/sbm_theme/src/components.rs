//! `[components]` and `[layout]` (fl_lib `components.dart`): which component
//! tables exist, which fields each has, what each field holds, and which of
//! them schema 2 already had.
//!
//! Checked and kept in full. The panel draws from the colors, the background
//! and the shapes today; drawing its own components from these is still to
//! come (TODO).

use serde_json::{Map, Value as Json};
use toml::Value;

use crate::error::{Result, fail};
use crate::palette::is_role;

pub const MAX_RADIUS: f64 = 40.0;
const MAX_BORDER_WIDTH: f64 = 8.0;
const MAX_ELEVATION: f64 = 24.0;
const MAX_SIZE: f64 = 96.0;
const MAX_THICKNESS: f64 = 16.0;
const MAX_INSET: f64 = 64.0;

#[derive(Clone, Copy, PartialEq, Eq)]
enum Kind {
    Color,
    Radius,
    BorderWidth,
    Elevation,
    Inset,
    Flag,
    Size,
    Thickness,
}

use Kind::*;

const SHAPE: [(&str, Kind); 3] = [("radius", Radius), ("borderColor", Color), ("borderWidth", BorderWidth)];
const SURFACE: [(&str, Kind); 4] = [
    ("backgroundColor", Color),
    ("elevation", Elevation),
    ("shadowColor", Color),
    ("surfaceTintColor", Color),
];
const BUTTON_OWN: [(&str, Kind); 4] = [
    ("foregroundColor", Color),
    ("overlayColor", Color),
    ("padding", Inset),
    ("minHeight", Size),
];

/// The fields of component [name] and what each holds; None for a component
/// that does not exist.
fn kinds(name: &str) -> Option<Vec<(&'static str, Kind)>> {
    let mut v: Vec<(&'static str, Kind)> = Vec::new();
    let button = |v: &mut Vec<(&'static str, Kind)>| {
        v.extend(SHAPE);
        v.extend(SURFACE);
        v.extend(BUTTON_OWN);
    };
    match name {
        "card" => {
            v.extend(SHAPE);
            v.extend(SURFACE);
            v.push(("margin", Inset));
        }
        "tile" => {
            v.extend(SHAPE);
            v.extend([
                ("backgroundColor", Color),
                ("selectedTileColor", Color),
                ("textColor", Color),
                ("iconColor", Color),
                ("selectedColor", Color),
                ("padding", Inset),
            ]);
        }
        "button" | "textButton" | "outlinedButton" => button(&mut v),
        "iconButton" => {
            button(&mut v);
            v.push(("iconSize", Size));
        }
        "input" => {
            v.extend(SHAPE);
            v.extend([
                ("filled", Flag),
                ("fillColor", Color),
                ("focusedBorderColor", Color),
                ("errorBorderColor", Color),
                ("disabledBorderColor", Color),
                ("padding", Inset),
            ]);
        }
        "search" => {
            v.extend(SHAPE);
            v.extend([
                ("backgroundColor", Color),
                ("elevation", Elevation),
                ("iconColor", Color),
                ("textColor", Color),
                ("hintColor", Color),
                ("height", Size),
                ("padding", Inset),
            ]);
        }
        "navigation" => v.extend([
            ("backgroundColor", Color),
            ("indicatorColor", Color),
            ("indicatorRadius", Radius),
            ("selectedIconColor", Color),
            ("unselectedIconColor", Color),
            ("selectedLabelColor", Color),
            ("unselectedLabelColor", Color),
            ("elevation", Elevation),
        ]),
        "appBar" => v.extend([
            ("backgroundColor", Color),
            ("foregroundColor", Color),
            ("titleColor", Color),
            ("iconColor", Color),
            ("elevation", Elevation),
            ("shadowColor", Color),
            ("surfaceTintColor", Color),
        ]),
        "segmented" => {
            v.extend(SHAPE);
            v.extend([
                ("backgroundColor", Color),
                ("selectedColor", Color),
                ("textColor", Color),
                ("selectedTextColor", Color),
            ]);
        }
        "sidebar" => v.extend([
            ("backgroundColor", Color),
            ("selectedColor", Color),
            ("textColor", Color),
            ("selectedTextColor", Color),
            ("iconColor", Color),
            ("selectedIconColor", Color),
            ("radius", Radius),
            ("padding", Inset),
        ]),
        "dialog" => {
            v.extend(SHAPE);
            v.extend(SURFACE);
            v.extend([("barrierColor", Color), ("insetPadding", Inset)]);
        }
        "sheet" => {
            v.extend(SHAPE);
            v.extend(SURFACE);
            v.extend([("barrierColor", Color), ("dragHandleColor", Color)]);
        }
        "menu" => {
            v.extend(SHAPE);
            v.extend(SURFACE);
            v.push(("textColor", Color));
        }
        "tooltip" => {
            v.extend(SHAPE);
            v.extend([("backgroundColor", Color), ("textColor", Color), ("padding", Inset)]);
        }
        "toast" => {
            v.extend(SHAPE);
            v.extend([("backgroundColor", Color), ("textColor", Color), ("elevation", Elevation)]);
        }
        "switch" => v.extend([
            ("thumbColor", Color),
            ("trackColor", Color),
            ("trackOutlineColor", Color),
            ("selectedThumbColor", Color),
            ("selectedTrackColor", Color),
            ("selectedTrackOutlineColor", Color),
        ]),
        "slider" => v.extend([
            ("activeTrackColor", Color),
            ("inactiveTrackColor", Color),
            ("thumbColor", Color),
            ("overlayColor", Color),
            ("trackHeight", Thickness),
        ]),
        "progress" => v.extend([("color", Color), ("trackColor", Color), ("thickness", Thickness), ("radius", Radius)]),
        "badge" => v.extend([("backgroundColor", Color), ("textColor", Color), ("smallSize", Size), ("largeSize", Size)]),
        "chip" => {
            v.extend(SHAPE);
            v.extend([
                ("backgroundColor", Color),
                ("selectedColor", Color),
                ("textColor", Color),
                ("padding", Inset),
            ]);
        }
        "divider" => v.extend([("color", Color), ("thickness", Thickness)]),
        "scrollbar" => v.extend([("thumbColor", Color), ("trackColor", Color), ("radius", Radius), ("thickness", Thickness)]),
        _ => return None,
    }
    Some(v)
}

/// The components with state tables.
const STATEFUL: [&str; 4] = ["button", "textButton", "outlinedButton", "iconButton"];

/// Highest priority first.
pub const STATES: [&str; 5] = ["disabled", "pressed", "hovered", "focused", "selected"];

/// What schema 2 had, and nothing more.
fn schema2(name: &str) -> Option<&'static [&'static str]> {
    const S: [&str; 3] = ["radius", "borderColor", "borderWidth"];
    macro_rules! with_shape {
        ($($f:literal),*) => {{
            const A: &[&str] = &[S[0], S[1], S[2], $($f),*];
            A
        }};
    }
    Some(match name {
        "card" => with_shape!("backgroundColor", "elevation", "shadowColor", "surfaceTintColor", "margin"),
        "tile" => with_shape!(
            "backgroundColor",
            "selectedTileColor",
            "textColor",
            "iconColor",
            "selectedColor",
            "padding"
        ),
        "button" => with_shape!(
            "backgroundColor",
            "elevation",
            "shadowColor",
            "surfaceTintColor",
            "foregroundColor",
            "overlayColor",
            "padding"
        ),
        "input" => with_shape!(
            "filled",
            "fillColor",
            "focusedBorderColor",
            "errorBorderColor",
            "disabledBorderColor",
            "padding"
        ),
        "navigation" => &[
            "backgroundColor",
            "indicatorColor",
            "indicatorRadius",
            "selectedIconColor",
            "unselectedIconColor",
            "selectedLabelColor",
            "unselectedLabelColor",
            "elevation",
        ],
        "dialog" => with_shape!(
            "backgroundColor",
            "elevation",
            "shadowColor",
            "surfaceTintColor",
            "barrierColor",
            "insetPadding"
        ),
        "sheet" => with_shape!(
            "backgroundColor",
            "elevation",
            "shadowColor",
            "surfaceTintColor",
            "barrierColor",
            "dragHandleColor"
        ),
        _ => return None,
    })
}

fn is_brightness(key: &str) -> bool {
    key == "light" || key == "dark"
}

/// Checked `[components]` and `[layout]`, as the installed manifest keeps
/// them.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Components {
    /// `[components]`, normalized: component (or brightness, then component)
    /// to its fields.
    pub tables: Map<String, Json>,
    /// `[layout] density`: `compact`, `standard` or `comfortable`.
    pub density: Option<String>,
}

impl Components {
    pub fn parse(raw: Option<&Value>, layout: Option<&Value>) -> Result<Self> {
        let density = density(layout)?;
        let Some(raw) = raw else {
            return Ok(Self { tables: Map::new(), density });
        };
        let mut tables = Map::new();
        for (key, value) in table(raw)? {
            let parsed = if is_brightness(key) {
                let mut group = Map::new();
                for (name, fields) in table(value)? {
                    group.insert(name.clone(), Json::Object(component(name, fields, false)?));
                }
                Json::Object(group)
            } else {
                Json::Object(component(key, value, false)?)
            };
            tables.insert(key.clone(), parsed);
        }
        Ok(Self { tables, density })
    }

    /// The schema version these need: 3 once anything beyond schema 2 is
    /// used, or `[layout]`.
    pub fn needed_schema(&self) -> u32 {
        if self.density.is_some() {
            return 3;
        }
        fn within(name: &str, fields: &Json) -> bool {
            let Some(allowed) = schema2(name) else { return false };
            let Json::Object(fields) = fields else { return false };
            fields.iter().all(|(key, value)| {
                if name == "button" && STATES.contains(&key.as_str()) {
                    match value {
                        Json::Object(state) => state.keys().all(|k| allowed.contains(&k.as_str())),
                        _ => false,
                    }
                } else {
                    allowed.contains(&key.as_str())
                }
            })
        }
        for (key, value) in &self.tables {
            if is_brightness(key) {
                let Json::Object(group) = value else { return 3 };
                if !group.iter().all(|(name, fields)| within(name, fields)) {
                    return 3;
                }
            } else if !within(key, value) {
                return 3;
            }
        }
        1
    }
}

fn table(value: &Value) -> Result<&toml::Table> {
    match value {
        Value::Table(t) => Ok(t),
        _ => fail("Invalid component table"),
    }
}

fn component(name: &str, raw: &Value, state: bool) -> Result<Map<String, Json>> {
    let Some(allowed) = kinds(name) else {
        return fail(format!("Unknown component: {name}"));
    };
    let mut out = Map::new();
    for (key, value) in table(raw)? {
        if STATEFUL.contains(&name) && !state && STATES.contains(&key.as_str()) {
            out.insert(key.clone(), Json::Object(component(name, value, true)?));
            continue;
        }
        let Some((_, kind)) = allowed.iter().find(|(k, _)| k == key) else {
            return fail(format!("Unknown {name} field: {key}"));
        };
        let json = match kind {
            Color => match value {
                Value::Integer(i) if (0..=0xffff_ffff).contains(i) => Json::from(*i),
                Value::String(s) if is_role(s) => Json::from(s.clone()),
                _ => return fail(format!("Invalid {name}.{key} color")),
            },
            Flag => match value {
                Value::Boolean(b) => Json::from(*b),
                _ => return fail(format!("Invalid {name}.{key} flag")),
            },
            Inset => {
                let insets = match value {
                    Value::Array(items) if items.len() == 4 => items
                        .iter()
                        .map(|v| number(v).filter(|n| (0.0..=MAX_INSET).contains(n)).map(|_| to_json(v)))
                        .collect::<Option<Vec<_>>>(),
                    _ => None,
                };
                match insets {
                    Some(insets) => Json::Array(insets),
                    None => return fail(format!("Invalid {name}.{key} insets")),
                }
            }
            Radius | BorderWidth | Elevation | Size | Thickness => {
                let max = match kind {
                    BorderWidth => MAX_BORDER_WIDTH,
                    Elevation => MAX_ELEVATION,
                    Size => MAX_SIZE,
                    Thickness => MAX_THICKNESS,
                    _ => MAX_RADIUS,
                };
                match number(value) {
                    Some(n) if (0.0..=max).contains(&n) => to_json(value),
                    _ => return fail(format!("Invalid {name}.{key} number")),
                }
            }
        };
        out.insert(key.clone(), json);
    }
    Ok(out)
}

/// A finite TOML number, integer or float.
pub(crate) fn number(value: &Value) -> Option<f64> {
    match value {
        Value::Integer(i) => Some(*i as f64),
        Value::Float(f) if f.is_finite() => Some(*f),
        _ => None,
    }
}

fn to_json(value: &Value) -> Json {
    match value {
        Value::Integer(i) => Json::from(*i),
        Value::Float(f) => Json::from(*f),
        _ => Json::Null,
    }
}

fn density(raw: Option<&Value>) -> Result<Option<String>> {
    let Some(raw) = raw else { return Ok(None) };
    let Value::Table(t) = raw else {
        return fail("Invalid layout table");
    };
    if !t.keys().all(|k| k == "density") {
        return fail("Invalid layout table");
    }
    match t.get("density") {
        None => Ok(None),
        Some(Value::String(s)) if matches!(s.as_str(), "compact" | "standard" | "comfortable") => Ok(Some(s.clone())),
        Some(_) => fail("Invalid layout density"),
    }
}
