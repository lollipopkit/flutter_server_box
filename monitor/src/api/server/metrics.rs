//! The numbers: `/status`, `/metrics`, `/metrics/history`, `/velocity*`.

use crate::{
    api::authz,
    monitoring::{self, SystemMetrics},
    monitoring::velocity::{NetworkSpeedInfo, VelocityAnalysisResponse},
    utils::error::Result,
};
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Serialize;
use std::sync::Arc;
use super::*;

#[derive(Serialize)]
pub(super) struct StatusResponse {
    name: String,
    cpu: String,
    memory: String,
    disk: String,
    network: String,
    temperature: Option<String>,
    timestamp: String,
}

pub(super) async fn get_status(
    req: HttpRequest,
    app_state: Arc<AppState>,
) -> Result<HttpResponse> {
    require_read_access!(&req, &app_state);
    touch_viewer_heartbeat(&app_state).await;

    let metrics = app_state.current_metrics.read().await;

    if let Some(ref metrics) = *metrics {
        let response = StatusResponse {
            name: metrics.server_name.clone(),
            cpu: format!("{:.1}%", metrics.cpu_usage),
            memory: format!(
                "{:.1}% ({} / {})",
                metrics.memory.usage_percent,
                format_bytes(metrics.memory.used),
                format_bytes(metrics.memory.total)
            ),
            disk: format!(
                "{:.1}% ({} / {})",
                metrics.disk.usage_percent,
                format_bytes(metrics.disk.used),
                format_bytes(metrics.disk.total)
            ),
            network: format!(
                "RX: {} / TX: {}",
                format_bytes(metrics.network.rx_bytes),
                format_bytes(metrics.network.tx_bytes)
            ),
            temperature: metrics.temperature.map(|t| format!("{:.1}°C", t)),
            timestamp: metrics.timestamp.to_rfc3339(),
        };

        Ok(HttpResponse::Ok().json(&response))
    } else {
        Ok(HttpResponse::ServiceUnavailable().json(&ErrorResponse {
            error: "Metrics not available yet".to_string(),
        }))
    }
}

pub(super) async fn get_metrics(
    req: HttpRequest,
    app_state: Arc<AppState>,
) -> Result<HttpResponse> {
    require_read_access!(&req, &app_state);
    touch_viewer_heartbeat(&app_state).await;

    let metrics = app_state.current_metrics.read().await;

    if let Some(ref metrics) = *metrics {
        let body = metrics_json(metrics)?;
        Ok(HttpResponse::Ok().json(&body))
    } else {
        Ok(HttpResponse::ServiceUnavailable().json(&ErrorResponse {
            error: "Metrics not available yet".to_string(),
        }))
    }
}

/// Keep the established numeric fields for existing clients, while exposing
/// exact decimal forms for browser clients that cannot represent every u64.
pub(super) fn metrics_json(metrics: &SystemMetrics) -> serde_json::Result<serde_json::Value> {
    let mut value = serde_json::to_value(metrics)?;
    add_exact_counters(
        &mut value,
        &metrics.network,
        &metrics.ifaces,
        &metrics.diskio,
    );
    Ok(value)
}

pub(super) fn add_exact_counters(
    value: &mut serde_json::Value,
    network_metrics: &monitoring::NetworkMetrics,
    iface_metrics: &[monitoring::IfaceMetrics],
    diskio_metrics: &[sbm_parser::types::DiskIoPiece],
) {
    if let Some(network) = value.get_mut("network").and_then(serde_json::Value::as_object_mut) {
        network.insert(
            "rx_bytes_exact".to_string(),
            serde_json::Value::String(network_metrics.rx_bytes.to_string()),
        );
        network.insert(
            "tx_bytes_exact".to_string(),
            serde_json::Value::String(network_metrics.tx_bytes.to_string()),
        );
    }

    if let Some(ifaces) = value.get_mut("ifaces").and_then(serde_json::Value::as_array_mut) {
        for (wire, source) in ifaces.iter_mut().zip(iface_metrics) {
            if let Some(wire) = wire.as_object_mut() {
                wire.insert(
                    "rx_bytes_exact".to_string(),
                    serde_json::Value::String(source.rx_bytes.to_string()),
                );
                wire.insert(
                    "tx_bytes_exact".to_string(),
                    serde_json::Value::String(source.tx_bytes.to_string()),
                );
            }
        }
    }

    if let Some(diskio) = value.get_mut("diskio").and_then(serde_json::Value::as_array_mut) {
        for (wire, source) in diskio.iter_mut().zip(diskio_metrics) {
            if let Some(wire) = wire.as_object_mut() {
                wire.insert(
                    "sectors_read_exact".to_string(),
                    serde_json::Value::String(source.sectors_read.to_string()),
                );
                wire.insert(
                    "sectors_write_exact".to_string(),
                    serde_json::Value::String(source.sectors_write.to_string()),
                );
            }
        }
    }
}

/// One numeric query parameter, or `None` when it is absent or unreadable.
///
/// Read by hand rather than deserialised into a struct: these are integers
/// with no encoding to undo, and every one of them is clamped at the use site
/// anyway, so a bad value and a missing value have the same answer.
pub(super) fn query_param<T: std::str::FromStr>(query: &str, name: &str) -> Option<T> {
    raw_param(query, name).and_then(|v| v.parse().ok())
}

/// The parameter as it was written, or `None` when it was not written at all.
///
/// The difference matters wherever a default is not the same answer as a
/// refusal: `?from=yesterday` is a caller asking for a window, and reading it
/// as "no window given" answers with the default hour and calls it what was
/// asked for.
pub(super) fn raw_param<'a>(query: &'a str, name: &str) -> Option<&'a str> {
    query
        .split('&')
        .find_map(|kv| kv.strip_prefix(name)?.strip_prefix('='))
}

#[derive(Serialize)]
pub(super) struct HistoryPoint {
    timestamp: String,
    cpu: f64,
    memory: f64,
    /// Percent, or absent on a machine with no swap — which is not the same
    /// as swap sitting at zero, and is the one a chart must not draw a line
    /// for.
    swap: Option<f64>,
    disk: f64,
    net_rx_speed: f64,
    net_tx_speed: f64,
    temperature: Option<f64>,
    diskio_read_speed: f64,
    diskio_write_speed: f64,
    battery_percent: Option<f64>,
}

/// Bucketed time series from system_metrics.
///
/// `?minutes=` selects a window ending now (default 60, clamped to 5..=10080),
/// or `?from=` and `?to=` name one outright, as epoch seconds — `to` defaults
/// to now, and `minutes` is ignored when `from` is given. `?max_points=` says
/// how many points to answer with (default 300, clamped to 2..=300). Rows are
/// averaged into that many buckets and network rates are derived from
/// consecutive cumulative counters.
///
/// An explicit window is not clamped to the `minutes` ceiling. A client asking
/// for more than this agent kept is not a client to correct: it gets the rows
/// there are, and the gap between what it asked for and what came back is
/// something only it can draw. Silently narrowing the window would report a
/// full one.
///
/// The count is the caller's to pick because it is a property of what is
/// drawing the result, not of what is stored: a home widget a few hundred
/// pixels wide cannot render 300 points, and asking for them means carrying
/// them over the network to throw them away. Thinning here is also better
/// than thinning on the client — an average over a wider bucket keeps the
/// spikes that dropping every third row loses.
pub(super) async fn get_metrics_history(
    req: HttpRequest,
    app_state: Arc<AppState>,
) -> Result<HttpResponse> {
    require_read_access!(&req, &app_state);

    let query = req.query_string();
    let now = chrono::Utc::now();
    // Both bounds are bound as `DateTime<Utc>`, so sqlx encodes them with the
    // same RFC 3339 form `store_metrics` writes the column with and the
    // comparison is between values of one shape.
    //
    // It was `datetime('now', '-N minutes')`, whose output is
    // `2026-09-08 07:28:22` while the column holds
    // `2026-09-08T08:28:18.493098803+00:00`. Both are text, so SQLite compares
    // them as text, and `'T'` sorts above `' '`: every row sharing the
    // boundary's *date* compared greater regardless of its time. The window
    // was therefore "since midnight UTC" whenever that was the longer of the
    // two — 4255 rows scanned for a 60-minute window holding 496, and the
    // factor grows through the UTC day to 24x.

    // A bound that was given but cannot be read is a refusal, not a default:
    // the caller is asking for a window, and answering with a different one is
    // how a client bug becomes a chart nobody questions.
    let bound = |name: &str| -> std::result::Result<Option<i64>, ()> {
        match raw_param(query, name) {
            None => Ok(None),
            Some(raw) => raw.parse::<i64>().map(Some).map_err(|_| ()),
        }
    };
    let bad_request = |message: &str| {
        Ok(HttpResponse::BadRequest().json(&ErrorResponse {
            error: message.to_string(),
        }))
    };
    let (Ok(from_param), Ok(to_param)) = (bound("from"), bound("to")) else {
        return bad_request("from/to must be epoch seconds");
    };

    // The window, as either of the two ways of naming one.
    let (cutoff, until) = match from_param {
        Some(from) => {
            let to = to_param.unwrap_or(now.timestamp());
            let from = chrono::DateTime::from_timestamp(from, 0);
            let to = chrono::DateTime::from_timestamp(to, 0);
            match (from, to) {
                // Refused rather than swapped or widened: an inverted window is
                // a caller bug, and answering it with something plausible is
                // how it stays one.
                (Some(from), Some(to)) if to > from => (from, Some(to)),
                _ => {
                    return bad_request("from/to must be epoch seconds with to > from");
                }
            }
        }
        None => {
            let minutes: i64 = query_param(query, "minutes")
                .unwrap_or(60)
                .clamp(5, 7 * 24 * 60);
            // `to` without `from` is a length ending somewhere other than now
            // — "the hour before the alert" — and dropping it answered with
            // the hour before *this request* instead, which looks like an
            // answer to the question that was asked.
            match to_param {
                None => (now - chrono::Duration::minutes(minutes), None),
                Some(to) => match chrono::DateTime::from_timestamp(to, 0) {
                    Some(to) => (to - chrono::Duration::minutes(minutes), Some(to)),
                    None => return bad_request("to must be epoch seconds"),
                },
            }
        }
    };
    let span_secs = (until.unwrap_or(now) - cutoff).num_seconds().max(1);

    /// What this endpoint has always answered with, and still does for a
    /// caller that names no count.
    const MAX_POINTS: i64 = 300;
    let max_points: i64 = query_param(query, "max_points")
        .unwrap_or(MAX_POINTS)
        .clamp(2, MAX_POINTS);

    // Rounded up, so the window divides into no more buckets than were asked
    // for. Rounding down leaves buckets narrower than the window/count ratio
    // and answers with more points than the caller said it could take —
    // `minutes=7&max_points=100` is 4-second buckets and 105 of them.
    // `i64::div_ceil` is still unstable; both operands are positive here.
    let bucket_secs = ((span_secs + max_points - 1) / max_points).max(1);

    use sqlx::Row;
    let rows = sqlx::query(
        "SELECT cast(strftime('%s', timestamp) as integer) / ?1 AS bucket,                 min(timestamp) AS ts,                 avg(cpu_usage) AS cpu,                 avg(CASE WHEN memory_total > 0 THEN memory_used * 100.0 / memory_total END) AS mem,                 avg(CASE WHEN swap_total > 0 THEN swap_used * 100.0 / swap_total END) AS swap,                 avg(CASE WHEN disk_total > 0 THEN disk_used * 100.0 / disk_total END) AS disk,                 avg(network_rx_bytes) AS rx,                 avg(network_tx_bytes) AS tx,                 avg(temperature) AS temp,                 avg(diskio_read_bytes) AS dio_r,                 avg(diskio_write_bytes) AS dio_w,                 avg(battery_percent) AS battery          FROM system_metrics          WHERE timestamp >= ?2 AND (?3 IS NULL OR timestamp <= ?3)          GROUP BY bucket ORDER BY bucket",
    )
    .bind(bucket_secs)
    .bind(cutoff)
    .bind(until)
    .fetch_all(&app_state.db)
    .await?;

    let mut points = Vec::with_capacity(rows.len());
    // (bucket, rx, tx, diskio_read, diskio_write)
    let mut prev: Option<(i64, f64, f64, f64, f64)> = None;
    for row in rows {
        let bucket: i64 = row.get("bucket");
        let rx: f64 = row.try_get("rx").unwrap_or(0.0);
        let tx: f64 = row.try_get("tx").unwrap_or(0.0);
        let dio_r: f64 = row.try_get("dio_r").unwrap_or(0.0);
        let dio_w: f64 = row.try_get("dio_w").unwrap_or(0.0);
        let (net_rx_speed, net_tx_speed, diskio_read_speed, diskio_write_speed) = match prev {
            Some((pb, prx, ptx, pdr, pdw)) if bucket > pb => {
                let dt = ((bucket - pb) * bucket_secs) as f64;
                (
                    ((rx - prx) / dt).max(0.0),
                    ((tx - ptx) / dt).max(0.0),
                    ((dio_r - pdr) / dt).max(0.0),
                    ((dio_w - pdw) / dt).max(0.0),
                )
            }
            _ => (0.0, 0.0, 0.0, 0.0),
        };
        prev = Some((bucket, rx, tx, dio_r, dio_w));
        points.push(HistoryPoint {
            timestamp: row.get("ts"),
            cpu: row.try_get("cpu").unwrap_or(0.0),
            memory: row.try_get("mem").unwrap_or(0.0),
            swap: row.try_get::<Option<f64>, _>("swap").ok().flatten(),
            disk: row.try_get("disk").unwrap_or(0.0),
            net_rx_speed,
            net_tx_speed,
            temperature: row.try_get::<Option<f64>, _>("temp").ok().flatten(),
            diskio_read_speed,
            diskio_write_speed,
            battery_percent: row.try_get::<Option<f64>, _>("battery").ok().flatten(),
        });
    }

    // A bucket boundary is an absolute multiple of `bucket_secs` while the
    // window's start is wherever "now minus N minutes" falls, so the first
    // bucket is a partial one and the count can come out one over. Drop from
    // the old end: the rates above are derived from consecutive buckets, so
    // they have to be computed over the whole series before anything is cut.
    let max_points = max_points as usize;
    if points.len() > max_points {
        points.drain(..points.len() - max_points);
    }

    Ok(HttpResponse::Ok().json(&points))
}

pub(super) async fn get_velocity(
    req: HttpRequest,
    app_state: Arc<AppState>,
) -> Result<HttpResponse> {
    require_read_access!(&req, &app_state);

    let server_name = app_state.config.get_server_name();

    // Everything this handler needs comes from one guard. A temporary in a
    // `match` scrutinee lives to the end of the match, so taking the lock
    // there and again inside an arm deadlocks against the monitoring loop's
    // writer: tokio's RwLock is fair, so the queued writer blocks the second
    // reader while itself waiting on the first guard.
    let sampled = {
        let velocity = app_state.velocity_manager.read().await;
        match velocity.get_server_velocity(&server_name).await {
            Ok(velocity_data) => {
                let network_totals = velocity.get_network_totals(&server_name).await;
                let is_ready = velocity.is_ready(&server_name).await;
                Ok((velocity_data, network_totals, is_ready))
            }
            Err(e) => Err(e),
        }
    };

    match sampled {
        Ok((velocity_data, network_totals, is_ready)) => {
            let network_info = NetworkSpeedInfo::new(
                velocity_data.network_rx_speed,
                velocity_data.network_tx_speed,
                network_totals.map(|(rx, _)| rx),
                network_totals.map(|(_, tx)| tx),
            );

            let response = VelocityAnalysisResponse::new(
                network_info,
                velocity_data.cpu_usage_percent,
                is_ready,
            );

            Ok(HttpResponse::Ok().json(&response))
        }
        Err(e) => Ok(HttpResponse::InternalServerError().json(&ErrorResponse {
            error: format!("Failed to get velocity data: {}", e),
        })),
    }
}

pub(super) async fn get_velocity_history(
    req: HttpRequest,
    app_state: Arc<AppState>,
) -> Result<HttpResponse> {
    require_read_access!(&req, &app_state);

    let query = web::types::Query::<serde_json::Value>::from_query(req.query_string())
        .unwrap_or_else(|_| web::types::Query(serde_json::Value::Object(serde_json::Map::new())));

    let limit = query
        .get("limit")
        .and_then(|v| {
            v.as_u64().or_else(|| {
                v.as_str()
                    .and_then(|s| s.parse::<u64>().ok())
            })
        })
        .map(|l| l as usize);

    match app_state
        .velocity_manager
        .read()
        .await
        .get_server_velocity_history(&app_state.config.get_server_name(), limit)
        .await
    {
        Ok(history) => Ok(HttpResponse::Ok().json(&history)),
        Err(e) => Ok(HttpResponse::InternalServerError().json(&ErrorResponse {
            error: format!("Failed to get velocity history: {}", e),
        })),
    }
}

/// The idle-pause heartbeat: called from the endpoints the panel actually
/// polls while open (`/metrics`, `/status`), not every authenticated
/// request — a one-off `/capabilities`/`/settings` fetch shouldn't count as
/// "someone's actively watching."
pub(super) async fn touch_viewer_heartbeat(app_state: &AppState) {
    *app_state.last_viewer_seen.write().await = chrono::Utc::now();
}

pub(super) fn format_bytes(bytes: u64) -> String {
    const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB"];
    let mut size = bytes as f64;
    let mut unit_index = 0;

    while size >= 1024.0 && unit_index < UNITS.len() - 1 {
        size /= 1024.0;
        unit_index += 1;
    }

    if unit_index == 0 {
        format!("{} {}", bytes, UNITS[unit_index])
    } else {
        format!("{:.1} {}", size, UNITS[unit_index])
    }
}

#[cfg(test)]
mod metrics_json_tests {
    use super::*;

    #[test]
    fn cumulative_counters_include_exact_decimal_strings() {
        let network = monitoring::NetworkMetrics {
            rx_bytes: 9_007_199_254_740_993,
            tx_bytes: 9_007_199_254_740_994,
        };
        let ifaces = [monitoring::IfaceMetrics {
            name: "eth0".to_string(),
            rx_bytes: 9_007_199_254_740_995,
            tx_bytes: 9_007_199_254_740_996,
        }];
        let diskio = [sbm_parser::types::DiskIoPiece {
            dev: "sda".to_string(),
            sectors_read: 9_007_199_254_740_997,
            sectors_write: 9_007_199_254_740_998,
        }];
        let mut value = serde_json::json!({
            "network": { "rx_bytes": network.rx_bytes, "tx_bytes": network.tx_bytes },
            "ifaces": [{ "name": "eth0", "rx_bytes": ifaces[0].rx_bytes, "tx_bytes": ifaces[0].tx_bytes }],
            "diskio": [{ "dev": "sda", "sectors_read": diskio[0].sectors_read, "sectors_write": diskio[0].sectors_write }],
        });

        add_exact_counters(&mut value, &network, &ifaces, &diskio);

        assert_eq!(value["network"]["rx_bytes_exact"], "9007199254740993");
        assert_eq!(value["ifaces"][0]["tx_bytes_exact"], "9007199254740996");
        assert_eq!(value["diskio"][0]["sectors_read_exact"], "9007199254740997");
    }
}
