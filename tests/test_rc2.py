#!/usr/bin/env python3
"""rc2 setup ownership, config preservation, privacy and failure checks."""
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib

root = Path(__file__).resolve().parent.parent

def module(name):
    loader = importlib.machinery.SourceFileLoader(name.replace('-','_'), str(root/'scripts'/name))
    spec = importlib.util.spec_from_loader(loader.name,loader)
    value = importlib.util.module_from_spec(spec); loader.exec_module(value)
    return value

setup = module('perch-agent-setup')
hook = module('perch-agent-hook')
path = Path('/tmp/a space/$(touch nope)/perch-agent-hook')
original = '# comment\nmodel = "custom"\n[tui]\nnotifications = true\n'
configured = setup.transform('codex',original,path,False)
assert tomllib.loads(configured)['tui']['notifications'] is True
assert setup.transform('codex',configured,path,False) == configured
assert setup.transform('codex',configured,path,True) == original
for bad in ['notify = ["existing"]\n', configured.replace('--perch-hook-v1','changed')]:
    try: setup.transform('codex',bad,path,False); assert False
    except ValueError: pass
other = {'permissions':{'deny':['Read(.env)']},'hooks':{'Stop':[{'hooks':[{'type':'command','command':'existing','timeout':9}]}]}}
claude = setup.transform('claude',json.dumps(other),path,False)
assert setup.transform('claude',claude,path,False) == claude
assert json.loads(setup.transform('claude',claude,path,True)) == other
assert json.loads(claude)['permissions'] == other['permissions']
try: setup.transform('claude','{"disableAllHooks":true}',path,False); assert False
except ValueError: pass
for event, state in [('UserPromptSubmit','running'),('Stop','done'),('PostToolUse','running')]:
    result=hook.report('claude',{'session_id':'secret-session','hook_event_name':event,'prompt':'secret prompt','tool_input':{'token':'secret'}})
    assert result['state'] == state
    assert 'secret' not in json.dumps(result)
original_target=hook.hyprland_target
hook.hyprland_target=lambda: '0xabc123'
session=hook.report('claude',{'session_id':'session','hook_event_name':'UserPromptSubmit','cwd':'/home/tom/code/perch'})
assert session['title']=='perch' and session['project']=='perch' and session['target']=='0xabc123' and session['kind']=='agent'
hook.hyprland_target=original_target
assert hook.report('claude',{'session_id':'s','hook_event_name':'Notification','notification_type':'auth_success'}) is None
assert hook.report('claude',{'session_id':'s','hook_event_name':'Notification','notification_type':'permission_prompt'})['state']=='waiting'
assert hook.report('codex',{'thread-id':'s','type':'approval-requested'}) is None
assert hook.report('codex',{'thread-id':'s','type':'agent-turn-complete'})['state']=='done'

with tempfile.TemporaryDirectory() as directory:
    home=Path(directory); bins=home/'bin'; bins.mkdir()
    log=home/'commands'
    for command in ['omarchy','omarchy-shell']:
        executable=bins/command
        executable.write_text('#!/usr/bin/env python3\nimport json,os,sys\nwith open(os.environ["TEST_LOG"],"a") as f:f.write(json.dumps(sys.argv[1:])+"\\n")\nif os.environ.get("TEST_FAIL_ENABLE") and sys.argv[1:3]==["plugin","enable"]:sys.exit(1)\nprint(json.dumps([{"id":"io.github.tcballard.perch-notifications"},{"id":"io.github.tcballard.perch-osd"}]) if sys.argv[1:] == ["plugin","list","--json"] else "ok" if sys.argv[1:3] != ["shell","rescanPlugins"] else "")\n')
        executable.chmod(0o755)
    env=dict(os.environ,HOME=str(home),PATH=str(bins)+os.pathsep+os.environ['PATH'],TEST_LOG=str(log))
    env.pop('CODEX_HOME',None);env.pop('CLAUDE_CONFIG_DIR',None)
    def run(script,*args,input=None):
        return subprocess.run(['python3',str(root/'scripts'/script),*args],input=input,text=True,capture_output=True,env=env,timeout=10)
    assert run('perch-agent-setup','claude').returncode==0
    assert not (home/'.claude').exists()
    for agent in ['claude','codex']:
        assert run('perch-agent-setup',agent,'--apply').returncode==0
        assert run('perch-agent-setup',agent,'--apply').returncode==0
        assert run('perch-agent-setup',agent,'--remove','--apply').returncode==0
    assert tomllib.loads((home/'.codex/config.toml').read_text())=={}
    assert json.loads((home/'.claude/settings.json').read_text())=={}
    data=json.dumps({'hook_event_name':'Stop','session_id':'private','prompt':'DO NOT LEAK'})
    outcome=run('perch-agent-hook','--perch-hook-v1','claude',input=data)
    assert outcome.returncode==0 and not outcome.stdout and not outcome.stderr
    assert 'DO NOT LEAK' not in log.read_text() and 'private' not in log.read_text()
    before=log.read_text()
    assert run('perch-agent-hook','--perch-hook-v1','claude',input='x'*65537).returncode==0
    assert log.read_text()==before
    # The companion copies only its own files and delegates enable/restore to Omarchy.
    config=home/'.config/omarchy'; config.mkdir(parents=True)
    (config/'shell.json').write_text(json.dumps({'plugins':[{'id':'io.github.tcballard.perch'}]}))
    assert run('perch-notifications-setup').returncode==0
    assert not (config/'plugins').exists()
    outcome=run('perch-notifications-setup','--apply'); assert outcome.returncode==0,outcome.stderr
    target=config/'plugins/io.github.tcballard.perch-notifications'
    assert (target/'manifest.json').exists()
    assert run('perch-notifications-setup','--apply').returncode==0
    original=(target/'Service.qml').read_text(); (target/'Service.qml').write_text(original+'// local edit\n')
    assert run('perch-notifications-setup','--apply').returncode!=0
    assert run('perch-notifications-setup','--remove','--apply').returncode!=0
    (target/'Service.qml').write_text(original)
    assert run('perch-notifications-setup','--remove','--apply').returncode==0
    assert not target.exists()
    assert run('perch-notifications-setup','--kind','osd','--apply').returncode==0
    osd=config/'plugins/io.github.tcballard.perch-osd'
    assert json.loads((osd/'manifest.json').read_text())['omarchy']['clonedFrom']=='omarchy.osd'
    assert run('perch-notifications-setup','--kind','osd','--remove','--apply').returncode==0
    assert not osd.exists()
    commands=[json.loads(line) for line in log.read_text().splitlines()]
    assert ['plugin','disable','io.github.tcballard.perch-notifications'] in commands
    # Setup health reports installed companion copies that lag this checkout; worker failures name the step.
    def tools(op,payload):
        outcome=subprocess.run(['python3',str(root/'scripts/perch-tools'),op,json.dumps(payload)],text=True,capture_output=True,env=dict(env,XDG_STATE_HOME=str(home/'state')),timeout=30)
        assert outcome.returncode==0,outcome.stderr
        return json.loads(outcome.stdout)
    assert run('perch-notifications-setup','--kind','osd','--apply').returncode==0
    (config/'shell.json').write_text(json.dumps({'plugins':[{'id':'io.github.tcballard.perch'},{'id':'io.github.tcballard.perch-osd'}]}))
    health=tools('health',{})['health']
    assert health['osd']=='enabled' and health['updates']==[]
    (osd/'Panel.qml').write_text((osd/'Panel.qml').read_text()+'// newer core\n')
    assert tools('health',{})['health']['updates']==['osd']
    (osd/'Panel.qml').write_text((root/'companions/osd/Panel.qml').read_text())
    result=tools('integration-worker',{'name':'osd','enabled':True})
    assert result['status']=='done' and 'omarchy restart shell' in result['message']
    (config/'shell.json').write_text(json.dumps({'plugins':[]}))
    result=tools('integration-worker',{'name':'notifications','enabled':True})
    assert result['status']=='failed' and 'Enable Perch before' in result['message'],result
    assert 'shell.json' not in result['message']
    assert tools('health',{})['health']['job']['status']=='failed'
    # A corrupt job file never crashes health; a failed enable on a first install leaves no clone behind.
    (home/'state/omarchy-perch/integrations.json').write_text('[]')
    assert tools('health',{})['health']['job']=={'started':0}
    (config/'shell.json').write_text(json.dumps({'plugins':[{'id':'io.github.tcballard.perch'}]}))
    (config/'plugins/broken').mkdir();(config/'plugins/broken/manifest.json').write_text('[1]')
    assert run('perch-notifications-setup','--kind','osd','--remove','--apply').returncode==0
    failing=dict(env,TEST_FAIL_ENABLE='1')
    outcome=subprocess.run(['python3',str(root/'scripts/perch-notifications-setup'),'--kind','osd','--apply'],text=True,capture_output=True,env=failing,timeout=20)
    assert outcome.returncode!=0 and not osd.exists(),outcome.stderr
    assert run('perch-notifications-setup','--kind','osd','--apply').returncode==0 and osd.exists()
print('rc2: reversible setup, owned edits, notifier preservation, silent hooks and status-only payloads passed.')

approval=hook.report('claude',{'session_id':'s','hook_event_name':'Notification','notification_type':'permission_prompt'})
question=hook.report('claude',{'session_id':'s','hook_event_name':'Notification','notification_type':'elicitation_dialog'})
assert approval['attention']=='approval' and question['attention']=='question'
a={'thread-id':'s','type':'agent-turn-complete','turn-id':'one'}
b=dict(a, **{'turn-id':'two'})
assert hook.report('codex',a)['eventKey']==hook.report('codex',a)['eventKey']
assert hook.report('codex',a)['eventKey']!=hook.report('codex',b)['eventKey']
