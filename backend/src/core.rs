use serde_json::{json, Value};
use std::{
    env,
    fs::{self, File, OpenOptions},
    io::{Read, Write},
    os::unix::{
        fs::{MetadataExt, OpenOptionsExt, PermissionsExt},
        process::CommandExt,
    },
    path::{Path, PathBuf},
    process::{Command, Stdio},
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};
pub type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
pub fn err<T>(message: &str) -> Result<T> {
    Err(message.into())
}
pub fn now() -> f64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs_f64()
}
pub fn uid() -> u32 {
    unsafe { libc::getuid() }
}
pub fn home() -> PathBuf {
    PathBuf::from(env::var_os("HOME").unwrap_or_else(|| "/".into()))
}
pub fn base(key: &str, default: PathBuf) -> PathBuf {
    env::var_os(key).map(PathBuf::from).unwrap_or(default)
}
pub fn root() -> PathBuf {
    if let Some(root) = env::var_os("PERCH_ROOT") {
        return root.into();
    }
    if let Ok(exe) = env::current_exe() {
        for parent in exe.ancestors().skip(1) {
            if parent.join("manifest.json").is_file() && parent.join("scripts").is_dir() {
                return parent.into();
            }
        }
    }
    PathBuf::from(".")
}
pub fn s<'a>(p: &'a Value, k: &str) -> &'a str {
    p[k].as_str().unwrap_or("")
}
pub fn cut(text: &str, n: usize) -> String {
    text.chars().take(n).collect()
}
pub fn clean(text: &str, n: usize) -> String {
    cut(
        &text
            .chars()
            .map(|c| if c.is_control() { ' ' } else { c })
            .collect::<String>(),
        n,
    )
}
pub fn valid(text: &str, pattern: &str) -> bool {
    static PATTERNS: std::sync::OnceLock<
        std::sync::Mutex<std::collections::HashMap<String, regex::Regex>>,
    > = std::sync::OnceLock::new();
    let mut cache = PATTERNS.get_or_init(Default::default).lock().unwrap();
    cache
        .entry(pattern.into())
        .or_insert_with(|| regex::Regex::new(pattern).unwrap())
        .is_match(text)
}
pub fn hash(text: &str) -> String {
    use sha2::{Digest, Sha256};
    format!("{:x}", Sha256::digest(text.as_bytes()))
}
pub fn which(name: &str) -> Option<PathBuf> {
    if name.contains('/') {
        return Path::new(name).is_file().then(|| name.into());
    }
    env::var_os("PATH").and_then(|p| {
        env::split_paths(&p)
            .map(|d| d.join(name))
            .find(|p| p.is_file())
    })
}
pub fn read(path: &Path, limit: usize, follow: bool) -> Result<Vec<u8>> {
    let mut f = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NONBLOCK | if follow { 0 } else { libc::O_NOFOLLOW })
        .open(path)?;
    let m = f.metadata()?;
    if !m.is_file() || m.len() > limit as u64 {
        return err("File is not regular or exceeds the size limit");
    };
    let mut data = Vec::new();
    std::io::Read::by_ref(&mut f)
        .take(limit as u64 + 1)
        .read_to_end(&mut data)?;
    if data.len() > limit {
        return err("File grew beyond the size limit");
    };
    Ok(data)
}
pub fn head(path: &Path, limit: usize) -> Result<Vec<u8>> {
    let f = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK)
        .open(path)?;
    if !f.metadata()?.is_file() {
        return err("Only regular files can be previewed");
    };
    let mut data = Vec::new();
    f.take(limit as u64).read_to_end(&mut data)?;
    Ok(data)
}
pub fn private_dir(path: &Path) -> Result<()> {
    if !path.exists() {
        fs::create_dir_all(path)?;
        fs::set_permissions(path, fs::Permissions::from_mode(0o700))?
    }
    let m = fs::symlink_metadata(path)?;
    if !m.is_dir() || m.uid() != uid() || m.mode() & 0o777 != 0o700 {
        return err("Unsafe private directory");
    };
    Ok(())
}
pub fn atomic(path: &Path, data: &[u8], mode: u32) -> Result<()> {
    fs::create_dir_all(path.parent().ok_or("Invalid destination")?)?;
    let mut tmp = tempfile::NamedTempFile::new_in(path.parent().unwrap())?;
    tmp.as_file()
        .set_permissions(fs::Permissions::from_mode(mode))?;
    tmp.write_all(data)?;
    tmp.as_file().sync_all()?;
    tmp.persist(path)?;
    File::open(path.parent().unwrap())?.sync_all()?;
    Ok(())
}
pub struct Store {
    pub path: PathBuf,
    _lock: File,
}
impl Store {
    pub fn new(name: &str) -> Result<Self> {
        if ![
            "shelf",
            "calendar",
            "notifications",
            "integrations",
            "usage-claude",
        ]
        .contains(&name)
        {
            return err("Unknown state store");
        };
        let root = base("XDG_STATE_HOME", home().join(".local/state")).join("omarchy-perch");
        if !root.exists() {
            fs::create_dir_all(&root)?;
            fs::set_permissions(&root, fs::Permissions::from_mode(0o700))?
        }
        let m = fs::symlink_metadata(&root)?;
        if !m.is_dir() || m.uid() != uid() {
            return err("Unsafe state directory");
        };
        fs::set_permissions(&root, fs::Permissions::from_mode(0o700))?;
        let lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .mode(0o600)
            .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK)
            .open(root.join(".lock"))?;
        let info = lock.metadata()?;
        if !info.is_file() || info.uid() != uid() || info.mode() & 0o777 != 0o600 {
            return err("Unsafe state lock");
        }
        if unsafe { libc::flock(std::os::fd::AsRawFd::as_raw_fd(&lock), libc::LOCK_EX) } != 0 {
            return Err(std::io::Error::last_os_error().into());
        };
        Ok(Self {
            path: root.join(format!("{name}.json")),
            _lock: lock,
        })
    }
    pub fn load(&self, default: Value) -> Result<Value> {
        match read(&self.path, 262144, false) {
            Ok(b) => Ok(serde_json::from_slice(&b)?),
            Err(e) if !self.path.exists() && !self.path.is_symlink() => {
                let _ = e;
                Ok(default)
            }
            Err(e) => Err(e),
        }
    }
    pub fn save(&self, v: &Value) -> Result<()> {
        let data = serde_json::to_vec(v)?;
        if data.len() > 262144 {
            return err("State exceeds size limit");
        };
        atomic(&self.path, &data, 0o600)
    }
}
static CANCELLED: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);
extern "C" fn terminate(_sig: i32) {
    CANCELLED.store(true, std::sync::atomic::Ordering::Relaxed);
}
pub fn cancelled() -> bool {
    CANCELLED.load(std::sync::atomic::Ordering::Relaxed)
}
pub fn signals() {
    unsafe {
        libc::signal(libc::SIGTERM, terminate as usize);
        libc::signal(libc::SIGINT, terminate as usize);
    }
}
struct ChildGuard(std::process::Child);
impl Drop for ChildGuard {
    fn drop(&mut self) {
        unsafe {
            libc::kill(-(self.0.id() as i32), libc::SIGKILL);
        }
        let _ = self.0.wait();
    }
}
pub fn run(args: &[&str], timeout: f64, limit: usize) -> Result<String> {
    Ok(String::from_utf8_lossy(&run_bytes(args, timeout, limit, None)?).into())
}
pub fn run_bytes(
    args: &[&str],
    timeout: f64,
    limit: usize,
    input: Option<&[u8]>,
) -> Result<Vec<u8>> {
    if args.is_empty() {
        return err("Missing command");
    };
    let source = if let Some(data) = input {
        let mut f = tempfile::tempfile()?;
        f.write_all(data)?;
        use std::io::Seek;
        f.rewind()?;
        Some(f)
    } else {
        None
    };
    let mut cmd = Command::new(args[0]);
    cmd.args(&args[1..])
        .stdin(source.map(Stdio::from).unwrap_or_else(Stdio::null))
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .process_group(0);
    let mut child = ChildGuard(cmd.spawn()?);

    let mut pipes = [
        child.0.stdout.take().unwrap().into_raw(),
        child.0.stderr.take().unwrap().into_raw(),
    ];
    let mut outputs = [Vec::new(), Vec::new()];
    for fd in pipes {
        unsafe {
            libc::fcntl(fd, libc::F_SETFL, libc::O_NONBLOCK);
        }
    }
    let start = Instant::now();
    let result = (|| {
        while pipes.iter().any(|f| *f >= 0) {
            if start.elapsed().as_secs_f64() >= timeout || cancelled() {
                return err("Command timed out");
            };
            let mut poll = pipes.map(|fd| libc::pollfd {
                fd,
                events: libc::POLLIN,
                revents: 0,
            });
            unsafe { libc::poll(poll.as_mut_ptr(), 2, 20) };
            for i in 0..2 {
                if pipes[i] < 0 {
                    continue;
                }
                let mut b = [0u8; 8192];
                let n = unsafe { libc::read(pipes[i], b.as_mut_ptr().cast(), b.len()) };
                if n == 0 {
                    unsafe {
                        libc::close(pipes[i]);
                    }
                    pipes[i] = -1;
                } else if n > 0 {
                    outputs[i].extend_from_slice(&b[..n as usize]);
                    if outputs[i].len() > limit {
                        return err("Command output exceeds limit");
                    }
                }
            }
        }
        loop {
            if let Some(status) = child.0.try_wait()? {
                if !status.success() {
                    return err("Command failed; check the integration or installed dependency");
                };
                return Ok(std::mem::take(&mut outputs[0]));
            }
            if start.elapsed().as_secs_f64() >= timeout || cancelled() {
                return err("Command timed out");
            };
            std::thread::sleep(Duration::from_millis(10));
        }
    })();
    for fd in pipes {
        if fd >= 0 {
            unsafe {
                libc::close(fd);
            }
        }
    }
    result
}
trait Raw {
    fn into_raw(self) -> i32;
}
impl Raw for std::process::ChildStdout {
    fn into_raw(self) -> i32 {
        std::os::fd::IntoRawFd::into_raw_fd(self)
    }
}
impl Raw for std::process::ChildStderr {
    fn into_raw(self) -> i32 {
        std::os::fd::IntoRawFd::into_raw_fd(self)
    }
}
pub fn launch(args: &[&str]) -> Result<()> {
    if which(args[0]).is_none() {
        return err(&format!("{} is not installed; nothing was opened", args[0]));
    };
    let mut cmd = Command::new(args[0]);
    cmd.args(&args[1..])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    unsafe {
        cmd.pre_exec(|| {
            if libc::setsid() < 0 {
                return Err(std::io::Error::last_os_error());
            };
            Ok(())
        });
    }
    let mut child = cmd.spawn()?;
    std::thread::sleep(Duration::from_millis(50));
    if child.try_wait()?.is_some_and(|s| !s.success()) {
        return err("Application could not be opened");
    };
    Ok(())
}
pub fn stdin(limit: usize, _line: bool) -> Result<Vec<u8>> {
    let mut raw = Vec::new();
    std::io::stdin()
        .lock()
        .take(limit as u64 + 1)
        .read_to_end(&mut raw)?;
    if raw.len() > limit {
        return err("Input exceeds limit");
    };
    Ok(raw)
}
pub fn string_json(v: &Value) -> String {
    serde_json::to_string(v).unwrap()
}
pub fn ok_message(text: &str) -> Value {
    json!({"message":text})
}
