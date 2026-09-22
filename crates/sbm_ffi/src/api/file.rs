//! Filesystem operations whose guarantees are not exposed by `dart:io`.

use std::fs::{self, File, OpenOptions};
use std::io::{self, ErrorKind};

/// Copies `source` into a newly created `destination` without following an
/// existing destination symlink or replacing any existing entry.
///
/// The exclusive create and all writes use the same file descriptor. Returns
/// `false` when another entry already owns the destination name.
pub fn copy_file_exclusive(source: String, destination: String) -> Result<bool, String> {
    copy_file_exclusive_impl(&source, &destination).map_err(|error| error.to_string())
}

fn copy_file_exclusive_impl(source: &str, destination: &str) -> io::Result<bool> {
    let mut input = File::open(source)?;
    let mut output = match OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(destination)
    {
        Ok(file) => file,
        Err(error) if error.kind() == ErrorKind::AlreadyExists => return Ok(false),
        Err(error) => return Err(error),
    };

    if let Err(error) = io::copy(&mut input, &mut output) {
        drop(output);
        let _ = fs::remove_file(destination);
        return Err(error);
    }

    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn test_dir(name: &str) -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system clock should be after Unix epoch")
            .as_nanos();
        std::env::temp_dir().join(format!("serverbox-{name}-{}-{nonce}", std::process::id()))
    }

    #[test]
    fn copies_to_a_new_destination_without_replacing_it() {
        let root = test_dir("exclusive-copy");
        fs::create_dir(&root).unwrap();
        let source = root.join("source");
        let destination = root.join("destination");
        fs::write(&source, b"legacy").unwrap();

        assert!(
            copy_file_exclusive_impl(source.to_str().unwrap(), destination.to_str().unwrap())
                .unwrap()
        );
        assert_eq!(fs::read(&destination).unwrap(), b"legacy");

        fs::write(&source, b"new").unwrap();
        assert!(
            !copy_file_exclusive_impl(source.to_str().unwrap(), destination.to_str().unwrap())
                .unwrap()
        );
        assert_eq!(fs::read(&destination).unwrap(), b"legacy");
        fs::remove_dir_all(root).unwrap();
    }

    #[cfg(unix)]
    #[test]
    fn rejects_an_existing_destination_symlink() {
        use std::os::unix::fs::symlink;

        let root = test_dir("exclusive-copy-symlink");
        fs::create_dir(&root).unwrap();
        let source = root.join("source");
        let victim = root.join("victim");
        let destination = root.join("destination");
        fs::write(&source, b"legacy").unwrap();
        fs::write(&victim, b"keep").unwrap();
        symlink(&victim, &destination).unwrap();

        assert!(
            !copy_file_exclusive_impl(source.to_str().unwrap(), destination.to_str().unwrap())
                .unwrap()
        );
        assert_eq!(fs::read(&victim).unwrap(), b"keep");
        fs::remove_dir_all(root).unwrap();
    }
}
