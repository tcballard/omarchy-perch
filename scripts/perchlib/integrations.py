import hashlib
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import time
import tomllib
from .storage import Store,read_file
from .process import run
from . import extensions
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
        data=json.loads(read_file(Path.home()/'.config/omarchy/shell.json',1048576,follow=True))
        entries=data.get('plugins',[])+sum((data.get('bar',{}).get('layout',{}).get(k,[]) for k in ('left','center','right')),[])
        return [e if isinstance(e,str) else e.get('id') for e in entries]
    except (OSError,ValueError,AttributeError):return []

def exact_hooks(config, event, command, matcher=None):
    hooks=config.get('hooks',{})
    groups=hooks.get(event,[]) if isinstance(hooks,dict) else []
    if not isinstance(groups,list):return False
    return any(isinstance(g,dict) and (matcher is None or g.get('matcher')==matcher)
        and isinstance(g.get('hooks'),list) and any(isinstance(h,dict) and
        h.get('type')=='command' and h.get('command')==command for h in g['hooks']) for g in groups)

def adapter_current(name):
    try:
        installed=read_file(Path.home()/'.local/share/omarchy-perch'/name,1048576)
        return installed==(ROOT/'scripts'/name).read_bytes()
    except (OSError,ValueError):return False

def health():
    ids=enabled_plugins();adapter=str(Path.home()/'.local/share/omarchy-perch/perch-agent-hook')
    result={'notifications':'enabled' if 'io.github.tcballard.perch-notifications' in ids else 'disabled', 'osd':'enabled' if 'io.github.tcballard.perch-osd' in ids else 'disabled'}
    result['updates']=[kind for kind in ('notifications','osd') if result[kind]=='enabled' and companion_state(kind)=='outdated']
    try:
        path=Path(os.environ.get('CODEX_HOME',str(Path.home()/'.codex')))/'config.toml'
        data=tomllib.loads(read_file(path,1048576).decode())
        result['codex']='enabled' if data.get('notify')==['python3',adapter,'--perch-hook-v1','codex'] else 'existing notifier' if 'notify' in data else 'disabled'
    except FileNotFoundError:result['codex']='not configured'
    except (ValueError,OSError):result['codex']='configuration unreadable'
    try:
        path=Path(os.environ.get('CLAUDE_CONFIG_DIR',str(Path.home()/'.claude')))/'settings.json'
        config=json.loads(read_file(path,1048576))
        if not isinstance(config,dict):raise ValueError('Invalid settings')
        command=shlex.join(['python3',adapter,'--perch-hook-v1','claude'])
        present=[exact_hooks(config,event,command) for event in ('UserPromptSubmit','PostToolUse','Notification','Stop','SessionEnd')]
        result['claude']='hooks disabled' if config.get('disableAllHooks') else 'enabled' if all(present) else 'incomplete' if any(present) else 'disabled'
        line=config.get('statusLine')
        owned={'type':'command','command':shlex.join(['python3',str(Path.home()/'.local/share/omarchy-perch/perch-usage-statusline')])}
        result['usage']='enabled' if line==owned else 'custom status line' if line else 'disabled'
        request_command=shlex.join(['python3',str(Path.home()/'.local/share/omarchy-perch/perch-request-hook')])
        requests=[exact_hooks(config,event,request_command,matcher) for event,matcher in [('PermissionRequest','*'),('PreToolUse','AskUserQuestion')]]
        result['requests']='hooks disabled' if config.get('disableAllHooks') else 'enabled' if all(requests) else 'incomplete' if any(requests) else 'disabled'
    except FileNotFoundError:
        for key in ('claude','usage','requests'):result[key]='not configured'
    except (OSError,ValueError,TypeError):
        for key in ('claude','usage','requests'):result[key]='configuration unreadable'
    for key,name in [('claude','perch-agent-hook'),('codex','perch-agent-hook'),('usage','perch-usage-statusline'),('requests','perch-request-hook')]:
        if result[key]=='enabled' and not adapter_current(name):result['updates'].append(key)
    for agent,filename,events in [(a,'settings.json',('UserPromptSubmit','PostToolUse','Notification','Stop','SessionEnd')) for a in ('qwen','qoder','factory','codebuddy')] + [('gemini','settings.json',('BeforeAgent','AfterTool','AfterAgent','Notification','SessionEnd')),('cursor','hooks.json',('beforeSubmitPrompt','postToolUse','stop','sessionEnd'))]:
        try:
            directory = Path.home()/('.'+agent)
            data=json.loads(read_file(directory/filename,1048576)) if (directory/filename).exists() else {}
            if not isinstance(data,dict):raise ValueError('Invalid settings')
            if agent == 'factory' and (directory/'hooks.json').exists():
                flags={k:data.get(k) for k in ('hooksDisabled','disableAllHooks','allowManagedHooksOnly')}
                data={**flags,'hooks':json.loads(read_file(directory/'hooks.json',1048576))}
            elif not (directory/filename).exists():raise FileNotFoundError()

            if not isinstance(data,dict):raise ValueError('Invalid settings')
            command=shlex.join(['python3',adapter,'--perch-hook-v1',agent])
            hooks=data.get('hooks',{})
            if not isinstance(hooks,dict):raise ValueError('Invalid hooks')
            if agent=='cursor':
                present=[isinstance(hooks.get(e),list) and any(isinstance(h,dict) and h.get('type','command')=='command' and h.get('command')==command for h in hooks[e]) for e in events]
            else:present=[exact_hooks(data,e,command) for e in events]
            disabled=data.get('disableAllHooks') or data.get('allowManagedHooksOnly') or data.get('hooksDisabled') or hooks.get('enabled') is False or agent=='gemini' and (isinstance(data.get('tools'),dict) and data['tools'].get('enableHooks') is False or isinstance(hooks.get('disabled'),list) and ('perch-status' in hooks['disabled'] or command in hooks['disabled']))
            result[agent]='hooks disabled' if disabled else 'enabled' if all(present) else 'incomplete' if any(present) else 'disabled'
            if result[agent]=='enabled' and not adapter_current('perch-agent-hook'):result['updates'].append(agent)
        except FileNotFoundError:result[agent]='not configured'
        except (OSError,ValueError,TypeError):result[agent]='configuration unreadable'
    try:
        path=Path(os.environ.get('KIMI_CODE_HOME',str(Path.home()/'.kimi-code')))/'config.toml'
        data=tomllib.loads(read_file(path,1048576).decode())
        entries=data.get('hooks',[])
        if not isinstance(entries,list):raise ValueError('Invalid Kimi hooks')
        command=shlex.join(['python3',adapter,'--perch-hook-v1','kimi'])
        present=[any(isinstance(h,dict) and h.get('event')==event and h.get('command')==command for h in entries) for event in ('TurnStarted','PostToolUse','PermissionRequest','PermissionResult','Stop','SessionEnd','Interrupt','StopFailure')]
        result['kimi']='enabled' if all(present) else 'incomplete' if any(present) else 'disabled'
        if result['kimi']=='enabled' and not adapter_current('perch-agent-hook'):result['updates'].append('kimi')
    except FileNotFoundError:result['kimi']='not configured'
    except (OSError,ValueError):result['kimi']='configuration unreadable'
    try:
        path=Path(os.environ.get('GROK_HOME',str(Path.home()/'.grok')))/'hooks/perch-status.json'
        data=json.loads(read_file(path,1048576))
        if not isinstance(data,dict):raise ValueError('Invalid Grok hooks')
        command=shlex.join(['python3',adapter,'--perch-hook-v1','grok'])
        present=[exact_hooks(data,event,command) for event in ('UserPromptSubmit','PostToolUse','Notification','Stop','SessionEnd','StopCancelled','StopFailure')]
        result['grok']='enabled' if all(present) else 'incomplete' if any(present) else 'disabled'
        if result['grok']=='enabled' and not adapter_current('perch-agent-hook'):result['updates'].append('grok')
    except FileNotFoundError:result['grok']='not configured'
    except (OSError,ValueError):result['grok']='configuration unreadable'
    for agent in extensions.AGENTS:
        try:result[agent]=extensions.health(agent)
        except (OSError,ValueError):result[agent]='configuration unreadable'
        if result[agent]=='outdated':
            result[agent]='enabled';result['updates'].append(agent)
        elif result[agent]=='enabled' and not adapter_current('perch-agent-hook'):result['updates'].append(agent)
    result['brightness']=backlight_state()
    result['sharing']='available' if (shutil.which('localsend') or shutil.which('localsend_app')) else 'LocalSend missing'
    result['alarm']='available' if shutil.which('canberra-gtk-play') else 'sound helper missing'
    state=job_state()
    if state.get('status')=='working' and time.time()-state['started']>900:state={**state,'status':'failed','message':'Setup was interrupted. Refresh and retry.'}
    result['job']=state
    return {'health':result}

def job_state(store=None):
    state=(store or Store('integrations')).load({})
    if not isinstance(state,dict):state={}
    started=state.get('started')
    return {**state,'started':started if isinstance(started,(int,float)) else 0}

def backlight_state():
    if not shutil.which('brightnessctl'):return 'brightnessctl missing'
    try:
        run(['brightnessctl','-c','backlight','-m'],timeout=3,limit=4096);return 'available'
    except (OSError,ValueError,subprocess.SubprocessError):return 'no backlight device'

def worker(p):
    store=Store('integrations');names=['claude','codex','gemini','cursor','qwen','qoder','factory','codebuddy','pi','omp','opencode','kimi','grok','usage','requests','osd','notifications'] if p.get('all') else [p['name']]
    enabled=p.get('enabled',False);failures=[]
    for name in names:
        if name in extensions.AGENTS:argv=['/usr/bin/python3','-I',str(ROOT/'scripts/perch-extension-setup'),name,'--apply']
        elif name=='requests':argv=['/usr/bin/python3','-I',str(ROOT/'scripts/perch-request-setup'),'--apply']
        elif name=='usage':argv=['/usr/bin/python3','-I',str(ROOT/'scripts/perch-usage-setup'),'--apply']
        elif name in ('claude','codex','gemini','cursor','qwen','qoder','factory','codebuddy','kimi','grok'):argv=['/usr/bin/python3','-I',str(ROOT/'scripts/perch-agent-setup'),name,'--apply']
        else:argv=['/usr/bin/python3','-I',str(ROOT/'scripts/perch-notifications-setup'),'--kind',name,'--apply']
        if not enabled:argv.append('--remove')
        try:run(argv,timeout=90,limit=16384,detail=True)
        except (OSError,ValueError,subprocess.SubprocessError) as error:failures.append(name+': '+str(error)[:200])
    if failures:
        # Each step is atomic and preserves existing configuration; report which one stopped.
        status={'status':'failed','message':'Setup did not complete. '+'; '.join(failures)[:400]+'. Other steps may have completed; review the integration states and retry.','started':time.time()}
    elif enabled and any(name in ('osd','notifications') for name in names):
        status={'status':'done','message':'Companion files updated and enabled. Run "omarchy restart shell" to load the new copy; restart agent clients after hook changes.','started':time.time()}
    else:
        status={'status':'done','message':'Integrations updated. Restart agent clients after hook changes.','started':time.time()}
    with store.lock():store.save(status)
    return status

def start(p):
    if not p.get('all') and p.get('name') not in ('notifications','osd','claude','codex','gemini','cursor','qwen','qoder','factory','codebuddy','pi','omp','opencode','kimi','grok','usage','requests'):raise ValueError('Unknown integration')
    if not isinstance(p.get('enabled',False),bool):raise ValueError('Invalid integration setting')
    store=Store('integrations')
    with store.lock():
        current=job_state(store)
        if current.get('status')=='working' and time.time()-current['started']<900:raise ValueError('Setup already running')
        # Deliberately detached: companion discovery reloads the hosting shell.
        subprocess.Popen(['/usr/bin/python3','-I',str(ROOT/'scripts/perch-tools'),'integration-worker',json.dumps(p)],stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
        store.save({'status':'working','message':'Updating integrations…','started':time.time()})
    return {**health(),'message':'Setup started. Perch may briefly reload; reopen Setup to see the result.'}

def brightness(p=None):
    if not shutil.which('brightnessctl'):raise ValueError('brightnessctl is not installed')
    if p is not None:
        v=p.get('value')
        if not isinstance(v,(int,float)) or not 1<=v<=100:raise ValueError('Brightness must be 1–100%')
        run(['brightnessctl','-c','backlight','set',str(round(v))+'%'],timeout=3)
    # Only real backlights: without the class filter brightnessctl falls back to keyboard LEDs.
    try:output=run(['brightnessctl','-c','backlight','-m'],timeout=3,limit=4096)
    except ValueError:raise ValueError('No backlight device found')
    row=output.strip().split(',')
    if len(row)<5 or not row[3].endswith('%'):raise ValueError('No supported brightness device')
    return {'brightness':int(row[3][:-1])}


def alarm(p):
    missing=[]
    preset=p.get('preset','complete')
    if preset not in ('complete','message-new-instant','bell'):raise ValueError('Unknown sound preset')
    if p.get('sound'):
        if shutil.which('canberra-gtk-play'):run(['canberra-gtk-play','-i',preset],timeout=4,limit=1024)
        else:missing.append('Sound unavailable: install canberra-gtk-play')
    if p.get('notify'):
        if shutil.which('notify-send'):run(['notify-send','--app-name=Perch','--',str(p.get('label','Timer'))[:80]+' finished','Your timer has completed.'],timeout=3,limit=1024)
        else:missing.append('Desktop notification helper unavailable')
    return {'message':'; '.join(missing)}
