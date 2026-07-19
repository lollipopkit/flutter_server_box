//! 首次启动引导:users 表为空时创建随机密码的初始 admin

use crate::utils::error::Result;
use crate::utils::secrets::random_password;
use sqlx::SqlitePool;
use tracing::info;

pub const INITIAL_ADMIN: &str = "admin";

pub async fn ensure_admin_user(pool: &SqlitePool) -> Result<()> {
    let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users")
        .fetch_one(pool)
        .await?;
    if count > 0 {
        return Ok(());
    }

    let password = random_password(24)?;
    let hash = crate::api::auth::hash_password(&password)?;
    sqlx::query("INSERT INTO users (username, password_hash) VALUES (?, ?)")
        .bind(INITIAL_ADMIN)
        .bind(hash)
        .execute(pool)
        .await?;

    info!("No users found; created initial admin user");
    // 明文密码仅此一次输出到 stdout,不落库不落日志文件
    println!("=====================================================");
    println!("  Initial admin credentials (shown only once)");
    println!("    username: {INITIAL_ADMIN}");
    println!("    password: {password}");
    println!("  Change it: server_box_monitor user set-password {INITIAL_ADMIN}");
    println!("=====================================================");
    Ok(())
}

/// 设置/重置用户密码;用户不存在时创建
pub async fn set_password(pool: &SqlitePool, username: &str, password: &str) -> Result<()> {
    let hash = crate::api::auth::hash_password(password)?;
    sqlx::query(
        "INSERT INTO users (username, password_hash) VALUES (?, ?)
         ON CONFLICT(username) DO UPDATE SET password_hash = excluded.password_hash",
    )
    .bind(username)
    .bind(hash)
    .execute(pool)
    .await?;
    Ok(())
}
