//! A `.fsbt` is a ZIP; this reads it into its files the way fl_lib's
//! `_readArchive` does, refusing what that refuses: an entry outside the
//! package root, a duplicate, a symlink, an encrypted or oddly compressed
//! entry, one larger than its kind may be, a total beyond the package limit,
//! and an entry whose bytes do not match its size and CRC.

use std::io::{Cursor, Read};

use indexmap::IndexMap;

use crate::error::{Result, ThemeError, fail};
use crate::package::{
    MAX_ASSETS, MAX_BACKGROUND_BYTES, MAX_ICON_BYTES, MAX_MANIFEST_BYTES, MAX_PACKAGE_BYTES, MAX_SPLASH_LOGO_BYTES,
    is_directory_entry,
};

/// Path in the package to its bytes; a directory entry (`icons/`) is empty.
pub type Assets = IndexMap<String, Vec<u8>>;

const S_IFMT: u32 = 0o170000;
const S_IFLNK: u32 = 0o120000;

pub fn read(bytes: &[u8]) -> Result<Assets> {
    let mut zip = zip::ZipArchive::new(Cursor::new(bytes)).map_err(|_| ThemeError::new("Invalid theme ZIP"))?;
    // The two directory entries, `icons/` and `variants/`, besides.
    if zip.is_empty() || zip.len() > MAX_ASSETS + 2 {
        return fail("Invalid theme ZIP");
    }
    let mut assets = Assets::new();
    let mut total = 0usize;
    for i in 0..zip.len() {
        let (path, method, encrypted, symlink, size, compressed, crc) = {
            let entry = zip.by_index_raw(i).map_err(|_| ThemeError::new("Invalid theme ZIP"))?;
            (
                entry.name().to_string(),
                entry.compression(),
                entry.encrypted(),
                entry.unix_mode().is_some_and(|m| m & S_IFMT == S_IFLNK),
                entry.size(),
                entry.compressed_size(),
                entry.crc32(),
            )
        };
        let stored = method == zip::CompressionMethod::Stored;
        let deflated = method == zip::CompressionMethod::Deflated;
        if is_directory_entry(&path)
            && !assets.contains_key(&path)
            && size == 0
            && compressed == 0
            && crc == 0
            && stored
            && !encrypted
            && !symlink
        {
            assets.insert(path, Vec::new());
            continue;
        }
        let max = if path == "manifest.toml" {
            MAX_MANIFEST_BYTES
        } else if path.starts_with("icons/") {
            MAX_ICON_BYTES
        } else if path.rsplit('/').next().is_some_and(|last| last.starts_with("splash_logo.")) {
            MAX_SPLASH_LOGO_BYTES
        } else {
            MAX_BACKGROUND_BYTES
        };
        if path.is_empty()
            || path.starts_with('/')
            || path.contains('\\')
            || path.split('/').any(|part| part.is_empty() || part == "." || part == "..")
            || assets.contains_key(&path)
            || symlink
            || encrypted
            || !(stored || deflated)
            || compressed > MAX_PACKAGE_BYTES as u64
            || size == 0
            || size > max as u64
            || total + size as usize > MAX_PACKAGE_BYTES
        {
            return fail("Invalid theme ZIP entry");
        }
        let mut entry = zip.by_index(i).map_err(|_| ThemeError::new("Invalid theme ZIP entry"))?;
        let mut decoded = Vec::with_capacity(size as usize);
        // Bounded as it is read: the header's size is what the entry claims,
        // not what inflating it produces. A wrong CRC fails the read.
        (&mut entry)
            .take(max as u64 + 1)
            .read_to_end(&mut decoded)
            .map_err(|_| ThemeError::new("Corrupt theme ZIP entry"))?;
        if decoded.len() > max {
            return fail("Theme asset exceeds size limit");
        }
        if decoded.len() as u64 != size {
            return fail("Corrupt theme ZIP entry");
        }
        total += decoded.len();
        assets.insert(path, decoded);
    }
    if !assets.contains_key("manifest.toml") {
        return fail("Missing theme manifest");
    }
    Ok(assets)
}
