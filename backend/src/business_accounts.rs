//! Named local accounts, explicit credential acquisition, and bounded daily observations.
use crate::{business, core::*};
use serde_json::{json, Value};
use std::{fs, path::Path};
fn rows() -> Result<Vec<Value>> {
    let store = Store::new("business-accounts")?;
    let data = store.load(json!([]))?;
    Ok(data.as_array().ok_or("Invalid account store")?.clone())
}
fn account(id: &str) -> Result<Value> {
    if !valid(id, "^[a-f0-9]{24}$") {
        return err("Choose a business account");
    }
    rows()?
        .into_iter()
        .find(|r| s(r, "id") == id)
        .ok_or_else(|| "Account is disconnected; choose another account".into())
}
fn public(r: &Value) -> Value {
    json!({"id":r["id"],"name":r["name"],"color":r["color"],"provider":r["provider"],"sandbox":r["sandbox"],"storage":r["storage"],"revision":r["revision"],"createdAt":r["createdAt"]})
}
pub fn list() -> Result<Value> {
    Ok(
        json!({"accounts":rows()?.iter().map(public).collect::<Vec<_>>(),"capabilities":{"dialog":which("zenity").is_some(),"keyring":which("secret-tool").is_some()}}),
    )
}
fn credentials(r: &Value) -> Result<Value> {
    match s(r, "storage") {
        "file" => Ok(r["credentials"].clone()),
        "external" => business::load_credentials(Path::new(s(r, "path"))),
        "keyring" => {
            let data=run(&["secret-tool","lookup","application","io.github.tcballard.perch","account",s(r,"id")],20.0,8192).map_err(|_|"Could not unlock/read this account in Secret Service. Unlock your keyring or reconnect the account.")?;
            serde_json::from_str(&data)
                .map_err(|_| "Stored account credential is unavailable; reconnect it".into())
        }
        _ => err("Unsupported credential storage"),
    }
}
fn check_credentials(v: &Value) -> Result<()> {
    let fields = match s(v, "provider") {
        "stripe" | "paddle" => vec!["apiKey"],
        "shopify" => vec!["shop", "clientId", "clientSecret"],
        _ => return err("Choose Stripe, Paddle or Shopify"),
    };
    for field in fields {
        let value = s(v, field);
        if value.is_empty() || value.len() > 4096 || value.chars().any(char::is_control) {
            return err("A credential field is missing or invalid");
        }
    }
    if string_json(v).len() > 8192 {
        return err("Credential fields exceed the 8 KiB limit");
    }
    Ok(())
}
fn naming(p: &Value) -> Result<(String, String)> {
    let name = clean(s(p, "name"), 60).trim().to_string();
    let color = s(p, "color");
    if name.is_empty() {
        return err("Give the account a name");
    }
    if !valid(color, "^#[0-9A-Fa-f]{6}$") {
        return err("Choose a six-digit account color");
    }
    Ok((name, color.into()))
}
pub fn handle(op: &str, p: &Value) -> Result<Value> {
    match op {
        "business-account-list" => list(),
        "business-account-rename" => {
            let (name, color) = naming(p)?;
            let id = s(p, "id");
            account(id)?;
            let store = Store::new("business-accounts")?;
            let mut data = store.load(json!([]))?;
            let row = data
                .as_array_mut()
                .ok_or("Invalid account store")?
                .iter_mut()
                .find(|r| s(r, "id") == id)
                .ok_or("Account disconnected")?;
            row["name"] = name.into();
            row["color"] = color.into();
            store.save(&data)?;
            drop(store);
            list()
        }
        "business-account-disconnect" => {
            let id = s(p, "id");
            let r = account(id)?;
            if s(&r, "storage") == "keyring" {
                run(
                    &[
                        "secret-tool",
                        "clear",
                        "application",
                        "io.github.tcballard.perch",
                        "account",
                        id,
                    ],
                    20.0,
                    8192,
                )
                .map_err(|_| "Could not remove the keyring entry; unlock the keyring and retry")?;
            }
            let store = Store::new("business-accounts")?;
            let mut data = store.load(json!([]))?;
            data.as_array_mut()
                .ok_or("Invalid account store")?
                .retain(|r| s(r, "id") != id);
            store.save(&data)?;
            drop(store);
            let history = Store::new(&format!("business-history-{id}"))?;
            if history.path.exists() {
                fs::remove_file(&history.path)?;
            }
            drop(history);
            list()
        }
        "business-account-test" => {
            let r = account(s(p, "id"))?;
            let report = business::report(
                &credentials(&r)?,
                &json!({"period":"today","currency":s(p,"currency"),"timeZone":s(p,"timeZone")}),
            )?;
            let store = Store::new("business-accounts")?;
            let mut data = store.load(json!([]))?;
            if let Some(account) = data
                .as_array_mut()
                .and_then(|rows| rows.iter_mut().find(|row| row["id"] == r["id"]))
            {
                account["sandbox"] = report["sandbox"].clone();
                store.save(&data)?;
            }
            drop(store);
            let mut response = list()?;
            response["message"] = "Read-only connection and report permissions verified".into();
            Ok(response)
        }
        "business-account-import" | "business-account-connect" => {
            let (name, color) = naming(p)?;
            let existing = rows()?;
            let import = op == "business-account-import";
            if !import && existing.len() >= 12 {
                return err("Perch supports up to 12 business accounts");
            }
            let mut storage = if import { "external" } else { s(p, "storage") };
            if !["external", "file", "keyring"].contains(&storage)
                || (!import && storage == "external")
            {
                return err("Choose keyring or private-file storage");
            }
            if storage == "keyring" && which("secret-tool").is_none() {
                return err("Install libsecret (secret-tool) and start a Secret Service keyring, or choose private-file storage");
            }
            let v = if import {
                let path = Path::new(s(p, "path"));
                if !path.is_absolute() {
                    return err("Choose an absolute credential file path");
                }
                // Import is idempotent and preserves the original file.
                if let Some(r) = existing
                    .iter()
                    .find(|r| s(r, "storage") == "external" && s(r, "path") == s(p, "path"))
                {
                    let mut result = list()?;
                    result["accountId"] = r["id"].clone();
                    return Ok(result);
                }
                business::load_credentials(path)?
            } else {
                if which("zenity").is_none() {
                    return err("Install zenity for the masked credential dialog, or import an existing private file");
                }
                let provider = s(p, "provider");
                let fields = match provider {
                    "stripe" => vec!["Restricted API key"],
                    "paddle" => vec!["Billing API key"],
                    "shopify" => vec![
                        "Shop domain (name.myshopify.com)",
                        "Client ID",
                        "Client secret",
                    ],
                    _ => return err("Choose Stripe, Paddle or Shopify"),
                };
                let title = format!("Perch — Connect {provider}");
                let mut args = vec![
                    "zenity",
                    "--forms",
                    "--title",
                    &title,
                    "--text",
                    "Read-only credentials stay on this computer.",
                    "--separator",
                    "\x1f",
                ];
                for (index, field) in fields.iter().enumerate() {
                    args.extend([
                        if provider == "shopify" && index < 2 {
                            "--add-entry"
                        } else {
                            "--add-password"
                        },
                        field,
                    ]);
                }
                let output = run(&args, 120.0, 16384).map_err(|_| {
                    "Credential entry cancelled, timed out, or unavailable. No account was saved."
                })?;
                let parts = output
                    .trim_end_matches(['\n', '\r'])
                    .split('\x1f')
                    .collect::<Vec<_>>();
                if parts.len() != fields.len() {
                    return err("Invalid credential dialog response");
                }
                if provider == "shopify" {
                    json!({"provider":provider,"shop":parts[0].trim(),"clientId":parts[1].trim(),"clientSecret":parts[2].trim()})
                } else {
                    json!({"provider":provider,"apiKey":parts[0].trim()})
                }
            };
            if existing.len() >= 12 {
                return err("Perch supports up to 12 business accounts");
            }
            check_credentials(&v)?;
            // Legacy import remains available offline. New credentials are verified before saving.
            let verified = if !import {
                business::report(
                    &v,
                    &json!({"period":"today","currency":s(p,"currency"),"timeZone":s(p,"timeZone")}),
                )?
            } else {
                json!({})
            };
            let id = cut(
                &hash(&format!("{}-{}-{}", now(), std::process::id(), name)),
                24,
            );
            let sandbox = match s(&v, "provider") {
                "stripe" => json!(s(&v, "apiKey").starts_with("rk_test_")),
                "paddle" => json!(s(&v, "apiKey").starts_with("pdl_sdbx_")),
                _ => verified["sandbox"].clone(),
            };
            let mut row = json!({"id":id,"name":name,"color":color,"provider":v["provider"],"sandbox":sandbox,"storage":storage,"revision":id,"createdAt":now()});
            if import {
                row["path"] = p["path"].clone();
                storage = "external";
            } else if storage == "keyring" {
                run_bytes(&["secret-tool","store","--label=Perch business account","application","io.github.tcballard.perch","account",&id],20.0,8192,Some(string_json(&v).as_bytes())).map_err(|_|"Could not store the key in Secret Service; unlock the keyring and retry. No private-file fallback was used.")?;
            } else {
                row["credentials"] = v;
            }
            let store = Store::new("business-accounts")?;
            let mut data = store.load(json!([]))?;
            let rows = data.as_array_mut().ok_or("Invalid account store")?;
            if rows.len() >= 12 {
                drop(store);
                if storage == "keyring" {
                    let _ = run(
                        &[
                            "secret-tool",
                            "clear",
                            "application",
                            "io.github.tcballard.perch",
                            "account",
                            &id,
                        ],
                        20.0,
                        8192,
                    );
                }
                return err("Account limit reached; retry after disconnecting an account");
            }
            rows.push(row);
            if let Err(error) = store.save(&data) {
                drop(store);
                if storage == "keyring" {
                    let _ = run(
                        &[
                            "secret-tool",
                            "clear",
                            "application",
                            "io.github.tcballard.perch",
                            "account",
                            &id,
                        ],
                        20.0,
                        8192,
                    );
                }
                return Err(error);
            }
            drop(store);
            let mut result = list()?;
            result["accountId"] = id.into();
            result["message"] = if import {
                "Imported existing connection; use Test connection to verify access"
            } else {
                "Connection verified and saved"
            }
            .into();
            Ok(result)
        }
        _ => err("Unknown business account operation"),
    }
}
pub fn metrics(p: &Value) -> Result<Value> {
    if s(p, "accountId").is_empty() {
        return business::read_metrics(p);
    }
    let account = account(s(p, "accountId"))?;
    let mut result = business::report(&credentials(&account)?, p)?;
    if s(&result, "provider") != s(&account, "provider") {
        return err("Credential provider changed; import the connection again");
    }
    result["accountId"] = account["id"].clone();
    if s(&result, "provider") == "stripe" {
        if let Err(e) = observe(&account, &mut result) {
            result["historyError"] = clean(&e.to_string(), 160).into();
        }
    }
    Ok(result)
}
pub fn observe(account: &Value, report: &mut Value) -> Result<()> {
    let id = s(account, "id");
    let registry = Store::new("business-accounts")?;
    let data = registry.load(json!([]))?;
    if !data.as_array().is_some_and(|rows| {
        rows.iter()
            .any(|r| r["id"] == account["id"] && r["revision"] == account["revision"])
    }) {
        return err("Account disconnected while reading; history was not saved");
    }
    // The shared lock also serializes history writers and disconnect. Reuse it directly.
    let path = registry
        .path
        .parent()
        .unwrap()
        .join(format!("business-history-{id}.json"));
    let mut samples = if path.exists() || path.is_symlink() {
        serde_json::from_slice::<Value>(&read(&path, 262144, false)?)?
            .as_array()
            .ok_or("Invalid metric history")?
            .clone()
    } else {
        Vec::new()
    };
    update_history(&mut samples, report)?;
    let bytes = serde_json::to_vec(&samples)?;
    if bytes.len() > 262144 {
        return err("History size limit reached");
    }
    atomic(&path, &bytes, 0o600)?;
    Ok(())
}
pub fn update_history(samples: &mut Vec<Value>, report: &mut Value) -> Result<()> {
    let date = s(&report["period"], "last").to_string();
    let zone = s(&report["period"], "timeZone").to_string();
    let currency = s(report, "currency").to_uppercase();
    let labels = ["MRR estimate", "ARR estimate", "Paying subscribers", "ARPU"];
    let values = report["metrics"]
        .as_array()
        .ok_or("Missing metrics")?
        .iter()
        .filter(|m| labels.contains(&s(m, "label")))
        .map(|m| (s(m, "label").to_string(), m["value"].clone()))
        .collect::<serde_json::Map<String, Value>>();
    samples.retain(|p| {
        !(s(p, "date") == date && s(p, "zone") == zone && s(p, "currency") == currency)
    });
    // Empty maps mark unsupported calculations; they must not retain an earlier valid daily value.
    samples.push(json!({"date":date,"zone":zone,"currency":currency,"values":values,"at":report["updatedAt"]}));
    samples.sort_by(|a, b| s(a, "date").cmp(s(b, "date")));
    if samples.len() > 400 {
        samples.drain(..samples.len() - 400);
    }
    let relevant = samples
        .iter()
        .filter(|p| s(p, "zone") == zone && s(p, "currency") == currency)
        .collect::<Vec<_>>();
    report["historyStarted"] = relevant
        .first()
        .map(|p| p["date"].clone())
        .unwrap_or(Value::Null);
    let first = chrono::NaiveDate::parse_from_str(s(&report["period"], "first"), "%Y-%m-%d")?;
    let last = chrono::NaiveDate::parse_from_str(&date, "%Y-%m-%d")?;
    let previous_end = s(&report["period"], "previousLast");
    let previous = relevant
        .iter()
        .find(|p| s(p, "date") == previous_end)
        .map(|p| p["values"].clone())
        .unwrap_or(json!({}));
    for label in labels {
        let mut points = Vec::new();
        let mut day = first;
        while day <= last {
            let value = relevant
                .iter()
                .find(|p| s(p, "date") == day.to_string())
                .map(|p| p["values"][label].clone())
                .unwrap_or(Value::Null);
            points.push(json!({"date":day.to_string(),"value":value}));
            day += chrono::Duration::days(1);
        }
        report["series"][label] = json!(points);
        if let Some(m) = report["metrics"]
            .as_array_mut()
            .unwrap()
            .iter_mut()
            .find(|m| s(m, "label") == label)
        {
            m["previous"] = previous[label].clone();
            m["comparisonKind"] = "Last observation on prior end date".into();
            m["changePercent"] = match (previous[label].as_f64(), m["value"].as_f64()) {
                (Some(p), Some(c)) if p != 0.0 => json!((c - p) / p.abs() * 100.0),
                _ => Value::Null,
            };
        }
    }
    Ok(())
}
