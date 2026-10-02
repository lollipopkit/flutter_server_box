//! The app's snippet tests (`test/unit/server/snippet_local_test.dart`),
//! ported before its Dart macro code was removed ("test as spec"). Where the
//! Rust behaviour departs from what the Dart code did, the module's own tests
//! say so; these are the cases both agree on.

use sbm_parser::snippet::{PlanError, SnippetContext, Step, expand, plan, uses_server_context};

fn server() -> SnippetContext {
    SnippetContext {
        host: Some("10.0.0.1".into()),
        port: Some("2222".into()),
        user: Some("lk".into()),
        pwd: None,
        id: Some("box-1".into()),
        name: Some("box".into()),
    }
}

#[test]
fn one_that_names_a_server_cannot_run_without_one() {
    for script in [
        r"ssh ${user}@${host}",
        r"echo ${port}",
        r"curl http://${host}:8080",
        r"echo ${name} ${id}",
        r"sshpass -p ${pwd} true",
    ] {
        assert!(uses_server_context(script), "{script}");
    }
}

#[test]
fn one_that_names_none_can() {
    for script in [
        "df -h",
        r"echo $HOME",
        r#"for f in *; do echo "$f"; done"#,
        r"${ctrl+c}",
    ] {
        assert!(!uses_server_context(script), "{script}");
    }
}

#[test]
fn a_server_answers_its_own_placeholders() {
    assert_eq!(
        expand(r"ssh ${user}@${host} -p ${port}", &server()).unwrap(),
        "ssh lk@10.0.0.1 -p 2222"
    );
}

#[test]
fn with_no_server_a_script_naming_none_is_left_as_written() {
    assert_eq!(expand("df -h", &SnippetContext::default()).unwrap(), "df -h");
}

/// Expanding for a run leaves the terminal macros alone: a command, not
/// keystrokes.
#[test]
fn expand_keeps_the_terminal_macros() {
    assert_eq!(
        expand(r"echo ${name}${sleep 1}${ctrl+c}", &server()).unwrap(),
        r"echo box${sleep 1}${ctrl+c}"
    );
}

/// A credential the server does not have is a refusal, whichever way the
/// script is run.
#[test]
fn a_missing_password_is_refused() {
    let refused = PlanError::Unanswerable { key: "pwd".into() };
    assert_eq!(expand(r"sshpass -p ${pwd} true", &server()), Err(refused.clone()));
    assert_eq!(plan(r"sshpass -p ${pwd} true", &server()), Err(refused));
}

/// `first ${sleep 1} second`: what the Dart test typed before and after the
/// wait.
#[test]
fn a_wait_splits_the_script() {
    assert_eq!(
        plan(r"first ${sleep 1} second", &SnippetContext::default()).unwrap(),
        vec![
            Step::Text { text: "first ".into() },
            Step::Sleep { seconds: 1 },
            Step::Text { text: " second".into() },
        ]
    );
}
