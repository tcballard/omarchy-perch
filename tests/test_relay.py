#!/usr/bin/env python3
import importlib.machinery,importlib.util,json,os,queue,socket,sys,tempfile,threading
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
def load(name):
    loader=importlib.machinery.SourceFileLoader(name,str(ROOT/'scripts'/name));spec=importlib.util.spec_from_loader(name,loader);m=importlib.util.module_from_spec(spec);loader.exec_module(m);return m
relay=load('perch-relay');hook=load('perch-agent-hook')
payload={'id':'claude.one','state':'waiting','agent':'Claude','title':'project','project':'project','eventKey':'turn','target':'0x123','targetPid':123,'requestId':'a'*32,'tool_input':{'command':'PRIVATE'},'detail':'PRIVATE'}
a=relay.normalize({'source':'buildbox','event':payload})
assert a['title']=='buildbox · project' and a['state']=='waiting'
assert not set(a)&{'target','targetPid','requestId','tool_input'} and 'PRIVATE' not in json.dumps(a)
assert a['id']!=relay.normalize({'source':'other','event':payload})['id']
for bad in ({'source':'../host','event':payload},{'source':'host','event':dict(payload,state='approve')},{'source':'host','event':dict(payload,id='x'*65)},[]):
    try:relay.normalize(bad);raise AssertionError('invalid message accepted')
    except ValueError:pass
with tempfile.TemporaryDirectory() as tmp,patch.dict(os.environ,{'XDG_RUNTIME_DIR':tmp,'PERCH_REMOTE_NAME':'buildbox'}):
    path=relay.endpoint();assert path.parent.stat().st_mode&0o777==0o700
    try:
        probe=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);probe.close();allowed=True
    except PermissionError:
        allowed=False;print('SKIP relay socket round trip: sandbox prohibits socket creation; CI exercises it.')
    if allowed:
        # A killed receiver may leave a socket inode, but its lock has been released.
        stale=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);stale.bind(str(path));path.chmod(0o600);stale.close()
        events=queue.Queue();errors=[]
        def serve():
            try:relay.serve(events.put,max_events=1)
            except BaseException as e:errors.append(e)
        worker=threading.Thread(target=serve,daemon=True);worker.start()
        ready=events.get(timeout=2);assert ready['ready']==str(path)
        assert path.stat().st_mode&0o777==0o600
        try:
            with relay.locked_endpoint():raise AssertionError('active receiver lock ignored')
        except BlockingIOError:pass
        assert path.exists()
        hook.send_relay(str(path),payload)
        event=events.get(timeout=2)['event'];assert event==a
        worker.join(2);assert not worker.is_alive() and not errors
        assert not path.exists()
        print('Relay Unix socket round trip, sender framing and cleanup passed.')
    path.parent.chmod(0o755)
    try:relay.endpoint();raise AssertionError('unsafe runtime accepted')
    except ValueError:pass
print('Remote status validation, source isolation, local-target/request stripping and private runtime checks passed.')
