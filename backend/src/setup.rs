use crate::core::*;
use serde_json::{json, Value};
use std::{
    collections::BTreeMap,
    fs,
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
};
static QUIET: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);
macro_rules! progress { ($($args:tt)*) => { if !QUIET.load(std::sync::atomic::Ordering::Relaxed) { println!($($args)*); } }; }
const AGENTS: &[&str] = &[
    "claude",
    "codex",
    "gemini",
    "cursor",
    "qwen",
    "qoder",
    "factory",
    "codebuddy",
    "kimi",
    "grok",
    "codex-hooks",
];
const EXTENSIONS: &[&str] = &["pi", "omp", "opencode", "opencode-requests"];
const MARKER: &str = "// Perch status extension v1 — owned by perch-extension-setup.\n";
fn events(agent: &str) -> &'static [&'static str] {
    match agent {
        "gemini" => &[
            "BeforeAgent",
            "AfterTool",
            "AfterAgent",
            "Notification",
            "SessionEnd",
        ],
        "cursor" => &["beforeSubmitPrompt", "postToolUse", "stop", "sessionEnd"],
        "codex-hooks" => &[
            "UserPromptSubmit",
            "PreToolUse",
            "PostToolUse",
            "PermissionRequest",
            "Stop",
            "SessionEnd",
            "Interrupt",
        ],
        "grok" => &[
            "UserPromptSubmit",
            "PostToolUse",
            "Notification",
            "Stop",
            "SessionEnd",
            "StopCancelled",
            "StopFailure",
        ],
        "kimi" => &[
            "TurnStarted",
            "PostToolUse",
            "PermissionRequest",
            "PermissionResult",
            "Stop",
            "SessionEnd",
            "Interrupt",
            "StopFailure",
        ],
        _ => &[
            "UserPromptSubmit",
            "PostToolUse",
            "Notification",
            "Stop",
            "SessionEnd",
        ],
    }
}
pub fn quote(s: &str) -> String {
    if !s.is_empty()
        && s.bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"_@%+=:,./-".contains(&b))
    {
        s.into()
    } else {
        format!("'{}'", s.replace('\'', "'\"'\"'"))
    }
}
fn adapter(name: &str) -> PathBuf {
    home().join(".local/share/omarchy-perch").join(name)
}
fn hook_command(name: &str, args: &[&str], legacy: bool) -> String {
    let mut parts = Vec::new();
    if legacy {
        parts.push("python3".to_owned())
    }
    parts.push(quote(&adapter(name).to_string_lossy()));
    parts.extend(args.iter().map(|v| quote(v)));
    parts.join(" ")
}
fn config_path(agent: &str) -> PathBuf {
    match agent {
        "claude" => base("CLAUDE_CONFIG_DIR", home().join(".claude")).join("settings.json"),
        "codex" => base("CODEX_HOME", home().join(".codex")).join("config.toml"),
        "codex-hooks" => base("CODEX_HOME", home().join(".codex")).join("hooks.json"),
        "kimi" => base("KIMI_CODE_HOME", home().join(".kimi-code")).join("config.toml"),
        "grok" => base("GROK_HOME", home().join(".grok")).join("hooks/perch-status.json"),
        "cursor" => home().join(".cursor/hooks.json"),
        a => home().join(format!(".{a}/settings.json")),
    }
}
fn config_read(p: &Path) -> Result<String> {
    if p.is_symlink() {
        return err("Refusing configuration symlink");
    };
    if !p.exists() {
        return Ok(String::new());
    };
    Ok(String::from_utf8(read(p, 1048576, false)?)?)
}
fn json_config(old: &str) -> Result<Value> {
    let v = if old.trim().is_empty() {
        json!({})
    } else {
        serde_json::from_str(old)?
    };
    if !v.is_object() {
        return err("Agent settings must be a JSON object");
    };
    Ok(v)
}
fn disabled(v: &Value) -> bool {
    ["disableAllHooks", "allowManagedHooksOnly", "hooksDisabled"]
        .iter()
        .any(|k| v[*k] == true)
}
fn codex_policy(remove: bool) -> Result<()> {
    let path = base("CODEX_HOME", home().join(".codex")).join("config.toml");
    let old = config_read(&path)?;
    let config = toml::Value::Table(toml::from_str(&old)?);
    if !remove
        && (config
            .get("features")
            .and_then(|v| v.get("hooks").or_else(|| v.get("codex_hooks")))
            .and_then(toml::Value::as_bool)
            == Some(false)
            || config
                .get("allow_managed_hooks_only")
                .and_then(toml::Value::as_bool)
                == Some(true)
            || config
                .get("hooks")
                .and_then(|v| v.get("allow_managed_hooks_only"))
                .and_then(toml::Value::as_bool)
                == Some(true))
    {
        return err("Codex hooks are disabled or managed-only; no changes made");
    };
    Ok(())
}
fn hooks_mut(v: &mut Value) -> Result<&mut serde_json::Map<String, Value>> {
    if v.get("hooks").is_none() {
        v["hooks"] = json!({})
    }
    v["hooks"]
        .as_object_mut()
        .ok_or("Agent hooks must be an object".into())
}
fn transform_groups(
    hooks: &mut serde_json::Map<String, Value>,
    event: &str,
    matcher: Option<&str>,
    commands: (&str, &str),
    remove: bool,
    timeout: u64,
    gemini: bool,
) -> Result<()> {
    let (command, legacy) = commands;
    let groups = hooks.get(event).cloned().unwrap_or(json!([]));
    let groups = groups.as_array().ok_or("Invalid hook groups")?;
    let mut kept = Vec::new();
    for group in groups {
        let entries = group["hooks"]
            .as_array()
            .ok_or("Unrecognized hook configuration; no changes made")?;
        let remain: Vec<_> = entries
            .iter()
            .filter(|h| {
                !(h["type"] == "command" && (h["command"] == command || h["command"] == legacy))
            })
            .cloned()
            .collect();
        if !remain.is_empty() || entries.is_empty() {
            let mut g = group.clone();
            g["hooks"] = json!(remain);
            kept.push(g)
        }
    }
    if !remove {
        let mut h = json!({"type":"command","command":command,"timeout":timeout});
        if gemini {
            h["name"] = "perch-status".into()
        }
        let mut group = json!({"hooks":[h]});
        if let Some(m) = matcher {
            group["matcher"] = m.into()
        }
        kept.push(group)
    }
    if kept.is_empty() {
        hooks.remove(event);
    } else {
        hooks.insert(event.into(), json!(kept));
    }
    Ok(())
}
fn text_result(old: &str, before: &Value, after: &Value) -> Result<String> {
    if before == after {
        Ok(old.into())
    } else {
        Ok(format!("{}\n", serde_json::to_string_pretty(after)?))
    }
}
fn marked_transform(
    old: &str,
    start: &str,
    end: &str,
    block: &str,
    legacy: &str,
    remove: bool,
    prepend: bool,
) -> Result<String> {
    let parsed = toml::Value::Table(toml::from_str(old)?);
    let _ = parsed;
    if old.contains(start) || old.contains(end) {
        if old.matches(start).count() != 1 || old.matches(end).count() != 1 {
            return err("Perch block was edited; no changes made");
        };
        let existing = if old.matches(block).count() == 1 {
            block
        } else if old.matches(legacy).count() == 1 {
            legacy
        } else {
            return err("Perch block was edited; no changes made");
        };
        let result = old.replacen(existing, if remove { "" } else { block }, 1);
        toml::from_str::<toml::Table>(&result)?;
        return Ok(result);
    }
    if remove {
        return Ok(old.into());
    };
    let result = if prepend {
        format!("{block}{old}")
    } else {
        format!(
            "{old}{}{block}",
            if old.is_empty() || old.ends_with('\n') {
                ""
            } else {
                "\n"
            }
        )
    };
    toml::from_str::<toml::Table>(&result)?;
    Ok(result)
}
pub fn transform_agent(agent: &str, old: &str, remove: bool, standalone: bool) -> Result<String> {
    if !AGENTS.contains(&agent) {
        return err("Unsupported agent");
    };
    if agent == "codex" {
        let parsed = toml::Value::Table(toml::from_str(old)?);
        let argv = json!([adapter("perch-agent-hook"), "--perch-hook-v1", "codex"]);
        let legacy = json!([
            "python3",
            adapter("perch-agent-hook"),
            "--perch-hook-v1",
            "codex"
        ]);
        let block = format!(
            "# BEGIN PERCH NOTIFY v1\nnotify = {}\n# END PERCH NOTIFY v1\n",
            string_json(&argv)
        );
        let oldblock = format!(
            "# BEGIN PERCH NOTIFY v1\nnotify = {}\n# END PERCH NOTIFY v1\n",
            serde_json::to_string(&legacy)?.replace(',', ", ")
        );
        if !old.contains("# BEGIN PERCH NOTIFY v1") && parsed.get("notify").is_some() && !remove {
            return err("Codex already has a notify command. It has been preserved.");
        };
        if old.contains("# BEGIN PERCH NOTIFY v1") {
            let notify = parsed
                .get("notify")
                .ok_or("Perch notify block was edited; no changes made")?;
            let v = serde_json::to_value(notify)?;
            if v != argv && v != legacy {
                return err("Perch notify block was edited; no changes made");
            }
        }
        return marked_transform(
            old,
            "# BEGIN PERCH NOTIFY v1",
            "# END PERCH NOTIFY v1",
            &block,
            &oldblock,
            remove,
            true,
        );
    }
    if agent == "kimi" {
        let parsed = toml::Value::Table(toml::from_str(old)?);
        if parsed.get("hooks").is_some_and(|v| !v.is_array()) {
            return err("Unrecognized Kimi hooks");
        };
        let block = |legacy| {
            format!(
                "# BEGIN PERCH KIMI v1\n{}# END PERCH KIMI v1\n",
                events("kimi")
                    .iter()
                    .map(|e| format!(
                        "[[hooks]]\nevent = {}\ncommand = {}\ntimeout = 3\n",
                        string_json(&json!(e)),
                        string_json(&json!(hook_command(
                            "perch-agent-hook",
                            &["--perch-hook-v1", "kimi"],
                            legacy
                        )))
                    ))
                    .collect::<String>()
            )
        };
        return marked_transform(
            old,
            "# BEGIN PERCH KIMI v1",
            "# END PERCH KIMI v1",
            &block(false),
            &block(true),
            remove,
            false,
        );
    }
    let mut before = json_config(old)?;
    if !remove && disabled(&before) {
        return err("Agent hooks are disabled; Perch will not override that preference");
    };
    if standalone {
        before = json!({"hooks":before})
    };
    if agent == "cursor" && before.get("version").is_some_and(|v| v != 1) {
        return err("Unsupported Cursor hooks version");
    };
    let mut after = before.clone();
    if agent == "cursor" && !remove && after.get("version").is_none() {
        after["version"] = 1.into()
    };
    let command = hook_command("perch-agent-hook", &["--perch-hook-v1", agent], false);
    let legacy = hook_command("perch-agent-hook", &["--perch-hook-v1", agent], true);
    if agent == "gemini"
        && !remove
        && (before["hooks"]["enabled"] == false
            || before["tools"]["enableHooks"] == false
            || before["hooks"]["disabled"].as_array().is_some_and(|v| {
                v.contains(&json!("perch-status"))
                    || v.contains(&json!(command))
                    || v.contains(&json!(legacy))
            }))
    {
        return err("Gemini hooks are disabled; no changes made");
    };
    let hooks = hooks_mut(&mut after)?;
    for event in events(agent) {
        if agent == "cursor" {
            let entries = hooks.get(*event).cloned().unwrap_or(json!([]));
            let entries = entries
                .as_array()
                .filter(|e| e.iter().all(Value::is_object))
                .ok_or("Invalid Cursor hook entries")?;
            let mut kept: Vec<_> = entries
                .iter()
                .filter(|h| {
                    !((h["command"] == command || h["command"] == legacy)
                        && h.get("type").is_none_or(|v| v == "command"))
                })
                .cloned()
                .collect();
            if !remove {
                kept.push(json!({"command":command,"timeout":3}))
            }
            if kept.is_empty() {
                hooks.remove(*event);
            } else {
                hooks.insert((*event).into(), json!(kept));
            }
        } else {
            transform_groups(
                hooks,
                event,
                None,
                (&command, &legacy),
                remove,
                if agent == "gemini" { 3000 } else { 3 },
                agent == "gemini",
            )?;
        }
    }
    if hooks.is_empty() {
        after.as_object_mut().unwrap().remove("hooks");
    }
    if standalone {
        if before == after {
            Ok(old.into())
        } else {
            Ok(format!(
                "{}\n",
                serde_json::to_string_pretty(after.get("hooks").unwrap_or(&json!({})))?
            ))
        }
    } else {
        text_result(old, &before, &after)
    }
}
fn transform_request(old: &str, agent: &str, remove: bool) -> Result<String> {
    let before = json_config(old)?;
    if !remove && disabled(&before) {
        return err("Hooks are disabled; no changes made");
    };
    let mut after = before.clone();
    let args = if agent == "claude" {
        vec![]
    } else {
        vec!["--agent", agent]
    };
    let command = hook_command("perch-request-hook", &args, false);
    let legacy = hook_command("perch-request-hook", &args, true);
    let hooks = hooks_mut(&mut after)?;
    for (event, matcher) in if agent == "claude" {
        vec![
            ("PermissionRequest", "*"),
            ("PreToolUse", "AskUserQuestion"),
        ]
    } else {
        vec![("PermissionRequest", "*")]
    } {
        transform_groups(
            hooks,
            event,
            Some(matcher),
            (&command, &legacy),
            remove,
            130,
            false,
        )?;
    }
    if hooks.is_empty() {
        after.as_object_mut().unwrap().remove("hooks");
    }
    text_result(old, &before, &after)
}
fn transform_usage(old: &str, remove: bool) -> Result<String> {
    let before = json_config(old)?;
    let owned =
        json!({"type":"command","command":hook_command("perch-usage-statusline",&[],false)});
    let legacy =
        json!({"type":"command","command":hook_command("perch-usage-statusline",&[],true)});
    if before
        .get("statusLine")
        .is_some_and(|v| !v.is_null() && v != &owned && v != &legacy)
    {
        if remove {
            return Ok(old.into());
        }
        return err("A custom status line already exists. It has been preserved.");
    };
    let mut after = before.clone();
    if remove {
        after.as_object_mut().unwrap().remove("statusLine");
    } else {
        after["statusLine"] = owned;
    }
    text_result(old, &before, &after)
}
fn backup_write(path: &Path, old: &str, new: &str) -> Result<()> {
    if old == new {
        return Ok(());
    };
    if config_read(path)? != old {
        return err("Configuration changed during setup. Run setup again.");
    };
    if path.exists() {
        let backup = path.with_file_name(format!(
            "{}.perch-backup-{}",
            path.file_name().unwrap_or_default().to_string_lossy(),
            (now() * 1e9) as u128
        ));
        atomic(&backup, old.as_bytes(), 0o600)?;
    }
    atomic(path, new.as_bytes(), 0o600)
}
fn install_adapter(name: &str) -> Result<()> {
    let target = adapter(name);
    let old = config_read(&target)?;
    let legacy = match name {
        "perch-agent-hook" => "Best-effort, status-only Claude Code / Codex hook.",
        "perch-request-hook" => "Perch request bridge v1",
        _ => "Perch usage statusline v1",
    };
    if !old.is_empty() && !old.contains(legacy) && !old.contains("# Perch Rust adapter v1") {
        return err("Adapter path is occupied by an unrelated file");
    };
    install_backend()?;
    let command = name.strip_prefix("perch-").unwrap();
    let script=format!("#!/bin/sh\n# Perch Rust adapter v1\nexec \"$(dirname \"$0\")/perch-backend\" {command} \"$@\"\n");
    backup_write(&target, &old, &script)?;
    fs::set_permissions(target, fs::Permissions::from_mode(0o700))?;
    Ok(())
}
fn install_backend() -> Result<()> {
    let binary = std::env::current_exe()?;
    let destination = adapter("perch-backend");
    let ownership = destination.with_extension("sha256");
    if destination.is_symlink() {
        return err("Refusing backend symlink");
    };
    if destination.exists() {
        let owned = config_read(&ownership)?;
        let bytes = read(&destination, 64 * 1024 * 1024, false)?;
        use sha2::{Digest, Sha256};
        if owned.trim() != format!("{:x}", Sha256::digest(&bytes)) {
            return err("Installed backend was modified or is not owned by Perch");
        }
    }
    let data = read(&binary, 64 * 1024 * 1024, false)?;
    use sha2::{Digest, Sha256};
    atomic(&destination, &data, 0o700)?;
    atomic(
        &ownership,
        format!("{:x}\n", Sha256::digest(&data)).as_bytes(),
        0o600,
    )?;
    Ok(())
}
fn extension_target(agent: &str) -> Result<PathBuf> {
    match agent {
        "opencode" | "opencode-requests" => Ok(base("XDG_CONFIG_HOME", home().join(".config"))
            .join(if agent == "opencode" {
                "opencode/plugins/perch-status.js"
            } else {
                "opencode/plugins/perch-requests.js"
            })),
        "pi" | "omp" => Ok(base(
            "PI_CODING_AGENT_DIR",
            home().join(format!(".{agent}/agent")),
        )
        .join("extensions/perch-status.js")),
        _ => err("Unknown extension client"),
    }
}
fn extension_render(agent: &str) -> Result<String> {
    let file = if agent.starts_with("opencode") {
        format!("{agent}.js")
    } else {
        "pi.js".into()
    };
    Ok(
        fs::read_to_string(root().join("scripts/extensions").join(file))?
            .replace(
                "__PERCH_ADAPTER__",
                &string_json(&json!(adapter("perch-agent-hook"))),
            )
            .replace("__PERCH_AGENT__", &string_json(&json!(agent)))
            .replace(
                "__PERCH_REQUEST_ADAPTER__",
                &string_json(&json!(adapter("perch-request-hook"))),
            ),
    )
}
pub fn setup(command: &str, args: &[String]) -> Result<()> {
    if args.iter().any(|a| a == "--help") {
        progress!("Perch Rust setup: --apply writes with backups; --remove removes only owned integration entries.");
        return Ok(());
    }
    let apply = args.iter().any(|a| a == "--apply");
    let remove = args.iter().any(|a| a == "--remove");
    let option = |key: &str, default: &str| {
        args.iter()
            .position(|a| a == key)
            .and_then(|i| args.get(i + 1))
            .cloned()
            .unwrap_or(default.into())
    };
    if command == "notifications-setup" {
        return companion(&option("--kind", "notifications"), apply, remove);
    }
    if command == "extension-setup" {
        let agent = args.first().ok_or("Choose an extension client")?;
        let path = extension_target(agent)?;
        let old = config_read(&path)?;
        if !old.is_empty() && !old.starts_with(MARKER) {
            return err("Extension path is occupied by an unrelated file");
        };
        progress!(
            "{} Perch extension: {}",
            if remove { "Remove" } else { "Install" },
            path.display()
        );
        if !apply {
            progress!("Preview only. Add --apply to write changes.");
            return Ok(());
        }
        if !remove {
            install_adapter(if agent == "opencode-requests" {
                "perch-request-hook"
            } else {
                "perch-agent-hook"
            })?;
        }
        let new = if remove {
            String::new()
        } else {
            extension_render(agent)?
        };
        backup_write(&path, &old, &new)?;
        if remove && path.exists() {
            fs::remove_file(path)?;
        }
        progress!("Done. Restart the client to load or unload the extension.");
        return Ok(());
    }
    let agent = if command == "agent-setup" {
        args.first().cloned().ok_or("Choose an agent")?
    } else if command == "request-setup" {
        option("--agent", "claude")
    } else {
        "claude".into()
    };
    let mut path = config_path(&agent);
    let mut standalone = false;
    if command == "agent-setup" && agent == "factory" {
        let settings = json_config(&config_read(&path)?)?;
        if !remove && disabled(&settings) {
            return err("Factory hooks are disabled or managed-only; no changes made");
        };
        let direct = home().join(".factory/hooks.json");
        if direct.exists() || settings.get("hooks").is_none() {
            if !direct.exists() && home().join(".factory/hooks/hooks.json").exists() {
                return err("Migrate legacy Factory hooks with /hooks first; no changes made");
            };
            path = direct;
            standalone = true;
        }
    }
    if agent == "codex-hooks" || command == "request-setup" && agent == "codex" {
        codex_policy(remove)?;
        path = config_path("codex-hooks");
    }
    let old = config_read(&path)?;
    let (name, new) = match command {
        "agent-setup" => (
            "perch-agent-hook",
            transform_agent(&agent, &old, remove, standalone)?,
        ),
        "request-setup" if ["claude", "codex"].contains(&agent.as_str()) => (
            "perch-request-hook",
            transform_request(&old, &agent, remove)?,
        ),
        "usage-setup" => ("perch-usage-statusline", transform_usage(&old, remove)?),
        _ => return err("Unknown setup command"),
    };
    progress!(
        "{} Perch {} integration in {}",
        if remove { "Remove" } else { "Install" },
        agent,
        path.display()
    );
    if !apply {
        progress!(
            "Preview only. Add --apply to write changes. Configuration contents are not printed."
        );
        return Ok(());
    }
    if !remove {
        install_adapter(name)?;
    }
    backup_write(&path, &old, &new)?;
    progress!("Done. Restart the client. Review new or changed hooks in /hooks; Perch does not override trust or managed restrictions.");
    Ok(())
}
fn enabled() -> Vec<String> {
    let path = home().join(".config/omarchy/shell.json");
    let data = read(&path, 1048576, true)
        .and_then(|v| Ok(serde_json::from_slice::<Value>(&v)?))
        .unwrap_or(json!({}));
    let mut rows = Vec::new();
    for v in [
        data["plugins"].clone(),
        data["bar"]["layout"]["left"].clone(),
        data["bar"]["layout"]["center"].clone(),
        data["bar"]["layout"]["right"].clone(),
    ] {
        if let Some(a) = v.as_array() {
            rows.extend(
                a.iter()
                    .filter_map(|e| e.as_str().or(e["id"].as_str()))
                    .map(str::to_owned),
            );
        }
    }
    rows
}
fn hashes(dir: &Path) -> Result<BTreeMap<String, String>> {
    let mut map = BTreeMap::new();
    let mut pending = vec![dir.to_owned()];
    let mut seen = 0;
    while let Some(d) = pending.pop() {
        for e in fs::read_dir(d)? {
            let p = e?.path();
            seen += 1;
            if seen > 64 {
                return err("Companion contains unexpected files");
            };
            let m = fs::symlink_metadata(&p)?;
            if m.file_type().is_symlink() {
                return err("Companion contains symlinks");
            };
            if m.is_dir() {
                pending.push(p)
            } else if m.is_file() && p.file_name().is_some_and(|s| s != ".perch-companion.json") {
                use sha2::{Digest, Sha256};
                let bytes = read(&p, 1048576, false)?;
                map.insert(
                    p.strip_prefix(dir)?.to_string_lossy().into(),
                    format!("{:x}", Sha256::digest(bytes)),
                );
            }
        }
    }
    Ok(map)
}
fn companion(kind: &str, apply: bool, remove: bool) -> Result<()> {
    if !["notifications", "osd"].contains(&kind) {
        return err("Unknown companion");
    };
    let id = format!("io.github.tcballard.perch-{kind}");
    let source_id = format!("omarchy.{kind}");
    let base = home().join(".config/omarchy/plugins");
    let target = base.join(&id);
    if target.is_symlink() {
        return err("Companion path is a symlink; no changes made");
    };
    if target.exists() {
        let owned: Value =
            serde_json::from_slice(&read(&target.join(".perch-companion.json"), 65536, false)?)?;
        if owned != serde_json::to_value(hashes(&target)?)? {
            return err(
                "Companion files were modified. Preserve edits before replacing/removing it.",
            );
        }
    }
    if !remove {
        let ids = enabled();
        if !ids.iter().any(|s| s == "io.github.tcballard.perch") {
            return err("Enable Perch before enabling its companion");
        };
        if let Ok(entries) = fs::read_dir(&base) {
            for e in entries.flatten() {
                let file = e.path().join("manifest.json");
                let Ok(raw) = read(&file, 65536, true) else {
                    continue;
                };
                let Ok(m) = serde_json::from_slice::<Value>(&raw) else {
                    continue;
                };
                if s(&m, "id") != id
                    && ids.contains(&s(&m, "id").into())
                    && m["omarchy"]["clonedFrom"] == source_id
                {
                    return err("Another clone is enabled. Disable it explicitly first.");
                }
            }
        }
    }
    progress!(
        "{} {}",
        if remove { "Remove" } else { "Install/update" },
        target.display()
    );
    if !apply {
        progress!("Preview only. Add --apply to make changes.");
        return Ok(());
    }
    if remove {
        if target.exists() {
            run(&["omarchy", "plugin", "disable", &id], 10.0, 16384)?;
            fs::remove_dir_all(&target)?;
            run(&["omarchy-shell", "shell", "rescanPlugins"], 10.0, 4096)?;
        }
        return Ok(());
    }
    if kind == "notifications" {
        install_backend()?;
    }
    fs::create_dir_all(&base)?;
    let stage = tempfile::Builder::new()
        .prefix(".perch-companion-")
        .tempdir_in(&base)?;
    let source = root().join("companions").join(kind);
    for file in if kind == "notifications" {
        vec![
            "manifest.json",
            "Service.qml",
            "CommandJob.qml",
            "NotificationStore.qml",
            "perch-notification-store",
        ]
    } else {
        vec!["manifest.json", "Panel.qml", "CommandJob.qml"]
    } {
        fs::copy(source.join(file), stage.path().join(file))?;
    }
    atomic(
        &stage.path().join(".perch-companion.json"),
        serde_json::to_string_pretty(&hashes(stage.path())?)?.as_bytes(),
        0o600,
    )?;
    run(
        &[
            "omarchy",
            "plugin",
            "validate",
            stage.path().to_str().ok_or("Invalid staging path")?,
        ],
        10.0,
        16384,
    )?;
    let fresh = !target.exists();
    if !fresh {
        let previous = base.join(format!(".perch-companion-old-{}", std::process::id()));
        if previous.exists() {
            return err("Previous companion backup exists; preserve it before retrying");
        };
        fs::rename(&target, &previous)?;
        if let Err(e) = fs::rename(stage.path(), &target) {
            fs::rename(previous, &target)?;
            return Err(e.into());
        };
        fs::remove_dir_all(previous)?;
    } else {
        fs::rename(stage.path(), &target)?;
    }
    run(&["omarchy-shell", "shell", "rescanPlugins"], 10.0, 4096)?;
    let discovered = (|| -> Result<()> {
        for _ in 0..40 {
            if let Ok(raw) = run(&["omarchy", "plugin", "list", "--json"], 2.0, 1048576) {
                if let Ok(v) = serde_json::from_str::<Value>(&raw) {
                    if v.as_array()
                        .is_some_and(|v| v.iter().any(|r| r["id"] == id))
                    {
                        run(&["omarchy", "plugin", "enable", &id], 10.0, 16384)?;
                        return Ok(());
                    }
                }
            }
            std::thread::sleep(std::time::Duration::from_millis(50));
        }
        err("Companion discovery timed out; restart the shell and rerun setup")
    })();
    if discovered.is_err() && fresh {
        let _ = fs::remove_dir_all(&target);
        let _ = run(&["omarchy-shell", "shell", "rescanPlugins"], 10.0, 4096);
    }
    discovered?;
    progress!("Companion enabled. After updates run: omarchy restart shell");
    Ok(())
}
fn exact(config: &Value, event: &str, command: &str, matcher: Option<&str>) -> bool {
    config["hooks"][event].as_array().is_some_and(|groups| {
        groups.iter().any(|g| {
            matcher.is_none_or(|m| g["matcher"] == m)
                && g["hooks"].as_array().is_some_and(|h| {
                    h.iter()
                        .any(|h| h["type"] == "command" && h["command"] == command)
                })
        })
    })
}
fn backend_current() -> bool {
    let Ok(installed) = read(&adapter("perch-backend"), 64 * 1024 * 1024, false) else {
        return false;
    };
    std::env::current_exe()
        .ok()
        .and_then(|p| read(&p, 64 * 1024 * 1024, false).ok())
        .is_some_and(|b| b == installed)
}
fn adapter_current(name: &str, current: bool) -> bool {
    current
        && config_read(&adapter(name)).is_ok_and(|text| text.contains("# Perch Rust adapter v1"))
}
fn integration_state(agent: &str) -> Result<(String, bool)> {
    let path = config_path(agent);
    if !path.exists() {
        return Ok(("not configured".into(), false));
    };
    let old = config_read(&path)?;
    if ["codex", "kimi"].contains(&agent) {
        let data = toml::Value::Table(toml::from_str(&old)?);
        if agent == "codex" {
            let argv = json!([adapter("perch-agent-hook"), "--perch-hook-v1", "codex"]);
            let legacy = json!([
                "python3",
                adapter("perch-agent-hook"),
                "--perch-hook-v1",
                "codex"
            ]);
            let v = data
                .get("notify")
                .map(serde_json::to_value)
                .transpose()?
                .unwrap_or(Value::Null);
            return Ok((
                if v == argv || v == legacy {
                    "enabled"
                } else if !v.is_null() {
                    "existing notifier"
                } else {
                    "disabled"
                }
                .into(),
                v == legacy,
            ));
        }
        let hooks = data.get("hooks").and_then(toml::Value::as_array);
        let c = hook_command("perch-agent-hook", &["--perch-hook-v1", agent], false);
        let l = hook_command("perch-agent-hook", &["--perch-hook-v1", agent], true);
        let present = events(agent)
            .iter()
            .map(|e| {
                hooks.is_some_and(|h| {
                    h.iter().any(|h| {
                        h.get("event").and_then(toml::Value::as_str) == Some(*e)
                            && h.get("command")
                                .and_then(toml::Value::as_str)
                                .is_some_and(|x| x == c || x == l)
                    })
                })
            })
            .collect::<Vec<_>>();
        return Ok((
            state(&present).into(),
            hooks.is_some_and(|h| {
                h.iter()
                    .any(|h| h.get("command").and_then(toml::Value::as_str) == Some(&l))
            }),
        ));
    }
    let mut data = json_config(&old)?;
    if agent == "factory" {
        let direct = home().join(".factory/hooks.json");
        if direct.exists() {
            data["hooks"] = json_config(&config_read(&direct)?)?;
        }
    }
    let c = hook_command("perch-agent-hook", &["--perch-hook-v1", agent], false);
    let l = hook_command("perch-agent-hook", &["--perch-hook-v1", agent], true);
    let mut legacy = false;
    let present = events(agent)
        .iter()
        .map(|e| {
            let check = |command: &str| {
                if agent == "cursor" {
                    data["hooks"][*e].as_array().is_some_and(|h| {
                        h.iter().any(|h| {
                            h["command"] == command && h.get("type").is_none_or(|v| v == "command")
                        })
                    })
                } else {
                    exact(&data, e, command, None)
                }
            };
            legacy |= check(&l);
            check(&c) || check(&l)
        })
        .collect::<Vec<_>>();
    let off = disabled(&data)
        || data["hooks"]["enabled"] == false
        || agent == "gemini"
            && (data["tools"]["enableHooks"] == false
                || data["hooks"]["disabled"].as_array().is_some_and(|v| {
                    v.contains(&json!("perch-status"))
                        || v.contains(&json!(c))
                        || v.contains(&json!(l))
                }));
    if agent == "codex-hooks" && codex_policy(false).is_err() {
        return Ok(("hooks disabled".into(), legacy));
    };
    Ok((
        if off {
            "hooks disabled"
        } else {
            state(&present)
        }
        .into(),
        legacy,
    ))
}
fn state(p: &[bool]) -> &'static str {
    if p.iter().all(|v| *v) {
        "enabled"
    } else if p.iter().any(|v| *v) {
        "incomplete"
    } else {
        "disabled"
    }
}
fn update_available() -> &'static str {
    let install = home().join(".config/omarchy/plugins/io.github.tcballard.perch");
    if install.is_symlink()
        || !install.join(".git").is_dir()
        || install.canonicalize().ok() != root().canonicalize().ok()
    {
        "manual install"
    } else if which("omarchy-plugin-update").is_none() {
        "host updater missing"
    } else if which("cargo").is_none() {
        "Rust build tool missing"
    } else {
        "available"
    }
}
fn apply_update() -> Result<Value> {
    if update_available() != "available" {
        return err("Update this install through its original method; git source updates require the Rust build toolchain");
    }
    let root = root();
    let path = root.to_str().ok_or("Invalid installation path")?;
    let git = |args: &[&str]| -> Result<String> {
        let mut argv = vec!["git", "-C", path];
        argv.extend_from_slice(args);
        Ok(run(&argv, 3.0, 16384)?.trim().into())
    };
    if !git(&["status", "--porcelain"])?.is_empty() {
        return err("Perch has local changes; update them manually");
    }
    let current = git(&["symbolic-ref", "--quiet", "--short", "HEAD"])?;
    let default = git(&["symbolic-ref", "--quiet", "refs/remotes/origin/HEAD"])?;
    if default.strip_prefix("refs/remotes/origin/") != Some(&current) {
        return err("Perch is on a review or custom branch; update it manually");
    }
    run(
        &[
            "omarchy-plugin-update",
            "io.github.tcballard.perch",
            "--yes",
        ],
        75.0,
        16384,
    )?;
    // Explicit/opted-in source updates finish their build before replacing the executable.
    let target = base("XDG_CACHE_HOME", home().join(".cache")).join("omarchy-perch-build/target");
    run(
        &[
            "cargo",
            "build",
            "--release",
            "--locked",
            "--target-dir",
            target.to_str().ok_or("Invalid build cache path")?,
            "--manifest-path",
            root.join("backend/Cargo.toml")
                .to_str()
                .ok_or("Invalid build path")?,
        ],
        300.0,
        1048576,
    )?;
    let binary = fs::read(target.join("release/perch-backend"))?;
    atomic(&root.join("bin/perch-backend"), &binary, 0o755)?;
    Ok(ok_message(
        "Perch updated and Rust backend rebuilt. Review Setup for hook and companion updates.",
    ))
}
pub fn health() -> Result<Value> {
    let ids = enabled();
    let current = backend_current();
    let mut result = json!({});
    let mut updates = Vec::new();
    for kind in ["notifications", "osd"] {
        let on = ids.contains(&format!("io.github.tcballard.perch-{kind}"));
        result[kind] = if on { "enabled" } else { "disabled" }.into();
        if on {
            let source = root().join("companions").join(kind);
            let target = home()
                .join(".config/omarchy/plugins")
                .join(format!("io.github.tcballard.perch-{kind}"));
            let files = if kind == "notifications" {
                vec![
                    "manifest.json",
                    "Service.qml",
                    "CommandJob.qml",
                    "NotificationStore.qml",
                    "perch-notification-store",
                ]
            } else {
                vec!["manifest.json", "Panel.qml", "CommandJob.qml"]
            };
            if files
                .iter()
                .any(|name| fs::read(source.join(name)).ok() != fs::read(target.join(name)).ok())
            {
                updates.push(kind.to_string());
            }
        }
    }
    for a in AGENTS {
        let (status, legacy) =
            integration_state(a).unwrap_or(("configuration unreadable".into(), false));
        if status == "enabled" && (legacy || !adapter_current("perch-agent-hook", current)) {
            updates.push(a.to_string());
        }
        result[*a] = status.into();
    }
    let claude =
        json_config(&config_read(&config_path("claude")).unwrap_or_default()).unwrap_or(json!({}));
    let usage_current =
        json!({"type":"command","command":hook_command("perch-usage-statusline",&[],false)});
    let usage_legacy =
        json!({"type":"command","command":hook_command("perch-usage-statusline",&[],true)});
    let usage = if claude["statusLine"] == usage_current || claude["statusLine"] == usage_legacy {
        "enabled"
    } else if !claude["statusLine"].is_null() {
        "custom status line"
    } else {
        "disabled"
    };
    result["usage"] = usage.into();
    if usage == "enabled"
        && (claude["statusLine"] == usage_legacy
            || !adapter_current("perch-usage-statusline", current))
    {
        updates.push("usage".into());
    }
    for (key, agent, data) in [
        ("requests", "claude", claude.clone()),
        (
            "requests-codex",
            "codex",
            json_config(&config_read(&config_path("codex-hooks")).unwrap_or_default())
                .unwrap_or(json!({})),
        ),
    ] {
        let args = if agent == "claude" {
            vec![]
        } else {
            vec!["--agent", agent]
        };
        let c = hook_command("perch-request-hook", &args, false);
        let l = hook_command("perch-request-hook", &args, true);
        let e = if agent == "claude" {
            vec![
                ("PermissionRequest", "*"),
                ("PreToolUse", "AskUserQuestion"),
            ]
        } else {
            vec![("PermissionRequest", "*")]
        };
        let present = e
            .iter()
            .map(|(e, m)| exact(&data, e, &c, Some(m)) || exact(&data, e, &l, Some(m)))
            .collect::<Vec<_>>();
        let status = if disabled(&data) || agent == "codex" && codex_policy(false).is_err() {
            "hooks disabled"
        } else {
            state(&present)
        };
        result[key] = status.into();
        if status == "enabled"
            && (!adapter_current("perch-request-hook", current)
                || e.iter().any(|(e, m)| exact(&data, e, &l, Some(m))))
        {
            updates.push(key.into());
        }
    }
    for agent in EXTENSIONS {
        let path = extension_target(agent)?;
        let status = if path.is_symlink() {
            "occupied"
        } else if !path.exists() {
            "not configured"
        } else if let Ok(old) = config_read(&path) {
            if old == extension_render(agent)? {
                "enabled"
            } else if old.starts_with(MARKER) {
                "outdated"
            } else {
                "occupied"
            }
        } else {
            "configuration unreadable"
        };
        if status == "outdated"
            || status == "enabled"
                && !adapter_current(
                    if *agent == "opencode-requests" {
                        "perch-request-hook"
                    } else {
                        "perch-agent-hook"
                    },
                    current,
                )
        {
            updates.push(agent.to_string());
        }
        result[*agent] = if status == "outdated" {
            "enabled"
        } else {
            status
        }
        .into();
    }
    result["updates"] = json!(updates);
    result["selfUpdate"] = update_available().into();
    result["brightness"] = if which("brightnessctl").is_none() {
        "brightnessctl missing"
    } else if run(&["brightnessctl", "-c", "backlight", "-m"], 3.0, 4096).is_ok() {
        "available"
    } else {
        "no backlight device"
    }
    .into();
    result["sharing"] = if which("localsend")
        .or_else(|| which("localsend_app"))
        .is_some()
    {
        "available"
    } else {
        "LocalSend missing"
    }
    .into();
    result["alarm"] = if which("canberra-gtk-play").is_some() {
        "available"
    } else {
        "sound helper missing"
    }
    .into();
    let mut job = Store::new("integrations")?.load(json!({}))?;
    if !job.is_object() {
        job = json!({})
    }
    if s(&job, "status") == "working" && now() - job["started"].as_f64().unwrap_or(0.0) > 900.0 {
        job["status"] = "failed".into();
        job["message"] = "Setup was interrupted. Refresh and retry.".into();
    }
    result["job"] = job;
    Ok(json!({"health":result}))
}
pub fn tools(op: &str, p: &Value) -> Result<Value> {
    if op == "health" {
        return health();
    }
    if op == "self-update-apply" {
        return apply_update();
    };
    let names = if p["all"] == true || op == "integration-remove-all" {
        AGENTS
            .iter()
            .chain(EXTENSIONS)
            .copied()
            .chain([
                "requests-codex",
                "usage",
                "requests",
                "osd",
                "notifications",
            ])
            .collect::<Vec<_>>()
    } else {
        vec![s(p, "name")]
    };
    if names.iter().any(|n| {
        !AGENTS.contains(n)
            && !EXTENSIONS.contains(n)
            && ![
                "requests-codex",
                "usage",
                "requests",
                "osd",
                "notifications",
                "perch-update",
            ]
            .contains(n)
    }) {
        return err("Unknown integration");
    };
    if p.get("enabled").is_some_and(|v| !v.is_boolean()) {
        return err("Invalid integration setting");
    };
    let enabled = p["enabled"] == true && op != "integration-remove-all";
    if op == "integration-worker" {
        QUIET.store(true, std::sync::atomic::Ordering::Relaxed);
        let mut failures = Vec::new();
        for name in names {
            if name == "perch-update" {
                if let Err(e) = apply_update() {
                    failures.push(format!("perch-update: {}", cut(&e.to_string(), 200)));
                }
                continue;
            }
            let (command, mut args) = if AGENTS.contains(&name) {
                ("agent-setup", vec![name.to_string()])
            } else if EXTENSIONS.contains(&name) {
                ("extension-setup", vec![name.to_string()])
            } else if name == "requests-codex" {
                ("request-setup", vec!["--agent".into(), "codex".into()])
            } else if name == "requests" {
                ("request-setup", vec![])
            } else if name == "usage" {
                ("usage-setup", vec![])
            } else {
                ("notifications-setup", vec!["--kind".into(), name.into()])
            };
            args.push("--apply".into());
            if !enabled {
                args.push("--remove".into())
            }
            if let Err(e) = setup(command, &args) {
                failures.push(format!("{name}: {}", cut(&e.to_string(), 200)));
            }
        }
        QUIET.store(false, std::sync::atomic::Ordering::Relaxed);
        let status = json!({"status":if failures.is_empty(){"done"}else{"failed"},"message":if failures.is_empty(){"Integrations updated. Restart clients and run omarchy restart shell after companion updates.".to_string()}else{format!("Setup did not complete. {}. Other steps may have completed; review integration states and retry.",cut(&failures.join("; "),400))},"started":now()});
        Store::new("integrations")?.save(&status)?;
        return Ok(status);
    }
    let store = Store::new("integrations")?;
    let current = store.load(json!({}))?;
    if s(&current, "status") == "working"
        && now() - current["started"].as_f64().unwrap_or(0.0) < 900.0
    {
        return err("Setup already running");
    };
    let request = if op == "integration-remove-all" {
        json!({"all":true,"enabled":false})
    } else {
        p.clone()
    };
    store.save(&json!({"status":"working","message":"Updating integrations…","started":now()}))?;
    let binary = std::env::current_exe()?;
    let result = launch(&[
        binary.to_str().ok_or("Invalid backend path")?,
        "tools",
        "integration-worker",
        &string_json(&request),
    ]);
    if let Err(e) = result {
        store.save(
            &json!({"status":"failed","message":"Setup worker could not start","started":now()}),
        )?;
        return Err(e);
    }
    drop(store);
    let mut result = health()?;
    result["message"] = "Setup started. Reopen Setup to see the result.".into();
    Ok(result)
}
