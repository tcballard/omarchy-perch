//! Dock utilities own only Perch state; file operations never remove originals.
use crate::{core::*, desktop};
use serde_json::{json, Value};
use std::{fs, os::unix::fs::MetadataExt};

pub fn reminders(op: &str, p: &Value) -> Result<Value> {
    let store = Store::new("reminders")?;
    let data = store.load(json!([]))?;
    let mut rows = data.as_array().ok_or("Invalid reminders state")?.clone();
    if rows.len() > 256 {
        return err("Too many saved reminders");
    }
    match op {
        "dock-reminders-add" => {
            let title = clean(s(p, "title"), 200).trim().to_owned();
            let list = clean(s(p, "list"), 60).trim().to_owned();
            if title.is_empty() || rows.len() >= 256 {
                return err("Enter a reminder; limit is 256");
            }
            let due = p["due"].as_f64().unwrap_or(0.0);
            if !due.is_finite() || !(0.0..=32503680000.0).contains(&due) {
                return err("Invalid due date");
            }
            rows.push(json!({"id":hash(&format!("{}:{}:{}",now(),std::process::id(),title))[..24].to_owned(),"title":title,"list":if list.is_empty(){"Personal"}else{&list},"done":false,"due":due}));
        }
        "dock-reminders-toggle" => {
            let row = rows
                .iter_mut()
                .find(|r| r["id"] == p["id"])
                .ok_or("Reminder no longer exists")?;
            let done = p["done"].as_bool().ok_or("Choose a completion state")?;
            row["done"] = done.into();
        }
        "dock-reminders-remove" => rows.retain(|r| r["id"] != p["id"]),
        "dock-reminders-list" => {}
        _ => return err("Unsupported reminder action"),
    }
    if op != "dock-reminders-list" {
        store.save(&json!(rows))?;
    }
    Ok(json!({"rows":rows}))
}
pub fn hydration(op: &str, p: &Value) -> Result<Value> {
    let store = Store::new("hydration")?;
    let data = store.load(json!([]))?;
    let mut rows = data.as_array().ok_or("Invalid hydration state")?.clone();
    if rows.len() > 2048 {
        return err("Hydration history exceeds limit");
    }
    match op {
        "dock-hydration-log" => {
            let amount = p["amount"]
                .as_u64()
                .filter(|n| *n <= 2000)
                .ok_or("Amount must be 0–2000 mL")?;
            let at = now();
            rows.push(json!({"id":hash(&format!("{}:{}",at,std::process::id()))[..24].to_owned(),"at":at,"amount":amount}));
            if rows.len() > 2048 {
                rows.remove(0);
            }
        }
        "dock-hydration-remove" => rows.retain(|r| r["id"] != p["id"]),
        "dock-hydration-restore" => {
            let row = &p["entry"];
            if !valid(s(row, "id"), "^[a-f0-9]{24}$")
                || row["at"]
                    .as_f64()
                    .filter(|t| *t > 0.0 && *t <= now())
                    .is_none()
                || row["amount"].as_u64().filter(|n| *n <= 2000).is_none()
            {
                return err("Invalid drink history entry");
            }
            if rows.len() >= 2048 {
                return err("History is full");
            }
            if !rows.iter().any(|r| r["id"] == row["id"]) {
                rows.push(json!({"id":row["id"],"at":row["at"],"amount":row["amount"]}));
            }
            rows.sort_by(|a, b| {
                a["at"]
                    .as_f64()
                    .unwrap_or(0.0)
                    .total_cmp(&b["at"].as_f64().unwrap_or(0.0))
            });
        }
        "dock-hydration-list" => {}
        _ => return err("Unsupported hydration action"),
    }
    if op != "dock-hydration-list" {
        store.save(&json!(rows))?;
    }
    Ok(json!({"rows":rows}))
}
pub fn browse(p: &Value) -> Result<Value> {
    let path = desktop::local(s(p, "path"))?;
    if !path.is_dir() {
        return err("Choose a folder to browse");
    }
    let mut rows = Vec::new();
    let mut partial = false;
    for (index, entry) in fs::read_dir(&path)?.enumerate() {
        if index >= 512 {
            partial = true;
            break;
        }
        let Ok(entry) = entry else {
            partial = true;
            continue;
        };
        let Ok(meta) = fs::symlink_metadata(entry.path()) else {
            partial = true;
            continue;
        };
        // Symlinks can escape the displayed directory and are opened by the file manager instead.
        if !meta.is_file() && !meta.is_dir() {
            continue;
        }
        rows.push(json!({"name":clean(&entry.file_name().to_string_lossy(),200),"path":entry.path().to_string_lossy(),"folder":meta.is_dir(),"bytes":meta.len()}));
    }
    rows.sort_by(|a, b| {
        b["folder"]
            .as_bool()
            .cmp(&a["folder"].as_bool())
            .then_with(|| {
                s(a, "name")
                    .to_lowercase()
                    .cmp(&s(b, "name").to_lowercase())
            })
    });
    Ok(
        json!({"path":path.to_string_lossy(),"parent":path.parent().map(|p|p.to_string_lossy()),"rows":rows,"partial":partial}),
    )
}
pub fn windows() -> Result<Value> {
    let raw = run(&["hyprctl", "-j", "clients"], 3.0, 262144)?;
    let data: Value = serde_json::from_str(&raw)?;
    let rows=data.as_array().ok_or("Hyprland returned invalid windows")?.iter().take(128).filter(|r|r["mapped"]==true && valid(s(r,"address"),"^0x[0-9a-fA-F]{1,16}$")).map(|r|json!({"address":r["address"],"title":clean(s(r,"title"),200),"class":clean(s(r,"class"),120),"workspace":r["workspace"]["name"],"pid":r["pid"]})).collect::<Vec<_>>();
    Ok(json!({"rows":rows}))
}
pub fn focus(p: &Value) -> Result<Value> {
    let address = s(p, "address");
    if !valid(address, "^0x[0-9a-fA-F]{1,16}$") {
        return err("Invalid window target");
    }
    let current = windows()?;
    if !current["rows"]
        .as_array()
        .unwrap()
        .iter()
        .any(|r| r["address"] == p["address"] && r["pid"] == p["pid"])
    {
        return err("That window closed or was replaced");
    }
    run(
        &[
            "hyprctl",
            "dispatch",
            "focuswindow",
            &format!("address:{address}"),
        ],
        3.0,
        4096,
    )?;
    Ok(ok_message("Window focused"))
}
pub fn storage(p: &Value) -> Result<Value> {
    let path = desktop::local(s(p, "path"))?;
    if !path.is_dir() {
        return err("Choose a directory");
    }
    let started = std::time::Instant::now();
    let mut count = 0usize;
    fn size(
        path: &std::path::Path,
        started: std::time::Instant,
        count: &mut usize,
        partial: &mut bool,
        depth: usize,
    ) -> u64 {
        if depth >= 64 || *count >= 20000 || started.elapsed().as_secs_f64() > 4.0 {
            *partial = true;
            return 0;
        }
        *count += 1;
        let Ok(meta) = fs::symlink_metadata(path) else {
            *partial = true;
            return 0;
        };
        if meta.is_symlink() {
            return 0;
        }
        if meta.is_file() {
            return meta.blocks() * 512;
        }
        if !meta.is_dir() {
            return 0;
        }
        let Ok(entries) = fs::read_dir(path) else {
            *partial = true;
            return 0;
        };
        let mut total = 0;
        for entry in entries.take(20001) {
            if *count >= 20000 || started.elapsed().as_secs_f64() > 4.0 {
                *partial = true;
                break;
            }
            if let Ok(entry) = entry {
                total += size(&entry.path(), started, count, partial, depth + 1);
            } else {
                *partial = true;
            }
        }
        total
    }
    let mut rows = Vec::new();
    let mut partial = false;
    for entry in fs::read_dir(&path)?.take(513) {
        if rows.len() >= 512 || count >= 20000 || started.elapsed().as_secs_f64() > 4.0 {
            partial = true;
            break;
        }
        let Ok(entry) = entry else {
            partial = true;
            continue;
        };
        let mut incomplete = false;
        let bytes = size(&entry.path(), started, &mut count, &mut incomplete, 0);
        partial |= incomplete;
        rows.push(json!({"name":clean(&entry.file_name().to_string_lossy(),200),"path":entry.path().to_string_lossy(),"bytes":bytes,"partial":incomplete}));
    }
    rows.sort_by_key(|r| std::cmp::Reverse(r["bytes"].as_u64().unwrap_or(0)));
    rows.truncate(40);
    Ok(json!({"rows":rows,"partial":partial,"scanned":count}))
}
pub fn handle(op: &str, p: &Value) -> Result<Value> {
    match op {
        x if x.starts_with("dock-reminders-") => reminders(op, p),
        x if x.starts_with("dock-hydration-") => hydration(op, p),
        "dock-weather-search" => weather_search(p),
        "dock-backup-read" | "dock-backup-write" => backup(op, p),
        "dock-trash" => trash(),
        "dock-trash-open" => {
            launch(&["xdg-open", "trash:///"])?;
            Ok(ok_message("Trash opened"))
        }
        "dock-browse" => browse(p),
        "dock-file-open" => {
            let path = desktop::local(s(p, "path"))?;
            launch(&["xdg-open", &desktop::uri(&path)])?;
            Ok(ok_message("Opened"))
        }
        "dock-windows" => windows(),
        "dock-window-focus" => focus(p),
        "dock-storage" => storage(p),
        _ => err("Unknown dock operation"),
    }
}

pub fn weather_search(p: &Value) -> Result<Value> {
    let query = clean(s(p, "query"), 100).trim().to_owned();
    if query.chars().count() < 2 {
        return err("Enter at least two letters of a city name");
    }
    let mut url = url::Url::parse("https://geocoding-api.open-meteo.com/v1/search")?;
    url.query_pairs_mut()
        .append_pair("name", &query)
        .append_pair("count", "8")
        .append_pair("language", "en")
        .append_pair("format", "json");
    let raw = run(
        &[
            "curl",
            "--disable",
            "--fail",
            "--silent",
            "--show-error",
            "--proto",
            "=https",
            "--max-time",
            "7",
            "--max-filesize",
            "65536",
            url.as_str(),
        ],
        8.0,
        65536,
    )?;
    let value: Value = serde_json::from_str(&raw)?;
    let rows=value["results"].as_array().into_iter().flatten().take(8).filter_map(|r|{
        let lat=r["latitude"].as_f64()?;let lon=r["longitude"].as_f64()?;
        if !(-90.0..=90.0).contains(&lat)||!(-180.0..=180.0).contains(&lon){return None;}
        Some(json!({"name":clean(s(r,"name"),80),"detail":clean(&format!("{}, {}",s(r,"admin1"),s(r,"country")),160),"latitude":lat,"longitude":lon}))
    }).collect::<Vec<_>>();
    Ok(json!({"rows":rows}))
}

pub fn backup(op: &str, p: &Value) -> Result<Value> {
    let path = std::path::Path::new(s(p, "path"));
    if !path.is_absolute() || path.is_symlink() || !s(p, "path").ends_with(".perch.json") {
        return err("Choose a regular .perch.json backup file");
    }
    if op == "dock-backup-read" {
        let bytes = read(path, 60000, false)?;
        let text = String::from_utf8(bytes)?;
        let value: Value = serde_json::from_str(&text)?;
        if value["format"] != "perch-docks" || value["version"] != 1 {
            return err("Not a supported Perch backup");
        }
        return Ok(json!({"text":text}));
    }
    let text = s(p, "text");
    if text.len() > 60000 {
        return err("Backup exceeds 60 KiB; use the copyable backup text");
    }
    let value: Value = serde_json::from_str(text)?;
    if value["format"] != "perch-docks" || value["version"] != 1 {
        return err("Not a supported Perch backup");
    }
    // Native Save dialog owns overwrite confirmation. Reject symlinks and special files.
    if path.exists() && !fs::symlink_metadata(path)?.is_file() {
        return err("Backup target is not a regular file");
    }
    atomic(path, text.as_bytes(), 0o600)?;
    Ok(ok_message("Backup saved"))
}
pub fn trash() -> Result<Value> {
    let path = base("XDG_DATA_HOME", home().join(".local/share")).join("Trash/files");
    if !path.exists() {
        return Ok(json!({"count":0,"partial":false}));
    }
    let count = fs::read_dir(path)?.take(1001).count();
    Ok(json!({"count":count.min(1000),"partial":count>1000}))
}
