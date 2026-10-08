//! The color roles a palette may set (fl_lib `palette.dart`), and the scheme a
//! seed generates (`ColorScheme.fromSeed`: material color utilities' tonal
//! spot, spec 2021, standard contrast) with a palette drawn over it.

use indexmap::IndexMap;
use material_colors::color::Rgb;
use material_colors::dynamic_color::{DynamicColor, MaterialDynamicColors as M};
use material_colors::hct::Hct;
use material_colors::palette::TonalPalette;
use material_colors::scheme::variant::SchemeTonalSpot;

/// Every non-deprecated `ColorScheme` role, in fl_lib's order.
pub const ROLES: [&str; 46] = [
    "primary",
    "onPrimary",
    "primaryContainer",
    "onPrimaryContainer",
    "primaryFixed",
    "primaryFixedDim",
    "onPrimaryFixed",
    "onPrimaryFixedVariant",
    "secondary",
    "onSecondary",
    "secondaryContainer",
    "onSecondaryContainer",
    "secondaryFixed",
    "secondaryFixedDim",
    "onSecondaryFixed",
    "onSecondaryFixedVariant",
    "tertiary",
    "onTertiary",
    "tertiaryContainer",
    "onTertiaryContainer",
    "tertiaryFixed",
    "tertiaryFixedDim",
    "onTertiaryFixed",
    "onTertiaryFixedVariant",
    "error",
    "onError",
    "errorContainer",
    "onErrorContainer",
    "surface",
    "onSurface",
    "surfaceDim",
    "surfaceBright",
    "surfaceContainerLowest",
    "surfaceContainerLow",
    "surfaceContainer",
    "surfaceContainerHigh",
    "surfaceContainerHighest",
    "onSurfaceVariant",
    "outline",
    "outlineVariant",
    "shadow",
    "scrim",
    "inverseSurface",
    "onInverseSurface",
    "inversePrimary",
    "surfaceTint",
];

pub fn is_role(name: &str) -> bool {
    ROLES.contains(&name)
}

fn dynamic(role: &str) -> DynamicColor<'static> {
    match role {
        "primary" => M::primary(),
        "onPrimary" => M::on_primary(),
        "primaryContainer" => M::primary_container(),
        "onPrimaryContainer" => M::on_primary_container(),
        "primaryFixed" => M::primary_fixed(),
        "primaryFixedDim" => M::primary_fixed_dim(),
        "onPrimaryFixed" => M::on_primary_fixed(),
        "onPrimaryFixedVariant" => M::on_primary_fixed_variant(),
        "secondary" => M::secondary(),
        "onSecondary" => M::on_secondary(),
        "secondaryContainer" => M::secondary_container(),
        "onSecondaryContainer" => M::on_secondary_container(),
        "secondaryFixed" => M::secondary_fixed(),
        "secondaryFixedDim" => M::secondary_fixed_dim(),
        "onSecondaryFixed" => M::on_secondary_fixed(),
        "onSecondaryFixedVariant" => M::on_secondary_fixed_variant(),
        "tertiary" => M::tertiary(),
        "onTertiary" => M::on_tertiary(),
        "tertiaryContainer" => M::tertiary_container(),
        "onTertiaryContainer" => M::on_tertiary_container(),
        "tertiaryFixed" => M::tertiary_fixed(),
        "tertiaryFixedDim" => M::tertiary_fixed_dim(),
        "onTertiaryFixed" => M::on_tertiary_fixed(),
        "onTertiaryFixedVariant" => M::on_tertiary_fixed_variant(),
        "error" => M::error(),
        "onError" => M::on_error(),
        "errorContainer" => M::error_container(),
        "onErrorContainer" => M::on_error_container(),
        "surface" => M::surface(),
        "onSurface" => M::on_surface(),
        "surfaceDim" => M::surface_dim(),
        "surfaceBright" => M::surface_bright(),
        "surfaceContainerLowest" => M::surface_container_lowest(),
        "surfaceContainerLow" => M::surface_container_low(),
        "surfaceContainer" => M::surface_container(),
        "surfaceContainerHigh" => M::surface_container_high(),
        "surfaceContainerHighest" => M::surface_container_highest(),
        "onSurfaceVariant" => M::on_surface_variant(),
        "outline" => M::outline(),
        "outlineVariant" => M::outline_variant(),
        "shadow" => M::shadow(),
        "scrim" => M::scrim(),
        "inverseSurface" => M::inverse_surface(),
        "onInverseSurface" => M::inverse_on_surface(),
        "inversePrimary" => M::inverse_primary(),
        "surfaceTint" => M::surface_tint(),
        _ => unreachable!("not a role: {role}"),
    }
}

/// Role name to ARGB, in [ROLES] order.
pub type Scheme = IndexMap<String, u32>;

/// What `ColorScheme.fromSeed(seedColor: seed, brightness)` holds, with
/// [palette]'s roles in place of the generated ones (`ThemePalette.apply`).
pub fn scheme(seed: u32, dark: bool, palette: &IndexMap<String, u32>) -> Scheme {
    let generated = SchemeTonalSpot::new(source(seed), dark, Some(0.0)).scheme;
    ROLES
        .iter()
        .map(|role| {
            let color = palette.get(*role).copied().unwrap_or_else(|| {
                let c = dynamic(role);
                let rgb = c.get_rgb(&generated);
                (u32::from(c.get_alpha(&generated)) << 24)
                    | (u32::from(rgb.red) << 16)
                    | (u32::from(rgb.green) << 8)
                    | u32::from(rgb.blue)
            });
            ((*role).to_string(), color)
        })
        .collect()
}

/// The tones of the accent palette a panel draws with (its `--berry-*`).
pub const ACCENT_TONES: [i32; 12] = [98, 95, 90, 80, 70, 60, 50, 40, 35, 30, 20, 10];
/// The tones of the neutral palette (its `--ink-*`).
pub const NEUTRAL_TONES: [i32; 17] = [99, 98, 96, 94, 92, 90, 80, 60, 50, 40, 30, 22, 17, 12, 10, 6, 4];

/// Tone to ARGB.
pub type Tones = IndexMap<String, u32>;

fn source(argb: u32) -> Hct {
    Hct::new(Rgb::new((argb >> 16) as u8, (argb >> 8) as u8, argb as u8))
}

fn tones_of(palette: &TonalPalette, tones: &[i32]) -> Tones {
    tones
        .iter()
        .map(|t| {
            let rgb = palette.tone(*t);
            (t.to_string(), 0xff00_0000 | (u32::from(rgb.red) << 16) | (u32::from(rgb.green) << 8) | u32::from(rgb.blue))
        })
        .collect()
}

/// The theme's accent and neutral palettes, tone by tone, for a design system
/// that draws from scales rather than from roles: the seed's primary palette
/// (or one from the light palette's own `primary`, when the theme sets it)
/// and the seed's neutral palette.
pub fn tones(seed: u32, palette_light: &IndexMap<String, u32>) -> (Tones, Tones) {
    let scheme = SchemeTonalSpot::new(source(seed), false, Some(0.0)).scheme;
    let accent = match palette_light.get("primary") {
        Some(primary) => TonalPalette::from_hct(source(*primary)),
        None => scheme.primary_palette,
    };
    (tones_of(&accent, &ACCENT_TONES), tones_of(&scheme.neutral_palette, &NEUTRAL_TONES))
}
