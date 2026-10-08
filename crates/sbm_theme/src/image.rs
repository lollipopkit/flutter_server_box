//! The two raster formats a package may carry, and how large they may be:
//! fl_lib reads the dimensions from the encoded header
//! (`ImageDescriptor.encoded`) without decoding the pixels, and so does this.

use crate::error::{Result, fail};

pub fn is_png(bytes: &[u8]) -> bool {
    bytes.starts_with(&[137, 80, 78, 71, 13, 10, 26, 10])
}

pub fn is_jpeg(bytes: &[u8]) -> bool {
    bytes.len() >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff
}

/// Refuses an image whose header cannot be read or which is larger than
/// [max_dimension] on a side or [max_pixels] in all.
pub fn verify(bytes: &[u8], max_dimension: u64, max_pixels: u64) -> Result<()> {
    let Ok(size) = imagesize::blob_size(bytes) else {
        return fail("Invalid image data");
    };
    let (w, h) = (size.width as u64, size.height as u64);
    if w == 0 || h == 0 {
        return fail("Invalid image data");
    }
    if w > max_dimension || h > max_dimension || w * h > max_pixels {
        return fail("Image resolution exceeds limit");
    }
    Ok(())
}
