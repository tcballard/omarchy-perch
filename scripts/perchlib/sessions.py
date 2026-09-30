import json
import os
import stat
import re
import shutil
from pathlib import Path

from .process import run, launch

ADDRESS = re.compile(r'^0x[0-9a-fA-F]{1,16}$')


def process_start(pid):
    raw = Path(f'/proc/{pid}/stat').read_text()
    return raw[raw.rfind(')') + 2:].split()[19]


def select_tmux(target):
    if not isinstance(target, dict):
        raise ValueError('Invalid tmux target')
    path, pane, client = (target.get(k, '') for k in ('socket', 'pane', 'client'))
    if (not isinstance(path, str) or not path.startswith('/') or len(path) > 4096
            or not isinstance(pane, str) or not re.fullmatch(r'%[0-9]+', pane)
            or not isinstance(client, str) or not re.fullmatch(r'/dev/[A-Za-z0-9/_-]+', client)):
        raise ValueError('Invalid tmux target')
    info = os.lstat(path)
    if not stat.S_ISSOCK(info.st_mode) or info.st_uid != os.getuid() or not shutil.which('tmux'):
        raise ValueError('That tmux server is unavailable')
    for prefix in ('pane', 'client'):
        pid = target.get(prefix + 'Pid')
        if type(pid) is not int or pid <= 1 or process_start(pid) != target.get(prefix + 'Start'):
            raise ValueError('That tmux session has changed')
    argv = ['tmux', '-S', path]
    actual = run(argv + ['display-message', '-p', '-t', pane, '#{pane_pid}'], timeout=.75, limit=4096).strip()
    attached = run(argv + ['list-clients', '-F', '#{client_pid} #{client_tty}'], timeout=.75, limit=65536).splitlines()
    if actual != str(target['panePid']) or f"{target['clientPid']} {client}" not in attached:
        raise ValueError('That tmux pane or terminal is no longer available')
    run(argv + ['switch-client', '-c', client, '-t', pane], timeout=1, limit=4096)


def select_wezterm(target, pid):
    if not isinstance(target,dict):raise ValueError('Invalid WezTerm target')
    path,pane=target.get('socket'),target.get('pane')
    if not isinstance(path,str) or not path.startswith('/') or len(path)>1024 or type(pane) is not int or not 0<=pane<10**12:
        raise ValueError('Invalid WezTerm target')
    info=os.lstat(path)
    if (not stat.S_ISSOCK(info.st_mode) or info.st_uid!=os.getuid()
            or str(info.st_dev)!=target.get('device') or str(info.st_ino)!=target.get('inode')
            or process_start(pid)!=target.get('windowStart')):
        raise ValueError('That WezTerm instance has changed')
    if not shutil.which('wezterm'):raise ValueError('WezTerm is unavailable')
    # env receives a validated name/value argument; no shell is involved.
    argv=['env','WEZTERM_UNIX_SOCKET='+path,'wezterm','cli']
    rows=json.loads(run(argv+['list','--format','json'],timeout=.75,limit=262144))
    if not isinstance(rows,list) or not any(isinstance(p,dict) and p.get('pane_id')==pane for p in rows):
        raise ValueError('That WezTerm pane is no longer open')
    run(argv+['activate-pane','--pane-id',str(pane)],timeout=1,limit=4096)


IDE_COMMANDS = {'code','code-insiders','cursor','windsurf','trae','zed','idea','webstorm',
    'pycharm','goland','clion','rubymine','phpstorm','rider','rustrover'}


def open_workspace(target):
    if not isinstance(target,dict):raise ValueError('Invalid workspace target')
    app,path,pid=target.get('app'),target.get('path'),target.get('pid')
    if (app not in IDE_COMMANDS or not isinstance(path,str) or not path.startswith('/')
            or len(path)>1024 or any(ord(c)<32 for c in path) or type(pid) is not int or pid<=1):
        raise ValueError('Invalid workspace target')
    if target.get('boot')!=Path('/proc/sys/kernel/random/boot_id').read_text().strip() or process_start(pid)!=target.get('start'):
        raise ValueError('That editor process has changed')
    actual=Path(os.readlink(f'/proc/{pid}/exe')).name.lower()
    if actual!=app and not (app=='zed' and actual=='zed-editor'):
        raise ValueError('That editor is no longer running')
    if not Path(path).is_dir():raise ValueError('That workspace folder is no longer available')
    launch([app,path])
    return {'message':'Opened session workspace'}


def handle(op, payload):
    if op == 'agent-discover':
        from .discovery import discover
        return discover()
    if op != 'agent-jump':
        raise ValueError('Unsupported session operation')
    if payload.get('targetWorkspace'):
        return open_workspace(payload['targetWorkspace'])
    address = payload.get('address', '')
    if not isinstance(address, str) or not ADDRESS.fullmatch(address):
        raise ValueError('That session has no valid Hyprland window target')
    if not shutil.which('hyprctl'):
        raise ValueError('hyprctl is unavailable; the session was not focused')
    clients = json.loads(run(['hyprctl', '-j', 'clients'], timeout=.75, limit=262144))
    if not isinstance(clients, list) or not any(
        isinstance(client, dict) and client.get('address') == address for client in clients
    ):
        raise ValueError('That session window is no longer open')
    if payload.get('targetPid') or payload.get('targetBoot'):
        boot = Path('/proc/sys/kernel/random/boot_id').read_text().strip()
        if payload.get('targetBoot') != boot or not any(
            isinstance(c, dict) and c.get('address') == address
            and c.get('pid') == payload.get('targetPid') for c in clients
        ):
            raise ValueError('That session target has changed; open it from your terminal')
    if payload.get('targetWezterm'):
        if not payload.get('targetPid') or not payload.get('targetBoot'):
            raise ValueError('Missing WezTerm window identity')
        select_wezterm(payload['targetWezterm'],payload['targetPid'])
    if payload.get('targetTmux'):
        if not payload.get('targetPid') or not payload.get('targetBoot'):
            raise ValueError('Missing tmux window identity')
        select_tmux(payload['targetTmux'])
    reply = run(['hyprctl', 'dispatch', 'focuswindow', 'address:' + address], timeout=1, limit=4096)
    if reply.strip() != 'ok':
        raise ValueError('Hyprland could not focus that session window')
    return {'message': 'Returned to session'}
