//! Credentials at rest ([`FIELDS`]): AES-256-GCM (ring) under the key in
//! `credentials.key` beside the database (0600, made on first use, never
//! replaced), each value bound to its column, so a sealed value moved to
//! another column does not open.
//!
//! What this keeps out of reach is the database without the key: a copy of
//! the file, a disk image without the agent's directory. Whoever reads both,
//! as the agent's account can, reads the credentials; `fs_roots::Protected`
//! keeps the key from `/fs` with the database.
//!
//! A stored value is `sealed:v1:` + base64url(nonce ‖ ciphertext ‖ tag). The
//! empty string is stored as it is: there is nothing in it to hide, and a
//! sealed one would still say how long it is. A settings backup carries the
//! values in clear ([`Sealer::unseal_all`]) inside its own encryption, so it
//! restores on a machine with another key ([`Sealer::seal_all`]).
//!
//! A lost key loses the credentials, not the rest: each one reads as
//! [`Error::Unreadable`] until it is entered again.

use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};

use base64::Engine as _;
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use ring::aead::{AES_256_GCM, Aad, LessSafeKey, NONCE_LEN, Nonce, UnboundKey};
use sqlx::{SqliteConnection, SqlitePool};
use zeroize::Zeroizing;

use crate::utils::lock::LockExt;

/// A column holding a credential.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Field {
    pub table: &'static str,
    pub column: &'static str,
    /// `NOT NULL`: none is `""` there, `NULL` elsewhere.
    pub required: bool,
}

const fn field(table: &'static str, column: &'static str) -> Field {
    Field { table, column, required: false }
}

const fn required(table: &'static str, column: &'static str) -> Field {
    Field { table, column, required: true }
}

pub const BMC_PASSWORD: Field = field("bmc_target", "password");
pub const PVE_PASSWORD: Field = field("virt_pve", "password");
pub const PVE_TOKEN_SECRET: Field = field("virt_pve", "token_secret");
pub const AGENT_CREDENTIAL: Field = required("agent_credential", "credential");
pub const AGENT_MCP_HEADERS: Field = required("agent_mcp_server", "headers");
pub const STACK_MCP_TOKEN: Field = field("stack_mcp", "token");
pub const MCP_OAUTH_CLIENT_SECRET: Field = field("mcp_oauth", "client_secret");
pub const MCP_OAUTH_ACCESS_TOKEN: Field = required("mcp_oauth", "access_token");
pub const MCP_OAUTH_REFRESH_TOKEN: Field = field("mcp_oauth", "refresh_token");
pub const BACKUP_PASSWORD: Field = field("monitor_backup", "password");

/// Every column holding a credential. A new one goes here
/// (`every_credential_column_is_sealed`).
pub const FIELDS: &[Field] = &[
    BMC_PASSWORD,
    PVE_PASSWORD,
    PVE_TOKEN_SECRET,
    AGENT_CREDENTIAL,
    AGENT_MCP_HEADERS,
    STACK_MCP_TOKEN,
    MCP_OAUTH_CLIENT_SECRET,
    MCP_OAUTH_ACCESS_TOKEN,
    MCP_OAUTH_REFRESH_TOKEN,
    BACKUP_PASSWORD,
];

const PREFIX: &str = "sealed:v1:";
const KEY_LEN: usize = 32;
const KEY_FILE: &str = "credentials.key";

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("credentials key {}: {source}", path.display())]
    Key { path: PathBuf, source: std::io::Error },
    #[error("system RNG unavailable")]
    Rng,
    #[error("a stored {0} cannot be read with this monitor's credentials key")]
    Unreadable(String),
    #[error(transparent)]
    Db(#[from] sqlx::Error),
}

impl From<Error> for sqlx::Error {
    fn from(e: Error) -> Self {
        match e {
            Error::Db(e) => e,
            other => sqlx::Error::Decode(Box::new(other)),
        }
    }
}

/// Seals and opens [`FIELDS`] with one database's key.
pub struct Sealer {
    /// `None`: an in-memory database's, whose key lives as long as this.
    file: Option<PathBuf>,
    key: OnceLock<LessSafeKey>,
    loading: Mutex<()>,
}

impl Sealer {
    /// The key of the database file [db_file].
    pub fn beside(db_file: &Path) -> Self {
        Self { file: Some(Self::key_path_beside(db_file)), key: OnceLock::new(), loading: Mutex::new(()) }
    }

    /// A key of its own, in memory only.
    pub fn temporary() -> Self {
        Self { file: None, key: OnceLock::new(), loading: Mutex::new(()) }
    }

    /// The key of the database [db] opened.
    pub fn of(db: &SqlitePool) -> Self {
        match crate::api::server::sqlite_file_of(db) {
            Some(file) => Self::beside(&file),
            None => Self::temporary(),
        }
    }

    pub fn key_path_beside(db_file: &Path) -> PathBuf {
        db_file.with_file_name(KEY_FILE)
    }

    /// Reads the key, or makes it on first use: at startup, so that a key
    /// that cannot be read stops the agent before a request finds out.
    pub fn ready(&self) -> Result<(), Error> {
        self.key().map(drop)
    }

    fn key(&self) -> Result<&LessSafeKey, Error> {
        if let Some(k) = self.key.get() {
            return Ok(k);
        }
        let _loading = self.loading.locked();
        if let Some(k) = self.key.get() {
            return Ok(k);
        }
        let bytes = match &self.file {
            Some(path) => load_or_create(path).map_err(|source| Error::Key { path: path.clone(), source })?,
            None => random_key()?,
        };
        let key = LessSafeKey::new(UnboundKey::new(&AES_256_GCM, &bytes[..]).expect("a 32-byte key"));
        Ok(self.key.get_or_init(|| key))
    }

    pub fn seal(&self, field: Field, plain: &str) -> Result<String, Error> {
        if plain.is_empty() {
            return Ok(String::new());
        }
        let key = self.key()?;
        let mut nonce = [0u8; NONCE_LEN];
        getrandom::fill(&mut nonce).map_err(|_| Error::Rng)?;
        let mut data = plain.as_bytes().to_vec();
        key.seal_in_place_append_tag(Nonce::assume_unique_for_key(nonce), aad(field), &mut data)
            .map_err(|_| Error::Rng)?;
        let mut out = nonce.to_vec();
        out.extend_from_slice(&data);
        Ok(format!("{PREFIX}{}", URL_SAFE_NO_PAD.encode(out)))
    }

    pub fn open(&self, field: Field, stored: &str) -> Result<String, Error> {
        if stored.is_empty() {
            return Ok(String::new());
        }
        let unreadable = || Error::Unreadable(format!("{}.{}", field.table, field.column));
        let raw = stored.strip_prefix(PREFIX).and_then(|b| URL_SAFE_NO_PAD.decode(b).ok()).ok_or_else(unreadable)?;
        if raw.len() < NONCE_LEN {
            return Err(unreadable());
        }
        let (nonce, sealed) = raw.split_at(NONCE_LEN);
        let nonce = Nonce::try_assume_unique_for_key(nonce).map_err(|_| unreadable())?;
        let key = self.key()?;
        let mut data = sealed.to_vec();
        let plain = key.open_in_place(nonce, aad(field), &mut data).map_err(|_| unreadable())?;
        String::from_utf8(plain.to_vec()).map_err(|_| unreadable())
    }

    pub fn seal_opt(&self, field: Field, plain: Option<&str>) -> Result<Option<String>, Error> {
        plain.map(|p| self.seal(field, p)).transpose()
    }

    pub fn open_opt(&self, field: Field, stored: Option<&str>) -> Result<Option<String>, Error> {
        stored.map(|s| self.open(field, s)).transpose()
    }

    /// [stored] opened, or none (logged) when this key no longer opens it:
    /// `NULL`, or `""` in a [`Field::required`] column. A key that cannot be
    /// read is still an error.
    pub fn open_or_none(&self, field: Field, stored: Option<&str>) -> Result<Option<String>, Error> {
        match self.open_opt(field, stored) {
            Err(Error::Unreadable(what)) => {
                tracing::warn!("{what}: cannot be read with this monitor's credentials key; taken as none");
                Ok(field.required.then(String::new))
            }
            other => other,
        }
    }

    /// Seals what an older agent stored in clear. At startup, before anything
    /// reads one. TODO: remove once every agent has started on a build that
    /// seals.
    pub async fn seal_legacy(&self, db: &SqlitePool) -> Result<(), Error> {
        match self.seal_all(&mut *db.acquire().await?, "main").await? {
            0 => {}
            n => tracing::info!("Sealed {n} stored credentials"),
        }
        Ok(())
    }

    /// Seals every value of [`FIELDS`] in [schema] still in clear: a
    /// restored backup's, and what an older agent stored ([`Self::seal_legacy`]).
    pub async fn seal_all(&self, conn: &mut SqliteConnection, schema: &str) -> Result<u64, Error> {
        self.rewrite(conn, schema, |s| !s.starts_with(PREFIX), |f, v| self.seal(f, v).map(Some)).await
    }

    /// Opens every sealed value of [`FIELDS`] in [schema]: a backup's copy.
    /// One this key no longer opens goes as none ([`Self::open_or_none`]).
    pub async fn unseal_all(&self, conn: &mut SqliteConnection, schema: &str) -> Result<u64, Error> {
        self.rewrite(conn, schema, |s| s.starts_with(PREFIX), |f, v| self.open_or_none(f, Some(v))).await
    }

    async fn rewrite(
        &self,
        conn: &mut SqliteConnection,
        schema: &str,
        pick: impl Fn(&str) -> bool,
        map: impl Fn(Field, &str) -> Result<Option<String>, Error>,
    ) -> Result<u64, Error> {
        use super::ident;
        let mut n = 0;
        for &f in FIELDS {
            let (s, t, c) = (ident(schema), ident(f.table), ident(f.column));
            let rows: Vec<(i64, String)> =
                sqlx::query_as(sqlx::AssertSqlSafe(format!("SELECT rowid, {c} FROM {s}.{t} WHERE {c} IS NOT NULL AND {c} != ''")))
                    .fetch_all(&mut *conn)
                    .await?;
            for (rowid, value) in rows.into_iter().filter(|(_, v)| pick(v)) {
                sqlx::query(sqlx::AssertSqlSafe(format!("UPDATE {s}.{t} SET {c} = ? WHERE rowid = ?")))
                    .bind(map(f, &value)?)
                    .bind(rowid)
                    .execute(&mut *conn)
                    .await?;
                n += 1;
            }
        }
        Ok(n)
    }
}

fn aad(field: Field) -> Aad<String> {
    Aad::from(format!("{}.{}", field.table, field.column))
}

fn random_key() -> Result<Zeroizing<[u8; KEY_LEN]>, Error> {
    let mut key = Zeroizing::new([0u8; KEY_LEN]);
    getrandom::fill(&mut key[..]).map_err(|_| Error::Rng)?;
    Ok(key)
}

/// The key at [path], or a new one put there. Never replaces a file: one
/// that does not hold a key is refused, since replacing it would lose every
/// credential sealed with what it held.
fn load_or_create(path: &Path) -> std::io::Result<Zeroizing<[u8; KEY_LEN]>> {
    loop {
        match std::fs::read_to_string(path) {
            Ok(text) => {
                restrict(path)?;
                let text = Zeroizing::new(text);
                let mut key = Zeroizing::new([0u8; KEY_LEN]);
                hex::decode_to_slice(text.trim(), &mut key[..]).map_err(|_| {
                    std::io::Error::new(std::io::ErrorKind::InvalidData, "not a key; the credentials it sealed cannot be read without it")
                })?;
                return Ok(key);
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
            Err(e) => return Err(e),
        }
        let key = random_key().map_err(std::io::Error::other)?;
        // Whole on the disk before it has a name, and given one only if
        // there is none: two processes starting at once both end with the
        // key that won.
        let tmp = path.with_extension(format!("tmp-{}-{}", std::process::id(), crate::utils::secrets::random_hex(4).map_err(std::io::Error::other)?));
        let written = crate::core::config_file::write_private_new(&tmp, Zeroizing::new(hex::encode(&key[..]) + "\n").as_bytes())
            .and_then(|()| std::fs::hard_link(&tmp, path));
        let _ = std::fs::remove_file(&tmp);
        match written {
            Ok(()) => {
                crate::core::config_file::sync_parent_dir(path).map_err(std::io::Error::other)?;
                tracing::info!("Generated the credentials key at {}", path.display());
                return Ok(key);
            }
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(e) => return Err(e),
        }
    }
}

#[cfg(unix)]
fn restrict(path: &Path) -> std::io::Result<()> {
    use std::os::unix::fs::PermissionsExt;
    if std::fs::metadata(path)?.permissions().mode() & 0o077 != 0 {
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))?;
    }
    Ok(())
}

#[cfg(not(unix))]
fn restrict(_path: &Path) -> std::io::Result<()> {
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_value_opens_only_in_its_own_column() {
        let s = Sealer::temporary();
        let sealed = s.seal(BMC_PASSWORD, "hunter2").unwrap();
        assert!(sealed.starts_with(PREFIX));
        assert_ne!(sealed, s.seal(BMC_PASSWORD, "hunter2").unwrap(), "a nonce of its own");
        assert_eq!(s.open(BMC_PASSWORD, &sealed).unwrap(), "hunter2");
        assert!(matches!(s.open(PVE_PASSWORD, &sealed), Err(Error::Unreadable(_))));
        assert!(matches!(Sealer::temporary().open(BMC_PASSWORD, &sealed), Err(Error::Unreadable(_))));
        assert!(matches!(s.open(BMC_PASSWORD, "hunter2"), Err(Error::Unreadable(_))), "clear is not opened");
        assert_eq!(s.seal(BMC_PASSWORD, "").unwrap(), "");
        assert_eq!(s.open(BMC_PASSWORD, "").unwrap(), "");
    }

    #[test]
    fn the_key_file_is_made_once_and_kept() {
        let dir = tempfile::tempdir().unwrap();
        let db = dir.path().join("monitor.db");
        let sealed = Sealer::beside(&db).seal(AGENT_CREDENTIAL, "k").unwrap();
        let path = Sealer::key_path_beside(&db);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            assert_eq!(std::fs::metadata(&path).unwrap().permissions().mode() & 0o777, 0o600);
        }
        assert_eq!(Sealer::beside(&db).open(AGENT_CREDENTIAL, &sealed).unwrap(), "k");
        assert_eq!(std::fs::read_dir(dir.path()).unwrap().count(), 1, "no temporary file left");

        std::fs::write(&path, "").unwrap();
        assert!(matches!(Sealer::beside(&db).ready(), Err(Error::Key { .. })), "a damaged key is not replaced");
        assert_eq!(std::fs::read_to_string(&path).unwrap(), "");
    }

    #[tokio::test]
    async fn every_credential_column_is_sealed() {
        let db = sqlx::sqlite::SqlitePoolOptions::new().max_connections(1).connect("sqlite::memory:").await.unwrap();
        crate::db::database::MIGRATOR.run(&db).await.unwrap();
        let columns: Vec<(String, String, bool)> = sqlx::query_as(
            "SELECT m.name, p.name, p.\"notnull\" FROM sqlite_master m JOIN pragma_table_info(m.name) p WHERE m.type = 'table' \
             AND (p.name LIKE '%password%' OR p.name LIKE '%secret%' OR p.name LIKE '%token%' OR p.name LIKE '%credential%' \
             OR p.name = 'headers')",
        )
        .fetch_all(&db)
        .await
        .unwrap();
        // Hashes, and names of where a token comes from.
        let not_secret = ["password_hash", "password_changed_ms", "token_hash", "token_endpoint", "token_id"];
        for (table, column, _) in columns.iter().filter(|(_, c, _)| !not_secret.contains(&c.as_str())) {
            assert!(FIELDS.iter().any(|f| f.table == table && f.column == column), "{table}.{column} is not in FIELDS");
        }
        for f in FIELDS {
            assert!(columns.iter().any(|(t, c, _)| t == f.table && c == f.column), "{}.{} is no column", f.table, f.column);
            let notnull = columns.iter().any(|(t, c, n)| t == f.table && c == f.column && *n);
            assert_eq!(f.required, notnull, "{}.{}: required is NOT NULL", f.table, f.column);
        }
    }

    #[tokio::test]
    async fn seal_all_and_unseal_all_round_trip() {
        let db = sqlx::sqlite::SqlitePoolOptions::new().max_connections(1).connect("sqlite::memory:").await.unwrap();
        crate::db::database::MIGRATOR.run(&db).await.unwrap();
        sqlx::query("INSERT INTO agent_credential (provider_id, credential, updated_at) VALUES ('a', '{\"key\":\"x\"}', ''), ('b', '', '')")
            .execute(&db)
            .await
            .unwrap();
        let s = Sealer::temporary();
        let mut conn = db.acquire().await.unwrap();
        assert_eq!(s.seal_all(&mut conn, "main").await.unwrap(), 1);
        assert_eq!(s.seal_all(&mut conn, "main").await.unwrap(), 0, "a sealed value is left as it is");
        let stored: String = sqlx::query_scalar("SELECT credential FROM agent_credential WHERE provider_id = 'a'").fetch_one(&mut *conn).await.unwrap();
        assert_eq!(s.open(AGENT_CREDENTIAL, &stored).unwrap(), "{\"key\":\"x\"}");
        assert_eq!(s.unseal_all(&mut conn, "main").await.unwrap(), 1);
        let stored: String = sqlx::query_scalar("SELECT credential FROM agent_credential WHERE provider_id = 'a'").fetch_one(&mut *conn).await.unwrap();
        assert_eq!(stored, "{\"key\":\"x\"}");
    }
}
