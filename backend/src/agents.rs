use crate::core::*;
use serde_json::{json, Value};
use std::{
    collections::HashSet,
    fs,
    os::unix::fs::{FileTypeExt, MetadataExt},
    path::{Path, PathBuf},
};
pub const THREAD: &str = r"^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$";
const DESKTOP: &str = r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,240}\.desktop$";
pub fn boot() -> Result<String> {
    Ok(fs::read_to_string("/proc/sys/kernel/random/boot_id")?
        .trim()
        .into())
}
pub fn proc_start(pid: u64) -> Result<String> {
    let raw = fs::read_to_string(format!("/proc/{pid}/stat"))?;
    Ok(raw
        .rsplit_once(')')
        .ok_or("Invalid process identity")?
        .1
        .split_whitespace()
        .nth(19)
        .ok_or("Invalid process identity")?
        .into())
}
pub fn parents(mut pid: u64) -> Vec<u64> {
    let mut out = Vec::new();
    for _ in 0..32 {
        let next = (|| -> Result<u64> {
            let raw = fs::read_to_string(format!("/proc/{pid}/stat"))?;
            Ok(raw
                .rsplit_once(')')
                .ok_or("Invalid process")?
                .1
                .split_whitespace()
                .nth(1)
                .ok_or("Invalid process")?
                .parse()?)
        })();
        match next {
            Ok(p) if p > 1 && !out.contains(&p) => {
                pid = p;
                out.push(pid)
            }
            _ => break,
        }
    }
    out
}
pub fn handler() -> Result<String> {
    let text = run(
        &["xdg-mime", "query", "default", "x-scheme-handler/codex"],
        0.5,
        4096,
    )?;
    Ok(if valid(text.trim(), DESKTOP) {
        text.trim().into()
    } else {
        String::new()
    })
}
fn process_identity(p: &Value, pid: &str, start: &str, bootkey: &str) -> Result<u64> {
    let id = p[pid]
        .as_u64()
        .filter(|p| *p > 1)
        .ok_or("Invalid process identity")?;
    if s(p, bootkey) != boot()? || s(p, start) != proc_start(id)? {
        return err("That process has changed");
    };
    Ok(id)
}
fn socket(path: &str) -> Result<fs::Metadata> {
    if !path.starts_with('/') || path.len() > 4096 {
        return err("Invalid socket path");
    };
    let m = fs::symlink_metadata(path)?;
    if !m.file_type().is_socket() || m.uid() != uid() {
        return err("That socket is unavailable");
    };
    Ok(m)
}
fn workspace(t: &Value) -> Result<Value> {
    let app = s(t, "app");
    let path = s(t, "path");
    if ![
        "code",
        "code-insiders",
        "cursor",
        "windsurf",
        "trae",
        "zed",
        "idea",
        "webstorm",
        "pycharm",
        "goland",
        "clion",
        "rubymine",
        "phpstorm",
        "rider",
        "rustrover",
    ]
    .contains(&app)
        || !path.starts_with('/')
        || path.len() > 1024
        || path.chars().any(char::is_control)
    {
        return err("Invalid workspace target");
    };
    let pid = process_identity(t, "pid", "start", "boot")?;
    let binary = fs::read_link(format!("/proc/{pid}/exe"))?;
    let name = binary
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_lowercase();
    if name != app && !(app == "zed" && name == "zed-editor") {
        return err("That editor is no longer running");
    };
    if !Path::new(path).is_dir() {
        return err("That workspace folder is no longer available");
    };
    launch(&[app, path])?;
    Ok(ok_message("Opened session workspace"))
}
fn tmux(t: &Value) -> Result<()> {
    let path = s(t, "socket");
    let pane = s(t, "pane");
    let client = s(t, "client");
    socket(path)?;
    if !valid(pane, r"^%[0-9]+$") || !valid(client, r"^/dev/[A-Za-z0-9/_-]+$") {
        return err("Invalid tmux target");
    };
    for prefix in ["pane", "client"] {
        let pid = t[format!("{prefix}Pid")]
            .as_u64()
            .filter(|p| *p > 1)
            .ok_or("Invalid tmux target")?;
        if proc_start(pid)? != s(t, &format!("{prefix}Start")) {
            return err("That tmux session has changed");
        }
    }
    let actual = run(
        &[
            "tmux",
            "-S",
            path,
            "display-message",
            "-p",
            "-t",
            pane,
            "#{pane_pid}",
        ],
        0.75,
        4096,
    )?;
    let attached = run(
        &[
            "tmux",
            "-S",
            path,
            "list-clients",
            "-F",
            "#{client_pid} #{client_tty}",
        ],
        0.75,
        65536,
    )?;
    if actual.trim().parse::<u64>().ok() != t["panePid"].as_u64()
        || !attached
            .lines()
            .any(|l| l == format!("{} {client}", t["clientPid"]))
    {
        return err("That tmux pane or terminal is no longer available");
    };
    run(
        &[
            "tmux",
            "-S",
            path,
            "switch-client",
            "-c",
            client,
            "-t",
            pane,
        ],
        1.0,
        4096,
    )?;
    Ok(())
}
fn wezterm(t: &Value, pid: u64) -> Result<()> {
    let path = s(t, "socket");
    let pane = t["pane"]
        .as_u64()
        .filter(|p| *p < 1_000_000_000_000)
        .ok_or("Invalid WezTerm target")?;
    if path.len() > 1024 {
        return err("Invalid WezTerm target");
    };
    let m = socket(path)?;
    if m.dev().to_string() != s(t, "device")
        || m.ino().to_string() != s(t, "inode")
        || proc_start(pid)? != s(t, "windowStart")
    {
        return err("That WezTerm instance has changed");
    };
    let env = format!("WEZTERM_UNIX_SOCKET={path}");
    let rows: Value = serde_json::from_str(&run(
        &["env", &env, "wezterm", "cli", "list", "--format", "json"],
        0.75,
        262144,
    )?)?;
    if rows
        .as_array()
        .is_none_or(|r| !r.iter().any(|r| r["pane_id"].as_u64() == Some(pane)))
    {
        return err("That WezTerm pane is no longer open");
    };
    run(
        &[
            "env",
            &env,
            "wezterm",
            "cli",
            "activate-pane",
            "--pane-id",
            &pane.to_string(),
        ],
        1.0,
        4096,
    )?;
    Ok(())
}
fn zellij(t: &Value) -> Result<Value> {
    let session = s(t, "session");
    let pane = t["pane"]
        .as_u64()
        .filter(|p| *p < u32::MAX as u64 + 1)
        .ok_or("Invalid Zellij target")?;
    let path = s(t, "socket");
    let binary = s(t, "binary");
    if !valid(session, r"^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$")
        || path.len() > 1024
        || Path::new(path).file_name().and_then(|p| p.to_str()) != Some(session)
        || !binary.starts_with('/')
        || Path::new(binary).file_name().and_then(|p| p.to_str()) != Some("zellij")
    {
        return err("Invalid Zellij target");
    };
    let pid = process_identity(t, "serverPid", "serverStart", "boot")?;
    let m = socket(path)?;
    let exe = fs::metadata(format!("/proc/{pid}/exe"))?;
    let disk = fs::metadata(binary)?;
    if m.dev().to_string() != s(t, "device")
        || m.ino().to_string() != s(t, "inode")
        || exe.dev() != disk.dev()
        || exe.ino() != disk.ino()
        || exe.dev().to_string() != s(t, "binaryDevice")
        || exe.ino().to_string() != s(t, "binaryInode")
        || fs::read_link(format!("/proc/{pid}/exe"))? != Path::new(binary)
        || which("zellij")
            .and_then(|p| p.canonicalize().ok())
            .as_deref()
            != Some(Path::new(binary))
    {
        return err("That Zellij socket or executable has changed");
    };
    let raw = head(Path::new(&format!("/proc/{pid}/cmdline")), 4096)?;
    let args = String::from_utf8_lossy(&raw);
    let args: Vec<_> = args.split('\0').collect();
    if args
        .iter()
        .position(|p| *p == "--server")
        .and_then(|i| args.get(i + 1))
        .copied()
        != Some(path)
    {
        return err("That Zellij server no longer owns the session");
    };
    let root = Path::new(path)
        .parent()
        .and_then(Path::parent)
        .ok_or("Invalid Zellij socket")?;
    let env = format!("ZELLIJ_SOCKET_DIR={}", root.display());
    let clients = run(
        &[
            "env",
            &env,
            "zellij",
            "--session",
            session,
            "action",
            "list-clients",
        ],
        0.5,
        65536,
    )?;
    let rows: Vec<_> = clients.trim().lines().collect();
    if rows.len() != 2
        || !rows[0]
            .split_whitespace()
            .take(2)
            .eq(["CLIENT_ID", "ZELLIJ_PANE_ID"])
        || !valid(rows[1], r"^\s*[0-9]+\s+(?:terminal|plugin)_[0-9]+(?:\s|$)")
    {
        return err("Select the session in Zellij: exactly one attached client is required");
    };
    let panes: Value = serde_json::from_str(&run(
        &[
            "env",
            &env,
            "zellij",
            "--session",
            session,
            "action",
            "list-panes",
            "--json",
        ],
        0.5,
        262144,
    )?)?;
    if panes.as_array().is_none_or(|rows| {
        !rows.iter().any(|p| {
            p["id"].as_u64() == Some(pane) && p["is_plugin"] == false && p["exited"] != true
        })
    }) {
        return err("That Zellij pane is no longer open");
    };
    run(
        &[
            "env",
            &env,
            "zellij",
            "--session",
            session,
            "action",
            "focus-pane-id",
            &format!("terminal_{pane}"),
        ],
        1.0,
        4096,
    )?;
    Ok(ok_message(
        "Selected the pane in the attached Zellij client",
    ))
}
pub fn handle(op: &str, p: &Value) -> Result<Value> {
    match op {
        "agent-discover" => discover(),
        "agent-liveness" => {
            let rows = p["sessions"]
                .as_array()
                .filter(|r| r.len() <= 32)
                .ok_or("Invalid session records")?;
            let b = boot()?;
            let mut ended = Vec::new();
            for r in rows {
                let id = s(r, "id");
                let pid = r["pid"]
                    .as_u64()
                    .filter(|p| *p > 1)
                    .ok_or("Invalid session process")?;
                if !valid(id, r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$") {
                    return err("Invalid session process");
                };
                if s(r, "boot") != b {
                    ended.push(id);
                    continue;
                }
                match proc_start(pid) {
                    Ok(start) if start != s(r, "start") => ended.push(id),
                    Err(_) if !Path::new(&format!("/proc/{pid}")).exists() => ended.push(id),
                    _ => {}
                }
            }
            Ok(json!({"ended":ended,"checked":rows}))
        }
        "agent-codex-open" => {
            let t = &p["targetCodex"];
            if !valid(s(t, "thread"), THREAD)
                || !valid(s(t, "handler"), DESKTOP)
                || s(t, "handler") != handler()?
            {
                return err(
                    "The Codex desktop handler changed or is unavailable; refresh this session",
                );
            };
            launch(&[
                "xdg-open",
                &format!("codex://threads/{}", s(t, "thread").to_lowercase()),
            ])?;
            Ok(ok_message(
                "Requested this local thread in the Codex desktop app",
            ))
        }
        "agent-zellij-select" => zellij(&p["targetZellij"]),
        "agent-jump" => {
            if p["targetWorkspace"].is_object() {
                return workspace(&p["targetWorkspace"]);
            }
            let address = s(p, "address");
            if !valid(address, r"^0x[0-9a-fA-F]{1,16}$") {
                return err("That session has no valid Hyprland window target");
            };
            let rows: Value =
                serde_json::from_str(&run(&["hyprctl", "-j", "clients"], 0.75, 262144)?)?;
            let rows = rows.as_array().ok_or("Invalid window list")?;
            if !rows.iter().any(|r| r["address"] == address) {
                return err("That session window is no longer open");
            };
            if !p["targetPid"].is_null() || !p["targetBoot"].is_null() {
                let pid = process_identity(p, "targetPid", "targetStart", "targetBoot")?;
                if !rows
                    .iter()
                    .any(|r| r["address"] == address && r["pid"].as_u64() == Some(pid))
                {
                    return err("That session target has changed; open it from your terminal");
                };
                if p["targetWezterm"].is_object() {
                    wezterm(&p["targetWezterm"], pid)?
                }
                if p["targetTmux"].is_object() {
                    tmux(&p["targetTmux"])?
                }
            } else if p["targetTmux"].is_object() || p["targetWezterm"].is_object() {
                return err("Missing window identity");
            };
            if run(
                &[
                    "hyprctl",
                    "dispatch",
                    "focuswindow",
                    &format!("address:{address}"),
                ],
                1.0,
                4096,
            )?
            .trim()
                != "ok"
            {
                return err("Hyprland could not focus that session window");
            };
            Ok(ok_message("Returned to session"))
        }
        _ => err("Unsupported session operation"),
    }
}
fn candidates(base: PathBuf) -> Vec<(f64, PathBuf)> {
    let mut pending = vec![(base, 0)];
    let mut found = Vec::new();
    let mut seen = 0;
    while let Some((path, depth)) = pending.pop() {
        if seen >= 4096 {
            break;
        }
        if path.is_symlink() {
            continue;
        }
        if let Ok(entries) = fs::read_dir(path) {
            for e in entries.flatten() {
                seen += 1;
                if seen > 4096 {
                    break;
                }
                let path = e.path();
                if path.is_symlink() {
                    continue;
                }
                if let Ok(m) = e.metadata() {
                    if m.is_dir() && depth < 4 {
                        pending.push((path, depth + 1))
                    } else if m.is_file()
                        && path.extension().is_some_and(|s| s == "jsonl")
                        && m.uid() == uid()
                    {
                        let modified = m.mtime() as f64;
                        if (now() - 86400.0..=now() + 60.0).contains(&modified) {
                            found.push((modified, path));
                        }
                    }
                }
            }
        }
    }
    found.sort_by(|a, b| b.0.total_cmp(&a.0));
    found.truncate(24);
    found
}
fn discover() -> Result<Value> {
    let mut rows = Vec::new();
    let handler = handler().unwrap_or_default();
    for (agent, label, base) in [
        (
            "claude",
            "Claude",
            base("CLAUDE_CONFIG_DIR", home().join(".claude")).join("projects"),
        ),
        (
            "codex",
            "Codex",
            base("CODEX_HOME", home().join(".codex")).join("sessions"),
        ),
        ("pi", "Pi", home().join(".pi/agent/sessions")),
        ("omp", "Oh My Pi", home().join(".omp/agent/sessions")),
    ] {
        for (modified, path) in candidates(base) {
            let Ok(raw) = head(&path, 65536) else {
                continue;
            };
            if fs::symlink_metadata(&path)?.uid() != uid() {
                continue;
            }
            for line in String::from_utf8_lossy(&raw).lines().take(32) {
                let Ok(mut data) = serde_json::from_str::<Value>(line) else {
                    continue;
                };
                if agent == "codex" {
                    if s(&data, "type") != "session_meta" {
                        continue;
                    };
                    data = data["payload"].clone();
                } else if ["pi", "omp"].contains(&agent) && s(&data, "type") != "session" {
                    continue;
                }
                let session = s(
                    &data,
                    if ["codex", "pi", "omp"].contains(&agent) {
                        "id"
                    } else {
                        "sessionId"
                    },
                );
                let cwd = s(&data, "cwd");
                if session.is_empty()
                    || session.len() > 4096
                    || !cwd.starts_with('/')
                    || cwd.len() > 4096
                {
                    continue;
                }
                let project = cut(
                    &Path::new(cwd)
                        .file_name()
                        .unwrap_or_default()
                        .to_string_lossy(),
                    100,
                );
                let mut row = json!({"id":format!("{agent}.{}",&hash(session)[..20]),"kind":"agent","agent":label,"title":if project.is_empty(){label}else{&project},"project":project,"updatedAt":modified.min(now())*1000.0});
                if agent == "codex" && !handler.is_empty() && valid(session, THREAD) {
                    row["targetCodex"] = json!({"thread":session.to_lowercase(),"handler":handler});
                }
                rows.push(row);
                break;
            }
        }
    }
    rows.sort_by(|a, b| {
        b["updatedAt"]
            .as_f64()
            .unwrap()
            .total_cmp(&a["updatedAt"].as_f64().unwrap())
    });
    let mut ids = HashSet::new();
    rows.retain(|r| ids.insert(s(r, "id").to_owned()));
    rows.truncate(8);
    Ok(json!({"sessions":rows}))
}
pub fn windows(raw: &Value, codex: bool) -> Vec<Value> {
    let mut result = Vec::new();
    for (name, default, minutes) in if codex {
        [("primary", "5h", 300.0), ("secondary", "7d", 10080.0)]
    } else {
        [("five_hour", "5h", 300.0), ("seven_day", "7d", 10080.0)]
    } {
        let r = &raw[name];
        let Some(used) = r[if codex {
            "used_percent"
        } else {
            "used_percentage"
        }]
        .as_f64()
        .filter(|v| (0.0..=100.0).contains(v)) else {
            continue;
        };
        let reset = r["resets_at"].as_f64().filter(|v| *v >= 0.0);
        let duration = r
            .get("window_minutes")
            .and_then(Value::as_f64)
            .unwrap_or(minutes);
        let label = if (0.0..=525600.0).contains(&duration) && duration > 0.0 {
            if duration % 1440.0 == 0.0 {
                format!("{}d", (duration / 1440.0) as u64)
            } else if duration % 60.0 == 0.0 {
                format!("{}h", (duration / 60.0) as u64)
            } else {
                format!("{}m", duration as u64)
            }
        } else {
            default.into()
        };
        result.push(json!({"label":label,"used":used,"resetsAt":reset}));
    }
    result
}
pub fn usage() -> Result<Value> {
    let mut sources = Vec::new();
    let mut codex = None;
    for (_, path) in candidates(base("CODEX_HOME", home().join(".codex")).join("sessions"))
        .into_iter()
        .take(12)
    {
        let result = (|| -> Result<Option<Value>> {
            use std::io::{Read, Seek, SeekFrom};
            use std::os::unix::fs::OpenOptionsExt;
            let mut f = fs::OpenOptions::new()
                .read(true)
                .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK)
                .open(&path)?;
            let m = f.metadata()?;
            if !m.is_file() || m.uid() != uid() {
                return err("Unreadable usage source");
            };
            let offset = m.len().saturating_sub(262144);
            f.seek(SeekFrom::Start(offset))?;
            let mut raw = Vec::new();
            f.take(262144).read_to_end(&mut raw)?;
            let raw = if offset > 0 {
                raw.iter()
                    .position(|b| *b == b'\n')
                    .map(|i| &raw[i + 1..])
                    .unwrap_or(&[])
            } else {
                &raw
            };
            for line in String::from_utf8_lossy(raw).lines().rev() {
                let Ok(r) = serde_json::from_str::<Value>(line) else {
                    continue;
                };
                if s(&r, "type") != "event_msg" || s(&r["payload"], "type") != "token_count" {
                    continue;
                }
                let windows = windows(&r["payload"]["rate_limits"], true);
                if windows.is_empty() {
                    continue;
                }
                let stamp = chrono::DateTime::parse_from_rfc3339(s(&r, "timestamp"))
                    .map(|t| t.timestamp() as f64)
                    .unwrap_or(m.mtime() as f64);
                return Ok(Some(json!({"windows":windows,"updatedAt":stamp})));
            }
            Ok(None)
        })();
        if let Ok(Some(data)) = result {
            if codex
                .as_ref()
                .is_none_or(|v: &Value| v["updatedAt"].as_f64() < data["updatedAt"].as_f64())
            {
                codex = Some(data);
            }
        }
    }
    for name in ["Codex", "Claude"] {
        let data = if name == "Codex" {
            codex.clone()
        } else {
            Store::new("usage-claude").and_then(|st|st.load(json!({}))).ok().map(|v|json!({"windows":windows(&v["rate_limits"],false),"updatedAt":v["updatedAt"]}))
        };
        if let Some(v) = data.filter(|v| v["windows"].as_array().is_some_and(|w| !w.is_empty())) {
            let stamp = v["updatedAt"].as_f64().unwrap_or(0.0);
            sources.push(json!({"name":name,"windows":v["windows"],"updatedAt":stamp,"status":if now()-stamp>900.0{"Stale snapshot"}else{"Local snapshot"}}));
        } else {
            sources.push(json!({"name":name,"windows":[],"status":"No local usage available"}));
        }
    }
    Ok(json!({"sources":sources}))
}
pub fn report(agent: &str, data: &Value) -> Option<Value> {
    if !data.is_object() {
        return None;
    }
    let agent = if agent == "codex-hooks" {
        "codex"
    } else {
        agent
    };
    let label = match agent {
        "claude" => "Claude",
        "codex" => "Codex",
        "gemini" => "Gemini",
        "cursor" => "Cursor",
        "qwen" => "Qwen Code",
        "qoder" => "Qoder",
        "factory" => "Factory Droid",
        "codebuddy" => "CodeBuddy",
        "pi" => "Pi",
        "omp" => "Oh My Pi",
        "opencode" => "OpenCode",
        "kimi" => "Kimi",
        "grok" => "Grok",
        _ => return None,
    };
    let session = if agent == "codex" && s(data, "type") == "agent-turn-complete" {
        s(data, "thread-id")
    } else if agent == "cursor" {
        data["conversation_id"]
            .as_str()
            .unwrap_or(s(data, "session_id"))
    } else if agent == "grok" {
        data["sessionId"].as_str().unwrap_or(s(data, "session_id"))
    } else {
        s(data, "session_id")
    };
    if session.is_empty() || session.len() > 4096 {
        return None;
    }
    let mut attention = "attention";
    let mut detail = String::new();
    let event = data["hook_event_name"]
        .as_str()
        .unwrap_or(s(data, "hookEventName"));
    let event = if agent == "grok" {
        match event {
            "user_prompt_submit" => "UserPromptSubmit",
            "post_tool_use" => "PostToolUse",
            "notification" => "Notification",
            "stop" => "Stop",
            "session_end" => "SessionEnd",
            "stop_cancelled" => "StopCancelled",
            "stop_failure" => "StopFailure",
            e => e,
        }
    } else {
        event
    };
    let state = if ["pi", "omp", "opencode"].contains(&agent) {
        let state = s(data, "state");
        if !["running", "done", "error", "waiting"].contains(&state) {
            return None;
        }
        if ["approval", "question"].contains(&s(data, "attention")) {
            attention = s(data, "attention")
        };
        detail = match state {
            "done" => "Turn complete",
            "error" => "Agent stopped with an error",
            "waiting" => "Needs your attention in the agent",
            _ => "Working",
        }
        .into();
        state
    } else if agent == "codex" && s(data, "type") == "agent-turn-complete" {
        "done"
    } else if event == "Notification" {
        let kind = data["notificationType"]
            .as_str()
            .unwrap_or(s(data, "notification_type"));
        if agent == "gemini" && kind != "ToolPermission"
            || agent != "gemini"
                && !["permission_prompt", "idle_prompt", "elicitation_dialog"].contains(&kind)
        {
            return None;
        }
        attention = if ["permission_prompt", "ToolPermission"].contains(&kind) {
            "approval"
        } else {
            "question"
        };
        detail = format!(
            "Needs your attention in {}",
            if agent == "claude" {
                "Claude Code"
            } else if agent == "gemini" {
                "Gemini CLI"
            } else {
                label
            }
        );
        "waiting"
    } else if event == "PermissionRequest" && ["codex", "kimi"].contains(&agent) {
        attention = "approval";
        detail = format!("Needs your approval in {label}");
        "waiting"
    } else {
        match (agent, event) {
            ("gemini", "BeforeAgent" | "AfterTool")
            | ("cursor", "beforeSubmitPrompt" | "postToolUse")
            | ("kimi", "TurnStarted" | "PostToolUse" | "PermissionResult") => "running",
            ("gemini", "AfterAgent" | "SessionEnd") => "done",
            ("cursor", "stop" | "sessionEnd") => {
                let status = data["status"].as_str().unwrap_or(s(data, "reason"));
                if status == "aborted" {
                    detail = "Turn cancelled".into()
                }
                if event == "sessionEnd" {
                    detail = "Session ended".into()
                }
                if status == "error" {
                    "error"
                } else {
                    "done"
                }
            }
            (_, "UserPromptSubmit" | "PostToolUse")
                if [
                    "claude",
                    "qwen",
                    "qoder",
                    "factory",
                    "codebuddy",
                    "grok",
                    "codex",
                ]
                .contains(&agent) =>
            {
                "running"
            }
            ("codex", "PreToolUse") => "running",
            (_, "Stop" | "SessionEnd")
                if [
                    "claude",
                    "qwen",
                    "qoder",
                    "factory",
                    "codebuddy",
                    "grok",
                    "codex",
                    "kimi",
                ]
                .contains(&agent) =>
            {
                "done"
            }
            ("grok", "StopCancelled") | ("codex" | "kimi", "Interrupt") => {
                detail = "Turn cancelled".into();
                "done"
            }
            ("grok" | "kimi", "StopFailure") => "error",
            _ => return None,
        }
    };
    if detail.is_empty() {
        detail = match state {
            "running" => "Working",
            "error" => "Agent stopped with an error",
            _ if event == "SessionEnd" => "Session ended",
            _ => "Turn complete",
        }
        .into()
    };
    let cwd = if agent == "cursor" {
        data["workspace_roots"]
            .as_array()
            .and_then(|r| r.first())
            .and_then(Value::as_str)
            .unwrap_or(s(data, "cwd"))
    } else {
        s(data, "cwd")
    };
    let project = if cwd.len() <= 4096 {
        cut(
            &Path::new(cwd)
                .file_name()
                .unwrap_or_default()
                .to_string_lossy(),
            100,
        )
    } else {
        String::new()
    };
    let mut out = json!({"id":format!("{agent}.{}",&hash(session)[..20]),"title":if project.is_empty(){label}else{&project},"state":state,"detail":detail,"ttl":if state=="done"{30}else{3600},"kind":"agent","agent":label,"project":project,"attention":attention,"eventKey":&hash(&string_json(data))[..32]});
    capture_targets(&mut out, agent, cwd);
    if agent == "codex"
        && std::env::var_os("PERCH_RELAY_SOCKET").is_none()
        && valid(session, THREAD)
    {
        if let Ok(handler) = handler() {
            if !handler.is_empty() {
                out["targetCodex"] = json!({"thread":session.to_lowercase(),"handler":handler});
            }
        }
    }
    Some(out)
}
fn window_target(w: &Value) -> Result<Value> {
    let address = s(w, "address");
    let pid = w["pid"].as_u64().ok_or("Invalid window")?;
    if !valid(address, r"^0x[0-9a-fA-F]{1,16}$") {
        return err("Invalid window");
    };
    Ok(
        json!({"target":address,"targetPid":pid,"targetStart":proc_start(pid)?,"targetBoot":boot()?}),
    )
}
fn capture_targets(out: &mut Value, agent: &str, cwd: &str) {
    let ancestors = parents(std::process::id() as u64);
    let _ = (|| -> Result<()> {
        let names: &[&str] = match agent {
            "claude" => &["claude"],
            "codex" => &["codex"],
            "gemini" => &["gemini"],
            "cursor" => &["cursor", "cursor-agent"],
            "factory" => &["droid"],
            "qoder" => &["qoder", "qodercli"],
            _ => &[agent],
        };
        let package = match agent {
            "claude" => "/@anthropic-ai/claude-code/",
            "codex" => "/@openai/codex/",
            "gemini" => "/@google/gemini-cli/",
            "qwen" => "/@qwen-code/qwen-code/",
            "pi" => "/@earendil-works/pi-coding-agent/",
            "omp" => "/@oh-my-pi/pi-coding-agent/",
            _ => "",
        };
        for pid in &ancestors {
            let Ok(binary) = fs::read_link(format!("/proc/{pid}/exe")) else {
                continue;
            };
            let name = binary
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_lowercase();
            let raw = fs::read(format!("/proc/{pid}/cmdline")).unwrap_or_default();
            let args = String::from_utf8_lossy(&raw);
            if names.contains(&name.as_str())
                || args
                    .split('\0')
                    .take(3)
                    .filter(|v| v.starts_with('/'))
                    .any(|p| {
                        names.contains(
                            &Path::new(p)
                                .file_name()
                                .unwrap_or_default()
                                .to_string_lossy()
                                .as_ref(),
                        ) || !package.is_empty() && p.contains(package)
                    })
            {
                out["agentProcess"] = json!({"pid":pid,"start":proc_start(*pid)?,"boot":boot()?});
                break;
            }
        }
        Ok(())
    })();
    let _ = (|| -> Result<()> {
        if cwd.starts_with('/') && cwd.len() <= 1024 && Path::new(cwd).is_dir() {
            for pid in &ancestors {
                let Ok(binary) = fs::read_link(format!("/proc/{pid}/exe")) else {
                    continue;
                };
                let name = binary
                    .file_name()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .to_lowercase();
                let app = if name == "zed-editor" { "zed" } else { &name };
                if [
                    "code",
                    "code-insiders",
                    "cursor",
                    "windsurf",
                    "trae",
                    "zed",
                    "idea",
                    "webstorm",
                    "pycharm",
                    "goland",
                    "clion",
                    "rubymine",
                    "phpstorm",
                    "rider",
                    "rustrover",
                ]
                .contains(&app)
                {
                    out["targetWorkspace"] = json!({"app":app,"path":cwd,"pid":pid,"start":proc_start(*pid)?,"boot":boot()?});
                    break;
                }
            }
        }
        Ok(())
    })();
    let _ = (|| -> Result<()> {
        let session = std::env::var("ZELLIJ_SESSION_NAME").unwrap_or_default();
        let pane = std::env::var("ZELLIJ_PANE_ID").unwrap_or_default();
        if std::env::var_os("TMUX").is_some()
            || std::env::var_os("PERCH_RELAY_SOCKET").is_some()
            || !valid(&session, r"^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$")
        {
            return Ok(());
        };
        let pane = pane.parse::<u32>()?;
        for pid in &ancestors {
            let Ok(binary) = fs::read_link(format!("/proc/{pid}/exe")) else {
                continue;
            };
            if binary.file_name().is_none_or(|s| s != "zellij") {
                continue;
            }
            let args = fs::read(format!("/proc/{pid}/cmdline"))?;
            let args = String::from_utf8_lossy(&args);
            let args: Vec<_> = args.split('\0').collect();
            let Some(path) = args
                .iter()
                .position(|s| *s == "--server")
                .and_then(|i| args.get(i + 1))
            else {
                continue;
            };
            if Path::new(path).file_name().and_then(|v| v.to_str()) != Some(&session) {
                continue;
            }
            let m = socket(path)?;
            let exe = fs::metadata(format!("/proc/{pid}/exe"))?;
            let disk = fs::metadata(&binary)?;
            if (exe.dev(), exe.ino()) != (disk.dev(), disk.ino()) {
                continue;
            }
            out["targetZellij"] = json!({"session":session,"pane":pane,"socket":path,"device":m.dev().to_string(),"inode":m.ino().to_string(),"serverPid":pid,"serverStart":proc_start(*pid)?,"boot":boot()?,"binary":binary,"binaryDevice":exe.dev().to_string(),"binaryInode":exe.ino().to_string()});
            break;
        }
        Ok(())
    })();
    let _ = (|| -> Result<()> {
        if std::env::var_os("HYPRLAND_INSTANCE_SIGNATURE").is_none()
            || std::env::var_os("ZELLIJ_SESSION_NAME").is_some()
                && std::env::var_os("TMUX").is_none()
        {
            return Ok(());
        };
        let clients: Value =
            serde_json::from_str(&run(&["hyprctl", "-j", "clients"], 0.25, 262144)?)?;
        let clients = clients.as_array().ok_or("Invalid windows")?;
        let mut targets = Vec::new();
        if let Ok(value) = std::env::var("TMUX") {
            let pane = std::env::var("TMUX_PANE").unwrap_or_default();
            if !valid(&pane, r"^%[0-9]+$") {
                return Ok(());
            };
            let path = value.rsplitn(3, ',').last().unwrap_or("");
            socket(path)?;
            let query = run(
                &[
                    "tmux",
                    "-S",
                    path,
                    "display-message",
                    "-p",
                    "-t",
                    &pane,
                    "#{pane_pid} #{session_id}",
                ],
                0.25,
                65536,
            )?;
            let q: Vec<_> = query.split_whitespace().collect();
            if q.len() != 2 {
                return Ok(());
            };
            let pane_pid = q[0].parse::<u64>()?;
            if !ancestors.contains(&pane_pid) {
                return Ok(());
            };
            let attached = run(
                &[
                    "tmux",
                    "-S",
                    path,
                    "list-clients",
                    "-F",
                    "#{client_pid} #{client_tty} #{session_id}",
                ],
                0.25,
                65536,
            )?;
            for line in attached.lines() {
                let l: Vec<_> = line.split_whitespace().collect();
                if l.len() != 3 || l[2] != q[1] {
                    continue;
                }
                let pid = l[0].parse::<u64>()?;
                let mut a = parents(pid);
                a.push(pid);
                for w in clients {
                    if w["pid"].as_u64().is_some_and(|p| a.contains(&p)) {
                        let mut t = window_target(w)?;
                        t["targetTmux"] = json!({"socket":path,"pane":pane,"panePid":pane_pid,"paneStart":proc_start(pane_pid)?,"client":l[1],"clientPid":pid,"clientStart":proc_start(pid)?});
                        targets.push(t);
                    }
                }
            }
        } else {
            let windows: Vec<_> = clients
                .iter()
                .filter(|w| w["pid"].as_u64().is_some_and(|p| ancestors.contains(&p)))
                .collect();
            if windows.len() != 1 {
                return Ok(());
            };
            let w = windows[0];
            let mut t = window_target(w)?;
            if let Ok(pane) = std::env::var("WEZTERM_PANE") {
                let pane = pane.parse::<u64>()?;
                let path = std::env::var("WEZTERM_UNIX_SOCKET")?;
                let m = socket(&path)?;
                let rows: Value = serde_json::from_str(&run(
                    &["wezterm", "cli", "list", "--format", "json"],
                    0.25,
                    262144,
                )?)?;
                if rows.as_array().is_none_or(|r| {
                    r.iter()
                        .filter(|p| p["pane_id"].as_u64() == Some(pane))
                        .count()
                        != 1
                }) {
                    return Ok(());
                };
                t["targetWezterm"] = json!({"socket":path,"pane":pane,"device":m.dev().to_string(),"inode":m.ino().to_string(),"windowStart":proc_start(w["pid"].as_u64().unwrap())?});
            }
            targets.push(t);
        }
        if targets.len() == 1 {
            for (k, v) in targets.remove(0).as_object().unwrap() {
                out[k] = v.clone();
            }
        }
        Ok(())
    })();
}
