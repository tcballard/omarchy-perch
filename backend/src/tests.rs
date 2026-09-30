use crate::{agents, calendar, cli, core::*, desktop, setup, sockets, tools};
use serde_json::{json, Value};
use std::{fs, os::unix::fs::PermissionsExt};
#[test]
fn bounded_card_actions_and_revisions() {
    let base = json!({"version":1,"revision":"r1","status":"ready","title":"Reader\nNews","actions":[{"id":"refresh","label":"Refresh"}],"rows":[{"id":"story1","title":"Story","action":{"id":"open:1","label":"Open"}}]});
    let card = desktop::normalize_card(&base).unwrap();
    assert_eq!(card["title"], "Reader News");
    assert_eq!(card["rows"][0]["detail"], "");
    for patch in [
        json!({"version":true}),
        json!({"revision":"invalid space"}),
        json!({"status":"execute"}),
        json!({"actions":[{"id":"x","label":"x"},{"id":"x","label":"y"}]}),
        json!({"rows":[{"id":"story","title":"one"},{"id":"story","title":"two"}]}),
        json!({"actions":null}),
        json!({"title":4}),
    ] {
        let mut v = base.clone();
        v.as_object_mut()
            .unwrap()
            .extend(patch.as_object().unwrap().clone());
        assert!(desktop::normalize_card(&v).is_err(), "{v}");
    }
    assert!(desktop::normalize_card(&json!({"version":1,"revision":"r","status":"ready","title":"x","actions":vec![json!({"id":"x","label":"x"});5]})).is_err());
}
#[test]
fn request_decisions_are_explicit_and_bounded() {
    let raw = json!({"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"private"},"cwd":"/work"});
    for agent in ["claude", "codex", "opencode"] {
        let data = sockets::request_data(&raw, "a", now() + 120.0, agent).unwrap();
        assert_eq!(data["kind"], "approval");
        assert_eq!(
            sockets::decision(&data, &json!({"action":"session"})).unwrap(),
            json!({})
        );
        assert!(sockets::decision(&data, &json!({"action":"always"})).is_err());
        let allow = sockets::decision(&data, &json!({"action":"allow"})).unwrap();
        if agent == "opencode" {
            assert_eq!(allow, json!({"response":"once"}));
        } else {
            assert_eq!(allow["hookSpecificOutput"]["decision"]["behavior"], "allow");
        }
    }
    let question = json!({"hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"__proto__","options":[{"label":"Blue"}]}]}});
    let data = sockets::request_data(&question, "a", now() + 120.0, "claude").unwrap();
    let answer = sockets::decision(
        &data,
        &json!({"action":"answer","answers":{"__proto__":"Blue"}}),
    )
    .unwrap();
    assert_eq!(
        answer["hookSpecificOutput"]["updatedInput"]["answers"]["__proto__"],
        "Blue"
    );
    for response in [
        json!({"action":"answer","answers":{}}),
        json!({"action":"answer","answers":{"__proto__":""}}),
        json!({"action":"answer","answers":{"__proto__":"Blue","other":"extra"}}),
    ] {
        assert!(sockets::decision(&data, &response).is_err())
    }
    for agent in ["codex", "opencode", "unknown"] {
        assert!(sockets::request_data(&question, "a", now(), agent).is_err());
    }
    let duplicate = json!({"hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"q"},{"question":"q"}]}});
    assert!(sockets::request_data(&duplicate, "a", now(), "claude").is_err());
}
#[test]
fn relay_never_accepts_local_targets_or_requests() {
    let raw = json!({"source":"laptop","event":{"id":"claude.abc","state":"waiting","title":"Work\u{0000}test","project":"repo","agent":"Claude","requestId":"private","target":"0x123","targetWorkspace":{"path":"/private"},"input":"secret"}});
    let event = sockets::relay_normalize(&raw).unwrap();
    assert_eq!(event["title"], "laptop · Work test");
    assert!(event["id"].as_str().unwrap().starts_with("remote."));
    let output = string_json(&event);
    for forbidden in ["private", "target", "requestId", "secret"] {
        assert!(!output.contains(forbidden))
    }
    for invalid in [
        json!({"source":"../bad","event":{"id":"x","state":"done"}}),
        json!({"source":"x","event":{"id":"x","state":"exec"}}),
    ] {
        assert!(sockets::relay_normalize(&invalid).is_err())
    }
}
#[test]
fn thirteen_status_clients_emit_metadata_only() {
    let agents = [
        "claude",
        "codex-hooks",
        "gemini",
        "cursor",
        "qwen",
        "qoder",
        "factory",
        "codebuddy",
        "pi",
        "omp",
        "opencode",
        "kimi",
        "grok",
    ];
    for agent in agents {
        let event = match agent {
            "gemini" => "BeforeAgent",
            "cursor" => "beforeSubmitPrompt",
            "kimi" => "TurnStarted",
            _ => "UserPromptSubmit",
        };
        let mut data = json!({"session_id":"one","conversation_id":"one","hook_event_name":event,"cwd":"/work/project","prompt":"PRIVATE PROMPT","tool_input":{"command":"PRIVATE COMMAND"}});
        if ["pi", "omp", "opencode"].contains(&agent) {
            data["state"] = "running".into()
        }
        let report = agents::report(agent, &data).unwrap();
        assert_eq!(report["state"], "running");
        assert_eq!(report["project"], "project");
        assert!(!string_json(&report).contains("PRIVATE"));
        let stop = match agent {
            "gemini" => "AfterAgent",
            "cursor" => "stop",
            _ => "Stop",
        };
        data["hook_event_name"] = stop.into();
        data["state"] = "done".into();
        assert_eq!(agents::report(agent, &data).unwrap()["state"], "done");
        data["hook_event_name"] = "unknown".into();
        data["state"] = "unknown".into();
        assert!(agents::report(agent, &data).is_none());
    }
    let codex = agents::report(
        "codex",
        &json!({"type":"agent-turn-complete","thread-id":"one","cwd":"/work/repo"}),
    )
    .unwrap();
    assert_eq!(codex["state"], "done");
    assert!(agents::report(
        "claude",
        &json!({"session_id":true,"hook_event_name":"Stop"})
    )
    .is_none());
}
#[test]
fn setup_roundtrips_preserve_unrelated_hooks() {
    for agent in [
        "claude",
        "gemini",
        "cursor",
        "qwen",
        "qoder",
        "factory",
        "codebuddy",
        "grok",
        "codex-hooks",
    ] {
        let before = if agent == "cursor" {
            json!({"theme":"keep","hooks":{"custom":[{"command":"keep"}]}})
        } else {
            json!({"theme":"keep","hooks":{"Stop":[{"hooks":[{"type":"command","command":"keep"}]}]}})
        };
        let old = string_json(&before);
        let new = setup::transform_agent(agent, &old, false, false).unwrap();
        assert_eq!(
            serde_json::from_str::<Value>(&new).unwrap()["theme"],
            "keep"
        );
        assert_eq!(
            setup::transform_agent(agent, &new, false, false).unwrap(),
            new
        );
        let removed = setup::transform_agent(agent, &new, true, false).unwrap();
        let mut expected = before.clone();
        if agent == "cursor" {
            expected["version"] = 1.into()
        };
        assert_eq!(serde_json::from_str::<Value>(&removed).unwrap(), expected);
        for flag in ["disableAllHooks", "allowManagedHooksOnly", "hooksDisabled"] {
            let mut off = before.clone();
            off[flag] = true.into();
            assert!(setup::transform_agent(agent, &string_json(&off), false, false).is_err());
            assert!(setup::transform_agent(agent, &string_json(&off), true, false).is_ok());
        }
    }
    assert!(setup::transform_agent("cursor", "{\"version\":2}", false, false).is_err());
    for v in [
        json!({"hooks":{"enabled":false}}),
        json!({"tools":{"enableHooks":false}}),
        json!({"hooks":{"disabled":["perch-status"]}}),
    ] {
        assert!(setup::transform_agent("gemini", &string_json(&v), false, false).is_err());
    }
}
#[test]
fn codex_and_kimi_blocks_keep_user_toml() {
    for agent in ["codex", "kimi"] {
        let old = "model = \"example\"\n# keep this comment\n";
        let new = setup::transform_agent(agent, old, false, false).unwrap();
        assert!(new.contains(old));
        assert!(!new.contains("python3"));
        assert_eq!(
            setup::transform_agent(agent, &new, false, false).unwrap(),
            new
        );
        assert_eq!(
            setup::transform_agent(agent, &new, true, false).unwrap(),
            old
        );
        let edited = new
            .replace("timeout = 3", "timeout = 4")
            .replace("--perch-hook-v1", "--changed");
        assert!(setup::transform_agent(agent, &edited, true, false).is_err());
    }
    assert!(setup::transform_agent("codex", "notify = [\"custom\"]\n", false, false).is_err());
    assert_eq!(
        setup::transform_agent("codex", "notify = [\"custom\"]\n", true, false).unwrap(),
        "notify = [\"custom\"]\n"
    );
}
#[test]
fn notification_history_cannot_restore_actions() {
    let data = json!({"rows":[{"key":"s.1","app":"Sender","title":"Notice","body":"body","actions":[{"command":"danger"}],"reply":true,"unread":true},{"key":"s.1","title":"duplicate"},{"key":"../bad"}],"dnd":true,"blocked":["Sender"]});
    let clean = cli::normalize_notifications(&data).unwrap();
    assert_eq!(clean["rows"].as_array().unwrap().len(), 1);
    assert_eq!(clean["rows"][0]["actions"], json!([]));
    assert_eq!(clean["rows"][0]["reply"], false);
    assert_eq!(clean["dnd"], true);
    assert!(cli::normalize_notifications(&json!({"rows":vec![json!({});21]})).is_err());
}
#[test]
fn calendar_nested_alarms_recurrence_exclusions_and_overrides() {
    let now = chrono::DateTime::parse_from_rfc3339("2026-09-30T00:00:00Z")
        .unwrap()
        .timestamp();
    let ics=b"BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:weekly\r\nDTSTART:20260930T100000Z\r\nDTEND:20260930T110000Z\r\nSUMMARY:Weekly\\, meeting\r\nRRULE:FREQ=WEEKLY;BYDAY=WE;COUNT=4\r\nEXDATE:20261007T100000Z\r\nURL:https://example.org/meeting\r\nBEGIN:VALARM\r\nSUMMARY:Wrong title\r\nEND:VALARM\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nUID:weekly\r\nRECURRENCE-ID:20261014T100000Z\r\nDTSTART:20261014T120000Z\r\nDURATION:PT30M\r\nSUMMARY:Moved meeting\r\nEND:VEVENT\r\nEND:VCALENDAR";
    let (mut events, skipped) = calendar::parse(ics, now).unwrap();
    assert_eq!(skipped, 0);
    assert_eq!(events.len(), 3);
    events.sort_by_key(|e| e["start"].as_i64());
    assert_eq!(events[0]["title"], "Weekly, meeting");
    assert_eq!(events[1]["title"], "Moved meeting");
    assert_eq!(
        events[1]["end"].as_i64().unwrap() - events[1]["start"].as_i64().unwrap(),
        1800000
    );
    assert_eq!(events[0]["url"], "https://example.org/meeting");
    let (events,skipped)=calendar::parse(b"BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART:20260930T100000Z\nRRULE:FREQ=MONTHLY\nEND:VEVENT\nEND:VCALENDAR",now).unwrap();
    assert!(events.is_empty());
    assert_eq!(skipped, 1);
    assert!(calendar::parse(b"not a calendar", now).is_err());
}
#[test]
fn calendar_custom_exchange_dst_rules() {
    let now = chrono::DateTime::parse_from_rfc3339("2026-09-30T00:00:00Z")
        .unwrap()
        .timestamp();
    let ics=b"BEGIN:VCALENDAR\nBEGIN:VTIMEZONE\nTZID:Custom Eastern\nBEGIN:STANDARD\nDTSTART:19701101T020000\nTZOFFSETTO:-0500\nRRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU\nEND:STANDARD\nBEGIN:DAYLIGHT\nDTSTART:19700308T020000\nTZOFFSETTO:-0400\nRRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU\nEND:DAYLIGHT\nEND:VTIMEZONE\nBEGIN:VEVENT\nDTSTART;TZID=Custom Eastern:20260930T100000\nDURATION:PT1H\nSUMMARY:Local time\nEND:VEVENT\nEND:VCALENDAR";
    let (events, skipped) = calendar::parse(ics, now).unwrap();
    assert_eq!(skipped, 0);
    assert_eq!(
        events[0]["start"].as_i64().unwrap(),
        (now + 14 * 3600) * 1000
    );
}
#[test]
fn file_io_refuses_symlinks_and_limits() {
    let temp = tempfile::tempdir().unwrap();
    let file = temp.path().join("regular");
    fs::write(&file, b"1234").unwrap();
    let link = temp.path().join("link");
    std::os::unix::fs::symlink(&file, &link).unwrap();
    assert!(read(&link, 32, false).is_err());
    assert_eq!(read(&link, 32, true).unwrap(), b"1234");
    assert!(read(&file, 3, false).is_err());
    assert_eq!(head(&file, 2).unwrap(), b"12");
    atomic(&file, b"changed", 0o600).unwrap();
    assert_eq!(fs::read(&file).unwrap(), b"changed");
    assert_eq!(
        fs::metadata(&file).unwrap().permissions().mode() & 0o777,
        0o600
    );
    assert!(desktop::local("file://remote/etc/passwd").is_err());
    assert!(desktop::local("relative").is_err());
}
#[test]
fn process_output_deadline_and_descendants_are_bounded() {
    assert_eq!(
        run(&["printf", "literal $(unsafe)"], 1.0, 256).unwrap(),
        "literal $(unsafe)"
    );
    assert!(run(&["sh", "-c", "yes"], 1.0, 1024).is_err());
    let start = std::time::Instant::now();
    assert!(run(&["sh", "-c", "sleep 10 & wait"], 0.1, 1024).is_err());
    assert!(start.elapsed().as_secs_f64() < 1.0);
}
#[test]
fn codex_server_records_are_readonly_metadata() {
    let id = "12345678-1234-1234-1234-123456789abc";
    let thread = json!({"id":id,"cwd":"/work/repo","status":{"type":"active","activeFlags":["waitingOnApproval"]},"turns":[{"text":"PRIVATE"}]});
    let row = sockets::codex_record(&thread, "codex.desktop").unwrap();
    assert_eq!(row["state"], "waiting");
    assert_eq!(row["attention"], "approval");
    assert!(!string_json(&row).contains("PRIVATE"));
    let mut child = thread.clone();
    child["parentThreadId"] = id.into();
    assert!(sockets::codex_record(&child, "").is_none());
    child["id"] = "not a UUID".into();
    assert!(sockets::codex_record(&child, "").is_none());
}
#[test]
fn invalid_payloads_do_not_spawn_actions() {
    for (op, p) in [
        ("brightness-set", json!({"value":true})),
        ("module-weather", json!({"latitude":true,"longitude":0})),
        ("app-link", json!({"url":"https://user:secret@example.com"})),
        ("agent-jump", json!({"address":"0x123; exec"})),
        ("plugin-open", json!({"id":"../bad"})),
        (
            "agent-liveness",
            json!({"sessions":[{"id":"x","pid":true}]}),
        ),
        ("request-get", json!({"id":"../bad"})),
    ] {
        assert!(tools(op, &p).is_err(), "{op}");
    }
}
