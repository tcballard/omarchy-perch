import json
import os
import stat
import re
import shutil
from pathlib import Path

from .process import run, launch

ADDRESS = re.compile(r'^0x[0-9a-fA-F]{1,16}$')
THREAD = re.compile(r'^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
DESKTOP = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,240}\.desktop$')


def codex_handler():
    value=run(['xdg-mime','query','default','x-scheme-handler/codex'],timeout=.5,limit=4096).strip()
    return value if DESKTOP.fullmatch(value) else ''


def open_codex(target):
    if not isinstance(target,dict) or not isinstance(target.get('thread'),str) or not THREAD.fullmatch(target['thread']):
        raise ValueError('Invalid local Codex thread')
    handler=target.get('handler')
    if not isinstance(handler,str) or not DESKTOP.fullmatch(handler) or handler!=codex_handler():
        raise ValueError('The Codex desktop handler changed or is unavailable; refresh this session')
    launch(['xdg-open','codex://threads/'+target['thread'].lower()])
    return {'message':'Requested this local thread in the Codex desktop app'}


def process_start(pid):
    raw = Path(f'/proc/{pid}/stat').read_text()
    return raw[raw.rfind(')') + 2:].split()[19]


def select_zellij(target):
    if not isinstance(target,dict):raise ValueError('Invalid Zellij target')
    session,pane,path,binary,pid=(target.get(k) for k in ('session','pane','socket','binary','serverPid'))
    if (not isinstance(session,str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,79}',session)
            or type(pane) is not int or not 0<=pane<2**32 or type(pid) is not int or pid<=1
            or not isinstance(path,str) or not path.startswith('/') or len(path)>1024
            or Path(path).name!=session or len(Path(path).parents)<2
            or not isinstance(binary,str) or not binary.startswith('/') or len(binary)>1024 or Path(binary).name!='zellij'):
        raise ValueError('Invalid Zellij target')
    if target.get('boot')!=Path('/proc/sys/kernel/random/boot_id').read_text().strip() or process_start(pid)!=target.get('serverStart'):
        raise ValueError('That Zellij server has changed')
    info=os.lstat(path);exe=Path(f'/proc/{pid}/exe').stat();disk=Path(binary).stat()
    command=shutil.which('zellij')
    if (not stat.S_ISSOCK(info.st_mode) or info.st_uid!=os.getuid()
            or not command or str(Path(command).resolve())!=binary
            or str(info.st_dev)!=target.get('device') or str(info.st_ino)!=target.get('inode')
            or os.readlink(f'/proc/{pid}/exe')!=binary
            or (exe.st_dev,exe.st_ino)!=(disk.st_dev,disk.st_ino)
            or str(exe.st_dev)!=target.get('binaryDevice') or str(exe.st_ino)!=target.get('binaryInode')):
        raise ValueError('That Zellij socket or executable has changed')
    with open(f'/proc/{pid}/cmdline','rb') as stream:args=stream.read(4096).decode().split('\0')
    if '--server' not in args or args[args.index('--server')+1:args.index('--server')+2]!=[path]:
        raise ValueError('That Zellij server no longer owns the session')
    # The matching server binary appends its protocol directory to this root.
    argv=['env','ZELLIJ_SOCKET_DIR='+str(Path(path).parent.parent),'zellij','--session',session,'action']
    clients=run(argv+['list-clients'],timeout=.5,limit=65536).strip().splitlines()
    if (len(clients)!=2 or clients[0].split()[:2]!=['CLIENT_ID','ZELLIJ_PANE_ID']
            or not re.match(r'^\s*[0-9]+\s+(?:terminal|plugin)_[0-9]+(?:\s|$)',clients[1])):
        raise ValueError('Select the session in Zellij: exactly one attached client is required')
    panes=json.loads(run(argv+['list-panes','--json'],timeout=.5,limit=262144))
    if not isinstance(panes,list) or not any(isinstance(p,dict) and type(p.get('id')) is int and p['id']==pane and p.get('is_plugin') is False and p.get('exited') is not True for p in panes):
        raise ValueError('That Zellij pane is no longer open')
    run(argv+['focus-pane-id','terminal_'+str(pane)],timeout=1,limit=4096)
    return {'message':'Selected the pane in the attached Zellij client'}


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


def liveness(records):
    if not isinstance(records,list) or len(records)>8:raise ValueError('Invalid session records')
    boot=Path('/proc/sys/kernel/random/boot_id').read_text().strip()
    ended=[]
    for row in records:
        if not isinstance(row,dict):raise ValueError('Invalid session record')
        ident,pid=row.get('id'),row.get('pid')
        if not isinstance(ident,str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,63}',ident) or type(pid) is not int or pid<=1:
            raise ValueError('Invalid session process')
        try:
            if row.get('boot')!=boot or process_start(pid)!=row.get('start'):ended.append(ident)
        except (FileNotFoundError,ProcessLookupError):ended.append(ident)
        except (PermissionError,IndexError,ValueError):pass # Unknown is not proof of exit.
    return {'ended':ended,'checked':records}


def handle(op, payload):
    if op == 'agent-zellij-select':return select_zellij(payload.get('targetZellij'))
    if op == 'agent-codex-open':return open_codex(payload.get('targetCodex'))
    if op == 'agent-liveness':return liveness(payload.get('sessions'))
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
        pid=payload.get('targetPid')
        if (type(pid) is not int or pid<=1 or payload.get('targetBoot') != boot
                or not re.fullmatch(r'[0-9]{1,24}',str(payload.get('targetStart','')))
                or process_start(pid)!=payload['targetStart'] or not any(
            isinstance(c, dict) and c.get('address') == address
            and c.get('pid') == pid for c in clients
        )):
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
