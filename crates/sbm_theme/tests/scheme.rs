//! `ColorScheme.fromSeed` as the app computes it, held against values written
//! by material color utilities 0.13 (the version the app resolves) with
//! `fixtures/from_seed.dart`.

use indexmap::IndexMap;
use sbm_theme::palette::{ROLES, scheme};

#[test]
fn a_seed_generates_the_scheme_the_app_generates() {
    let reference: IndexMap<String, IndexMap<String, u32>> =
        serde_json::from_str(include_str!("fixtures/from_seed.json")).unwrap();
    for (key, expected) in &reference {
        let (seed, mode) = key.split_once('-').unwrap();
        let seed = u32::from_str_radix(seed, 16).unwrap();
        let got = scheme(seed, mode == "dark", &IndexMap::new());
        for role in ROLES {
            assert_eq!(
                format!("{:08x}", got[role]),
                format!("{:08x}", expected[role]),
                "{key} {role}"
            );
        }
    }
}

#[test]
fn a_palette_replaces_only_the_roles_it_names() {
    let palette: IndexMap<String, u32> = [("primary".to_string(), 0xFFC87FD0)].into();
    let plain = scheme(0xFF880E4F, true, &IndexMap::new());
    let drawn = scheme(0xFF880E4F, true, &palette);
    assert_eq!(drawn["primary"], 0xFFC87FD0);
    assert_eq!(drawn["surface"], plain["surface"]);
}

#[test]
fn the_tones_follow_the_seed_or_the_primary_a_theme_sets() {
    use sbm_theme::palette::{ACCENT_TONES, NEUTRAL_TONES, tones};
    let (accent, neutral) = tones(0xFF880E4F, &IndexMap::new());
    assert_eq!(accent.len(), ACCENT_TONES.len());
    assert_eq!(neutral.len(), NEUTRAL_TONES.len());
    // Tone 40 of the primary palette is the light scheme's primary.
    assert_eq!(accent["40"], scheme(0xFF880E4F, false, &IndexMap::new())["primary"]);
    let set: IndexMap<String, u32> = [("primary".to_string(), 0xFF1F74A8)].into();
    let (blue, same_neutral) = tones(0xFF880E4F, &set);
    assert_ne!(blue["40"], accent["40"]);
    assert_eq!(same_neutral, neutral);
}
