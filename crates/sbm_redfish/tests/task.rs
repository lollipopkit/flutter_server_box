//! A `202` means the work is happening somewhere else — `task_test.dart`.

use sbm_redfish::Outcome;
use sbm_redfish::model::{RedfishTask, TaskState};
use serde_json::json;

#[test]
fn the_states_that_mean_it_is_over() {
    for s in [TaskState::Completed, TaskState::Killed, TaskState::Exception, TaskState::Cancelled] {
        assert!(!s.is_running(), "{s:?}");
    }
}

#[test]
fn the_states_that_mean_it_is_not() {
    for s in [
        TaskState::New,
        TaskState::Starting,
        TaskState::Running,
        TaskState::Suspended,
        TaskState::Interrupted,
        TaskState::Pending,
        TaskState::Stopping,
    ] {
        assert!(s.is_running(), "{s:?}");
    }
}

#[test]
fn an_unrecognised_state_counts_as_still_running() {
    let s = TaskState::parse(Some(&json!("SomethingNewIn2027")));
    assert_eq!(s, TaskState::Unknown);
    assert!(s.is_running());
    assert!(!s.is_success());
}

#[test]
fn only_completed_is_success() {
    assert!(TaskState::Completed.is_success());
    for s in [TaskState::Killed, TaskState::Exception, TaskState::Cancelled] {
        assert!(!s.is_success(), "{s:?}");
    }
}

#[test]
fn reads_what_a_service_reports_mid_flight() {
    let t = RedfishTask::from_json(&json!({
        "Id": "1",
        "Name": "Update Task",
        "TaskState": "Running",
        "PercentComplete": 42,
    }));
    assert_eq!(t.state, TaskState::Running);
    assert_eq!(t.percent_complete, Some(42));
    assert_eq!(t.id.as_deref(), Some("1"));
    assert_eq!(t.name.as_deref(), Some("Update Task"));
    assert!(t.state.is_running());
}

#[test]
fn a_fractional_percentage_is_rounded() {
    assert_eq!(RedfishTask::from_json(&json!({"PercentComplete": 42.5})).percent_complete, Some(43));
    assert_eq!(RedfishTask::from_json(&json!({"PercentComplete": "42"})).percent_complete, None);
}

#[test]
fn messages_are_the_only_description_of_a_failure() {
    let t = RedfishTask::from_json(&json!({
        "TaskState": "Exception",
        "Messages": [
            {"Message": "The image is not compatible with this system."},
            {"MessageId": "Base.1.0.GeneralError"},
        ],
    }));
    assert_eq!(t.state, TaskState::Exception);
    assert!(!t.state.is_running());
    assert!(!t.state.is_success());
    assert_eq!(t.messages, ["The image is not compatible with this system."]);
}

#[test]
fn absent_progress_means_nothing_about_progress() {
    assert_eq!(RedfishTask::from_json(&json!({"TaskState": "Running"})).percent_complete, None);
}

#[test]
fn a_document_with_nothing_in_it_is_unknown_which_is_still_running() {
    let t = RedfishTask::from_json(&json!({}));
    assert_eq!(t.state, TaskState::Unknown);
    assert!(t.state.is_running());
}

#[test]
fn every_state_name_parses_and_serializes_as_its_dart_name() {
    for (raw, state, dart) in [
        ("New", TaskState::New, "news"),
        ("Starting", TaskState::Starting, "starting"),
        ("Running", TaskState::Running, "running"),
        ("Suspended", TaskState::Suspended, "suspended"),
        ("Interrupted", TaskState::Interrupted, "interrupted"),
        ("Pending", TaskState::Pending, "pending"),
        ("Stopping", TaskState::Stopping, "stopping"),
        ("Completed", TaskState::Completed, "completed"),
        ("Killed", TaskState::Killed, "killed"),
        ("Exception", TaskState::Exception, "exception"),
        ("Cancelled", TaskState::Cancelled, "cancelled"),
    ] {
        assert_eq!(TaskState::parse(Some(&json!(raw))), state);
        assert_eq!(serde_json::to_value(state).unwrap(), dart);
    }
}

#[test]
fn done_and_accepted_are_different_answers() {
    let describe = |o: &Outcome| match o {
        Outcome::Done => "finished".to_string(),
        Outcome::Accepted(path) => path.clone(),
    };
    assert_eq!(describe(&Outcome::Done), "finished");
    assert_eq!(
        describe(&Outcome::Accepted("/redfish/v1/TaskService/Tasks/1".into())),
        "/redfish/v1/TaskService/Tasks/1"
    );
    assert_eq!(serde_json::to_value(Outcome::Done).unwrap(), json!({"kind": "done"}));
    assert_eq!(
        serde_json::to_value(Outcome::Accepted("/t".into())).unwrap(),
        json!({"kind": "accepted", "path": "/t"})
    );
}
