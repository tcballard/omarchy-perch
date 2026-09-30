mod agents;
mod calendar;
mod cli;
mod core;
mod desktop;
mod setup;
mod sockets;
use core::*;
use serde_json::{json, Value};
fn tools(op: &str, p: &Value) -> Result<Value> {
    match op {
        "health"
        | "integration"
        | "integration-remove-all"
        | "integration-worker"
        | "self-update-apply" => setup::tools(op, p),
        "codex-server-status" => sockets::codex(p),
        "request-get" | "request-reply" => sockets::tools(op, p),
        "usage" => agents::usage(),
        _ if op.starts_with("agent-") => agents::handle(op, p),
        _ if op.starts_with("calendar-") => calendar::handle(op, p),
        _ => desktop::handle(op, p),
    }
}
fn main() {
    signals();
    let a: Vec<String> = std::env::args().skip(1).collect();
    let command = a.first().map(String::as_str).unwrap_or("help");
    let args = &a[usize::from(!a.is_empty())..];
    if command == "tools" {
        let result = (|| {
            if args.len() != 2 || args[1].len() > 65536 {
                return err("Invalid request");
            };
            let p: Value = serde_json::from_str(&args[1])?;
            if !p.is_object() {
                return err("Invalid request object");
            };
            let mut v = tools(&args[0], &p)?;
            v.as_object_mut()
                .ok_or("Invalid backend result")?
                .insert("ok".into(), true.into());
            let out = string_json(&v);
            if out.len() > 131072 {
                return err("Result exceeds limit");
            };
            Ok(out)
        })();
        println!(
            "{}",
            result.unwrap_or_else(|e| string_json(
                &json!({"ok":false,"error":cut(&e.to_string(),240)})
            ))
        );
        return;
    }
    if let Err(e) = cli::dispatch(command, args) {
        eprintln!("Perch: {}", cut(&e.to_string(), 240));
        std::process::exit(1)
    }
}

#[cfg(test)]
mod tests;
