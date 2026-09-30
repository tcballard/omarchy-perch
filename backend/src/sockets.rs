use crate::{agents, core::*};
use serde_json::{json, Value};
use std::{
    collections::HashSet,
    fs,
    io::{Read, Write},
    os::{
        fd::AsRawFd,
        unix::{
            fs::{FileTypeExt, MetadataExt, OpenOptionsExt, PermissionsExt},
            net::{UnixListener, UnixStream},
        },
    },
    path::{Path, PathBuf},
    time::{Duration, Instant},
};
fn runtime(kind: &str) -> Result<PathBuf> {
    let root =
        base("XDG_RUNTIME_DIR", std::env::temp_dir()).join(format!("perch-{kind}-{}", uid()));
    private_dir(&root)?;
    Ok(root)
}
fn socket_owned(path: &Path, private: bool) -> Result<()> {
    let m = fs::symlink_metadata(path)?;
    if !m.file_type().is_socket() || m.uid() != uid() || private && m.mode() & 0o077 != 0 {
        return err("Unsafe socket");
    };
    Ok(())
}
fn peer(conn: &UnixStream) -> Result<()> {
    let mut cred: libc::ucred = unsafe { std::mem::zeroed() };
    let mut len = std::mem::size_of::<libc::ucred>() as libc::socklen_t;
    if unsafe {
        libc::getsockopt(
            conn.as_raw_fd(),
            libc::SOL_SOCKET,
            libc::SO_PEERCRED,
            (&mut cred as *mut libc::ucred).cast(),
            &mut len,
        )
    } != 0
    {
        return Err(std::io::Error::last_os_error().into());
    };
    if cred.uid != uid() {
        return err("Socket owner changed");
    };
    Ok(())
}
fn receive(conn: &mut UnixStream, limit: usize) -> Result<Value> {
    let mut raw = Vec::new();
    loop {
        let mut bytes = [0; 2048];
        let n = conn.read(&mut bytes)?;
        if n == 0 {
            return err("Incomplete socket message");
        };
        raw.extend_from_slice(&bytes[..n]);
        if raw.len() > limit {
            return err("Response too large");
        };
        if let Some(end) = raw.iter().position(|v| *v == b'\n') {
            return Ok(serde_json::from_slice(&raw[..end])?);
        }
    }
}
fn send(conn: &mut UnixStream, v: &Value) -> Result<()> {
    conn.write_all(string_json(v).as_bytes())?;
    conn.write_all(b"\n")?;
    Ok(())
}
struct Paths(Vec<PathBuf>);
impl Drop for Paths {
    fn drop(&mut self) {
        for p in &self.0 {
            let _ = fs::remove_file(p);
        }
    }
}
pub fn request_read(token: &str) -> Result<Value> {
    if !valid(token, r"^[0-9a-f]{32}$") {
        return err("Invalid request identity");
    };
    let path = runtime("requests")?.join(format!("{token}.json"));
    let raw = read(&path, 32768, false)?;
    if fs::symlink_metadata(path)?.uid() != uid() {
        return err("Invalid request record");
    };
    let data: Value = serde_json::from_slice(&raw)?;
    if data["id"] != token || data["expiresAt"].as_f64().unwrap_or(0.0) <= now() {
        return err("Request expired; continue in your agent session");
    };
    Ok(data)
}
pub fn decision(data: &Value, response: &Value) -> Result<Value> {
    let action = s(response, "action");
    if action == "session" {
        return Ok(json!({}));
    }
    if s(data, "kind") == "approval" {
        if !["allow", "deny"].contains(&action) {
            return err("Choose Allow once or Deny");
        };
        return Ok(if s(data, "agent") == "opencode" {
            json!({"response":if action=="allow"{"once"}else{"reject"}})
        } else {
            json!({"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":action}}})
        });
    }
    if action == "deny" {
        return Ok(
            json!({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"User declined to answer in Perch"}}),
        );
    }
    if action != "answer" {
        return err("Unsupported response");
    };
    let answers = response["answers"]
        .as_object()
        .ok_or("Answer every question")?;
    let questions = data["input"]["questions"]
        .as_array()
        .ok_or("Invalid question")?;
    if answers.len() != questions.len()
        || questions
            .iter()
            .any(|q| !answers.contains_key(s(q, "question")))
    {
        return err("Answer every question");
    };
    if answers.values().any(|v| {
        v.as_str()
            .is_none_or(|s| s.trim().is_empty() || s.chars().count() > 2000)
    }) {
        return err("Answers must contain 1–2000 characters");
    };
    let mut input = data["input"].clone();
    input["answers"] = response["answers"].clone();
    Ok(
        json!({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":input}}),
    )
}
pub fn tools(op: &str, p: &Value) -> Result<Value> {
    let token = s(p, "id");
    let data = request_read(token)?;
    if op == "request-get" {
        return Ok(json!({"request":data}));
    }
    decision(&data, p)?;
    let path = runtime("requests")?.join(format!("{token}.sock"));
    socket_owned(&path, true)?;
    let mut conn = UnixStream::connect(path)?;
    conn.set_read_timeout(Some(Duration::from_secs(8)))?;
    conn.set_write_timeout(Some(Duration::from_secs(2)))?;
    peer(&conn)?;
    send(&mut conn, p)?;
    let reply = receive(&mut conn, 16384)?;
    if reply["ok"] != true {
        return err(reply["error"]
            .as_str()
            .unwrap_or("Request was not accepted"));
    };
    Ok(ok_message("Response delivered"))
}
pub fn request_data(raw: &Value, token: &str, deadline: f64, agent: &str) -> Result<Value> {
    let event = s(raw, "hook_event_name");
    let tool = raw["tool_name"]
        .as_str()
        .filter(|t| t.len() <= 160)
        .ok_or("Unsupported request")?;
    let input = &raw["tool_input"];
    if !["PermissionRequest", "PreToolUse"].contains(&event)
        || !input.is_object()
        || !["claude", "codex", "opencode"].contains(&agent)
        || agent != "claude" && event != "PermissionRequest"
    {
        return err("Unsupported request");
    };
    if serde_json::to_vec(input)?.len() > 16384 {
        return err("Review large input in the agent session");
    };
    let kind = if event == "PreToolUse" {
        if tool != "AskUserQuestion" {
            return err("Unsupported question tool");
        };
        let questions = input["questions"]
            .as_array()
            .filter(|v| !v.is_empty() && v.len() <= 4)
            .ok_or("Unsupported question count")?;
        let mut seen = HashSet::new();
        for q in questions {
            let question = q["question"]
                .as_str()
                .filter(|q| !q.is_empty() && q.chars().count() <= 1000)
                .ok_or("Invalid question")?;
            if !seen.insert(question) {
                return err("Invalid question");
            };
            let empty = vec![];
            let options = q
                .get("options")
                .map(|v| v.as_array().ok_or("Unsupported options"))
                .transpose()?
                .unwrap_or(&empty);
            if options.len() > 8
                || options
                    .iter()
                    .any(|v| v["label"].as_str().is_none_or(|s| s.chars().count() > 160))
            {
                return err("Unsupported options");
            }
        }
        "question"
    } else {
        "approval"
    };
    Ok(
        json!({"id":token,"agent":agent,"kind":kind,"tool":tool,"input":input,"cwd":if s(raw,"cwd").len()<=4096{s(raw,"cwd")}else{""},"expiresAt":deadline,"pid":std::process::id()}),
    )
}
fn publish(v: &Value, verb: &str) -> bool {
    run(
        &[
            "omarchy-shell",
            "io.github.tcballard.perch",
            verb,
            &if verb == "activity" {
                string_json(v)
            } else {
                v.as_str().unwrap_or("").into()
            },
        ],
        2.0,
        4096,
    )
    .is_ok_and(|s| s.trim() == "ok")
}
pub fn input_line(limit: usize, timeout: f64) -> Result<Vec<u8>> {
    let mut raw = Vec::new();
    let deadline = Instant::now();
    loop {
        let remaining = timeout - deadline.elapsed().as_secs_f64();
        if remaining <= 0.0 || cancelled() {
            return err("Input timed out");
        };
        let mut poll = libc::pollfd {
            fd: 0,
            events: libc::POLLIN,
            revents: 0,
        };
        if unsafe { libc::poll(&mut poll, 1, (remaining * 1000.0).min(100.0) as i32) } <= 0 {
            continue;
        };
        let mut byte = [0u8; 1];
        if std::io::stdin().read(&mut byte)? == 0 {
            return err("Input closed");
        };
        if byte[0] == b'\n' {
            return Ok(raw);
        }
        raw.push(byte[0]);
        if raw.len() > limit {
            return err("Input exceeds limit");
        }
    }
}
pub fn request_hook(args: &[String]) -> Result<()> {
    let agent = if args.is_empty() {
        "claude"
    } else if args.len() == 2
        && args[0] == "--agent"
        && ["codex", "opencode"].contains(&args[1].as_str())
    {
        &args[1]
    } else {
        return Ok(());
    };
    let result = (|| -> Result<()> {
        let raw = if agent == "opencode" {
            input_line(65536, 6.0)?
        } else {
            stdin(65536, false)?
        };
        let raw: Value = serde_json::from_slice(&raw)?;
        let root = runtime("requests")?;
        let mut random = [0u8; 16];
        fs::File::open("/dev/urandom")?.read_exact(&mut random)?;
        let token = random
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect::<String>();
        let deadline = now() + 120.0;
        let data = request_data(&raw, &token, deadline, agent)?;
        let mut count = 0;
        for p in fs::read_dir(&root)?
            .flatten()
            .map(|p| p.path())
            .filter(|p| p.extension().is_some_and(|s| s == "json"))
            .take(32)
        {
            let t = p.file_stem().unwrap_or_default().to_string_lossy();
            if request_read(&t).is_ok() {
                count += 1
            } else if valid(&t, r"^[0-9a-f]{32}$") {
                let _ = fs::remove_file(&p);
                let _ = fs::remove_file(p.with_extension("sock"));
            }
        }
        if count >= 8 {
            return Ok(());
        };
        let path = root.join(format!("{token}.json"));
        let socket = root.join(format!("{token}.sock"));
        let server = UnixListener::bind(&socket)?;
        fs::set_permissions(&socket, fs::Permissions::from_mode(0o600))?;
        let _guard = Paths(vec![path.clone(), socket]);
        let mut record = fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .custom_flags(libc::O_NOFOLLOW)
            .open(&path)?;
        record.write_all(string_json(&data).as_bytes())?;
        let id = format!("request.{token}");
        let project = Path::new(s(&data, "cwd"))
            .file_name()
            .unwrap_or_default()
            .to_string_lossy();
        if !publish(
            &json!({"id":id,"kind":"agent","agent":match agent{"codex"=>"Codex","opencode"=>"OpenCode",_=>"Claude"},"state":"waiting","attention":data["kind"],"requestId":token,"title":data["tool"],"detail":"Review in Perch or continue in your session","project":project,"ttl":120}),
            "activity",
        ) {
            return Ok(());
        };
        let result = (|| -> Result<()> {
            server.set_nonblocking(true)?;
            while now() < deadline && !cancelled() {
                match server.accept() {
                    Ok((mut conn, _)) => {
                        conn.set_read_timeout(Some(Duration::from_secs(2)))?;
                        conn.set_write_timeout(Some(Duration::from_secs(2)))?;
                        let response = (|| -> Result<Value> {
                            peer(&conn)?;
                            let response = receive(&mut conn, 16384)?;
                            if response["id"] != token || now() >= deadline {
                                return err("Request expired");
                            };
                            decision(&data, &response)
                        })();
                        match response {
                            Ok(value) => {
                                if value.as_object().is_some_and(|v| !v.is_empty()) {
                                    if agent == "opencode" {
                                        println!("{}", string_json(&value));
                                        std::io::stdout().flush()?;
                                        let delivered = input_line(1024, 6.0)
                                            .and_then(|v| Ok(serde_json::from_slice::<Value>(&v)?))
                                            .is_ok_and(|v| v["delivered"] == true);
                                        if !delivered {
                                            send(
                                                &mut conn,
                                                &json!({"ok":false,"error":"Client did not confirm delivery. Continue in your agent session."}),
                                            )?;
                                            return Ok(());
                                        }
                                    } else {
                                        println!("{}", string_json(&value));
                                        std::io::stdout().flush()?;
                                    }
                                }
                                send(&mut conn, &json!({"ok":true}))?;
                                return Ok(());
                            }
                            Err(_) => {
                                let _ = send(
                                    &mut conn,
                                    &json!({"ok":false,"error":"Invalid or expired response"}),
                                );
                            }
                        }
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        std::thread::sleep(Duration::from_millis(20))
                    }
                    Err(e) => return Err(e.into()),
                }
            }
            Ok(())
        })();
        publish(&json!(id), "dismiss");
        result
    })();
    let _ = result;
    Ok(())
}
pub fn relay_normalize(data: &Value) -> Result<Value> {
    let source = s(data, "source");
    let p = &data["event"];
    let id = s(p, "id");
    let state = s(p, "state");
    if !valid(source, r"^[A-Za-z0-9][A-Za-z0-9._-]{0,39}$")
        || !valid(id, r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
        || !["running", "waiting", "done", "error"].contains(&state)
    {
        return err("Invalid relay message");
    };
    Ok(
        json!({"id":format!("remote.{}",&hash(&format!("{source}:{id}"))[..32]),"kind":"agent","agent":format!("{} · remote",clean(s(p,"agent"),24)),"title":format!("{source} · {}",if s(p,"title").is_empty(){"Agent".into()}else{clean(s(p,"title"),72)}),"project":clean(s(p,"project"),100),"detail":match state{"running"=>"Working remotely","waiting"=>"Continue in your remote session","done"=>"Remote turn complete",_=>"Remote agent reported an error"},"state":state,"ttl":if state=="done"{30}else{3600},"eventKey":clean(s(p,"eventKey"),80)}),
    )
}
pub fn relay(args: &[String]) -> Result<()> {
    let path = runtime("relay")?.join("status.sock");
    if args.first().is_some_and(|a| a == "path") {
        println!("{}", path.display());
        return Ok(());
    };
    if args.first().is_none_or(|a| a != "serve") {
        return err("Use relay serve or relay path");
    };
    let lock = fs::OpenOptions::new()
        .create(true)
        .write(true)
        .read(true)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW)
        .open(path.with_extension("lock"))?;
    let m = lock.metadata()?;
    if !m.is_file()
        || m.uid() != uid()
        || m.mode() & 0o777 != 0o600
        || unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0
    {
        return err("Receiver already active or unsafe relay lock");
    };
    if path.exists() || path.is_symlink() {
        socket_owned(&path, true)?;
        match UnixStream::connect(&path) {
            Err(e) if e.kind() == std::io::ErrorKind::ConnectionRefused => fs::remove_file(&path)?,
            _ => return err("Receiver already active"),
        }
    }
    let server = UnixListener::bind(&path)?;
    fs::set_permissions(&path, fs::Permissions::from_mode(0o600))?;
    let _guard = Paths(vec![path.clone()]);
    println!("{}", json!({"ready":path}));
    std::io::stdout().flush()?;
    server.set_nonblocking(true)?;
    while !cancelled() {
        let mut conn = match server.accept() {
            Ok((conn, _)) => conn,
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                std::thread::sleep(Duration::from_millis(20));
                continue;
            }
            Err(e) => return Err(e.into()),
        };
        conn.set_read_timeout(Some(Duration::from_secs(1)))?;
        conn.set_write_timeout(Some(Duration::from_secs(1)))?;
        let event = peer(&conn)
            .and_then(|_| receive(&mut conn, 8192))
            .and_then(|v| relay_normalize(&v));
        match event {
            Ok(event) => {
                println!("{}", json!({"event":event}));
                std::io::stdout().flush()?;
                let _ = send(&mut conn, &json!({"ok":true}));
            }
            Err(_) => {
                let _ = send(&mut conn, &json!({"ok":false}));
            }
        }
    }
    Ok(())
}
pub fn send_relay(path: &str, payload: &Value) -> Result<()> {
    if path.len() > 100 {
        return err("Invalid relay socket");
    };
    socket_owned(Path::new(path), true)?;
    let source = std::env::var("PERCH_REMOTE_NAME").unwrap_or("remote".into());
    if !valid(&source, r"^[A-Za-z0-9][A-Za-z0-9._-]{0,39}$") {
        return err("Invalid remote name");
    };
    let mut event = json!({});
    for k in ["id", "state", "title", "project", "agent", "eventKey"] {
        if let Some(v) = payload.get(k) {
            event[k] = v.clone();
        }
    }
    let message = json!({"source":source,"event":event});
    if string_json(&message).len() > 8192 {
        return err("Relay message too large");
    };
    let mut conn = UnixStream::connect(path)?;
    peer(&conn)?;
    conn.set_write_timeout(Some(Duration::from_millis(750)))?;
    conn.set_read_timeout(Some(Duration::from_millis(750)))?;
    send(&mut conn, &message)?;
    let _ = receive(&mut conn, 128)?;
    Ok(())
}
struct Reader {
    ws: tungstenite::WebSocket<UnixStream>,
    deadline: Instant,
    seq: u64,
    received: usize,
}
impl Reader {
    fn call(&mut self, method: &str, params: Value) -> Result<Value> {
        if !["initialize", "thread/loaded/list", "thread/read"].contains(&method) {
            return err("Unsupported observer operation");
        };
        self.seq += 1;
        let id = self.seq;
        self.ws.send(tungstenite::Message::Text(
            string_json(&json!({"id":id,"method":method,"params":params})).into(),
        ))?;
        for _ in 0..64 {
            let remaining = self
                .deadline
                .checked_duration_since(Instant::now())
                .ok_or("Codex status snapshot timed out")?;
            self.ws.get_mut().set_read_timeout(Some(remaining))?;
            let raw = self.ws.read()?;
            let text = match raw {
                tungstenite::Message::Text(text) => text,
                tungstenite::Message::Ping(_) | tungstenite::Message::Pong(_) => continue,
                _ => return err("Invalid Codex response"),
            };
            self.received += text.len();
            if text.len() > 65536 || self.received > 1048576 {
                return err("Codex snapshot exceeded its receive limit");
            };
            let data: Value = serde_json::from_str(&text)?;
            if !data.is_object() {
                return err("Invalid Codex response");
            };
            if data.get("method").is_some() && data.get("id").is_some() {
                return err("This server requested an interactive client; continue in Codex");
            };
            if data["id"] != id {
                continue;
            }
            if data.get("error").is_some() {
                return err("Codex rejected a read-only status request");
            };
            if !data["result"].is_object() {
                return err("Invalid Codex result");
            };
            return Ok(data["result"].clone());
        }
        err("Too many unrelated Codex messages")
    }
}
pub fn codex_record(t: &Value, handler: &str) -> Option<Value> {
    let id = s(t, "id");
    if !valid(id, agents::THREAD) || !t["parentThreadId"].is_null() {
        return None;
    };
    let status = &t["status"];
    let kind = s(status, "type");
    let flags = status["activeFlags"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    if !["active", "idle", "systemError"].contains(&kind) {
        return None;
    };
    let waiting = kind == "active"
        && (flags.contains(&json!("waitingOnApproval"))
            || flags.contains(&json!("waitingOnUserInput")));
    let state = if waiting {
        "waiting"
    } else {
        match kind {
            "active" => "running",
            "systemError" => "error",
            _ => "idle",
        }
    };
    let cwd = s(t, "cwd");
    let project = if cwd.starts_with('/') && cwd.len() <= 4096 {
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
    let mut row = json!({"id":format!("codex.{}",&hash(id)[..20]),"kind":"agent","agent":"Codex","title":if project.is_empty(){"Codex"}else{&project},"project":project,"state":state,"detail":match state{"waiting"=>"Needs your attention in Codex","running"=>"Working in Codex","error"=>"Codex server reported an error",_=>"Idle in Codex"},"attention":if waiting&&flags.contains(&json!("waitingOnApproval")){"approval"}else if waiting{"question"}else{"attention"},"ttl":30,"serverSource":true});
    if !handler.is_empty() {
        row["targetCodex"] = json!({"thread":id.to_lowercase(),"handler":handler});
    }
    Some(row)
}
pub fn codex(p: &Value) -> Result<Value> {
    let path = s(p, "path");
    if !path.starts_with('/') || path.len() > 1024 || path.chars().any(char::is_control) {
        return err("Choose an absolute local Codex control socket path");
    };
    if fs::symlink_metadata(path)?.uid() != uid() {
        return err("Codex status requires a private socket owned by your user");
    };
    let path = fs::canonicalize(path)?;
    if path.as_os_str().len() > 107 {
        return err("The resolved Codex socket path is too long");
    };
    socket_owned(&path, true)?;
    let peer_socket = UnixStream::connect(&path)?;
    peer(&peer_socket)?;
    peer_socket.set_read_timeout(Some(Duration::from_secs(1)))?;
    peer_socket.set_write_timeout(Some(Duration::from_secs(1)))?;
    let config = tungstenite::protocol::WebSocketConfig::default()
        .max_message_size(Some(65536))
        .max_frame_size(Some(65536));
    let (ws, _) =
        tungstenite::client::client_with_config("ws://localhost/", peer_socket, Some(config))
            .map_err(|_| {
                "Codex control socket is unavailable or incompatible; use an existing server"
            })?;
    let mut reader = Reader {
        ws,
        deadline: Instant::now() + Duration::from_secs(4),
        seq: 0,
        received: 0,
    };
    reader.call("initialize",json!({"clientInfo":{"name":"perch-status-observer","version":"1.0"},"capabilities":{"experimentalApi":false,"requestAttestation":false}}))?;
    reader.ws.send(tungstenite::Message::Text(
        string_json(&json!({"method":"initialized"})).into(),
    ))?;
    let loaded = reader.call("thread/loaded/list", json!({"limit":8}))?;
    let loaded = loaded["data"]
        .as_array()
        .filter(|v| v.len() <= 8)
        .ok_or("Invalid loaded thread list")?;
    let handler = agents::handler().unwrap_or_default();
    let mut rows = Vec::new();
    for id in loaded {
        let Some(id) = id.as_str().filter(|id| valid(id, agents::THREAD)) else {
            continue;
        };
        let data = reader.call("thread/read", json!({"threadId":id,"includeTurns":false}))?;
        if s(&data["thread"], "id") != id {
            return err("Codex returned a different thread");
        };
        if let Some(row) = codex_record(&data["thread"], &handler) {
            rows.push(row)
        }
    }
    Ok(json!({"sessions":rows}))
}
