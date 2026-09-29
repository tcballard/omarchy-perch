#!/usr/bin/env python3
import importlib.machinery,importlib.util,json,subprocess,sys
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
def load(name):
    loader=importlib.machinery.SourceFileLoader(name,str(ROOT/'scripts'/name));spec=importlib.util.spec_from_loader(name,loader);m=importlib.util.module_from_spec(spec);loader.exec_module(m);return m
setup=load('perch-agent-setup');hook=load('perch-agent-hook');adapter=Path('/example/perch-agent-hook')
for agent,events in [('gemini',setup.GEMINI_EVENTS),('cursor',setup.CURSOR_EVENTS)]:
    old=json.dumps({'hooks':{'custom':[{'command':'keep'}]},'theme':'keep',**({'version':1} if agent=='cursor' else {})})
    new=setup.transform(agent,old,adapter,False);data=json.loads(new)
    assert data['theme']=='keep' and data['hooks']['custom']==[{'command':'keep'}]
    assert setup.transform(agent,new,adapter,False)==new
    assert json.loads(setup.transform(agent,new,adapter,True))==json.loads(old)
    for event in events:
        if agent=='gemini':assert data['hooks'][event][0]['hooks'][0]['timeout']==3000
        else:assert data['hooks'][event][0]['timeout']==3
    for event,state in ([('BeforeAgent','running'),('AfterTool','running'),('AfterAgent','done'),('Notification','waiting')] if agent=='gemini' else [('beforeSubmitPrompt','running'),('postToolUse','running'),('stop','done'),('sessionEnd','done')]):
        p={'hook_event_name':event,'session_id':'session','conversation_id':'session','cwd':'/work/perch','workspace_roots':['/work/perch'],'notification_type':'ToolPermission','status':'completed','prompt':'PRIVATE PROMPT','tool_input':{'command':'PRIVATE COMMAND'}}
        with patch.object(hook,'hyprland_target',return_value={}):report=hook.report(agent,p)
        assert report['state']==state and report['project']=='perch'
        assert 'PRIVATE' not in json.dumps(report)
    # Broken inputs never emit a blocking exit code or decision.
    r=subprocess.run([sys.executable,str(ROOT/'scripts/perch-agent-hook'),'--perch-hook-v1',agent],input='not json',text=True,capture_output=True)
    assert r.returncode==0 and json.loads(r.stdout)==({'continue':True} if agent=='cursor' else {})
for old in [{'hooks':{'enabled':False}},{'tools':{'enableHooks':False}},{'hooks':{'disabled':['perch-status']}}]:
    try:setup.transform('gemini',json.dumps(old),adapter,False);raise AssertionError('disabled hooks overwritten')
    except ValueError:pass
try:setup.transform('cursor','{"version":2}',adapter,False);raise AssertionError('unknown version accepted')
except ValueError:pass
with patch.object(hook,'hyprland_target',return_value={}):
    assert hook.report('cursor',{'conversation_id':'one','hook_event_name':'stop','status':'error'})['state']=='error'
    assert hook.report('gemini',{'session_id':'one','hook_event_name':'Notification','notification_type':'Other'}) is None
print('Gemini/Cursor event mapping, privacy, reversible configuration, timeout units and nonblocking output passed.')
