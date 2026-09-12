#![cfg_attr(doc, doc = include_str!("../README.md"))]
#![doc(html_logo_url = "https://cdnweb.devolutions.net/images/projects/devolutions/logos/devolutions-icon-shadow.svg")]
// No need to be as strict as in production libraries
#![allow(clippy::arithmetic_side_effects)]
#![allow(clippy::cast_lossless)]
#![allow(clippy::cast_possible_truncation)]
#![allow(clippy::cast_possible_wrap)]
#![allow(clippy::cast_sign_loss)]

pub mod config;
pub mod rdp;

#[cfg(all(windows, feature = "clipboard"))]
mod clipboard;

mod ws;
