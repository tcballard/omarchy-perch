import json,os,socket,sys,tempfile,threading,time
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from perchlib import codex_server as C
THREAD='12345678-1234-1234-1234-123456789abc'
metadata={'id':THREAD,'cwd':'/work/perch','status':{'type':'active','activeFlags':['waitingOnApproval']},
    'preview':'PRIVATE PROMPT','turns':[{'input':'PRIVATE'}],'name':'PRIVATE TITLE'}

class Fake:
    def __init__(self,interactive=False):self.sent=[];self.messages=[];self.interactive=interactive
    def send(self,raw):
        p=json.loads(raw);self.sent.append(p)
        if 'id' not in p:return
        result={} if p['method']=='initialize' else {'data':[THREAD]} if p['method']=='thread/loaded/list' else {'thread':metadata}
        self.messages.append(json.dumps({'id':p['id'],'result':result}))
    def recv(self,timeout):
        if self.interactive:return json.dumps({'id':42,'method':'item/commandExecution/requestApproval','params':{'command':'PRIVATE'}})
        return self.messages.pop(0)

fake=Fake();result=C.Reader(fake,time.monotonic()+4).snapshot('codex.desktop')
row=result['sessions'][0];assert row['state']=='waiting' and row['attention']=='approval'
assert 'PRIVATE' not in json.dumps(result) and 'turns' not in row
assert row['targetCodex']['thread']==THREAD
assert [p['method'] for p in fake.sent]==['initialize','initialized','thread/loaded/list','thread/read']
assert fake.sent[-1]['params']=={'threadId':THREAD,'includeTurns':False}
assert C.record({**metadata,'parentThreadId':'parent'}) is None
assert C.record({**metadata,'status':{'type':'idle'}})['state']=='idle'
assert C.record({**metadata,'status':{'type':'active','activeFlags':['waitingOnUserInput']}})['attention']=='question'
try:C.Reader(Fake(True),time.monotonic()+4).snapshot();raise AssertionError('interactive request accepted')
except ValueError as e:assert 'interactive client' in str(e)
try:C.Reader(Fake(),time.monotonic()+4).call('turn/start',{});raise AssertionError('mutating method accepted')
except ValueError:pass
try:C.snapshot({'path':'ws://127.0.0.1:1234'});raise AssertionError('network endpoint accepted')
except ValueError:pass

try:
    from websockets.sync.server import unix_serve
    probe=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);probe.close()
    available=True
except (ImportError,PermissionError):
    available=False
    print('SKIP live Codex socket: requires permitted Unix sockets and python-websockets; CI installs the dependency and runs it.')
if available:
    for interactive in (False,True):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'server.sock';seen=[]
            def handle(conn):
                try:
                    for raw in conn:
                        p=json.loads(raw);seen.append(p)
                        if 'id' not in p:continue
                        if interactive:
                            conn.send(json.dumps({'id':42,'method':'item/commandExecution/requestApproval'}));continue
                        reply={} if p['method']=='initialize' else {'data':[THREAD]} if p['method']=='thread/loaded/list' else {'thread':metadata}
                        conn.send(json.dumps({'id':p['id'],'result':reply}))
                except Exception:pass # The reader deliberately closes on interactive requests.
            with unix_serve(handle,str(path),compression=None) as server:
                path.chmod(0o600)
                runner=threading.Thread(target=server.serve_forever);runner.start()
                try:
                    with patch.object(C,'codex_handler',return_value=''):
                        if interactive:
                            try:C.snapshot({'path':str(path)});raise AssertionError('interactive request handled')
                            except ValueError as e:assert 'interactive client' in str(e)
                        else:
                            alias=Path(tmp)/'alias';alias.symlink_to(path)
                            assert C.snapshot({'path':str(alias)})['sessions'][0]['state']=='waiting'
                            path.chmod(0o666)
                            try:C.snapshot({'path':str(path)});raise AssertionError('public socket accepted')
                            except ValueError as e:assert 'private socket' in str(e)
                finally:server.shutdown();runner.join(2)
                assert all(p.get('method') in C.ALLOWED|{'initialized'} for p in seen)
print('Codex observer uses only bounded metadata reads, strips content, rejects network/public sockets and never responds to approvals.')
