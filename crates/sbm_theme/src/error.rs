use std::fmt;

/// Why a package, a catalog or a repository was refused, in the words fl_lib's
/// installer uses for the same refusal (`FormatException`, `ThemeRepoError`),
/// so the app and the panel say one thing about one package.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ThemeError(pub String);

impl ThemeError {
    pub fn new(message: impl Into<String>) -> Self {
        Self(message.into())
    }
}

impl fmt::Display for ThemeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

impl std::error::Error for ThemeError {}

pub type Result<T> = std::result::Result<T, ThemeError>;

pub(crate) fn fail<T>(message: impl Into<String>) -> Result<T> {
    Err(ThemeError::new(message))
}
