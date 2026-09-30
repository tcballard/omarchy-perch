use crate::core::*;
use serde_json::{json, Value};
use std::{
    fs,
    io::Write,
    net::{IpAddr, ToSocketAddrs},
    os::unix::fs::MetadataExt,
    path::{Path, PathBuf},
};
pub fn uri(path: &Path) -> String {
    format!(
        "file://{}",
        path.to_string_lossy()
            .bytes()
            .map(|c| if c.is_ascii_alphanumeric() || b"/-._~".contains(&c) {
                (c as char).to_string()
            } else {
                format!("%{c:02X}")
            })
            .collect::<String>()
    )
}
fn decode(text: &str) -> Result<String> {
    let mut b = Vec::new();
    let x = text.as_bytes();
    let mut i = 0;
    while i < x.len() {
        if x[i] == b'%' {
            if i + 2 >= x.len() {
                return err("Invalid file URL");
            };
            let hex = std::str::from_utf8(&x[i + 1..i + 3])?;
            b.push(u8::from_str_radix(hex, 16)?);
            i += 3;
        } else {
            b.push(x[i]);
            i += 1;
        }
    }
    Ok(String::from_utf8(b)?)
}
pub fn local(value: &str) -> Result<PathBuf> {
    if value.len() > 4096 || value.contains('\0') {
        return err("Invalid file path");
    };
    let value = if let Some(v) = value.strip_prefix("file://") {
        let path = if v.starts_with('/') {
            v
        } else {
            v.strip_prefix("localhost/")
                .map(|s| &v[v.len() - s.len() - 1..])
                .ok_or("Only local file URLs can be placed on the shelf")?
        };
        if path.contains(['?', '#']) {
            return err("Invalid file URL");
        };
        decode(path)?
    } else {
        value.to_owned()
    };
    let p = if let Some(value) = value.strip_prefix("~/") {
        home().join(value)
    } else {
        PathBuf::from(value)
    };
    if !p.is_absolute() {
        return err("Use an absolute path");
    };
    let p = p.canonicalize()?;
    if !p.is_file() && !p.is_dir() {
        return err("Only regular files and folders are supported");
    };
    Ok(p)
}
fn mime(p: &Path) -> &'static str {
    match p
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_ascii_lowercase()
        .as_str()
    {
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "webp" => "image/webp",
        "txt" | "log" | "md" | "rs" | "py" | "qml" | "js" | "toml" | "yaml" | "yml" | "ics" => {
            "text/plain"
        }
        "json" => "application/json",
        _ => "application/octet-stream",
    }
}
fn describe(p: &Path) -> Value {
    let name = p.file_name().unwrap_or_default().to_string_lossy();
    json!({"id":&hash(&p.to_string_lossy())[..24],"path":p,"url":uri(p),"name":cut(&name,160),"exists":p.exists(),"folder":p.is_dir(),"mime":mime(p),"size":if p.is_file(){p.metadata().map(|m|m.len()).unwrap_or(0)}else{0}})
}
fn shelf(op: &str, p: &Value) -> Result<Value> {
    let store = Store::new("shelf")?;
    let data = store.load(json!([]))?;
    let rows = data
        .as_array()
        .ok_or("Shelf state is invalid; preserve it before resetting")?;
    if rows.len() > 32
        || rows
            .iter()
            .any(|r| r.as_str().is_none_or(|s| !Path::new(s).is_absolute()))
    {
        return err("Shelf state is invalid; preserve it before resetting");
    };
    let mut paths: Vec<PathBuf> = rows
        .iter()
        .map(|r| PathBuf::from(r.as_str().unwrap()))
        .collect();
    match op {
        "shelf-add" => {
            let urls = p["urls"].as_array().ok_or("Drop at most 32 files")?;
            if urls.len() > 32 {
                return err("Drop at most 32 files");
            };
            let mut next = Vec::new();
            for v in urls {
                let p = local(v.as_str().ok_or("Invalid file path")?)?;
                if !next.contains(&p) {
                    next.push(p)
                }
            }
            for p in paths {
                if !next.contains(&p) {
                    next.push(p)
                }
            }
            if next.len() > 32 {
                return err("Shelf is full (32 items). Remove an item first.");
            };
            paths = next;
            store.save(&json!(paths))?
        }
        "shelf-remove" => {
            paths.retain(|r| describe(r)["id"] != p["id"]);
            store.save(&json!(paths))?
        }
        "shelf-open" | "shelf-reveal" | "shelf-share" | "shelf-preview" => {
            let chosen = paths
                .iter()
                .find(|r| describe(r)["id"] == p["id"])
                .ok_or("Shelf item no longer exists")?;
            let path = local(&chosen.to_string_lossy())?;
            if op == "shelf-preview" {
                let name = path.file_name().unwrap_or_default().to_string_lossy();
                if path.is_file()
                    && (mime(&path).starts_with("text/") || mime(&path) == "application/json")
                {
                    return Ok(
                        json!({"preview":cut(&String::from_utf8_lossy(&head(&path,65536)?),8000),"kind":"text","name":name}),
                    );
                }
                let image = mime(&path).starts_with("image/") && path.metadata()?.len() <= 2097152;
                return Ok(
                    json!({"preview":if image{uri(&path)}else{String::new()},"kind":if image{"image"}else{"external"},"name":name}),
                );
            }
            if op == "shelf-share" {
                let executable = which("localsend")
                    .or_else(|| which("localsend_app"))
                    .ok_or("Install LocalSend to share files; no transfer was started")?;
                launch(&[
                    executable.to_str().ok_or("Invalid executable")?,
                    path.to_str().ok_or("Invalid path")?,
                ])?
            } else {
                launch(&[
                    "xdg-open",
                    &uri(if op == "shelf-reveal" {
                        path.parent().unwrap_or(&path)
                    } else {
                        &path
                    }),
                ])?
            }
        }
        "shelf-list" => {}
        _ => return err("Unsupported shelf operation"),
    };
    Ok(json!({"items":paths.iter().map(|p|describe(p)).collect::<Vec<_>>()}))
}
pub fn web_url(value: &str) -> Result<&str> {
    if value.len() > 2048 || value.chars().any(|c| c.is_control() || c.is_whitespace()) {
        return err("Enter an HTTP or HTTPS URL without credentials");
    };
    let (_, host, _, _) = url_parts(value)?;
    if host.is_empty() {
        return err("Enter an HTTP or HTTPS URL without credentials");
    };
    Ok(value)
}
pub fn url_parts(value: &str) -> Result<(&str, String, u16, String)> {
    let u = url::Url::parse(value)?;
    if !["http", "https"].contains(&u.scheme())
        || !u.username().is_empty()
        || u.password().is_some()
        || value.chars().any(char::is_control)
    {
        return err("Use an HTTP(S) URL without credentials");
    }
    let host = match u.host().ok_or("Invalid URL")? {
        url::Host::Domain(h) => h.to_owned(),
        url::Host::Ipv4(v) => v.to_string(),
        url::Host::Ipv6(v) => v.to_string(),
    };
    let path = format!(
        "{}{}",
        u.path(),
        u.query().map(|q| format!("?{q}")).unwrap_or_default()
    );
    Ok((
        if u.scheme() == "https" {
            "https"
        } else {
            "http"
        },
        host,
        u.port_or_known_default().ok_or("Invalid URL port")?,
        path,
    ))
}
fn apps() -> Vec<Value> {
    let mut rows = std::collections::BTreeMap::new();
    for folder in [
        PathBuf::from("/usr/share/applications"),
        home().join(".local/share/applications"),
    ] {
        if let Ok(entries) = fs::read_dir(folder) {
            for e in entries.take(1200).flatten() {
                let path = e.path();
                let id = e.file_name().to_string_lossy().into_owned();
                if !valid(&id, r"^[A-Za-z0-9._][A-Za-z0-9._-]*\.desktop$") {
                    continue;
                }
                if let Ok(raw) = read(&path, 65536, true) {
                    let text = String::from_utf8_lossy(&raw);
                    let mut section = false;
                    let mut fields = std::collections::HashMap::new();
                    for line in text.lines() {
                        if line.starts_with('[') {
                            section = line.trim() == "[Desktop Entry]";
                        } else if section {
                            if let Some((k, v)) = line.split_once('=') {
                                fields.insert(k.trim(), v.trim());
                            }
                        }
                    }
                    if fields.get("Type") == Some(&"Application")
                        && fields.get("Hidden") != Some(&"true")
                        && fields.get("NoDisplay") != Some(&"true")
                    {
                        rows.insert(id.clone(),json!({"id":id,"name":cut(fields.get("Name").unwrap_or(&id.trim_end_matches(".desktop")),100)}));
                    }
                }
            }
        }
    }
    let mut rows: Vec<_> = rows.into_values().collect();
    rows.sort_by_key(|r| s(r, "name").to_lowercase());
    rows.truncate(500);
    rows
}
pub fn plugins() -> Result<Vec<Value>> {
    let raw = run(&["omarchy-shell", "shell", "listPlugins"], 3.0, 262144)?;
    let rows: Value = serde_json::from_str(&raw)?;
    let rows = rows
        .as_array()
        .filter(|r| r.len() <= 2000)
        .ok_or("Invalid plugin catalog")?;
    let mut out = std::collections::BTreeMap::new();
    for r in rows {
        let id = s(r, "id");
        if !valid_id(id)
            || id == "io.github.tcballard.perch"
            || id.starts_with("omarchy.")
            || r["firstParty"] != false
        {
            continue;
        }
        if r["kinds"].as_array().is_none_or(|k| {
            !k.iter().any(|v| {
                v.as_str()
                    .is_some_and(|x| ["panel", "overlay", "menu", "bar-widget"].contains(&x))
            })
        }) {
            continue;
        }
        out.insert(id.to_string(),json!({"id":id,"name":cut(r["name"].as_str().unwrap_or(id),100),"enabled":r["enabled"]==true}));
    }
    if out.len() > 300 {
        return err("Plugin catalog exceeds 300 launchable plugins");
    };
    let mut result: Vec<_> = out.into_values().collect();
    result.sort_by_key(|r| (s(r, "name").to_lowercase(), s(r, "id").to_string()));
    Ok(result)
}
pub fn valid_id(id: &str) -> bool {
    id.len() <= 160 && valid(id, r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
}
pub fn normalize_card(v: &Value) -> Result<Value> {
    if v["version"].as_u64() != Some(1) {
        return err("This plugin does not provide a supported Perch card yet");
    };
    fn token(v: &Value) -> bool {
        v.as_str()
            .is_some_and(|s| valid(s, r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$"))
    }
    if !token(&v["revision"])
        || !["ready", "empty", "loading", "error", "offline"].contains(&s(v, "status"))
    {
        return err("Invalid card state");
    };
    let empty = vec![];
    let actions = v
        .get("actions")
        .unwrap_or(&Value::Null)
        .as_array()
        .unwrap_or(&empty);
    let rows = v
        .get("rows")
        .unwrap_or(&Value::Null)
        .as_array()
        .unwrap_or(&empty);
    if actions.len() > 4
        || rows.len() > 8
        || v.get("actions").is_some_and(|v| !v.is_array())
        || v.get("rows").is_some_and(|v| !v.is_array())
    {
        return err("Card exceeds its item limit");
    };
    let mut ids = std::collections::HashSet::new();
    let mut action = |a: &Value| -> Result<Value> {
        let label = a["label"].as_str().ok_or("Invalid card text")?;
        if !token(&a["id"]) || !ids.insert(a["id"].clone()) {
            return err("Invalid or duplicate card action");
        };
        Ok(json!({"id":a["id"],"label":clean(label,40)}))
    };
    let actions = actions
        .iter()
        .map(&mut action)
        .collect::<Result<Vec<_>>>()?;
    let mut row_ids = std::collections::HashSet::new();
    let mut result = Vec::new();
    for row in rows {
        if !token(&row["id"]) || !row_ids.insert(row["id"].clone()) {
            return err("Invalid or duplicate card row");
        };
        result.push(json!({"id":row["id"],"title":clean(row["title"].as_str().ok_or("Invalid card text")?,180),"detail":clean(row.get("detail").unwrap_or(&json!("")).as_str().ok_or("Invalid card text")?,240),"action":if row["action"].is_null(){Value::Null}else{action(&row["action"])?}}));
    }
    Ok(
        json!({"version":1,"revision":v["revision"],"status":v["status"],"title":clean(v["title"].as_str().ok_or("Invalid card text")?,100),"summary":clean(v.get("summary").unwrap_or(&json!("")).as_str().ok_or("Invalid card text")?,240),"actions":actions,"rows":result}),
    )
}
fn card_snapshot(id: &str) -> Result<Value> {
    normalize_card(&serde_json::from_str(&run(
        &["omarchy-shell", id, "perchCard"],
        2.0,
        32768,
    )?)?)
}
fn card(op: &str, p: &Value) -> Result<Value> {
    let id = s(p, "id");
    if !valid_id(id) || !["card-read", "card-action"].contains(&op) {
        return err("Invalid card request");
    };
    if !plugins()?
        .iter()
        .any(|r| r["id"] == id && r["enabled"] == true)
    {
        return err("Plugin is missing or disabled. Manage it in Omarchy.");
    };
    let mut card = card_snapshot(id)?;
    if op == "card-action" {
        if p["revision"] != card["revision"] {
            return err("This card changed. Refresh it before trying again.");
        };
        let allowed = card["actions"].as_array().unwrap().iter().chain(
            card["rows"]
                .as_array()
                .unwrap()
                .iter()
                .map(|r| &r["action"]),
        );
        if !allowed
            .into_iter()
            .any(|a| !a.is_null() && a["id"] == p["action"])
        {
            return err("That action is no longer available");
        };
        let request =
            string_json(&json!({"version":1,"revision":card["revision"],"action":p["action"]}));
        let reply: Value = serde_json::from_str(&run(
            &["omarchy-shell", id, "perchAction", &request],
            2.0,
            4096,
        )?)?;
        if reply["ok"] != true {
            return err("Plugin could not complete that action. Refresh its card.");
        };
        card = match card_snapshot(id) {
            Ok(v) => v,
            Err(_) => {
                return Ok(
                    json!({"card":null,"message":"Action completed. Refresh to see the latest state."}),
                )
            }
        };
    }
    Ok(json!({"card":card,"message":if op=="card-action"{"Action completed"}else{""}}))
}
fn owned_read(path: &Path, limit: usize) -> Result<Vec<u8>> {
    let data = read(path, limit, false)?;
    if fs::symlink_metadata(path)?.uid() != uid() {
        return err("Expected a regular file owned by you");
    };
    Ok(data)
}
fn history() -> Result<Vec<(String, String, String, Value)>> {
    let raw = owned_read(
        &home().join(".local/state/omarchy/clipboard-history.json"),
        4 * 1024 * 1024,
    )?;
    let rows: Value = serde_json::from_slice(&raw)?;
    let rows = rows
        .as_array()
        .ok_or("Unsupported clipboard history format")?;
    let mut result = Vec::new();
    for row in rows.iter().take(500) {
        let row = if let Some(text) = row.as_str() {
            json!({"type":"text","text":text})
        } else {
            row.clone()
        };
        let (kind, key, preview) = if s(&row, "type") == "text" && row["text"].is_string() {
            let text = s(&row, "text");
            (
                if text.starts_with("file://") {
                    "file"
                } else if text.starts_with("https://") || text.starts_with("http://") {
                    "link"
                } else {
                    "text"
                },
                format!("text:{text}"),
                cut(text, 160),
            )
        } else if s(&row, "type") == "image" && row["path"].is_string() {
            (
                "image",
                format!("image:{}", s(&row, "path")),
                format!("Image · {}", cut(s(&row, "capturedAt"), 120)),
            )
        } else {
            continue;
        };
        result.push((hash(&key), kind.into(), preview, row));
    }
    Ok(result)
}
fn clipboard(op: &str, p: &Value) -> Result<Value> {
    let rows = history()?;
    if op == "module-copy" {
        let r = rows
            .iter()
            .find(|r| r.0 == s(p, "id"))
            .ok_or("That entry is no longer in history. Refresh and try again.")?;
        let (mime, data) = if r.1 == "image" {
            let m = r.3["mime"].as_str().unwrap_or("image/png");
            if !["image/png", "image/jpeg", "image/webp"].contains(&m) {
                return err("Unsupported image type");
            };
            (m, owned_read(Path::new(s(&r.3, "path")), 8 * 1024 * 1024)?)
        } else {
            (
                if r.1 == "file" {
                    "text/uri-list"
                } else {
                    "text/plain;charset=utf-8"
                },
                s(&r.3, "text").as_bytes().to_vec(),
            )
        }; // wl-copy owns the selection in a detached child; do not kill it on success.
        let mut input = tempfile::tempfile()?;
        input.write_all(&data)?;
        use std::io::Seek;
        input.rewind()?;
        use std::os::unix::process::CommandExt;
        let mut child = std::process::Command::new("wl-copy")
            .args(["--type", mime])
            .stdin(input)
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .process_group(0)
            .spawn()?;
        let start = std::time::Instant::now();
        loop {
            if let Some(status) = child.try_wait()? {
                if !status.success() {
                    return err("Clipboard copy failed; check the Wayland session");
                };
                break;
            }
            if start.elapsed().as_secs() >= 3 {
                unsafe {
                    libc::kill(-(child.id() as i32), libc::SIGKILL);
                }
                let _ = child.wait();
                return err("Clipboard copy timed out");
            };
            std::thread::sleep(std::time::Duration::from_millis(10));
        }
        return Ok(ok_message("Copied. Paste in your application."));
    }
    let query = cut(s(p, "query"), 120).to_lowercase();
    let kind = p["kind"].as_str().unwrap_or("all");
    let mut out = Vec::new();
    for (id, typ, preview, entry) in &rows {
        if kind != "all" && kind != typ
            || !cut(entry["text"].as_str().unwrap_or(preview), 8192)
                .to_lowercase()
                .contains(&query)
        {
            continue;
        };
        let mut row = json!({"id":id,"kind":typ,"preview":preview});
        if typ == "image" {
            let path = Path::new(s(entry, "path"));
            if let Ok(data) = owned_read(path, 8 * 1024 * 1024) {
                if let Ok((w, h)) = dimensions(&data) {
                    if data.starts_with(b"\x89PNG\r\n\x1a\n")
                        && w > 0
                        && h > 0
                        && w <= 4096
                        && h <= 4096
                    {
                        row["image"] = uri(path).into();
                    }
                }
            }
        }
        out.push(row);
        if out.len() == 50 {
            break;
        }
    }
    Ok(json!({"rows":out,"count":rows.len()}))
}
fn stats() -> Result<Value> {
    let proc = fs::read_to_string("/proc/stat")?;
    let values = proc
        .lines()
        .next()
        .ok_or("CPU statistics unavailable")?
        .split_whitespace()
        .skip(1)
        .take(8)
        .map(str::parse::<u64>)
        .collect::<std::result::Result<Vec<_>, _>>()?;
    if values.len() < 4 {
        return err("CPU statistics unavailable");
    };
    let mem = fs::read_to_string("/proc/meminfo")?;
    let find = |key: &str| -> Option<u64> {
        mem.lines()
            .find(|l| l.starts_with(key))
            .and_then(|l| l.split_whitespace().nth(1)?.parse::<u64>().ok())
            .map(|v| v * 1024)
    };
    let total = find("MemTotal:")
        .filter(|v| *v > 0)
        .ok_or("Memory statistics unavailable")?;
    let available = find("MemAvailable:").ok_or("Memory statistics unavailable")?;
    let mut disk: libc::statvfs = unsafe { std::mem::zeroed() };
    if unsafe { libc::statvfs(c"/".as_ptr(), &mut disk) } != 0 {
        return Err(std::io::Error::last_os_error().into());
    };
    let disk_total = disk.f_blocks * disk.f_frsize;
    let disk_free = disk.f_bfree * disk.f_frsize;
    Ok(
        json!({"sample":{"total":values.iter().sum::<u64>(),"idle":values[3]+values.get(4).unwrap_or(&0),"memory":(1000.0*(total-available) as f64/total as f64).round()/10.0,"memoryUsed":total-available,"memoryTotal":total,"disk":(1000.0*(disk_total-disk_free) as f64/disk_total as f64).round()/10.0,"diskFree":disk.f_bavail*disk.f_frsize}}),
    )
}
fn weather(p: &Value) -> Result<Value> {
    let lat = p["latitude"]
        .as_f64()
        .ok_or("Set a latitude and longitude first")?;
    let lon = p["longitude"]
        .as_f64()
        .ok_or("Set a latitude and longitude first")?;
    if !(-90.0..=90.0).contains(&lat) || !(-180.0..=180.0).contains(&lon) {
        return err("Coordinates are out of range");
    };
    let url=format!("https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code,wind_speed_10m&hourly=temperature_2m&forecast_hours=6&timezone=auto");
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
            &url,
        ],
        8.0,
        65536,
    )?;
    let v: Value = serde_json::from_str(&raw)?;
    for key in ["temperature_2m", "weather_code", "wind_speed_10m"] {
        if v["current"][key].as_f64().is_none() {
            return err("Weather provider returned incomplete data");
        }
    }
    let mut hours = Vec::new();
    if let (Some(times), Some(temperatures)) = (
        v["hourly"]["time"].as_array(),
        v["hourly"]["temperature_2m"].as_array(),
    ) {
        for (time, t) in times.iter().zip(temperatures).take(6) {
            if t.as_f64().is_none() {
                return err("Weather provider returned incomplete data");
            };
            hours.push(json!({"time":cut(time.as_str().unwrap_or(""),16),"temperature":t}));
        }
    }
    Ok(
        json!({"weather":{"temperature":v["current"]["temperature_2m"],"code":v["current"]["weather_code"],"wind":v["current"]["wind_speed_10m"],"hours":hours}}),
    )
}
pub fn dimensions(b: &[u8]) -> Result<(u32, u32)> {
    if b.starts_with(b"\x89PNG\r\n\x1a\n") && b.len() >= 24 {
        return Ok((
            u32::from_be_bytes(b[16..20].try_into()?),
            u32::from_be_bytes(b[20..24].try_into()?),
        ));
    }
    if b.starts_with(&[255, 216]) {
        let mut i = 2;
        while i + 9 < b.len() {
            if b[i] != 255 {
                return err("Invalid JPEG");
            };
            let marker = b[i + 1];
            i += 2;
            if [0xd8, 0xd9].contains(&marker) {
                continue;
            }
            let length = u16::from_be_bytes(b[i..i + 2].try_into()?) as usize;
            if length < 2 {
                return err("Invalid JPEG");
            };
            if [0xc0, 0xc1, 0xc2].contains(&marker) {
                return Ok((
                    u16::from_be_bytes(b[i + 5..i + 7].try_into()?) as u32,
                    u16::from_be_bytes(b[i + 3..i + 5].try_into()?) as u32,
                ));
            }
            i += length;
        }
    }
    err("Artwork must be PNG or JPEG")
}
fn public(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(v) => {
            let a = v.octets();
            !v.is_private()
                && !v.is_loopback()
                && !v.is_link_local()
                && !v.is_unspecified()
                && !v.is_broadcast()
                && !v.is_documentation()
                && !v.is_multicast()
                && a[0] != 0
                && a[0] < 224
                && !(a[0] == 100 && (64..=127).contains(&a[1]))
                && !(a[0] == 198 && [18, 19].contains(&a[1]))
                && !(a[0] == 192 && a[1] == 0 && a[2] == 0)
        }
        IpAddr::V6(v) => {
            if let Some(v) = v.to_ipv4_mapped() {
                return public(IpAddr::V4(v));
            };
            let s = v.segments();
            (s[0] & 0xe000) == 0x2000
                && s[..2] != [0x2001, 0xdb8]
                && s[0] != 0x2002
                && !(s[0] == 0x2001 && s[1] < 0x0200)
        }
    }
}
fn artwork(url: &str) -> Result<Value> {
    if url.len() > 4096 {
        return err("Invalid artwork URL");
    };
    let root = base("XDG_CACHE_HOME", home().join(".cache")).join("omarchy-perch");
    private_dir(&root)?;
    let target = root.join(format!("{}.image", hash(url)));
    if target.exists()
        && now()
            - target
                .metadata()?
                .modified()?
                .duration_since(std::time::UNIX_EPOCH)?
                .as_secs_f64()
            < 86400.0
        && !target.is_symlink()
    {
        return Ok(json!({"art":uri(&target)}));
    };
    let mut url = url.to_owned();
    let deadline = std::time::Instant::now();
    for _ in 0..4 {
        let (scheme, host, port, _) = url_parts(&url)?;
        if scheme != "https" || port != 443 {
            return err("Only public HTTPS artwork is supported");
        };
        let (sender, receiver) = std::sync::mpsc::channel();
        let hostname = host.clone();
        std::thread::spawn(move || {
            let result = (hostname.as_str(), port)
                .to_socket_addrs()
                .map(|v| v.collect::<Vec<_>>());
            let _ = sender.send(result);
        });
        let dns_timeout = std::time::Duration::from_secs_f64(
            (7.0 - deadline.elapsed().as_secs_f64()).clamp(0.001, 3.0),
        );
        let addresses = receiver
            .recv_timeout(dns_timeout)
            .map_err(|_| "Artwork host lookup timed out")??;
        if addresses.is_empty() || addresses.iter().any(|a| !public(a.ip())) {
            return err("Artwork host is not a public address");
        };
        let resolve = format!(
            "{host}:443:{}",
            match addresses[0].ip() {
                IpAddr::V4(v) => v.to_string(),
                IpAddr::V6(v) => format!("[{v}]"),
            }
        );
        let remaining = 7.0 - deadline.elapsed().as_secs_f64();
        if remaining <= 0.0 {
            return err("Artwork request timed out");
        };
        let output = run_bytes(
            &[
                "curl",
                "--disable",
                "--silent",
                "--show-error",
                "--noproxy",
                "*",
                "--proto",
                "=https",
                "--max-time",
                &remaining.to_string(),
                "--max-filesize",
                "2097152",
                "--resolve",
                &resolve,
                "--include",
                "--user-agent",
                "Perch/0.1",
                "--header",
                "Accept: image/png,image/jpeg",
                &url,
            ],
            remaining,
            2113536,
            None,
        )?;
        let split = output
            .windows(4)
            .position(|b| b == b"\r\n\r\n")
            .ok_or("Invalid artwork response")?;
        let headers = String::from_utf8_lossy(&output[..split]);
        let status = headers
            .lines()
            .next()
            .and_then(|l| l.split_whitespace().nth(1))
            .unwrap_or("");
        if ["301", "302", "303", "307", "308"].contains(&status) {
            let next = headers
                .lines()
                .find_map(|l| {
                    l.split_once(':')
                        .filter(|(k, _)| k.eq_ignore_ascii_case("location"))
                        .map(|(_, v)| v.trim())
                })
                .ok_or("Invalid artwork redirect")?;
            url = url::Url::parse(&url)?.join(next)?.to_string();
            continue;
        }
        if status != "200" {
            return err("Artwork provider returned an error");
        };
        let data = &output[split + 4..];
        if data.len() > 2097152 {
            return err("Artwork exceeds 2 MiB");
        };
        let (w, h) = dimensions(data)?;
        if w == 0 || h == 0 || w > 4096 || h > 4096 || w as u64 * h as u64 > 8388608 {
            return err("Artwork dimensions exceed limits");
        };
        atomic(&target, data, 0o600)?;
        let mut cached = fs::read_dir(&root)?
            .flatten()
            .map(|e| e.path())
            .filter(|p| p.extension().is_some_and(|x| x == "image") && !p.is_symlink())
            .collect::<Vec<_>>();
        cached.sort_by_key(|p| std::cmp::Reverse(p.metadata().and_then(|m| m.modified()).ok()));
        for p in cached.iter().skip(32) {
            fs::remove_file(p)?;
        }
        return Ok(json!({"art":uri(&target)}));
    }
    err("Too many artwork redirects")
}
fn lyrics(path: &str) -> Result<Value> {
    let path = local(path)?;
    if !path.extension().is_some_and(|s| s == "lrc" || s == "txt") {
        return err("Choose local .lrc or .txt lyrics");
    };
    let raw = read(&path, 65536, false)?;
    let text = String::from_utf8_lossy(&raw);
    let stamps = regex::Regex::new(r"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]")?;
    let tags = regex::Regex::new(r"\[[^\]]*\]")?;
    let mut rows = Vec::new();
    for line in text.trim_start_matches('\u{feff}').lines().take(1000) {
        let words = cut(&tags.replace_all(line, ""), 240);
        let mut matched = false;
        for m in stamps.captures_iter(line) {
            matched = true;
            let fraction = m
                .get(3)
                .map(|v| v.as_str().parse::<f64>().unwrap() / 10f64.powi(v.len() as i32))
                .unwrap_or(0.0);
            rows.push(json!({"time":m[1].parse::<f64>()?*60.0+m[2].parse::<f64>()?+fraction,"text":words}));
        }
        if !matched && !words.trim().is_empty() {
            rows.push(json!({"time":-1,"text":words}));
        }
    }
    rows.sort_by(|a, b| {
        a["time"]
            .as_f64()
            .unwrap()
            .total_cmp(&b["time"].as_f64().unwrap())
    });
    rows.truncate(500);
    Ok(json!({"lyrics":rows}))
}
pub fn handle(op: &str, p: &Value) -> Result<Value> {
    match op {
        _ if op.starts_with("shelf-") => shelf(op, p),
        _ if op.starts_with("card-") => card(op, p),
        "plugin-list" => Ok(json!({"plugins":plugins()?})),
        "plugin-open" => {
            let id = s(p, "id");
            if !valid_id(id) {
                return err("Invalid plugin request");
            };
            let rows = plugins()?;
            let row = rows
                .iter()
                .find(|r| r["id"] == id)
                .ok_or("Plugin was removed or has no supported visual entry point")?;
            if row["enabled"] != true {
                return err("Plugin is disabled; manage it in Omarchy");
            };
            if run(&["omarchy-shell", "shell", "summon", id, "{}"], 3.0, 4096)?.trim() != "ok" {
                return err("Omarchy could not open this plugin; its panel may be unavailable");
            }
            Ok(ok_message(&format!("Opened {}", s(row, "name"))))
        }
        "app-link" => {
            launch(&["xdg-open", web_url(s(p, "url"))?])?;
            Ok(ok_message("Link opened"))
        }
        "app-list" => Ok(json!({"apps":apps()})),
        "app-open" => {
            if !apps().iter().any(|a| a["id"] == p["id"]) {
                return err("Application is no longer installed");
            };
            launch(&["gtk-launch", s(p, "id")])?;
            Ok(ok_message("Application launch requested"))
        }
        "module-stats" => stats(),
        "module-weather" => weather(p),
        "module-clipboard" | "module-copy" => clipboard(op, p),
        "artwork" => artwork(s(p, "url")),
        "lyrics" => lyrics(s(p, "path")),
        "brightness-get" | "brightness-set" => {
            if which("brightnessctl").is_none() {
                return err("brightnessctl is not installed");
            };
            if op == "brightness-set" {
                let v = p["value"]
                    .as_f64()
                    .filter(|v| (1.0..=100.0).contains(v))
                    .ok_or("Brightness must be 1–100%")?;
                run(
                    &[
                        "brightnessctl",
                        "-c",
                        "backlight",
                        "set",
                        &format!("{}%", v.round()),
                    ],
                    3.0,
                    65536,
                )?;
            }
            let output = run(&["brightnessctl", "-c", "backlight", "-m"], 3.0, 4096)?;
            let row: Vec<_> = output.trim().split(',').collect();
            let v = row
                .get(3)
                .and_then(|s| s.strip_suffix('%'))
                .ok_or("No supported brightness device")?
                .parse::<u32>()?;
            Ok(json!({"brightness":v}))
        }
        "alarm" => {
            let preset = p["preset"].as_str().unwrap_or("complete");
            if !["complete", "message-new-instant", "bell"].contains(&preset) {
                return err("Unknown sound preset");
            };
            let mut missing = Vec::new();
            if p["sound"] == true {
                if which("canberra-gtk-play").is_some() {
                    run(&["canberra-gtk-play", "-i", preset], 4.0, 1024)?;
                } else {
                    missing.push("Sound unavailable: install canberra-gtk-play")
                }
            }
            if p["notify"] == true {
                if which("notify-send").is_some() {
                    run(
                        &[
                            "notify-send",
                            "--app-name=Perch",
                            "--",
                            &format!(
                                "{} finished",
                                cut(p["label"].as_str().unwrap_or("Timer"), 80)
                            ),
                            "Your timer has completed.",
                        ],
                        3.0,
                        1024,
                    )?;
                } else {
                    missing.push("Desktop notification helper unavailable")
                }
            }
            Ok(ok_message(&missing.join("; ")))
        }
        _ => err("Unsupported operation"),
    }
}
