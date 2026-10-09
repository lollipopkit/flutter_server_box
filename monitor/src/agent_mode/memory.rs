//! An account's memory (`fl_pi_llm::host::memory`), kept in `agent_memory`.

use fl_pi_llm::host::BoxFuture;
use fl_pi_llm::host::memory::{Change, MemoryBackend, MemoryFile};
use sqlx::SqlitePool;

pub(super) struct DbMemory {
    pub db: SqlitePool,
    pub user_id: i64,
}

impl MemoryBackend for DbMemory {
    fn list(&self) -> BoxFuture<'_, Result<Vec<MemoryFile>, String>> {
        Box::pin(async move {
            let rows: Vec<(String, String, String)> =
                sqlx::query_as("SELECT path, content, updated_at FROM agent_memory WHERE user_id = ?")
                    .bind(self.user_id)
                    .fetch_all(&self.db)
                    .await
                    .map_err(|e| e.to_string())?;
            Ok(rows
                .into_iter()
                .map(|(key, content, at)| MemoryFile {
                    key,
                    content,
                    modified: chrono::DateTime::parse_from_rfc3339(&at).ok().map(|t| t.timestamp_millis()),
                })
                .collect())
        })
    }

    fn apply(&self, change: Change) -> BoxFuture<'_, Result<(), String>> {
        Box::pin(async move {
            let now = chrono::Utc::now().to_rfc3339();
            let mut tx = self.db.begin().await.map_err(|e| e.to_string())?;
            for key in &change.remove {
                sqlx::query("DELETE FROM agent_memory WHERE user_id = ? AND path = ?")
                    .bind(self.user_id)
                    .bind(key)
                    .execute(&mut *tx)
                    .await
                    .map_err(|e| e.to_string())?;
            }
            for (key, content) in &change.put {
                sqlx::query(
                    "INSERT INTO agent_memory (user_id, path, content, updated_at) VALUES (?, ?, ?, ?) \
                     ON CONFLICT (user_id, path) DO UPDATE SET content = excluded.content, updated_at = excluded.updated_at",
                )
                .bind(self.user_id)
                .bind(key)
                .bind(content)
                .bind(&now)
                .execute(&mut *tx)
                .await
                .map_err(|e| e.to_string())?;
            }
            tx.commit().await.map_err(|e| e.to_string())
        })
    }
}
