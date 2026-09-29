"""Bounded data adapters for native QML modules; no capture daemon or widget runtime."""
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import stat
import struct
import signal
import subprocess
import tempfile
from urllib.parse import urlencode
from .process import run

HISTORY_LIMIT = 4 * 1024 * 1024

def read_regular(path, limit):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
            raise ValueError('Expected a regular file owned by you')
        if info.st_size > limit:
            raise ValueError('File exceeds the supported size; use the Omarchy clipboard')
        result = stream.read(limit + 1)
        if len(result) > limit:
            raise ValueError('File exceeds the supported size; use the Omarchy clipboard')
        return result

def history():
    path = Path.home() / '.local/state/omarchy/clipboard-history.json'
    if not path.exists():
        raise ValueError('Omarchy clipboard history is unavailable. Enable the built-in clipboard.')
    entries = json.loads(read_regular(path, HISTORY_LIMIT))
    if not isinstance(entries, list):
        raise ValueError('Unsupported clipboard history format')
    result = []
    for entry in entries[:500]:
        if isinstance(entry, str): entry = {'type': 'text', 'text': entry}
        if not isinstance(entry, dict): continue
        if entry.get('type') == 'text' and isinstance(entry.get('text'), str):
            text = entry['text']
            kind = 'file' if text.startswith('file://') else 'link' if text.startswith(('https://', 'http://')) else 'text'
            key = 'text:' + text
            preview = text[:160]
        elif entry.get('type') == 'image' and isinstance(entry.get('path'), str):
            kind = 'image'; key = 'image:' + entry['path']
            preview = 'Image · ' + str(entry.get('capturedAt', ''))[:120]
        else: continue
        result.append((hashlib.sha256(key.encode()).hexdigest(), kind, preview, entry))
    return result

def clipboard_list(payload):
    query = str(payload.get('query', ''))[:120].casefold()
    kind = payload.get('kind', 'all')
    entries = history()
    rows = [{'id': key, 'kind': typ, 'preview': preview} for key, typ, preview, _ in entries
            if (kind == 'all' or kind == typ) and query in str(_.get('text', preview))[:8192].casefold()][:50]
    by_id = {row[0]:row[3] for row in entries}
    for row in rows:
        if row['kind'] != 'image': continue
        try:
            path = Path(by_id[row['id']]['path'])
            fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
            with os.fdopen(fd, 'rb') as stream:
                info = os.fstat(stream.fileno())
                if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_size > 8 * 1024 * 1024: continue
                data = stream.read(24)
            if data[:8] == b'\x89PNG\r\n\x1a\n' and len(data) >= 24:
                width, height = struct.unpack('>II', data[16:24])
                if 0 < width <= 4096 and 0 < height <= 4096:
                    row['image'] = path.absolute().as_uri()
        except (OSError, ValueError, KeyError): pass
    return {'rows': rows, 'count': len(entries)}

def copy_bytes(mime, data):
    # wl-copy forks the selection owner after accepting stdin. A successful owner
    # must outlive this request; the normal command runner kills descendants.
    with tempfile.TemporaryFile() as source:
        source.write(data); source.seek(0)
        child = subprocess.Popen(['/usr/bin/wl-copy', '--type', mime], stdin=source,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                 start_new_session=True)
        try:
            code = child.wait(timeout=3)
        except subprocess.TimeoutExpired:
            try: os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            child.wait()
            raise ValueError('Clipboard copy timed out')
        if code != 0:
            raise ValueError('Clipboard copy failed; check the Wayland session')

def clipboard_copy(payload):
    # Resolve by content identity, not a shifting history index. No clipboard text
    # travels in argv, and we never rewrite Omarchy's shared history file.
    match = next((row for row in history() if row[0] == payload.get('id')), None)
    if match is None: raise ValueError('That entry is no longer in history. Refresh and try again.')
    entry = match[3]
    if match[1] == 'image':
        mime = entry.get('mime', 'image/png')
        if mime not in ('image/png', 'image/jpeg', 'image/webp'): raise ValueError('Unsupported image type')
        data = read_regular(Path(entry['path']), 8 * 1024 * 1024)
    else:
        mime = 'text/uri-list' if match[1] == 'file' else 'text/plain;charset=utf-8'
        data = entry['text'].encode()
    copy_bytes(mime, data)
    return {'message': 'Copied. Paste in your application.'}

def stats():
    with open('/proc/stat') as f: parts = f.readline(4096).split()
    if parts[0] != 'cpu' or len(parts) < 5: raise ValueError('CPU statistics unavailable')
    values = [int(x) for x in parts[1:9]]  # guest counters are already included
    with open('/proc/meminfo') as f: raw = f.read(32768)
    mem = {line.split(':')[0]: int(line.split()[1]) * 1024 for line in raw.splitlines() if ':' in line}
    total = mem.get('MemTotal', 0); available = mem.get('MemAvailable')
    if total <= 0 or available is None: raise ValueError('Memory statistics unavailable')
    disk = shutil.disk_usage('/')
    return {'sample': {'total': sum(values), 'idle': values[3] + (values[4] if len(values) > 4 else 0),
                       'memory': round(100 * (total - available) / total, 1),
                       'memoryUsed': total - available, 'memoryTotal': total,
                       'disk': round(100 * disk.used / disk.total, 1), 'diskFree': disk.free}}

def weather(payload):
    lat, lon = payload.get('latitude'), payload.get('longitude')
    if any(isinstance(n, bool) or not isinstance(n, (float, int)) or not math.isfinite(n) for n in (lat, lon)):
        raise ValueError('Set a latitude and longitude first')
    if not (-90 <= lat <= 90 and -180 <= lon <= 180): raise ValueError('Coordinates are out of range')
    query = urlencode({'latitude': lat, 'longitude': lon, 'current': 'temperature_2m,weather_code,wind_speed_10m',
                       'hourly': 'temperature_2m', 'forecast_hours': 6, 'timezone': 'auto'})
    # Fixed HTTPS endpoint; no redirects, credentials, location lookup or downloads to disk.
    raw = run(['/usr/bin/curl', '--disable', '--fail', '--silent', '--show-error', '--proto', '=https',
               '--max-time', '7', '--max-filesize', '65536', 'https://api.open-meteo.com/v1/forecast?' + query],
              timeout=8, limit=65536)
    obj = json.loads(raw); current = obj.get('current', {}); hourly = obj.get('hourly', {})
    def number(value):
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
            raise ValueError('Weather provider returned incomplete data')
        return value
    hours = [{'time': str(t)[:16], 'temperature': number(v)} for t, v in
             list(zip(hourly.get('time', []), hourly.get('temperature_2m', [])))[:6]]
    return {'weather': {'temperature': number(current.get('temperature_2m')), 'code': number(current.get('weather_code')),
                        'wind': number(current.get('wind_speed_10m')), 'hours': hours}}
