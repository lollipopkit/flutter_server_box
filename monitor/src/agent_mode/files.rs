//! Files a task is given: what the account attached in the composer (picked,
//! pasted, dropped). Each is uploaded first (`POST /agent/files`) and waits
//! in `uploads/`, known only to this process, until a task names it; then it
//! moves to `files/<task>/` under the agent's own directory, where the
//! task's commands read it, and goes when the task goes. One nobody names is
//! deleted after [`KEEP_PENDING`], at the account's next upload, or at start.
//!
//! The model is told each file's name, type, size and path; a short text
//! file is put in the prompt whole, and an image goes to the model as an
//! image as well.

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::{Duration, Instant};

use base64::Engine;
use serde::Serialize;
use serde_json::{Value, json};

/// One file's limit.
pub const MAX_BYTES: usize = 20 << 20;
/// Files one task is given.
pub const MAX_PER_TASK: usize = 10;
/// Uploads an account has waiting.
const MAX_PENDING: usize = 16;
const KEEP_PENDING: Duration = Duration::from_secs(3600);
/// Text up to this size is put in the prompt.
const INLINE_TEXT: u64 = 16 << 10;
/// Images up to this size go to the model as images.
const MAX_IMAGE: u64 = 5 << 20;
const MAX_NAME_CHARS: usize = 120;

#[derive(Debug, Clone, Serialize)]
pub struct FileView {
    pub id: String,
    pub name: String,
    pub mime: String,
    pub size: u64,
}

struct Upload {
    user: i64,
    /// Whose it is by name: what [`Files::forget`] is given.
    username: String,
    view: FileView,
    created: Instant,
}

/// A file in a task's directory.
#[derive(Debug, Clone)]
pub struct Attached {
    pub name: String,
    pub mime: String,
    pub size: u64,
    pub path: PathBuf,
}

#[derive(Debug, PartialEq, Eq)]
pub enum FileError {
    TooMany,
    Unknown,
    Io(String),
}

pub struct Files {
    root: PathBuf,
    pending: Mutex<HashMap<String, Upload>>,
}

impl Files {
    /// Under [root], the agent's own directory; made absolute, since the
    /// model is given these paths and a command runs in a directory of its
    /// own.
    pub fn new(root: &Path) -> Self {
        let root = std::path::absolute(root).unwrap_or_else(|_| root.to_path_buf());
        Self { root, pending: Mutex::default() }
    }

    fn uploads(&self) -> PathBuf {
        self.root.join("uploads")
    }

    fn task_dir(&self, flow: &str) -> PathBuf {
        self.root.join("files").join(flow)
    }

    /// At start: what waited is gone with the process that knew it, and a
    /// task no row names has no files.
    pub async fn recover(&self, known: &HashSet<String>) {
        let _ = tokio::fs::remove_dir_all(self.uploads()).await;
        let Ok(mut dirs) = tokio::fs::read_dir(self.root.join("files")).await else { return };
        while let Ok(Some(d)) = dirs.next_entry().await {
            if !known.contains(d.file_name().to_string_lossy().as_ref()) {
                let _ = tokio::fs::remove_dir_all(d.path()).await;
            }
        }
    }

    /// Keeps [bytes] for [user] until a task names it.
    pub async fn put(&self, user: i64, username: &str, name: &str, mime: &str, bytes: &[u8]) -> Result<FileView, FileError> {
        self.expire().await;
        if self.pending.lock().unwrap().values().filter(|u| u.user == user).count() >= MAX_PENDING {
            return Err(FileError::TooMany);
        }
        let id = super::uuid_v4();
        let dir = self.uploads();
        private_dir(&dir).await.map_err(|e| FileError::Io(e.to_string()))?;
        write_private(&dir.join(&id), bytes).await.map_err(|e| FileError::Io(e.to_string()))?;
        let view = FileView { id: id.clone(), name: clean_name(name), mime: clean_mime(mime), size: bytes.len() as u64 };
        self.pending.lock().unwrap().insert(id, Upload { user, username: username.to_string(), view: view.clone(), created: Instant::now() });
        Ok(view)
    }

    /// Removes one of [user]'s waiting uploads.
    pub async fn discard(&self, user: i64, id: &str) -> bool {
        let gone = {
            let mut p = self.pending.lock().unwrap();
            match p.get(id) {
                Some(u) if u.user == user => p.remove(id).is_some(),
                _ => false,
            }
        };
        if gone {
            let _ = tokio::fs::remove_file(self.uploads().join(id)).await;
        }
        gone
    }

    /// Drops what [username] has waiting: the account ended or lost `shell`.
    pub fn forget(&self, username: &str) {
        let gone: Vec<String> = {
            let mut p = self.pending.lock().unwrap();
            let ids: Vec<String> = p.iter().filter(|(_, u)| u.username == username).map(|(id, _)| id.clone()).collect();
            ids.iter().for_each(|id| {
                p.remove(id);
            });
            ids
        };
        // Unlinking a few files; the caller is not async.
        for id in gone {
            let _ = std::fs::remove_file(self.uploads().join(id));
        }
    }

    /// Whether [user] has every one of [ids] waiting.
    pub fn has(&self, user: i64, ids: &[String]) -> bool {
        let p = self.pending.lock().unwrap();
        ids.iter().all(|id| p.get(id).is_some_and(|u| u.user == user))
    }

    /// Moves [user]'s uploads [ids] into [flow]'s directory.
    pub async fn attach(&self, user: i64, flow: &str, ids: &[String]) -> Result<Vec<Attached>, FileError> {
        if ids.len() > MAX_PER_TASK {
            return Err(FileError::TooMany);
        }
        let taken: Vec<FileView> = {
            let mut p = self.pending.lock().unwrap();
            if !ids.iter().all(|id| p.get(id).is_some_and(|u| u.user == user)) || ids.iter().collect::<HashSet<_>>().len() != ids.len() {
                return Err(FileError::Unknown);
            }
            ids.iter().filter_map(|id| p.remove(id)).map(|u| u.view).collect()
        };
        let dir = self.task_dir(flow);
        let mut out = Vec::new();
        // A task given files before keeps them.
        let mut used = HashSet::new();
        if let Ok(mut entries) = tokio::fs::read_dir(&dir).await {
            while let Ok(Some(e)) = entries.next_entry().await {
                used.insert(e.file_name().to_string_lossy().into_owned());
            }
        }
        let result = async {
            if !taken.is_empty() {
                private_dir(&dir).await?;
            }
            for v in &taken {
                let name = unique(&v.name, &mut used);
                let path = dir.join(&name);
                tokio::fs::rename(self.uploads().join(&v.id), &path).await?;
                out.push(Attached { name, mime: v.mime.clone(), size: v.size, path });
            }
            std::io::Result::Ok(())
        }
        .await;
        match result {
            Ok(()) => Ok(out),
            Err(e) => {
                for v in &taken {
                    let _ = tokio::fs::remove_file(self.uploads().join(&v.id)).await;
                }
                let _ = tokio::fs::remove_dir_all(&dir).await;
                Err(FileError::Io(e.to_string()))
            }
        }
    }

    pub async fn remove_task(&self, flow: &str) {
        let _ = tokio::fs::remove_dir_all(self.task_dir(flow)).await;
    }

    async fn expire(&self) {
        let old: Vec<String> = {
            let mut p = self.pending.lock().unwrap();
            let ids: Vec<String> = p.iter().filter(|(_, u)| u.created.elapsed() > KEEP_PENDING).map(|(id, _)| id.clone()).collect();
            ids.iter().for_each(|id| {
                p.remove(id);
            });
            ids
        };
        for id in old {
            let _ = tokio::fs::remove_file(self.uploads().join(id)).await;
        }
    }
}

/// The prompt for [words] with [files]: the text, and pi `ImageContent`
/// parts for the images when [with_images] (where it goes can take them).
/// The list goes in an `<attachments>` block, which the panel shows as the
/// files rather than as text.
pub async fn compose(words: &str, files: &[Attached], with_images: bool) -> (String, Option<Value>) {
    if files.is_empty() {
        return (words.to_string(), None);
    }
    let mut block = String::from("<attachments>\nThe person attached these files; they are on this machine, read them with commands.\n");
    let mut images = Vec::new();
    for f in files {
        block.push_str(&format!("- `{}` ({}, {}) at `{}`", f.name, f.mime, size(f.size), f.path.display()));
        if with_images
            && is_image(&f.mime)
            && f.size <= MAX_IMAGE
            && let Ok(bytes) = tokio::fs::read(&f.path).await
        {
            images.push(json!({ "type": "image", "data": base64::engine::general_purpose::STANDARD.encode(bytes), "mimeType": f.mime }));
            block.push_str(" (the image is attached)");
        } else if f.size <= INLINE_TEXT
            && is_text(&f.mime, &f.name)
            && let Ok(text) = tokio::fs::read_to_string(&f.path).await
        {
            let fence = "`".repeat(longest_backticks(&text).max(2) + 1);
            block.push_str(&format!(":\n{fence}\n{}\n{fence}", text.trim_end_matches('\n')));
        }
        block.push('\n');
    }
    block.push_str("</attachments>");
    let text = if words.trim().is_empty() { block } else { format!("{words}\n\n{block}") };
    (text, (!images.is_empty()).then(|| Value::Array(images)))
}

fn is_image(mime: &str) -> bool {
    matches!(mime, "image/png" | "image/jpeg" | "image/gif" | "image/webp")
}

fn is_text(mime: &str, name: &str) -> bool {
    mime.starts_with("text/")
        || matches!(mime, "application/json" | "application/toml" | "application/x-yaml" | "application/yaml" | "application/xml")
        || name.rsplit_once('.').is_some_and(|(_, ext)| {
            matches!(
                ext.to_ascii_lowercase().as_str(),
                "log" | "txt" | "out" | "conf" | "cfg" | "ini" | "env" | "service" | "yml" | "yaml" | "json" | "toml" | "sh" | "md" | "csv"
            )
        })
}

fn longest_backticks(text: &str) -> usize {
    text.split(|c| c != '`').map(str::len).max().unwrap_or(0)
}

fn size(n: u64) -> String {
    match n {
        n if n < 1024 => format!("{n} B"),
        n if n < 1 << 20 => format!("{:.1} KiB", n as f64 / 1024.0),
        n => format!("{:.1} MiB", n as f64 / (1u64 << 20) as f64),
    }
}

/// A file name to keep: the last path part, no control characters, no
/// leading dot, at most [`MAX_NAME_CHARS`].
fn clean_name(name: &str) -> String {
    let base = name.rsplit(['/', '\\']).next().unwrap_or("");
    let cleaned: String = base.chars().filter(|c| !c.is_control()).take(MAX_NAME_CHARS).collect();
    let cleaned = cleaned.trim().trim_start_matches('.').trim().to_string();
    if cleaned.is_empty() { "file".into() } else { cleaned }
}

fn clean_mime(mime: &str) -> String {
    let m = mime.split(';').next().unwrap_or("").trim().to_ascii_lowercase();
    let ok = m.split_once('/').is_some_and(|(a, b)| {
        let part = |s: &str| !s.is_empty() && s.len() <= 64 && s.chars().all(|c| c.is_ascii_alphanumeric() || "+-.".contains(c));
        part(a) && part(b)
    });
    if ok { m } else { "application/octet-stream".into() }
}

/// [name], or `name (2).ext` when it is taken.
fn unique(name: &str, used: &mut HashSet<String>) -> String {
    let mut candidate = name.to_string();
    let (stem, ext) = match name.rsplit_once('.') {
        Some((s, e)) if !s.is_empty() => (s.to_string(), format!(".{e}")),
        _ => (name.to_string(), String::new()),
    };
    let mut n = 2;
    while used.contains(&candidate) {
        candidate = format!("{stem} ({n}){ext}");
        n += 1;
    }
    used.insert(candidate.clone());
    candidate
}

async fn private_dir(dir: &Path) -> std::io::Result<()> {
    tokio::fs::create_dir_all(dir).await?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        tokio::fs::set_permissions(dir, std::fs::Permissions::from_mode(0o700)).await?;
    }
    Ok(())
}

async fn write_private(path: &Path, bytes: &[u8]) -> std::io::Result<()> {
    let mut opts = tokio::fs::OpenOptions::new();
    opts.write(true).create_new(true);
    #[cfg(unix)]
    opts.mode(0o600);
    use tokio::io::AsyncWriteExt;
    let mut f = opts.open(path).await?;
    f.write_all(bytes).await?;
    f.flush().await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names_are_kept_to_their_last_part_and_made_unique() {
        assert_eq!(clean_name("../../etc/passwd"), "passwd");
        assert_eq!(clean_name("C:\\logs\\a.log"), "a.log");
        assert_eq!(clean_name(".env"), "env");
        assert_eq!(clean_name("..\u{0}"), "file");
        let mut used = HashSet::new();
        assert_eq!(unique("a.log", &mut used), "a.log");
        assert_eq!(unique("a.log", &mut used), "a (2).log");
        assert_eq!(unique("a.log", &mut used), "a (3).log");
    }

    #[test]
    fn a_type_is_kept_only_when_it_looks_like_one() {
        assert_eq!(clean_mime("text/plain; charset=utf-8"), "text/plain");
        assert_eq!(clean_mime("image/PNG"), "image/png");
        assert_eq!(clean_mime("text/plain\r\nX: y"), "application/octet-stream");
        assert_eq!(clean_mime(""), "application/octet-stream");
    }

    #[tokio::test]
    async fn uploads_are_the_accounts_own_and_move_into_the_task() {
        let root = std::env::temp_dir().join(format!("sbm-agent-files-{}", std::process::id()));
        let files = Files::new(&root);
        let a = files.put(1, "a", "app.log", "text/plain", b"line ```x```\n").await.unwrap();
        let b = files.put(1, "a", "app.log", "image/png", b"\x89PNG").await.unwrap();
        assert!(!files.has(2, std::slice::from_ref(&a.id)));
        assert_eq!(files.attach(2, "t", std::slice::from_ref(&a.id)).await.err(), Some(FileError::Unknown));
        let got = files.attach(1, "t", &[a.id.clone(), b.id.clone()]).await.unwrap();
        assert_eq!(got[1].name, "app (2).log");
        assert!(got.iter().all(|f| f.path.exists() && f.path.is_absolute()));
        assert!(Files::new(Path::new("rel")).task_dir("t").is_absolute());
        // Taken once.
        assert_eq!(files.attach(1, "u", std::slice::from_ref(&a.id)).await.err(), Some(FileError::Unknown));
        let (text, images) = compose("look", &got, true).await;
        assert!(text.starts_with("look\n\n<attachments>\n"), "{text}");
        assert!(text.contains("````\nline ```x```\n````"), "{text}");
        assert_eq!(images.unwrap()[0]["mimeType"], "image/png");
        // A second batch keeps the first.
        let c = files.put(1, "a", "app.log", "text/plain", b"again").await.unwrap();
        let more = files.attach(1, "t", std::slice::from_ref(&c.id)).await.unwrap();
        assert_eq!(more[0].name, "app (3).log");
        assert!(compose("", &got, false).await.1.is_none());
        files.remove_task("t").await;
        assert!(!got[0].path.exists());
        // An account that ends takes what it had waiting.
        let w = files.put(1, "a", "x.txt", "text/plain", b"x").await.unwrap();
        let other = files.put(2, "b", "y.txt", "text/plain", b"y").await.unwrap();
        files.forget("a");
        assert!(!files.has(1, std::slice::from_ref(&w.id)) && !root.join("uploads").join(&w.id).exists());
        assert!(files.has(2, std::slice::from_ref(&other.id)));
        let _ = std::fs::remove_dir_all(&root);
    }
}
