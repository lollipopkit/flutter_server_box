pub mod accounts;
pub mod bootstrap;
pub mod cleanup;
pub mod database;
pub mod sealed;

/// [name] as an SQL identifier, quoted.
pub(crate) fn ident(name: &str) -> String {
    format!("\"{}\"", name.replace('"', "\"\""))
}
