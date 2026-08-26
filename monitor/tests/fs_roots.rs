//! What keeps `/api/v1/fs/*` from being a shell with extra steps.
//!
//! Every one of these is a way out of the roots that has to stay closed. They
//! test `FsRoots` directly rather than through the HTTP layer because that is
//! where the decision is made — a handler that skips it is a bug no test of
//! the handler would catch.

use std::fs;
use std::path::{Path, PathBuf};

use server_box_monitor::core::fs_roots::{FsDenied, FsRoots};

/// A root with a file and a subdirectory in it, plus a sibling directory
/// outside the root to try to reach.
struct Sandbox {
    _dir: tempfile::TempDir,
    root: PathBuf,
    outside: PathBuf,
    roots: FsRoots,
}

fn sandbox() -> Sandbox {
    let dir = tempfile::tempdir().expect("temp dir");
    // Canonicalised because macOS puts temp dirs under a symlinked `/var`, and
    // a test comparing a resolved path against an unresolved root would fail
    // for reasons that have nothing to do with what it is testing.
    let base = fs::canonicalize(dir.path()).expect("canonical base");
    let root = base.join("root");
    let outside = base.join("outside");
    fs::create_dir(&root).unwrap();
    fs::create_dir(&outside).unwrap();
    fs::write(root.join("inside.txt"), b"in").unwrap();
    fs::write(outside.join("secret.txt"), b"out").unwrap();
    fs::create_dir(root.join("sub")).unwrap();

    let roots = FsRoots::from_canonical(vec![root.clone()]);
    Sandbox {
        _dir: dir,
        root,
        outside,
        roots,
    }
}

fn s(path: &Path) -> String {
    path.to_string_lossy().into_owned()
}

fn request_path(path: &Path) -> String {
    let raw = s(path);
    #[cfg(windows)]
    {
        if let Some(rest) = raw.strip_prefix(r"\\?\UNC\") {
            return format!(r"\\{rest}");
        }
        if let Some(rest) = raw.strip_prefix(r"\\?\") {
            return rest.to_string();
        }
    }
    raw
}

fn filesystem_root() -> PathBuf {
    std::env::current_dir()
        .expect("current directory")
        .ancestors()
        .last()
        .expect("filesystem root")
        .to_path_buf()
}

#[test]
fn a_path_inside_a_root_resolves() {
    let sb = sandbox();

    let resolved = sb
        .roots
        .resolve_existing(&s(&sb.root.join("inside.txt")))
        .expect("inside the root");

    assert_eq!(resolved, sb.root.join("inside.txt"));
}

#[test]
fn a_path_outside_every_root_is_refused() {
    let sb = sandbox();

    let err = sb
        .roots
        .resolve_existing(&s(&sb.outside.join("secret.txt")))
        .unwrap_err();

    assert_eq!(err, FsDenied::OutsideRoots);
}

#[test]
fn dot_dot_is_refused_even_when_it_would_land_inside() {
    // `/root/sub/../inside.txt` is inside the root. It is still refused: a
    // client that knows where it wants to go can say so, and allowing it would
    // make the two resolvers have to agree about a partly-resolvable `..`.
    let sb = sandbox();
    let root = request_path(&sb.root);
    let requested = if cfg!(windows) {
        format!(r"{root}\sub\..\inside.txt")
    } else {
        format!("{root}/sub/../inside.txt")
    };

    let err = sb.roots.resolve_existing(&requested).unwrap_err();

    assert_eq!(err, FsDenied::Traversal);
}

#[cfg(unix)]
#[test]
fn a_symlink_pointing_out_of_the_root_is_refused() {
    // The reason resolution happens before the check. Textually
    // `<root>/escape/secret.txt` is inside the root; it is not.
    let sb = sandbox();
    std::os::unix::fs::symlink(&sb.outside, sb.root.join("escape")).unwrap();

    let err = sb
        .roots
        .resolve_existing(&s(&sb.root.join("escape").join("secret.txt")))
        .unwrap_err();

    assert_eq!(err, FsDenied::OutsideRoots);
}

#[cfg(unix)]
#[test]
fn a_symlink_staying_inside_the_root_is_allowed() {
    // The check is about where a path lands, not about links being suspicious.
    let sb = sandbox();
    std::os::unix::fs::symlink(sb.root.join("inside.txt"), sb.root.join("link")).unwrap();

    let resolved = sb
        .roots
        .resolve_existing(&s(&sb.root.join("link")))
        .expect("still inside");

    assert_eq!(resolved, sb.root.join("inside.txt"));
}

#[cfg(unix)]
#[test]
fn a_directory_entry_resolution_preserves_the_final_symlink() {
    let sb = sandbox();
    let link = sb.root.join("link");
    std::os::unix::fs::symlink(&sb.outside, &link).unwrap();

    let resolved = sb
        .roots
        .resolve_entry(&s(&link))
        .expect("the link entry is inside the root");

    assert_eq!(resolved, link);
    assert!(
        fs::symlink_metadata(resolved)
            .unwrap()
            .file_type()
            .is_symlink()
    );
}

#[cfg(unix)]
#[test]
fn a_write_through_a_symlinked_parent_is_refused() {
    // The new-path resolver anchors on the deepest existing ancestor, so a
    // link in the middle has to be caught there too.
    let sb = sandbox();
    std::os::unix::fs::symlink(&sb.outside, sb.root.join("escape")).unwrap();

    let err = sb
        .roots
        .resolve_new(&s(&sb.root.join("escape").join("planted.sh")))
        .unwrap_err();

    assert_eq!(err, FsDenied::OutsideRoots);
}

#[test]
fn a_file_that_does_not_exist_yet_resolves_under_its_parent() {
    let sb = sandbox();

    let resolved = sb
        .roots
        .resolve_new(&s(&sb.root.join("sub").join("new.txt")))
        .expect("a new file in an existing directory");

    assert_eq!(resolved, sb.root.join("sub").join("new.txt"));
}

#[test]
fn a_directory_tree_that_does_not_exist_yet_resolves() {
    let sb = sandbox();

    let resolved = sb
        .roots
        .resolve_new(&s(&sb.root.join("a").join("b").join("c")))
        .expect("several missing levels");

    assert_eq!(resolved, sb.root.join("a").join("b").join("c"));
}

#[test]
fn a_new_path_outside_the_roots_is_refused() {
    let sb = sandbox();

    let err = sb
        .roots
        .resolve_new(&s(&sb.outside.join("planted.sh")))
        .unwrap_err();

    assert_eq!(err, FsDenied::OutsideRoots);
}

#[test]
fn a_relative_path_is_refused() {
    // There is no working directory a client and this agent would agree on.
    let sb = sandbox();

    assert_eq!(
        sb.roots.resolve_existing("inside.txt").unwrap_err(),
        FsDenied::NotAbsolute
    );
    assert_eq!(
        sb.roots.resolve_new("sub/new.txt").unwrap_err(),
        FsDenied::NotAbsolute
    );
}

#[test]
fn a_sibling_sharing_a_prefix_is_not_inside() {
    // `/var/logs` must not read as being under `/var/log`. A string prefix
    // comparison would say it is.
    let dir = tempfile::tempdir().unwrap();
    let base = fs::canonicalize(dir.path()).unwrap();
    fs::create_dir(base.join("log")).unwrap();
    fs::create_dir(base.join("logs")).unwrap();
    let roots = FsRoots::from_canonical(vec![base.join("log")]);

    assert_eq!(
        roots.resolve_existing(&s(&base.join("logs"))).unwrap_err(),
        FsDenied::OutsideRoots
    );
}

#[test]
fn no_roots_means_nothing_resolves() {
    // The state an operator lands in by switching the API on without saying
    // where. `fs_available()` is false, and even if it were not, this holds.
    let roots = FsRoots::from_canonical(vec![]);

    assert!(roots.is_empty());
    let existing = std::env::current_dir().expect("current directory");
    assert_eq!(
        roots.resolve_existing(&s(&existing)).unwrap_err(),
        FsDenied::OutsideRoots
    );
}

#[test]
fn the_filesystem_root_is_recognised_as_unrestricted() {
    // What the startup warning keys on.
    assert!(FsRoots::from_canonical(vec![filesystem_root()]).is_unrestricted());
    let nested = std::env::current_dir().expect("current directory");
    assert!(!FsRoots::from_canonical(vec![nested]).is_unrestricted());
}

#[test]
fn a_root_is_not_renamable_out_from_under_the_confinement() {
    // `remove` refuses this; `rename` did not, and moving a root leaves it
    // pointing at a path that no longer exists — after which every request is
    // refused because nothing under it can be canonicalised.
    //
    // Checked here as the property the handler relies on: the root is one of
    // `as_slice`, and that is what the guard compares against.
    let sb = sandbox();

    let resolved = sb.roots.resolve_existing(&s(&sb.root)).unwrap();

    assert!(sb.roots.as_slice().contains(&resolved));
}

#[test]
fn an_unusable_root_is_dropped_rather_than_fatal() {
    let dir = tempfile::tempdir().unwrap();
    let base = fs::canonicalize(dir.path()).unwrap();
    fs::create_dir(base.join("real")).unwrap();

    let roots = FsRoots::resolve(&[s(&base.join("real")), s(&base.join("does-not-exist"))]);

    assert_eq!(roots.as_slice().len(), 1);
    assert!(roots.resolve_existing(&s(&base.join("real"))).is_ok());
}
