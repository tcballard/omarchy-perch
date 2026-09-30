#!/usr/bin/env python3
import json,os,shlex,sys,tempfile
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from perchlib import integrations as I
with tempfile.TemporaryDirectory() as d:
    home=Path(d);claude=home/'.claude';claude.mkdir();codex=home/'.codex';codex.mkdir()
    adapter=home/'.local/share/omarchy-perch';adapter.mkdir(parents=True)
    status=shlex.join(['python3',str(adapter/'perch-agent-hook'),'--perch-hook-v1','claude'])
    request=shlex.join(['python3',str(adapter/'perch-request-hook')])
    config={'hooks':{e:[{'matcher':'*','hooks':[{'type':'command','command':status}]}] for e in ('UserPromptSubmit','PostToolUse','Notification','Stop','SessionEnd')}}
    config['hooks']['PermissionRequest']=[{'matcher':'*','hooks':[{'type':'command','command':request}]}]
    config['hooks']['PreToolUse']=[{'matcher':'AskUserQuestion','hooks':[{'type':'command','command':request}]}]
    config['statusLine']={'type':'command','command':shlex.join(['python3',str(adapter/'perch-usage-statusline')])}
    def check():
        (claude/'settings.json').write_text(json.dumps(config))
        with patch.object(Path,'home',return_value=home),patch.dict(os.environ,{'CLAUDE_CONFIG_DIR':str(claude),'CODEX_HOME':str(codex)}),patch.object(I,'enabled_plugins',return_value=[]),patch.object(I,'job_state',return_value={}),patch.object(I,'backlight_state',return_value='missing'):
            return I.health()['health']
    health=check();assert all(health[k]=='enabled' and k in health['updates'] for k in ('claude','requests','usage'))
    for name in ('perch-agent-hook','perch-request-hook','perch-usage-statusline'):(adapter/name).write_bytes((I.ROOT/'scripts'/name).read_bytes())
    assert check()['updates']==[]
    config['disableAllHooks']=True
    assert check()['requests']=='hooks disabled' and check()['claude']=='hooks disabled'
    del config['disableAllHooks'];del config['hooks']['PreToolUse']
    assert check()['requests']=='incomplete'
    config['hooks']={'Stop':[{'hooks':[{'command':'echo '+status}]}]}
    config['statusLine']={'type':'command','command':'echo perch-usage-statusline'}
    assert check()['claude']=='disabled' and check()['usage']=='custom status line'
print('Integration health checks exact ownership, complete hook sets, disabled hooks and installed adapter versions.')

import subprocess
with tempfile.TemporaryDirectory() as d:
    home=Path(d)
    env={**os.environ,'HOME':d,'CODEX_HOME':d+'/.codex','CLAUDE_CONFIG_DIR':d+'/.claude','KIMI_CODE_HOME':d+'/.kimi-code','GROK_HOME':d+'/.grok'}
    for agent in ('qwen','qoder','factory','codebuddy','kimi','grok','codex-hooks'):
        args=[sys.executable,str(I.ROOT/'scripts/perch-agent-setup'),agent,'--apply']
        completed=subprocess.run(args,env=env,capture_output=True,text=True)
        assert completed.returncode==0,(agent,completed.stderr)
        with patch.object(Path,'home',return_value=home),patch.dict(os.environ,env),patch.object(I,'enabled_plugins',return_value=[]),patch.object(I,'job_state',return_value={}),patch.object(I,'backlight_state',return_value='missing'):
            assert I.health()['health'][agent]=='enabled',agent
        assert subprocess.run(args+['--remove'],env=env,capture_output=True).returncode==0
    (home/'.codex/config.toml').write_text('[features]\nhooks = false\n')
    r=subprocess.run([sys.executable,str(I.ROOT/'scripts/perch-agent-setup'),'codex-hooks','--apply'],env=env,capture_output=True)
    assert r.returncode!=0
print('All new adapters install into isolated homes, report exact health and remove; disabled Codex hooks stay disabled.')
