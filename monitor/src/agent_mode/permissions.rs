//! The monitor's stored [`Permissions`] (migration 023). What they mean and
//! how a command is decided by them is `fl_pi_llm::permissions`, the
//! one logic the app's Agent decides by too.

use sqlx::SqlitePool;

pub use fl_pi_llm::permissions::*;

pub async fn load(db: &SqlitePool) -> Result<Permissions, sqlx::Error> {
    let row = sqlx::query_as::<_, (String, bool, String, String)>(
        "SELECT default_mode, disable_bypass, rules, auto_mode FROM agent_permissions WHERE id = 1",
    )
    .fetch_optional(db)
    .await?;
    Ok(match row {
        Some((mode, disable_bypass, rules, auto_mode)) => Permissions {
            default_mode: Mode::parse(&mode),
            disable_bypass,
            rules: serde_json::from_str(&rules).unwrap_or_default(),
            auto_mode: serde_json::from_str(&auto_mode).unwrap_or_default(),
        },
        None => Permissions::default(),
    })
}

pub async fn store(db: &SqlitePool, p: &Permissions) -> Result<(), sqlx::Error> {
    sqlx::query(
        "INSERT INTO agent_permissions (id, default_mode, disable_bypass, rules, auto_mode, updated_at) VALUES (1, ?, ?, ?, ?, ?) \
         ON CONFLICT(id) DO UPDATE SET default_mode = excluded.default_mode, disable_bypass = excluded.disable_bypass, \
         rules = excluded.rules, auto_mode = excluded.auto_mode, updated_at = excluded.updated_at",
    )
    .bind(p.default_mode.as_str())
    .bind(p.disable_bypass)
    .bind(serde_json::to_string(&p.rules).expect("rules serialise"))
    .bind(serde_json::to_string(&p.auto_mode).expect("auto mode serialises"))
    .bind(chrono::Utc::now().to_rfc3339())
    .execute(db)
    .await?;
    Ok(())
}
