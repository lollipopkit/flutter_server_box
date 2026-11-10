//! App ids: `<publisher>.<name>` (`serverbox.files`, `futo.immich`), made
//! from the two names a manifest gives, never written by hand. The panel's
//! own apps, desk packages and the web app catalog share the form.

/// The panel's own apps' publisher; a package may not take it.
pub const BUILT_IN_PUBLISHER: &str = "serverbox";

/// Short enough that `sbm-<publisher>-<name>` fits Compose's 63.
const MAX_PART: usize = 24;

/// A publisher or an app name: lowercase letters, digits and `_`, a letter
/// first, at most 24. No `.` or `-`, so an id splits one way and maps onto a
/// Compose project name one way (`stacks::Stacks::spec`).
pub fn valid_part(part: &str) -> bool {
    (1..=MAX_PART).contains(&part.len())
        && part.as_bytes()[0].is_ascii_lowercase()
        && part.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_')
}

/// The id of app [name] by [publisher], when both are valid parts.
pub fn make(publisher: &str, name: &str) -> Option<String> {
    (publisher.len() >= 2 && valid_part(publisher) && valid_part(name)).then(|| format!("{publisher}.{name}"))
}

/// Whether [id] is one [make] gives.
pub fn valid(id: &str) -> bool {
    id.split_once('.').is_some_and(|(publisher, name)| make(publisher, name).is_some())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ids_are_publisher_dot_name() {
        assert_eq!(make("futo", "immich").as_deref(), Some("futo.immich"));
        assert_eq!(make("serverbox", "system_users").as_deref(), Some("serverbox.system_users"));
        for (publisher, name) in [("a", "x"), ("Futo", "x"), ("futo", ""), ("fu-to", "x"), ("futo", "im.mich"), ("1x", "y")] {
            assert_eq!(make(publisher, name), None, "{publisher}.{name}");
        }
        assert!(valid("futo.immich"));
        for id in ["immich", "futo.", ".immich", "futo.immich.x", "futo_immich", &format!("ab.{}", "x".repeat(25))] {
            assert!(!valid(id), "{id}");
        }
    }
}
