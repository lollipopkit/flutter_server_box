//! Theme packages (`.fsbt`) and the theme store, read and checked the way
//! fl_lib's installer reads them (`packages/fl_lib/lib/src/theme/`), so a
//! package one of them installs the other installs too, and one refused is
//! refused by both for the same reason.
//!
//! Pure: bytes in, a checked package or a refusal out. Fetching a catalog or
//! a package is the caller's (the agent's).

mod error;
pub mod palette;

pub use error::{Result, ThemeError};
mod archive;
pub mod components;
mod image;
pub mod package;
mod svg;

pub use package::{Package, Theme, install};
pub mod repo;
