//! `?max_points=` on `GET /api/v1/metrics/history`.
//!
//! How many points come back is the caller's decision, because it is a
//! property of what is drawing them: a home widget a few hundred pixels wide
//! cannot render 300, and asking for 300 means carrying them over a phone's
//! radio to throw most of them away. What the agent does with the number is
//! widen its buckets, so the answer still covers the whole window and still
//! averages every row in it — a spike survives thinning here that would not
//! survive a client dropping every Nth point.
//!
//! Two things are easy to get wrong and are asserted below: the count is a
//! ceiling rather than a suggestion, including for windows that do not divide
//! by it evenly; and a caller that names no count still gets the 300 this
//! endpoint has always answered with, since watches and widgets in the field
//! are asking exactly as they always did.

use std::sync::{Arc, Once};

use chrono::{DateTime, Duration, Utc};
use ntex::web::App;
use ntex::web::test::{self as web_test, TestServer};
use rustls::crypto::ring;
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
use server_box_monitor::core::config::Config;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

/// The test client speaks TLS whether or not this server does, and rustls
/// refuses to pick a provider for itself.
fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

/// One row every 10 seconds over the last [`minutes`], which is denser than
/// any point count asked for below — so a short answer is the bucketing and
/// not a shortage of rows.
async fn state_with_samples(minutes: i64) -> Arc<AppState> {
    state_with_samples_every(minutes * 60, 10).await
}

/// One row every [`step_secs`] over the last [`span_secs`].
///
/// The step matters to the two tests below that are about bucket *width*: a
/// bucket narrower than the gap between rows holds one row like any other, so
/// a fixture at 10-second spacing answers identically whether the width was
/// rounded up or down and proves nothing either way.
async fn state_with_samples_every(span_secs: i64, step_secs: i64) -> Arc<AppState> {
    let rows = span_secs / step_secs;
    let now = Utc::now();
    let at: Vec<_> = (0..rows)
        .map(|i| now - Duration::seconds((rows - i) * step_secs))
        .collect();
    state_with(&at).await
}

/// One row per instant given, in the order given.
async fn state_with(at: &[DateTime<Utc>]) -> Arc<AppState> {
    ensure_crypto_provider();
    let config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();

    for (i, at) in at.iter().enumerate() {
        insert_sample(&db, *at, i as i64).await;
    }

    AppState::new(Arc::new(config), db)
}

/// One row, timestamped the way `store_metrics` timestamps one.
///
/// The column is written by binding a `DateTime<Utc>`, which sqlx encodes as
/// RFC 3339 (`2026-09-08T08:28:18.493098803+00:00`). A fixture that reached
/// for `datetime('now', ...)` instead — as this one did — writes
/// `2026-09-08 07:28:22`, a shape nothing in the agent produces, and the two
/// do not compare against each other as either one compares against itself.
/// That is what let a broken window bound sit here unnoticed: the fixture and
/// the query agreed with each other and with nothing that ships.
async fn insert_sample(db: &sqlx::SqlitePool, at: DateTime<Utc>, i: i64) {
    sqlx::query(
        "INSERT INTO system_metrics (
            timestamp, server_name, cpu_usage,
            memory_total, memory_used, disk_total, disk_used,
            network_rx_bytes, network_tx_bytes
         ) VALUES (?1, 'test', ?2, 100, 50, 100, 50, ?3, ?3)",
    )
    .bind(at)
    .bind(i as f64 % 100.0)
    .bind(i * 1000)
    .execute(db)
    .await
    .unwrap();
}

async fn test_server(state: Arc<AppState>) -> TestServer {
    web_test::server(move || {
        let state = state.clone();
        async move {
            let limit = state.remote_access.exec.max_request_bytes;
            App::new().state(state).configure(configure_api(limit))
        }
    })
    .await
}

async fn history(srv: &TestServer, query: &str) -> Vec<serde_json::Value> {
    let token = generate_token("admin", SECRET).unwrap();
    let resp = srv
        .get(format!("/api/v1/metrics/history?{query}"))
        .header("Authorization", format!("Bearer {token}"))
        .send()
        .await
        .unwrap();
    assert!(resp.status().is_success(), "GET ?{query} failed");
    resp.json().await.unwrap()
}

#[ntex::test]
async fn max_points_is_a_ceiling() {
    let srv = test_server(state_with_samples(60).await).await;

    for max in [2, 10, 60, 100, 300] {
        let points = history(&srv, &format!("minutes=60&max_points={max}")).await;
        assert!(
            points.len() <= max,
            "asked for at most {max} points, got {}",
            points.len()
        );
    }
}

/// The case integer division gets wrong, asserted on the symptom it has.
///
/// Rounding the width down makes more buckets than were asked for, but that
/// is not what a caller sees: the handler caps the vector at the end, and it
/// drops from the *old* end, so the count is right and the window is short.
/// Five minutes over 200 points is 1.5 seconds a bucket — rounded down to 1
/// that is 300 buckets for a 200-point answer, and the 100 dropped are the
/// oldest third of the window.
///
/// Asserting `len() <= max` alone cannot fail here. The cap guarantees it
/// whether the width was computed correctly or not, which is why this test
/// passed for the whole time it was checking that and nothing else.
#[ntex::test]
async fn a_window_that_does_not_divide_evenly_is_still_covered() {
    let srv = test_server(state_with_samples_every(6 * 60, 1).await).await;

    let points = history(&srv, "minutes=5&max_points=200").await;
    assert!(
        points.len() <= 200,
        "asked for at most 200 points, got {}",
        points.len()
    );
    let span = span_secs(&points);
    assert!(
        span >= 280,
        "5 minutes at 200 points covered {span}s of the 300 asked for"
    );
}

/// Not "roughly 20": a chart drawn from 3 points where 20 were asked for is a
/// bucketing bug, and a ceiling alone would not notice it.
#[ntex::test]
async fn the_window_is_still_covered() {
    let srv = test_server(state_with_samples(60).await).await;

    let points = history(&srv, "minutes=60&max_points=20").await;
    assert!(
        points.len() >= 18,
        "an hour of samples thinned to 20 gave {}",
        points.len()
    );
    // Twenty points clustered into the last few minutes would satisfy the
    // count and still be the wrong chart. One bucket is three minutes here,
    // and the oldest is a partial one, so the span is short of the full hour
    // by up to that much even when everything is right.
    let span = span_secs(&points);
    assert!(
        span >= 55 * 60,
        "20 points over an hour spanned {span}s"
    );
}

/// What every watch and widget already in the field sends.
#[ntex::test]
async fn no_count_answers_as_it_always_did() {
    let srv = test_server(state_with_samples(60).await).await;

    let points = history(&srv, "minutes=60").await;
    // 60 minutes / 300 buckets is one every 12 seconds, and the rows are 10
    // seconds apart, so this is the endpoint's own cap rather than the data's.
    assert!(
        points.len() > 200 && points.len() <= 300,
        "default answered with {} points",
        points.len()
    );
}

/// A count outside the range is clamped rather than refused — every other
/// parameter here behaves that way, and a widget is in no position to retry.
#[ntex::test]
async fn a_silly_count_is_clamped() {
    let srv = test_server(state_with_samples(60).await).await;

    let huge = history(&srv, "minutes=60&max_points=100000").await;
    assert!(huge.len() <= 300, "got {} points", huge.len());

    let zero = history(&srv, "minutes=60&max_points=0").await;
    assert!(zero.len() >= 2, "got {} points", zero.len());

    let nonsense = history(&srv, "minutes=60&max_points=abc").await;
    assert!(
        nonsense.len() > 200 && nonsense.len() <= 300,
        "an unreadable count should read as absent, got {}",
        nonsense.len()
    );
}


/// `minutes` is a window, and a row outside it is not in the answer.
///
/// The bound used to be `datetime('now', '-N minutes')`, whose `YYYY-MM-DD
/// HH:MM:SS` output compares against this column's RFC 3339 only as far as the
/// date: every row from the same UTC day passed it whatever its time. That is
/// what this places — one row at the start of the current UTC day — and it is
/// the only shape that can catch it, since a row from any *earlier* day is
/// excluded correctly by the broken bound too.
///
/// `max_points` is well above the number of rows on purpose. The handler keeps
/// the newest `max_points` buckets, so with a dense fixture it hands back a
/// window-sized answer either way and the extra rows are only extra work;
/// two rows and 300 points is where the difference reaches the response.
#[ntex::test]
async fn a_row_from_earlier_today_is_outside_a_five_minute_window() {
    const MINUTES: i64 = 5;
    let now = Utc::now();
    let day_start = now.date_naive().and_hms_opt(0, 0, 0).unwrap().and_utc();
    let stale = day_start + Duration::seconds(1);

    if now - stale <= Duration::minutes(MINUTES) {
        // The first few minutes of a UTC day: "earlier today" is inside the
        // window, so the defect has nothing to show and neither has this test.
        eprintln!("skipped: {now} is within {MINUTES} minutes of {day_start}");
        return;
    }
    let fresh = now - Duration::seconds(30);

    let srv = test_server(state_with(&[stale, fresh]).await).await;
    let points = history(&srv, &format!("minutes={MINUTES}&max_points=300")).await;

    assert_eq!(
        points.len(),
        1,
        "a {MINUTES}-minute window over one row inside it and one at {stale} \
         answered with {} points",
        points.len()
    );
    let oldest = point_time(&points[0]);
    assert!(
        now - oldest <= Duration::minutes(MINUTES),
        "oldest point {oldest} is outside the {MINUTES}-minute window ending {now}"
    );
}

/// Seconds between the first and last point.
fn span_secs(points: &[serde_json::Value]) -> i64 {
    match (points.first(), points.last()) {
        (Some(f), Some(l)) => (point_time(l) - point_time(f)).num_seconds(),
        _ => 0,
    }
}

fn point_time(point: &serde_json::Value) -> DateTime<Utc> {
    let ts = point["timestamp"].as_str().expect("point has no timestamp");
    DateTime::parse_from_rfc3339(ts)
        .unwrap_or_else(|e| panic!("point timestamp {ts:?} is not RFC 3339: {e}"))
        .with_timezone(&Utc)
}
