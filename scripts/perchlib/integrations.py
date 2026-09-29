import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import tomllib
from .storage import Store,read_file
from .process import run
ROOT=Path(__file__).resolve().parents[2]
COMPANION_FILES={'notifications':['manifest.json','Service.qml','CommandJob.qml','store.py','NotificationStore.qml'],'osd':['manifest.json','Panel.qml','CommandJob.qml']}

def companion_state(kind):
    """'absent', 'current' or 'outdated': the installed copy versus this checkout."""
    target=Path.home()/'.config/omarchy/plugins'/('io.github.tcballard.perch-'+kind)
    if not target.is_dir():return 'absent'
    try:
        for name in COMPANION_FILES[kind]:
            if hashlib.sha256((target/name).read_bytes()).digest()!=hashlib.sha256((ROOT/'companions'/kind/name).read_bytes()).digest():return 'outdated'
    except OSError:return 'outdated'
    return 'current'

def enabled_plugins():
    try:
        data=json.loads(read_file(Path.home()/'.config/omarchy/shell.json',1048576))
        entries=data.get('plugins',[])+sum((data.get('bar',{}).get('layout',{}).get(k,[]) for k in ('left','center','right')),[])
        return [e if isinstance(e,str) else e.get('id') for e in entries]
    except (OSError,ValueError,AttributeError):return []

def health():
    ids=enabled_plugins();adapter=str(Path.home()/'.local/share/omarchy-perch/perch-agent-hook')
    result={'notifications':'enabled' if 'io.github.tcballard.perch-notifications' in ids else 'disabled', 'osd':'enabled' if 'io.github.tcballard.perch-osd' in ids else 'disabled'}
    # After a core update the separate companion copies lag until Update is used.
    result['updates']=[kind for kind in ('notifications','osd') if result[kind]=='enabled' and companion_state(kind)=='outdated']
    for agent,directory,filename in [('claude',os.environ.get('CLAUDE_CONFIG_DIR',str(Path.home()/'.claude')),'settings.json'),('codex',os.environ.get('CODEX_HOME',str(Path.home()/'.codex')),'config.toml')]:
        try:
            raw=read_file(Path(directory)/filename,1048576).decode()
            data=json.loads(raw) if agent=='claude' else tomllib.loads(raw)
            if agent=='codex':result[agent]='enabled' if data.get('notify')==['python3',adapter,'--perch-hook-v1','codex'] else 'existing notifier' if 'notify' in data else 'disabled'
            else:result[agent]='hooks disabled' if data.get('disableAllHooks') else 'enabled' if adapter in json.dumps(data.get('hooks',{})) and '--perch-hook-v1' in json.dumps(data.get('hooks',{})) else 'disabled'
        except FileNotFoundError:result[agent]='not configured'
        except (ValueError,OSError):result[agent]='configuration unreadable'
    result['brightness']='available' if shutil.which('brightnessctl') else 'brightnessctl missing'
    result['sharing']='available' if (shutil.which('localsend') or shutil.which('localsend_app')) else 'LocalSend missing'
    result['alarm']='available' if shutil.which('canberra-gtk-play') else 'sound helper missing'
    state=Store('integrations').load({})
    if state.get('status')=='working' and time.time()-state.get('started',0)>480:state={**state,'status':'failed','message':'Setup was interrupted. Refresh and retry.'}
    result['job']=state
    return {'health':result}

def worker(p):
    store=Store('integrations');names=['claude','codex','osd','notifications'] if p.get('all') else [p['name']]
    enabled=p.get('enabled',False);failures=[]
    for name in names:
        if name in ('claude','codex'):argv=['/usr/bin/python3','-I',str(ROOT/'scripts/perch-agent-setup'),name,'--apply']
        else:argv=['/usr/bin/python3','-I',str(ROOT/'scripts/perch-notifications-setup'),'--kind',name,'--apply']
        if not enabled:argv.append('--remove')
        try:run(argv,timeout=90,limit=16384,detail=True)
        except (OSError,ValueError,subprocess.SubprocessError) as error:failures.append(name+': '+str(error)[:200])
    if failures:
        # Each step is atomic and preserves existing configuration; report which one stopped.
        status={'status':'failed','message':'Setup did not complete. '+'; '.join(failures)[:400]+'. Nothing else was changed; fix this and retry.','started':time.time()}
    elif enabled and any(name in ('osd','notifications') for name in names):
        status={'status':'done','message':'Companion files updated and enabled. Run "omarchy restart shell" to load the new copy; restart agent clients after hook changes.','started':time.time()}
    else:
        status={'status':'done','message':'Integrations updated. Restart agent clients after hook changes.','started':time.time()}
    with store.lock():store.save(status)
    return status

def start(p):
    if not p.get('all') and p.get('name') not in ('notifications','osd','claude','codex'):raise ValueError('Unknown integration')
    if not isinstance(p.get('enabled',False),bool):raise ValueError('Invalid integration setting')
    store=Store('integrations')
    with store.lock():
        current=store.load({})
        if current.get('status')=='working' and time.time()-current.get('started',0)<480:raise ValueError('Setup already running')
        store.save({'status':'working','message':'Updating integrations…','started':time.time()})
        # Deliberately detached: companion discovery reloads the hosting shell.
        subprocess.Popen(['/usr/bin/python3','-I',str(ROOT/'scripts/perch-tools'),'integration-worker',json.dumps(p)],stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
    return {**health(),'message':'Setup started. Perch may briefly reload; reopen Setup to see the result.'}

def brightness(p=None):
    if not shutil.which('brightnessctl'):raise ValueError('brightnessctl is not installed')
    if p is not None:
        v=p.get('value')
        if not isinstance(v,(int,float)) or not 1<=v<=100:raise ValueError('Brightness must be 1–100%')
        run(['brightnessctl','set',str(round(v))+'%'],timeout=3)
    output=run(['brightnessctl','-m'],timeout=3,limit=4096)
    row=output.strip().split(',')
    if len(row)<5 or not row[3].endswith('%'):raise ValueError('No supported brightness device')
    return {'brightness':int(row[3][:-1])}


def alarm(p):
    missing=[]
    if p.get('sound'):
        if shutil.which('canberra-gtk-play'):run(['canberra-gtk-play','-i','complete'],timeout=4,limit=1024)
        else:missing.append('Timer sound unavailable: install canberra-gtk-play')
    if p.get('notify'):
        if shutil.which('notify-send'):run(['notify-send','--app-name=Perch','--',str(p.get('label','Timer'))[:80]+' finished','Your timer has completed.'],timeout=3,limit=1024)
        else:missing.append('Desktop notification helper unavailable')
    return {'message':'; '.join(missing)}
