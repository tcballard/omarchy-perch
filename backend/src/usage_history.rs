//! Bounded local counters only; no prompts or tool contents leave this reader.
use crate::core::*;
use chrono::{DateTime, Utc};
use serde_json::{json, Value};
use std::{
    collections::{BTreeMap, HashMap},
    fs,
    io::{Read, Seek, SeekFrom},
    os::unix::fs::{MetadataExt, OpenOptionsExt},
    path::PathBuf,
};
pub fn counters(raw: &str, provider: &str, truncated: bool) -> Result<Value> {
    let mut days = BTreeMap::<String, u64>::new();
    let mut previous = None;
    let mut messages = HashMap::<String, (String, u64)>::new();
    for line in raw.lines() {
        if line.len() > 262144 {
            continue;
        }
        let Ok(v) = serde_json::from_str::<Value>(line) else {
            continue;
        };
        let Ok(stamp) = DateTime::parse_from_rfc3339(s(&v, "timestamp")) else {
            continue;
        };
        let day = stamp.with_timezone(&Utc).format("%Y-%m-%d").to_string();
        if provider == "codex"
            && s(&v, "type") == "event_msg"
            && s(&v["payload"], "type") == "token_count"
        {
            let Some(total) = v["payload"]["info"]["total_token_usage"]["total_tokens"]
                .as_u64()
                .filter(|n| *n <= 1_000_000_000_000)
            else {
                continue;
            };
            let delta = match previous {
                Some(n) if total >= n => total - n,
                Some(_) => total,
                None if !truncated => total,
                None => 0,
            };
            *days.entry(day).or_default() += delta;
            previous = Some(total);
        } else if provider == "claude" && s(&v, "type") == "assistant" {
            let message = &v["message"];
            let id = s(message, "id");
            let usage = &message["usage"];
            if id.is_empty() || id.len() > 200 {
                continue;
            }
            let mut total = 0u64;
            for key in [
                "input_tokens",
                "output_tokens",
                "cache_creation_input_tokens",
                "cache_read_input_tokens",
            ] {
                let n = usage[key].as_u64().unwrap_or(0);
                if n > 1_000_000_000_000 {
                    return err("Usage counter exceeds range");
                }
                total += n;
            }
            messages.insert(id.to_owned(), (day, total));
        }
    }
    for (_, (day, total)) in messages {
        *days.entry(day).or_default() += total;
    }
    Ok(
        json!({"days":days.into_iter().map(|(date,tokens)|json!({"date":date,"tokens":tokens})).collect::<Vec<_>>()}),
    )
}
pub fn history(p: &Value) -> Result<Value> {
    let provider = s(p, "provider");
    let root = match provider {
        "codex" => base("CODEX_HOME", home().join(".codex")).join("sessions"),
        "claude" => base("CLAUDE_CONFIG_DIR", home().join(".claude")).join("projects"),
        _ => return err("Local history supports Codex and Claude"),
    };
    let days = p["days"]
        .as_i64()
        .filter(|n| [1, 7, 30].contains(n))
        .ok_or("Choose 1, 7 or 30 days")?;
    let cutoff = Utc::now().date_naive() - chrono::Duration::days(days - 1);
    let mut pending = vec![(root, 0)];
    let mut candidates = Vec::<(i64, PathBuf)>::new();
    let mut seen = 0;
    let mut partial = false;
    while let Some((path, depth)) = pending.pop() {
        if path.is_symlink() {
            continue;
        }
        let Ok(entries) = fs::read_dir(&path) else {
            continue;
        };
        for entry in entries {
            seen += 1;
            if seen > 4096 {
                partial = true;
                break;
            }
            let Ok(entry) = entry else {
                partial = true;
                continue;
            };
            let path = entry.path();
            let Ok(meta) = fs::symlink_metadata(&path) else {
                partial = true;
                continue;
            };
            if meta.is_symlink() || meta.uid() != uid() {
                continue;
            }
            if meta.is_dir() && depth < 4 {
                pending.push((path, depth + 1));
            } else if meta.is_file()
                && path.extension().is_some_and(|e| e == "jsonl")
                && meta.mtime() as f64 >= now() - 32.0 * 86400.0
            {
                candidates.push((meta.mtime(), path));
            }
        }
        if seen > 4096 {
            break;
        }
    }
    candidates.sort_by_key(|(time, _)| std::cmp::Reverse(*time));
    if candidates.len() > 32 {
        partial = true;
    }
    let mut totals = BTreeMap::<String, u64>::new();
    let mut files = 0;
    for (_, path) in candidates.into_iter().take(32) {
        let result = (|| -> Result<Value> {
            let mut file = fs::OpenOptions::new()
                .read(true)
                .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK)
                .open(path)?;
            let meta = file.metadata()?;
            if !meta.is_file() || meta.uid() != uid() {
                return err("Unreadable local usage file");
            }
            let offset = meta.len().saturating_sub(1048576);
            file.seek(SeekFrom::Start(offset))?;
            let mut bytes = Vec::new();
            file.take(1048576).read_to_end(&mut bytes)?;
            if offset > 0 {
                partial = true;
                let start = bytes
                    .iter()
                    .position(|b| *b == b'\n')
                    .map(|i| i + 1)
                    .unwrap_or(bytes.len());
                bytes.drain(..start);
            }
            counters(&String::from_utf8_lossy(&bytes), provider, offset > 0)
        })();
        match result {
            Ok(v) => {
                files += 1;
                for row in v["days"].as_array().unwrap() {
                    if s(row, "date") >= cutoff.to_string().as_str()
                        && s(row, "date") <= Utc::now().date_naive().to_string().as_str()
                    {
                        *totals.entry(s(row, "date").into()).or_default() +=
                            row["tokens"].as_u64().unwrap_or(0);
                    }
                }
            }
            Err(_) => partial = true,
        }
    }
    let total: u64 = totals.values().sum();
    Ok(
        json!({"provider":provider,"tokens":total,"files":files,"partial":partial,"days":totals.into_iter().map(|(date,tokens)|json!({"date":date,"tokens":tokens})).collect::<Vec<_>>(),"note":"UTC days; recorded local tokens including cache counters. Bounded to 32 recent files and 1 MiB per file. This is not account-wide usage or billing."}),
    )
}
