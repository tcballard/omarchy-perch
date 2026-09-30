import json,os,sys,tempfile,threading,time,queue,socket
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from perchlib.requests import bridge
raw={'hook_event_name':'PermissionRequest','tool_name':'Bash','tool_input':{'command':'printf example'},'cwd':'/work/perch'}
with tempfile.TemporaryDirectory() as tmp,patch.dict(os.environ,{'XDG_RUNTIME_DIR':tmp}):
    try:
        probe=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);probe.close();socket_allowed=True
    except PermissionError:
        socket_allowed=False
        print('SKIP live Unix socket round trips: this execution sandbox prohibits socket creation; CI runs them where permitted.')
    for action in (('allow','deny','session') if socket_allowed else ()):
        events=queue.Queue();out=[]
        def publish(value,verb='activity'):
            if verb=='activity':events.put(value)
            return True
        with patch.object(bridge,'publish',side_effect=publish):
            thread=threading.Thread(target=lambda:out.append(bridge.serve(raw,3)));thread.start()
            event=events.get(timeout=2);token=event['requestId']
            assert bridge.read_request(token)['input']['command']=='printf example'
            assert bridge.respond({'id':token,'action':action})['message']=='Response delivered'
            thread.join(2);assert not thread.is_alive()
            assert out[0] == ({} if action=='session' else {'hookSpecificOutput':{'hookEventName':'PermissionRequest','decision':{'behavior':action}}})
            try:bridge.respond({'id':token,'action':'allow'});assert False
            except (OSError,ValueError):pass
            assert not list(bridge.directory().glob('*.json'))
    if socket_allowed:
        with patch.object(bridge,'publish',return_value=True):
            assert bridge.serve(raw,.05)=={}
    data=bridge.request_data({'hook_event_name':'PreToolUse','tool_name':'AskUserQuestion','tool_input':{'questions':[{'question':'Which?', 'options':[{'label':'One'}]}]}},'a'*32,time.time()+5)
    reply=bridge.decision(data,{'action':'answer','answers':{'Which?':'One'}})
    assert reply['hookSpecificOutput']['updatedInput']['answers']=={'Which?':'One'}
    assert reply['hookSpecificOutput']['updatedInput']['questions']==data['input']['questions']
    for answers in ({},{'Which?':''},{'Wrong':'One'}):
        try:bridge.decision(data,{'action':'answer','answers':answers});assert False
        except ValueError:pass
    try:bridge.request_data(dict(raw,tool_input={'command':'x'*20000}),'b'*32,time.time()+5);assert False
    except ValueError:pass
print('Request decision schema, complete answers and input bounds passed; socket evidence is reported above.')

codex=bridge.request_data(raw,'a'*32,time.time()+120,'codex')
assert codex['agent']=='codex'
assert bridge.decision(codex,{'action':'allow'})=={'hookSpecificOutput':{'hookEventName':'PermissionRequest','decision':{'behavior':'allow'}}}
assert bridge.decision(codex,{'action':'session'})=={}
try:bridge.request_data(dict(raw,hook_event_name='PreToolUse',tool_name='AskUserQuestion'),'a'*32,time.time()+120,'codex');raise AssertionError('unsupported Codex questions accepted')
except ValueError:pass
import runpy
setup=runpy.run_path(str(Path(__file__).resolve().parents[1]/'scripts/perch-request-setup'))
old='{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"keep"}]}]}}'
new=setup['transform'](old,Path('/owned/request'),False,'codex')
assert set(json.loads(new)['hooks'])=={'Stop','PermissionRequest'}
assert json.loads(setup['transform'](new,Path('/owned/request'),True,'codex'))==json.loads(old)
print('Codex approval schema, explicit fallback and separately owned setup/removal passed.')

opencode=bridge.request_data(raw,'a'*32,time.time()+120,'opencode')
assert bridge.decision(opencode,{'action':'allow'})=={'response':'once'}
assert bridge.decision(opencode,{'action':'deny'})=={'response':'reject'}
assert bridge.decision(opencode,{'action':'session'})=={}
if socket_allowed:
    with tempfile.TemporaryDirectory() as tmp,patch.dict(os.environ,{'XDG_RUNTIME_DIR':tmp}):
        for accepted in (True,False):
            events=queue.Queue();out=[];deliveries=[]
            def publish(value,verb='activity'):
                if verb=='activity':events.put(value)
                return True
            def deliver(value):
                deliveries.append(value);return accepted
            with patch.object(bridge,'publish',side_effect=publish):
                thread=threading.Thread(target=lambda:out.append(bridge.serve(raw,3,'opencode',deliver)));thread.start()
                token=events.get(timeout=2)['requestId']
                try:
                    bridge.respond({'id':token,'action':'allow'});assert accepted
                except ValueError as error:
                    assert not accepted and 'did not confirm' in str(error)
                thread.join(2);assert not thread.is_alive()
                assert deliveries==[{'response':'once'}]
                assert out==[{'response':'once'} if accepted else {}]
                assert not list(bridge.directory().glob('*.json'))
print('OpenCode decision schema passed; client acknowledgment socket checks run where permitted.')
