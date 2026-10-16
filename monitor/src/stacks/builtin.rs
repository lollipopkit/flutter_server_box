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
    app!("adguard.adguard_home": "manifest.toml", "compose.yaml"),
    app!("coder.code_server": "manifest.toml", "compose.yaml"),
    app!("freshrss.freshrss": "manifest.toml", "compose.yaml"),
    app!("futo.immich": "manifest.toml", "compose.yaml", "hwaccel.ml.yml", "hwaccel.transcoding.yml"),
    app!("gotson.komga": "manifest.toml", "compose.yaml"),
    app!("homeassistant.home_assistant": "manifest.toml", "compose.yaml"),
    app!("janeczku.calibre_web": "manifest.toml", "compose.yaml"),
    app!("jellyfin.jellyfin": "manifest.toml", "compose.yaml", "hwaccel.yml"),
    app!("louislam.uptime_kuma": "manifest.toml", "compose.yaml"),
    app!("mayswind.ariang": "manifest.toml", "compose.yaml", "ariang.Dockerfile"),
    app!("navidrome.navidrome": "manifest.toml", "compose.yaml"),
    app!("nextcloud.nextcloud": "manifest.toml", "compose.yaml"),
    app!("openlistteam.openlist": "manifest.toml", "compose.yaml"),
    app!("qbittorrent.qbittorrent": "manifest.toml", "compose.yaml"),
    app!("stirling.pdf": "manifest.toml", "compose.yaml"),
    app!("syncthing.syncthing": "manifest.toml", "compose.yaml"),
    app!("transmission.transmission": "manifest.toml", "compose.yaml"),
    app!("usememos.memos": "manifest.toml", "compose.yaml"),
    app!("vaultwarden.server": "manifest.toml", "compose.yaml"),
];

static PACKAGES: LazyLock<Vec<Package>> = LazyLock::new(|| {
    FILES
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
});

pub fn packages() -> &'static [Package] {
    &PACKAGES
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    #[test]
    fn every_store_app_is_built_in_whole() {
        let store = Path::new(env!("CARGO_MANIFEST_DIR")).join("../store/apps");
        let mut on_disk = BTreeMap::new();
        for entry in std::fs::read_dir(&store).expect("store/apps") {
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
        let built_in: BTreeMap<String, Vec<String>> = FILES
            .iter()
            .map(|(id, files)| {
                let mut names: Vec<String> = files.iter().map(|(n, _)| n.to_string()).collect();
                names.sort();
                (id.to_string(), names)
            })
            .collect();
        assert_eq!(built_in, on_disk, "builtin.rs FILES must list every file of store/apps");
        assert_eq!(packages().len(), FILES.len(), "every built-in app reads");
    }
}
