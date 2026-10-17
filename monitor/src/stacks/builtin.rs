//! The web apps shipped inside the agent: `store/apps/<id>/`, file by file,
//! so an agent with no network still offers them. A test holds this list
//! equal to the folders.

use std::collections::BTreeMap;
use std::sync::LazyLock;

use super::manifest::Package;

macro_rules! app {
    ($id:literal: $($file:literal),+ $(,)?) => {
        ($id, &[$(($file, include_str!(concat!("../../../store/apps/", $id, "/", $file)))),+])
    };
}

/// Every built-in app's files, by app id.
const FILES: &[(&str, &[(&str, &str)])] = &[
    app!("adguard.adguard_home": "manifest.toml", "compose.yaml", "mcp-gate.conf.template"),
    app!("advplyr.audiobookshelf": "manifest.toml", "compose.yaml"),
    app!("binwiederhier.ntfy": "manifest.toml", "compose.yaml"),
    app!("coder.code_server": "manifest.toml", "compose.yaml"),
    app!("corentinth.it_tools": "manifest.toml", "compose.yaml", "it-tools.Dockerfile"),
    app!("freshrss.freshrss": "manifest.toml", "compose.yaml"),
    app!("futo.immich": "manifest.toml", "compose.yaml", "hwaccel.ml.yml", "hwaccel.transcoding.yml", "mcp-gate.conf.template"),
    app!("gitea.gitea": "manifest.toml", "compose.yaml"),
    app!("gotson.komga": "manifest.toml", "compose.yaml"),
    app!("homeassistant.home_assistant": "manifest.toml", "compose.yaml"),
    app!("janeczku.calibre_web": "manifest.toml", "compose.yaml"),
    app!("jellyfin.jellyfin": "manifest.toml", "compose.yaml", "hwaccel.yml"),
    app!("louislam.uptime_kuma": "manifest.toml", "compose.yaml"),
    app!("mayswind.ariang": "manifest.toml", "compose.yaml", "ariang.Dockerfile"),
    app!("mealie.mealie": "manifest.toml", "compose.yaml"),
    app!("navidrome.navidrome": "manifest.toml", "compose.yaml"),
    app!("nextcloud.nextcloud": "manifest.toml", "compose.yaml"),
    app!("openlistteam.openlist": "manifest.toml", "compose.yaml"),
    app!("openwebui.open_webui": "manifest.toml", "compose.yaml"),
    app!("paperless.paperless_ngx": "manifest.toml", "compose.yaml"),
    app!("qbittorrent.qbittorrent": "manifest.toml", "compose.yaml"),
    app!("sissbruecker.linkding": "manifest.toml", "compose.yaml", "linkding_custom.py"),
    app!("stirling.pdf": "manifest.toml", "compose.yaml"),
    app!("syncthing.syncthing": "manifest.toml", "compose.yaml"),
    app!("transmission.transmission": "manifest.toml", "compose.yaml", "mcp-gate.conf.template"),
    app!("usememos.memos": "manifest.toml", "compose.yaml"),
    app!("vaultwarden.server": "manifest.toml", "compose.yaml"),
];

/// The engines of Local inference (`monitor/inference/engines/`): deployed
/// as stacks, shown in its window, never in the App Store, and never taken
/// from the store or the operator's folder.
macro_rules! part {
    ($id:literal: $($file:literal),+ $(,)?) => {
        ($id, &[$(($file, include_str!(concat!("../../inference/engines/", $id, "/", $file)))),+])
    };
}

const PART_FILES: &[(&str, &[(&str, &str)])] = &[
    part!("ggml.llama_cpp": "manifest.toml", "compose.yaml", "gpu.yml"),
    part!("ollama.ollama": "manifest.toml", "compose.yaml", "gpu.yml"),
    part!("sglang.sglang": "manifest.toml", "compose.yaml"),
    part!("vllm.vllm": "manifest.toml", "compose.yaml"),
];

/// The desk app the parts belong to.
pub const PARTS_OF: &str = "serverbox.inference";

static PACKAGES: LazyLock<Vec<Package>> = LazyLock::new(|| read(FILES));
static PARTS: LazyLock<Vec<Package>> = LazyLock::new(|| read(PART_FILES));

fn read(files: &[(&str, &[(&str, &str)])]) -> Vec<Package> {
    files
        .iter()
        .filter_map(|(id, files)| {
            let files: BTreeMap<String, Vec<u8>> =
                files.iter().map(|(name, text)| (name.to_string(), text.as_bytes().to_vec())).collect();
            match Package::read(&files) {
                Ok(p) if p.manifest.id == *id => Some(p),
                Ok(_) => {
                    tracing::error!("built-in app {id}: its manifest names another id");
                    None
                }
                Err(problems) => {
                    tracing::error!("built-in app {id}: {problems:?}");
                    None
                }
            }
        })
        .collect()
}

pub fn packages() -> &'static [Package] {
    &PACKAGES
}

pub fn parts() -> &'static [Package] {
    &PARTS
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    #[test]
    fn every_store_app_is_built_in_whole() {
        assert_whole(FILES, &Path::new(env!("CARGO_MANIFEST_DIR")).join("../store/apps"));
        assert_eq!(packages().len(), FILES.len(), "every built-in app reads");
    }

    #[test]
    fn every_engine_is_built_in_whole() {
        assert_whole(PART_FILES, &Path::new(env!("CARGO_MANIFEST_DIR")).join("inference/engines"));
        assert_eq!(parts().len(), PART_FILES.len(), "every engine reads");
        assert!(parts().iter().all(|p| p.manifest.llm.is_some() && p.manifest.web.is_none()));
    }

    fn assert_whole(files: &[(&str, &[(&str, &str)])], store: &Path) {
        let mut on_disk = BTreeMap::new();
        for entry in std::fs::read_dir(store).expect("the apps folder") {
            let dir = entry.expect("entry").path();
            if !dir.is_dir() {
                continue;
            }
            let mut names: Vec<String> = std::fs::read_dir(&dir)
                .expect("app folder")
                .map(|e| e.expect("file").file_name().to_string_lossy().into_owned())
                .collect();
            names.sort();
            on_disk.insert(dir.file_name().unwrap().to_string_lossy().into_owned(), names);
        }
        let built_in: BTreeMap<String, Vec<String>> = files
            .iter()
            .map(|(id, files)| {
                let mut names: Vec<String> = files.iter().map(|(n, _)| n.to_string()).collect();
                names.sort();
                (id.to_string(), names)
            })
            .collect();
        assert_eq!(built_in, on_disk, "builtin.rs must list every file of {}", store.display());
    }
}
