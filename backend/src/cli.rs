use crate::{agents, core::*, setup, sockets};
use serde_json::{json, Value};
use std::{
    fs,
    io::{Read, Write},
    os::unix::{fs::OpenOptionsExt, process::CommandExt},
    path::PathBuf,
    process::{Command, Stdio},
    time::{Duration, Instant},
};
pub fn dispatch(command: &str, args: &[String]) -> Result<()> {
    if args.iter().any(|a| a == "--help") || ["help", "--help"].contains(&command) {
        println!("Perch Rust backend\nCommands: tools, activity, task, agent-hook, request-hook, relay, agent-setup, request-setup, extension-setup, usage-setup, usage-statusline, notifications-setup, notification-store, support, diagnostics");
        return Ok(());
    }
    match command {
        "agent-setup"
        | "request-setup"
        | "extension-setup"
        | "usage-setup"
        | "notifications-setup" => setup::setup(command, args),
        "relay" => {
            let result = sockets::relay(args);
            if result.is_err() {
                println!(
                    "{}",
                    json!({"error":"Relay could not start. Check the runtime directory and stop any existing receiver."})
                );
            }
            result
        }
        "request-hook" => sockets::request_hook(args),
        "agent-hook" => {
            let _ = (|| -> Result<()> {
                if args.len() < 2 || args[0] != "--perch-hook-v1" {
                    return Ok(());
                };
                let agent = &args[1];
                let raw = if agent == "codex" {
                    if args.len() != 3 {
                        return Ok(());
                    };
                    args[2].as_bytes().to_vec()
                } else {
                    if args.len() != 2 {
                        return Ok(());
                    };
                    stdin(65536, false)?
                };
                if raw.len() > 65536 {
                    return Ok(());
                };
                if let Some(p) = agents::report(agent, &serde_json::from_slice(&raw)?) {
                    if let Ok(path) = std::env::var("PERCH_RELAY_SOCKET") {
                        sockets::send_relay(&path, &p)?
                    } else {
                        let _ = run(
                            &[
                                "omarchy-shell",
                                "io.github.tcballard.perch",
                                "activity",
                                &string_json(&p),
                            ],
                            1.0,
                            4096,
                        );
                    }
                }
                Ok(())
            })();
            if args.get(1).is_some_and(|a| a == "cursor") {
                println!("{{\"continue\":true}}")
            } else if args.get(1).is_some_and(|a| a == "gemini") {
                println!("{{}}")
            }
            Ok(())
        }
        "usage-statusline" => {
            let _ = usage_statusline();
            Ok(())
        }
        "notification-store" => {
            let result = notification_store(args);
            println!(
                "{}",
                result.unwrap_or_else(
                    |_| json!({"ok":false,"error":"History unavailable; existing file preserved"})
                )
            );
            Ok(())
        }
        "activity" => activity(args),
        "task" => task(args),
        "support" => {
            println!("{}", serde_json::to_string_pretty(&support())?);
            Ok(())
        }
        "diagnostics" => diagnostics(args),
        _ => err("Unknown backend command"),
    }
}
fn option<'a>(args: &'a [String], key: &str, default: &'a str) -> &'a str {
    args.iter()
        .position(|a| a == key)
        .and_then(|i| args.get(i + 1))
        .map(String::as_str)
        .unwrap_or(default)
}
fn activity(args: &[String]) -> Result<()> {
    let id = args.first().ok_or("Supply a stable activity ID")?;
    if !valid(id, r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$") {
        return err("Invalid activity ID");
    };
    let state = option(args, "--state", "running");
    let progress = option(args, "--progress", "-1").parse::<f64>()?;
    if !["running", "waiting", "done", "error"].contains(&state)
        || !(-1.0..=1.0).contains(&progress)
    {
        return err("Invalid activity state or progress");
    };
    let mut p = json!({"id":id,"state":state,"title":cut(option(args,"--title","Activity"),120),"detail":cut(option(args,"--detail",""),240),"progress":progress});
    if args.iter().any(|s| s == "--ttl") {
        let ttl = option(args, "--ttl", "").parse::<u64>()?;
        if !(5..=86400).contains(&ttl) {
            return err("ttl must be between 5 and 86400 seconds");
        };
        p["ttl"] = ttl.into();
    }
    let dismiss = args.iter().any(|s| s == "--dismiss");
    let result = run(
        &[
            "omarchy-shell",
            "io.github.tcballard.perch",
            if dismiss { "dismiss" } else { "activity" },
            &if dismiss {
                id.to_string()
            } else {
                string_json(&p)
            },
        ],
        5.0,
        65536,
    )?;
    println!("{}", result.trim());
    if result.trim() != "ok" {
        return err("Perch did not accept the activity");
    };
    Ok(())
}
fn usage_statusline() -> Result<()> {
    let data: Value = serde_json::from_slice(&stdin(65536, false)?)?;
    let mut clean = json!({});
    for key in ["five_hour", "seven_day"] {
        let row = &data["rate_limits"][key];
        let Some(used) = row["used_percentage"]
            .as_f64()
            .filter(|v| (0.0..=100.0).contains(v))
        else {
            continue;
        };
        clean[key] = json!({"used_percentage":used,"resets_at":row["resets_at"].as_f64().filter(|v|*v>=0.0)});
    }
    Store::new("usage-claude")?.save(&json!({"rate_limits":clean,"updatedAt":now()}))?;
    let labels = clean
        .as_object()
        .unwrap()
        .iter()
        .map(|(k, v)| {
            format!(
                "{}: {}% used",
                if k == "five_hour" { "5h" } else { "7d" },
                v["used_percentage"].as_f64().unwrap().round()
            )
        })
        .collect::<Vec<_>>();
    println!(
        "{}",
        if labels.is_empty() {
            "Perch · usage unavailable".into()
        } else {
            labels.join(" | ")
        }
    );
    Ok(())
}
pub fn normalize_notifications(data: &Value) -> Result<Value> {
    let rows = data["rows"]
        .as_array()
        .filter(|r| r.len() <= 20)
        .ok_or("Invalid history")?;
    let mut seen = std::collections::HashSet::new();
    let mut result = Vec::new();
    for row in rows {
        let key = s(row, "key");
        if !valid(key, r"^[A-Za-z0-9.-]{1,100}$") || !seen.insert(key) {
            continue;
        };
        let mut clean = json!({"actions":[],"reply":false,"unread":row["unread"]==true});
        for (k, n) in [
            ("key", 100),
            ("app", 64),
            ("title", 120),
            ("body", 400),
            ("icon", 100),
        ] {
            clean[k] = cut(s(row, k), n).into();
        }
        result.push(clean)
    }
    let blocked = data["blocked"]
        .as_array()
        .map(|r| {
            r.iter()
                .take(64)
                .map(|v| cut(v.as_str().unwrap_or(""), 64))
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    Ok(json!({"rows":result,"dnd":data["dnd"]==true,"blocked":blocked}))
}
fn notification_store(args: &[String]) -> Result<Value> {
    let store = Store::new("notifications")?;
    let op = args.first().map(String::as_str).unwrap_or("");
    let data = match op {
        "read" => {
            if store.path.exists() && fs::symlink_metadata(&store.path)?.len() > 131072 {
                return err("History too large");
            };
            store.load(json!({"rows":[],"dnd":false,"blocked":[]}))?
        }
        "write" => serde_json::from_slice(&stdin(131072, false)?)?,
        _ => return err("Unknown history operation"),
    };
    let mut clean = normalize_notifications(&data)?;
    if op == "write" {
        if serde_json::to_vec(&clean)?.len() > 131072 {
            return err("History too large");
        };
        store.save(&clean)?;
        Ok(json!({"ok":true}))
    } else {
        clean["ok"] = true.into();
        Ok(clean)
    }
}
fn support() -> Value {
    let root = root();
    let git = |args: &[&str]| {
        let mut cmd = vec!["git", "-C", root.to_str().unwrap_or("/")];
        cmd.extend_from_slice(args);
        run(&cmd, 2.0, 16384).ok().map(|s| s.trim().to_owned())
    };
    let version = read(&root.join("manifest.json"), 65536, false)
        .ok()
        .and_then(|v| serde_json::from_slice::<Value>(&v).ok())
        .and_then(|v| {
            v["version"]
                .as_str()
                .filter(|s| valid(s, r"^[0-9A-Za-z.+-]{1,64}$"))
                .map(str::to_owned)
        })
        .unwrap_or("unavailable".into());
    let revision = git(&["rev-parse", "HEAD"])
        .filter(|s| valid(s, r"^[0-9a-f]{40,64}$"))
        .unwrap_or("unavailable".into());
    let mut commands = json!({});
    for name in [
        "omarchy-shell",
        "hyprctl",
        "wl-copy",
        "curl",
        "brightnessctl",
        "canberra-gtk-play",
        "notify-send",
        "gtk-launch",
        "xdg-open",
        "localsend",
        "localsend_app",
        "tmux",
        "wezterm",
        "zellij",
    ] {
        commands[name] = which(name).is_some().into();
    }
    json!({"perch_version":version,"revision":revision,"tracked_local_edits":git(&["status","--porcelain","--untracked-files=no"]).map(|v|!v.is_empty()),"system":"Linux","kernel":fs::read_to_string("/proc/sys/kernel/osrelease").unwrap_or_default().trim(),"architecture":std::env::consts::ARCH,"backend":"Rust","backend_version":env!("CARGO_PKG_VERSION"),"commands_available":commands,"scope":"Local version/capability report only; no configuration, user content or logs collected."})
}
struct TaskChild(std::process::Child);
impl Drop for TaskChild {
    fn drop(&mut self) {
        unsafe {
            libc::kill(-(self.0.id() as i32), libc::SIGKILL);
        }
        let _ = self.0.wait();
    }
}
fn task_report(title: &str, state: &str, progress: f64, detail: &str) {
    let _ = run(
        &[
            "omarchy-shell",
            "io.github.tcballard.perch",
            "activity",
            &string_json(
                &json!({"id":format!("task.{}",std::process::id()),"title":cut(title,120),"state":state,"progress":progress,"detail":cut(detail,240),"ttl":if state=="running"{86400}else{60}}),
            ),
        ],
        1.0,
        4096,
    );
}
fn task(args: &[String]) -> Result<()> {
    let mut i = 0;
    let mut title = "Task";
    let mut timeout = 3600u64;
    let mut limit = 1073741824u64;
    while i < args.len() && args[i].starts_with("--") {
        let value = args.get(i + 1).ok_or("Missing option value")?;
        match args[i].as_str() {
            "--title" => title = value,
            "--timeout" => timeout = value.parse()?,
            "--max-bytes" => limit = value.parse()?,
            _ => return err("Unknown task option"),
        };
        i += 2;
    }
    if !(1..=86400).contains(&timeout) || !(1..=1099511627776).contains(&limit) {
        return err("Invalid deadline or transfer limit");
    };
    let kind = args.get(i).ok_or("Choose run, copy or download")?;
    let rest = &args[i + 1..];
    let start = Instant::now();
    task_report(title, "running", -1.0, "");
    let result = (|| -> Result<i32> {
        if kind == "run" {
            let rest = if rest.first().is_some_and(|s| s == "--") {
                &rest[1..]
            } else {
                rest
            };
            let first = rest.first().ok_or("Supply a command after run --")?;
            let mut child = TaskChild(
                Command::new(first)
                    .args(&rest[1..])
                    .process_group(0)
                    .spawn()?,
            );
            loop {
                if let Some(status) = child.0.try_wait()? {
                    use std::os::unix::process::ExitStatusExt;
                    return Ok(status
                        .code()
                        .unwrap_or_else(|| 128 + status.signal().unwrap_or(1)));
                }
                if start.elapsed().as_secs() >= timeout || cancelled() {
                    return err("Job timed out");
                };
                std::thread::sleep(Duration::from_millis(20));
            }
        }
        if !["copy", "download"].contains(&kind.as_str()) || rest.len() != 2 {
            return err("Supply source and destination");
        };
        let expand = |s: &str| {
            if let Some(v) = s.strip_prefix("~/") {
                home().join(v)
            } else {
                PathBuf::from(s)
            }
        };
        let destination = expand(&rest[1]);
        let destination = if destination.is_absolute() {
            destination
        } else {
            std::env::current_dir()?.join(destination)
        };
        if destination.exists() || destination.is_symlink() {
            return err("Destination already exists");
        };
        let mut tmp = tempfile::Builder::new()
            .prefix(".perch-transfer-")
            .tempfile_in(destination.parent().ok_or("Invalid destination")?)?;
        if kind == "copy" {
            let mut source = fs::OpenOptions::new()
                .read(true)
                .custom_flags(libc::O_NONBLOCK)
                .open(expand(&rest[0]))?;
            let info = source.metadata()?;
            if !info.is_file() {
                return err("Copy source must be a regular file");
            };
            let total = info.len();
            if total > limit {
                return err("Transfer exceeds size limit");
            };
            let mut count = 0u64;
            let mut last = Instant::now();
            let mut bytes = [0u8; 262144];
            loop {
                if start.elapsed().as_secs() >= timeout || cancelled() {
                    return err("Job timed out");
                };
                let n = source.read(&mut bytes)?;
                if n == 0 {
                    break;
                }
                count += n as u64;
                if count > limit {
                    return err("Transfer exceeds size limit");
                };
                tmp.write_all(&bytes[..n])?;
                if last.elapsed().as_secs() >= 1 {
                    task_report(
                        title,
                        "running",
                        if total > 0 {
                            (count as f64 / total as f64).min(1.0)
                        } else {
                            -1.0
                        },
                        &format!("{count} bytes"),
                    );
                    last = Instant::now();
                }
            }
            if count != total {
                return err("Transfer ended before its advertised size");
            }
        } else {
            crate::desktop::web_url(&rest[0])?;
            let headers = tempfile::NamedTempFile::new_in(destination.parent().unwrap())?;
            let mut url = url::Url::parse(&rest[0])?;
            let mut complete = false;
            for _ in 0..5 {
                crate::desktop::web_url(url.as_str())?;
                let remaining = timeout as f64 - start.elapsed().as_secs_f64();
                if remaining <= 0.0 || cancelled() {
                    return err("Job timed out");
                }
                let mut child = TaskChild(
                    Command::new("curl")
                        .args([
                            "--disable",
                            "--fail",
                            "--silent",
                            "--show-error",
                            "--proto",
                            "=http,https",
                            "--max-time",
                            &remaining.to_string(),
                            "--max-filesize",
                            &limit.to_string(),
                            "--dump-header",
                            headers.path().to_str().ok_or("Invalid header path")?,
                            "--output",
                            tmp.path().to_str().ok_or("Invalid temporary path")?,
                            url.as_str(),
                        ])
                        .stdin(Stdio::null())
                        .stdout(Stdio::null())
                        .stderr(Stdio::null())
                        .process_group(0)
                        .spawn()?,
                );
                let mut last = Instant::now();
                loop {
                    let count = tmp.as_file().metadata()?.len();
                    if count > limit || start.elapsed().as_secs() >= timeout || cancelled() {
                        return err("Transfer exceeded deadline or size limit");
                    }
                    if let Some(status) = child.0.try_wait()? {
                        if !status.success() {
                            return err("Download failed or incomplete");
                        };
                        break;
                    }
                    if last.elapsed().as_secs() >= 1 {
                        task_report(title, "running", -1.0, &format!("{count} bytes"));
                        last = Instant::now();
                    }
                    std::thread::sleep(Duration::from_millis(20));
                }
                let raw = read(headers.path(), 65536, false)?;
                let text = std::str::from_utf8(&raw)?;
                let response = text
                    .split("\r\n\r\n")
                    .filter(|h| h.starts_with("HTTP/"))
                    .last()
                    .ok_or("Invalid download response")?;
                let status = response
                    .lines()
                    .next()
                    .and_then(|l| l.split_whitespace().nth(1))
                    .ok_or("Invalid download status")?
                    .parse::<u16>()?;
                if [301, 302, 303, 307, 308].contains(&status) {
                    let location = response
                        .lines()
                        .find_map(|l| {
                            l.split_once(':')
                                .filter(|(k, _)| k.eq_ignore_ascii_case("location"))
                                .map(|(_, v)| v.trim())
                        })
                        .ok_or("Invalid download redirect")?;
                    let next = url.join(location)?;
                    crate::desktop::web_url(next.as_str())?;
                    if url.scheme() == "https" && next.scheme() != "https" {
                        return err("HTTPS downgrade refused");
                    };
                    url = next;
                    continue;
                }
                if !(200..300).contains(&status) {
                    return err("Download provider returned an error");
                };
                complete = true;
                break;
            }
            if !complete {
                return err("Too many download redirects");
            }
        }
        tmp.as_file().sync_all()?; // persist_noclobber reserves the destination without overwriting a racing writer.
        if let Err(error) = tmp.persist_noclobber(&destination) {
            if !error.error.raw_os_error().is_some_and(|code| {
                [libc::EPERM, libc::ENOTSUP, libc::EXDEV, libc::EACCES].contains(&code)
            }) {
                return Err(error.error.into());
            }
            let reservation = fs::OpenOptions::new()
                .create_new(true)
                .write(true)
                .mode(0o600)
                .open(&destination)?;
            drop(reservation);
            error.file.persist(&destination)?;
        }
        Ok(0)
    })();
    match result {
        Ok(code) => {
            task_report(
                title,
                if code == 0 { "done" } else { "error" },
                if code == 0 { 1.0 } else { -1.0 },
                if code == 0 {
                    "Completed"
                } else {
                    "Command failed"
                },
            );
            if code != 0 {
                std::process::exit(code)
            }
            Ok(())
        }
        Err(e) => {
            task_report(title, "error", -1.0, &e.to_string());
            if cancelled() || start.elapsed().as_secs() >= timeout {
                std::process::exit(130)
            }
            Err(e)
        }
    }
}
fn diagnostics(args: &[String]) -> Result<()> {
    let pid = option(args, "--pid", "").parse::<u64>()?;
    let seconds = option(args, "--seconds", "10").parse::<u64>()?;
    if pid < 1 || !(2..=60).contains(&seconds) {
        return err("Use a valid PID and 2–60 seconds");
    };
    let sample = || -> Result<(u64, u64, String)> {
        let raw = fs::read_to_string(format!("/proc/{pid}/stat"))?;
        let fields: Vec<_> = raw
            .rsplit_once(')')
            .ok_or("Invalid process")?
            .1
            .split_whitespace()
            .collect();
        if fields.len() < 22 {
            return err("Invalid process");
        };
        Ok((
            fields[11].parse::<u64>()? + fields[12].parse::<u64>()?,
            fields[21].parse::<u64>()? * unsafe { libc::sysconf(libc::_SC_PAGESIZE) } as u64,
            fields[19].into(),
        ))
    };
    let first = sample()?;
    let start = Instant::now();
    std::thread::sleep(Duration::from_secs(seconds));
    let last = sample()?;
    if first.2 != last.2 {
        return err("Process restarted during measurement");
    };
    let mut result = json!({"pid":pid,"sample_seconds":start.elapsed().as_secs_f64(),"whole_shell_cpu_percent":(last.0-first.0) as f64/unsafe{libc::sysconf(libc::_SC_CLK_TCK)} as f64/start.elapsed().as_secs_f64()*100.0,"whole_shell_rss_mib":last.1 as f64/1048576.0,"rss_delta_mib":(last.1 as f64-first.1 as f64)/1048576.0,"scope":"Whole shell, not Perch attribution; IPC round-trip is not visual frame latency"});
    if args.iter().any(|a| a == "--exercise") {
        let mut times = Vec::new();
        for _ in 0..10 {
            let start = Instant::now();
            run(
                &[
                    "omarchy-shell",
                    "shell",
                    "summon",
                    "io.github.tcballard.perch",
                ],
                3.0,
                4096,
            )?;
            times.push(start.elapsed().as_secs_f64() * 1000.0);
            std::thread::sleep(Duration::from_millis(250));
            run(
                &[
                    "omarchy-shell",
                    "shell",
                    "hide",
                    "io.github.tcballard.perch",
                ],
                3.0,
                4096,
            )?;
            std::thread::sleep(Duration::from_millis(250));
        }
        times.sort_by(f64::total_cmp);
        result["summon_ipc_median_ms"] = ((times[4] + times[5]) / 2.0).into();
        result["summon_ipc_max_ms"] = times[9].into();
    }
    println!("{}", serde_json::to_string_pretty(&result)?);
    Ok(())
}
