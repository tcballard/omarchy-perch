#!/usr/bin/env python3
"""Read-only Codex observer and verified terminal focus against local fixtures."""
import base64,hashlib,json,os,socket,struct,subprocess,tempfile,threading,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
try:
    probe=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);probe.close()
except PermissionError:
    if os.environ.get('PERCH_REQUIRE_SOCKET_TESTS')=='1':raise
    print('Codex/focus socket fixtures unavailable locally; required in CI.')
    raise SystemExit(0)
with tempfile.TemporaryDirectory(prefix='perch-ipc-') as directory:
    folder=Path(directory);fake=folder/'bin';fake.mkdir();calls=[]
    env={**os.environ,'HOME':str(folder),'PATH':str(fake)+os.pathsep+os.environ['PATH'],'PERCH_TEST_LOG':str(folder/'log'),'PERCH_TEST_PID':str(os.getpid())}
    for key in ['TMUX','WEZTERM_PANE','ZELLIJ_SESSION_NAME','PERCH_RELAY_SOCKET']:env.pop(key,None)
    def command(name,body):
        p=fake/name;p.write_text('#!/usr/bin/env python3\nimport json,os,sys\n'+body);p.chmod(0o755)
    command('xdg-mime','print("codex.desktop")\n')
    command('hyprctl','''with open(os.environ['PERCH_TEST_LOG'],'a') as f:f.write(json.dumps(sys.argv[1:])+"\\n")
print(json.dumps([{'address':'0x123','pid':int(os.environ['PERCH_TEST_PID'])}]) if sys.argv[1:]==['-j','clients'] else 'ok')
''')
    command('tmux','''with open(os.environ['PERCH_TEST_LOG'],'a') as f:f.write(json.dumps(sys.argv[1:])+"\\n")
a=sys.argv[3:]
print(os.environ['PERCH_TEST_PID'] if a[:1]==['display-message'] else os.environ['PERCH_TEST_PID']+' /dev/pts/1' if a[:1]==['list-clients'] else '')
''')
    command('wezterm','''with open(os.environ['PERCH_TEST_LOG'],'a') as f:f.write(json.dumps(sys.argv[1:])+"\\n")
print('[{"pane_id":42}]' if sys.argv[1:]==['cli','list','--format','json'] else '')
''')
    def tool(op,p):
        r=subprocess.run([str(ROOT/'scripts/perch-tools'),op,json.dumps(p)],text=True,capture_output=True,env=env,timeout=8)
        assert r.returncode==0,r.stderr
        return json.loads(r.stdout)
    # Minimal fixture implements only RFC6455 text transport; production uses tungstenite.
    def exact(conn,n):
        out=b''
        while len(out)<n:
            piece=conn.recv(n-len(out))
            if not piece:raise EOFError()
            out+=piece
        return out
    def read_frame(conn):
        first,second=exact(conn,2);n=second&127
        if n==126:n=struct.unpack('>H',exact(conn,2))[0]
        elif n==127:n=struct.unpack('>Q',exact(conn,8))[0]
        assert n<=65536
        mask=exact(conn,4) if second&128 else b'';raw=exact(conn,n)
        if mask:raw=bytes(b^mask[i%4] for i,b in enumerate(raw))
        assert first&15==1
        return json.loads(raw)
    def write_frame(conn,obj):
        raw=json.dumps(obj).encode();head=bytes([0x81,len(raw)]) if len(raw)<126 else b'\x81\x7e'+struct.pack('>H',len(raw));conn.sendall(head+raw)
    ident='12345678-1234-1234-1234-123456789abc'
    def observe(interactive=False,mismatch=False):
        path=folder/'codex.sock';server=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);server.bind(str(path));path.chmod(0o600);server.listen(1);errors=[];seen=[]
        def serve():
            try:
                conn,_=server.accept()
                with conn:
                    conn.settimeout(3);raw=b''
                    while b'\r\n\r\n' not in raw:raw+=conn.recv(4096)
                    key=next(l.split(b':',1)[1].strip() for l in raw.split(b'\r\n') if l.lower().startswith(b'sec-websocket-key:'))
                    accept=base64.b64encode(hashlib.sha1(key+b'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest())
                    conn.sendall(b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: '+accept+b'\r\n\r\n')
                    request=read_frame(conn);seen.append(request);assert request['method']=='initialize'
                    if interactive:
                        write_frame(conn,{'id':999,'method':'item/commandExecution/requestApproval','params':{'command':'PRIVATE'}});return
                    write_frame(conn,{'id':request['id'],'result':{}})
                    initialized=read_frame(conn);seen.append(initialized);assert initialized=={'method':'initialized'}
                    request=read_frame(conn);seen.append(request);assert request['method']=='thread/loaded/list' and request['params']['limit']==8
                    write_frame(conn,{'id':request['id'],'result':{'data':[ident]}})
                    request=read_frame(conn);seen.append(request);assert request['method']=='thread/read' and request['params']=={'threadId':ident,'includeTurns':False}
                    write_frame(conn,{'id':request['id'],'result':{'thread':{'id':('00000000-0000-0000-0000-000000000000' if mismatch else ident),'cwd':'/work/repo','status':{'type':'active','activeFlags':['waitingOnApproval']},'turns':[{'text':'PRIVATE TRANSCRIPT'}]}}})
            except Exception as e:errors.append(e)
        thread=threading.Thread(target=serve,daemon=True);thread.start()
        try:reply=tool('codex-server-status',{'path':str(path)})
        finally:server.close();thread.join(timeout=4);path.unlink(missing_ok=True)
        assert not errors,errors
        assert {r['method'] for r in seen}<={'initialize','initialized','thread/loaded/list','thread/read'}
        return reply
    result=observe();assert result['ok'] and result['sessions'][0]['state']=='waiting' and result['sessions'][0]['attention']=='approval'
    assert 'PRIVATE' not in json.dumps(result)
    assert observe(interactive=True)['ok'] is False
    assert observe(mismatch=True)['ok'] is False
    # An unsafe socket is refused before any connection/handshake.
    unsafe=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);unsafe.bind(str(folder/'unsafe.sock'));(folder/'unsafe.sock').chmod(0o666)
    assert tool('codex-server-status',{'path':str(folder/'unsafe.sock')})['ok'] is False;unsafe.close()
    pid=os.getpid();raw=Path(f'/proc/{pid}/stat').read_text();start=raw.rsplit(')',1)[1].split()[19];boot=Path('/proc/sys/kernel/random/boot_id').read_text().strip()
    target={'address':'0x123','targetPid':pid,'targetStart':start,'targetBoot':boot}
    stale={**target,'targetStart':'0'};assert tool('agent-jump',stale)['ok'] is False
    assert tool('agent-jump',target)['ok'] is True
    assert tool('agent-liveness',{'sessions':[{'id':'codex.one','pid':pid,'start':start,'boot':boot}]})['ended']==[]
    assert tool('agent-liveness',{'sessions':[{'id':'codex.one','pid':pid,'start':'0','boot':boot}]})['ended']==['codex.one']
    sock=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);path=folder/'terminal.sock';sock.bind(str(path));info=path.stat()
    tmux={'socket':str(path),'pane':'%1','panePid':pid,'paneStart':start,'client':'/dev/pts/1','clientPid':pid,'clientStart':start}
    assert tool('agent-jump',{**target,'targetTmux':tmux})['ok'] is True
    assert tool('agent-jump',{**target,'targetTmux':{**tmux,'clientStart':'0'}})['ok'] is False
    wezterm={'socket':str(path),'pane':42,'device':str(info.st_dev),'inode':str(info.st_ino),'windowStart':start}
    assert tool('agent-jump',{**target,'targetWezterm':wezterm})['ok'] is True
    assert tool('agent-jump',{**target,'targetWezterm':{**wezterm,'inode':'0'}})['ok'] is False
    sock.close()
print('Rust Codex observer, interactive refusal, socket privacy and verified terminal focus passed.')
