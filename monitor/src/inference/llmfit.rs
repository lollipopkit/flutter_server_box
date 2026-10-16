//! llmfit (`github.com/AlexsJones/llmfit`, MIT): its release for this
//! platform, fetched on first use and checked against the SHA-256 compiled
//! into `sbm_parser::inference`, then run for its recommendations.

use std::collections::HashMap;
use std::io::Read;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{Duration, Instant};

use sbm_parser::inference::{self as model, Hardware, LlmfitModel, RecommendQuery};
use sha2::{Digest, Sha256};

use crate::api::desk_themes::{Fetch, HttpFetch};

/// The archive's largest size: the releases are about 7 MB.
const MAX_ARCHIVE: usize = 32 << 20;
/// llmfit's answer for 300 models is about 600 KB.
const MAX_OUTPUT: u64 = 32 << 20;
const RUN_TIMEOUT: Duration = Duration::from_secs(120);
/// How long an answer is kept, by its arguments.
const TTL: Duration = Duration::from_secs(600);

/// When llmfit answered, and its models.
type Answer = (Instant, Arc<Vec<LlmfitModel>>);

pub struct Llmfit {
    /// `<inference>/llmfit-<version>`, holding the binary.
    dir: PathBuf,
    fetch: std::sync::RwLock<Arc<dyn Fetch>>,
    /// One download at a time.
    fetching: tokio::sync::Mutex<()>,
    answers: tokio::sync::Mutex<HashMap<Vec<String>, Answer>>,
}

impl Llmfit {
    pub fn new(dir: PathBuf) -> Self {
        Self {
            dir,
            fetch: std::sync::RwLock::new(Arc::new(HttpFetch::default())),
            fetching: tokio::sync::Mutex::new(()),
            answers: tokio::sync::Mutex::default(),
        }
    }

    /// Where the release is read from: for tests.
    pub fn set_fetch(&self, fetch: Arc<dyn Fetch>) {
        use crate::utils::lock::RwLockExt;
        *self.fetch.write_locked() = fetch;
    }

    fn binary(&self) -> PathBuf {
        self.dir.join(if cfg!(windows) { "llmfit.exe" } else { "llmfit" })
    }

    pub fn installed(&self) -> bool {
        self.binary().is_file()
    }

    /// The binary, fetched first when it is not there.
    async fn ensure(&self, hw: &Hardware) -> Result<PathBuf, String> {
        let bin = self.binary();
        if bin.is_file() {
            return Ok(bin);
        }
        let _one = self.fetching.lock().await;
        if bin.is_file() {
            return Ok(bin);
        }
        let asset = model::llmfit_asset(&hw.os, &hw.arch).ok_or_else(|| format!("no llmfit release for {} {}", hw.os, hw.arch))?;
        let fetch = {
            use crate::utils::lock::RwLockExt;
            self.fetch.read_locked().clone()
        };
        let bytes = fetch.get(&model::llmfit_url(asset), MAX_ARCHIVE).await?;
        let digest = hex::encode(Sha256::digest(&bytes));
        if digest != asset.sha256 {
            return Err(format!("{}: SHA-256 {digest}, expected {}", asset.file, asset.sha256));
        }
        let dir = self.dir.clone();
        let target = bin.clone();
        tokio::task::spawn_blocking(move || unpack(&bytes, &dir, &target)).await.map_err(|e| e.to_string())??;
        Ok(bin)
    }

    /// llmfit's models for [hw] and [query], from its answer of the last ten
    /// minutes when there is one.
    pub async fn recommend(&self, hw: &Hardware, query: &RecommendQuery) -> Result<Arc<Vec<LlmfitModel>>, String> {
        let args = model::recommend_args(hw, query).map_err(str::to_owned)?;
        if let Some((at, models)) = self.answers.lock().await.get(&args)
            && at.elapsed() < TTL
        {
            return Ok(models.clone());
        }
        let bin = self.ensure(hw).await?;
        let out = run(&bin, &args).await?;
        let models = Arc::new(model::parse_recommend(&out).map_err(|e| format!("llmfit's answer: {e}"))?.models);
        self.answers.lock().await.insert(args, (Instant::now(), models.clone()));
        Ok(models)
    }
}

/// Writes the archive's `llmfit` to [target], through a staged file.
fn unpack(bytes: &[u8], dir: &std::path::Path, target: &std::path::Path) -> Result<(), String> {
    std::fs::create_dir_all(dir).map_err(|e| e.to_string())?;
    let name = target.file_name().and_then(|n| n.to_str()).unwrap_or("llmfit").to_string();
    let mut archive = tar::Archive::new(flate2::read::GzDecoder::new(bytes));
    for entry in archive.entries().map_err(|e| e.to_string())? {
        let mut entry = entry.map_err(|e| e.to_string())?;
        let is_it = entry.header().entry_type().is_file() && entry.path().ok().and_then(|p| p.file_name().map(|n| n == name.as_str())).unwrap_or(false);
        if !is_it {
            continue;
        }
        let mut data = Vec::new();
        entry.by_ref().take(256 << 20).read_to_end(&mut data).map_err(|e| e.to_string())?;
        let part = target.with_extension("part");
        std::fs::write(&part, &data).map_err(|e| e.to_string())?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&part, std::fs::Permissions::from_mode(0o755)).map_err(|e| e.to_string())?;
        }
        return std::fs::rename(&part, target).map_err(|e| e.to_string());
    }
    Err(format!("no {name} in the archive"))
}

/// Runs llmfit with [args]; its JSON on stdout. WSL keeps `nvidia-smi` in
/// `/usr/lib/wsl/lib`, outside the agent's `PATH`.
async fn run(bin: &std::path::Path, args: &[String]) -> Result<String, String> {
    use tokio::io::AsyncReadExt;
    let path = std::env::var("PATH").unwrap_or_default();
    let mut child = tokio::process::Command::new(bin)
        .args(args)
        .env("PATH", format!("{path}:/usr/lib/wsl/lib"))
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .kill_on_drop(true)
        .spawn()
        .map_err(|e| format!("llmfit: {e}"))?;
    let mut stdout = child.stdout.take().expect("piped");
    let mut stderr = child.stderr.take().expect("piped");
    let work = async {
        let mut out = Vec::new();
        let mut err = Vec::new();
        let (mut o, mut e) = ((&mut stdout).take(MAX_OUTPUT), (&mut stderr).take(64 << 10));
        let (a, b) = tokio::join!(o.read_to_end(&mut out), e.read_to_end(&mut err));
        a.map_err(|e| e.to_string())?;
        b.map_err(|e| e.to_string())?;
        let status = child.wait().await.map_err(|e| e.to_string())?;
        Ok::<_, String>((status, out, err))
    };
    let (status, out, err) = tokio::time::timeout(RUN_TIMEOUT, work).await.map_err(|_| "llmfit timed out".to_string())??;
    if !status.success() {
        return Err(format!("llmfit exited with {status}: {}", String::from_utf8_lossy(&err).trim()));
    }
    String::from_utf8(out).map_err(|_| "llmfit's answer is not UTF-8".into())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn archive(files: &[(&str, &[u8])]) -> Vec<u8> {
        let mut tar = tar::Builder::new(flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::fast()));
        for (path, data) in files {
            let mut header = tar::Header::new_gnu();
            header.set_size(data.len() as u64);
            header.set_mode(0o755);
            header.set_cksum();
            tar.append_data(&mut header, path, *data).unwrap();
        }
        tar.into_inner().unwrap().finish().unwrap()
    }

    #[test]
    fn unpacks_the_binary_alone() {
        let dir = tempfile::tempdir().unwrap();
        let target = dir.path().join("llmfit");
        let bytes = archive(&[("llmfit-v1/README.md", b"x"), ("llmfit-v1/llmfit", b"#!/bin/sh\n")]);
        unpack(&bytes, dir.path(), &target).unwrap();
        assert_eq!(std::fs::read(&target).unwrap(), b"#!/bin/sh\n");
        assert!(unpack(&archive(&[("a/other", b"")]), dir.path(), &dir.path().join("x")).is_err());
    }
}
