#!/usr/bin/env python3
"""Exercise the compiled backend, real Unix sockets and installed Rust adapters.
Python is a development test driver; none of these modules ship runtime helpers.
"""
import base64
import datetime as dt
import hashlib
import http.server
import json
import os
from pathlib import Path
import select
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time

ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='perch-rust-') as directory:
    home=Path(directory); fake=home/'fake';fake.mkdir()
    env={**os.environ,'HOME':str(home),'XDG_STATE_HOME':str(home/'state'),'XDG_CACHE_HOME':str(home/'cache'),'XDG_CONFIG_HOME':str(home/'.config'),'XDG_RUNTIME_DIR':str(home/'run'),'PATH':str(fake)+os.pathsep+os.environ['PATH'],'PERCH_TEST_LOG':str(home/'log')}
    for key in ['CODEX_HOME','CLAUDE_CONFIG_DIR','KIMI_CODE_HOME','GROK_HOME','PI_CODING_AGENT_DIR','PERCH_RELAY_SOCKET','HYPRLAND_INSTANCE_SIGNATURE','TMUX','WEZTERM_PANE','ZELLIJ_SESSION_NAME']:
        env.pop(key,None)
    (home/'run').mkdir(mode=0o700)
    (fake/'omarchy-shell').write_text('''#!/usr/bin/env python3
import json,os,sys
with open(os.environ['PERCH_TEST_LOG'],'a') as f:f.write(json.dumps(sys.argv[1:])+"\\n")
a=sys.argv[1:]
if a==['shell','listPlugins']:
 print(json.dumps([{'id':'io.example.reader','name':'Reader','enabled':True,'firstParty':False,'kinds':['panel']},{'id':'io.example.off','name':'Off','enabled':False,'firstParty':False,'kinds':['panel']},{'id':'omarchy.stock','firstParty':True,'kinds':['panel']}]))
elif a==['io.example.reader','perchCard']:
 print(json.dumps({'version':1,'revision':'r1','status':'ready','title':'Reader','actions':[{'id':'refresh','label':'Refresh'}],'rows':[]}))
elif len(a)>1 and a[1]=='perchAction': print('{"ok":true}')
else:print('ok')
''');(fake/'omarchy-shell').chmod(0o755)
    def call(name,*args,input=None,timeout=12,environment=None):
        return subprocess.run([str(ROOT/'scripts'/('perch-'+name)),*args],input=input,text=True,capture_output=True,env=environment or env,timeout=timeout)
    def tool(op,p=None):
        r=call('tools',op,json.dumps(p or {}));assert r.returncode==0,(op,r.stderr);return json.loads(r.stdout)
    def good(op,p=None):
        v=tool(op,p);assert v.get('ok') is True,(op,v);return v
    def log():return [json.loads(l) for l in (home/'log').read_text().splitlines()]
    assert tool('unknown')['ok'] is False
    assert tool('module-weather',{'latitude':True,'longitude':0})['ok'] is False
    assert tool('module-weather',{'latitude':91,'longitude':0})['ok'] is False
    assert good('module-stats')['sample']['memoryTotal']>0
    assert tool('app-link',{'url':'https://user:password@example.com'})['ok'] is False
    # Shelf storage and identity match the existing state format, including file URLs.
    source=home/'notes with spaces #%.txt';source.write_text('Hello shelf')
    row=good('shelf-add',{'urls':[source.as_uri()]})['items'][0]
    assert row['id']==hashlib.sha256(str(source).encode()).hexdigest()[:24]
    assert good('shelf-preview',{'id':row['id']})['preview']=='Hello shelf'
    assert good('shelf-list')['items'][0]['url']==source.as_uri()
    assert tool('shelf-add',{'urls':['file://remote/etc/passwd']})['ok'] is False
    assert tool('shelf-add',{'urls':['file:///bad%☃']})['ok'] is False
    assert (home/'state/omarchy-perch/shelf.json').stat().st_mode&0o777==0o600
    good('shelf-remove',{'id':row['id']});assert source.read_text()=='Hello shelf'
    assert good('shelf-list')['items']==[]
    (home/'state/omarchy-perch/shelf.json').write_text('{}')
    assert tool('shelf-add',{'urls':[str(source)]})['ok'] is False
    assert (home/'state/omarchy-perch/shelf.json').read_text()=='{}'
    # Local lyrics and calendar source persistence, recurrence and safe join.
    lyric=home/'song.lrc';lyric.write_text('[00:01.50]One\n[00:03]Two\n')
    assert good('lyrics',{'path':str(lyric)})['lyrics']==[{'time':1.5,'text':'One'},{'time':3.0,'text':'Two'}]
    assert tool('artwork',{'url':'https://127.0.0.1/x'})['ok'] is False
    assert tool('artwork',{'url':'https://[::1]/x'})['ok'] is False
    stamp=dt.datetime.now(dt.timezone.utc)+dt.timedelta(days=1)
    date=stamp.strftime('%Y%m%dT%H%M%SZ');calendar=home/'agenda.ics'
    calendar.write_text(f'BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART:{date}\nDURATION:PT15M\nSUMMARY:Daily\nRRULE:FREQ=DAILY;COUNT=3\nURL:https://example.org/join\nEND:VEVENT\nEND:VCALENDAR')
    agenda=good('calendar-add',{'path':str(calendar)})
    assert len(agenda['events'])==3 and agenda['sources']==[str(calendar)]
    assert agenda['events'][0]['end']-agenda['events'][0]['start']==900000
    assert tool('calendar-join',{'url':'https://example.org/not-in-agenda'})['ok'] is False
    good('calendar-remove',{'path':str(calendar)});assert good('calendar-list')['sources']==[]
    # Plugin/cards revalidate immediately and reject stale or invented actions.
    assert [p['id'] for p in good('plugin-list')['plugins']]==['io.example.off','io.example.reader']
    assert tool('plugin-open',{'id':'io.example.off'})['ok'] is False
    assert good('plugin-open',{'id':'io.example.reader'})['message']=='Opened Reader'
    assert log()[-1]==['shell','summon','io.example.reader','{}']
    assert good('card-read',{'id':'io.example.reader'})['card']['revision']=='r1'
    assert tool('card-action',{'id':'io.example.reader','revision':'old','action':'refresh'})['ok'] is False
    assert tool('card-action',{'id':'io.example.reader','revision':'r1','action':'invented'})['ok'] is False
    assert good('card-action',{'id':'io.example.reader','revision':'r1','action':'refresh'})['message']=='Action completed'
    # Real installed adapters: upgrades/removal own exact commands, with backups.
    agents=['claude','gemini','cursor','qwen','qoder','factory','codebuddy','kimi','grok','codex','codex-hooks']
    for agent in agents:
        assert call('agent-setup',agent).returncode==0
        if agent=='claude':assert not (home/'.local/share/omarchy-perch/perch-agent-hook').exists()
        r=call('agent-setup',agent,'--apply');assert r.returncode==0,(agent,r.stderr)
        assert call('agent-setup',agent,'--apply').returncode==0
    adapter=home/'.local/share/omarchy-perch/perch-agent-hook'
    assert '# Perch Rust adapter v1' in adapter.read_text()
    r=subprocess.run([str(adapter),'--perch-hook-v1','claude'],input=json.dumps({'hook_event_name':'UserPromptSubmit','session_id':'one','cwd':'/work/repo','prompt':'PRIVATE'}),text=True,capture_output=True,env=env)
    assert r.returncode==0 and r.stdout==''
    payload=json.loads(log()[-1][-1]);assert payload['state']=='running' and payload['project']=='repo' and 'PRIVATE' not in json.dumps(payload)
    for agent,output in [('gemini',{}),('cursor',{'continue':True})]:
        r=call('agent-hook','--perch-hook-v1',agent,input='invalid');assert r.returncode==0 and json.loads(r.stdout)==output
    # Upgrade a real legacy v1 JSON command without touching its sibling hook.
    settings=home/'.claude/settings.json';data=json.loads(settings.read_text());command=f'python3 {adapter} --perch-hook-v1 claude'
    data['hooks']['Stop']=[{'hooks':[{'type':'command','command':command},{'type':'command','command':'custom keep'}]}];data['theme']='keep';settings.write_text(json.dumps(data))
    assert call('agent-setup','claude','--apply').returncode==0
    data=json.loads(settings.read_text());assert data['theme']=='keep'
    assert any(h['command']=='custom keep' for g in data['hooks']['Stop'] for h in g['hooks'])
    assert 'python3' not in settings.read_text()
    assert list(settings.parent.glob('settings.json.perch-backup-*'))
    assert good('health')['health']['claude']=='enabled'
    assert call('usage-setup','--apply').returncode==0
    assert call('usage-statusline',input=json.dumps({'rate_limits':{'five_hour':{'used_percentage':25,'resets_at':time.time()+100}}})).returncode==0
    usage=good('usage')['sources'];assert usage[1]['windows'][0]['used']==25
    assert call('usage-setup','--remove','--apply').returncode==0
    data=json.loads(settings.read_text());data['statusLine']={'type':'command','command':'my custom status'};settings.write_text(json.dumps(data))
    assert call('usage-setup','--apply').returncode==1
    assert json.loads(settings.read_text())['statusLine']['command']=='my custom status'
    data['disableAllHooks']=True;settings.write_text(json.dumps(data));before=settings.read_text()
    assert call('agent-setup','claude','--apply').returncode==1 and settings.read_text()==before
    assert good('health')['health']['claude']=='hooks disabled'
    assert call('agent-setup','claude','--remove','--apply').returncode==0
    data=json.loads(settings.read_text());data.pop('disableAllHooks');settings.write_text(json.dumps(data))
    for agent in ['pi','omp','opencode','opencode-requests']:
        r=call('extension-setup',agent,'--apply');assert r.returncode==0,(agent,r.stderr)
        assert good('health')['health'][agent]=='enabled'
        assert call('extension-setup',agent,'--remove','--apply').returncode==0
    assert call('request-setup','--apply').returncode==0
    assert call('request-setup','--agent','codex','--apply').returncode==0
    assert good('health')['health']['requests']=='enabled'
    # History strips executable actions on disk and preserves malformed sources.
    store=ROOT/'companions/notifications/perch-notification-store'
    persisted={'rows':[{'key':'s.1','app':'Sender','title':'Notice','body':'text','actions':[{'command':'danger'}],'reply':True,'unread':True}],'dnd':True,'blocked':['Sender']}
    def history(op,body=None):return json.loads(subprocess.run([str(store),op],input=json.dumps(body) if body is not None else None,text=True,capture_output=True,env=env).stdout)
    assert history('write',persisted)['ok'] is True
    restored=history('read');assert restored['rows'][0]['actions']==[] and restored['rows'][0]['reply'] is False and restored['dnd']
    state=home/'state/omarchy-perch/notifications.json';state.write_text('broken');assert history('read')['ok'] is False and state.read_text()=='broken'
    try:
        with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM):pass
        with socket.socket(socket.AF_INET,socket.SOCK_STREAM):pass
        sockets_available=True
    except PermissionError:
        if os.environ.get('PERCH_REQUIRE_SOCKET_TESTS')=='1':raise
        sockets_available=False
        print('Local socket creation is blocked; GitHub CI requires the live bridge/HTTP checks.')
    # Interactive stdin must consume a complete line while the writer stays open.
    pipe_child=subprocess.Popen([str(ROOT/'scripts/perch-request-hook'),'--agent','opencode'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=env)
    pipe_child.stdin.write('not-json\n');pipe_child.stdin.flush()
    pipe_child.wait(timeout=1);assert pipe_child.returncode==0 and pipe_child.stdout.read()==''
    pipe_child.stdin.close()
    # Real request bridge sockets, cancellation and one-off decisions.
    if sockets_available:
        request={'hook_event_name':'PermissionRequest','tool_name':'Bash','tool_input':{'command':'make test'},'cwd':'/work/repo'}
        def start_request(agent='claude'):
            child=subprocess.Popen([str(ROOT/'scripts/perch-request-hook')]+(['--agent',agent] if agent!='claude' else []),stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=env)
            child.stdin.write(json.dumps(request)+'\n');child.stdin.flush()
            if agent!='opencode':child.stdin.close()
            root=home/'run'/f'perch-requests-{os.getuid()}'
            until=time.monotonic()+3
            while time.monotonic()<until:
                paths=list(root.glob('*.json'))
                if paths:return child,root,paths[0].stem
                if child.poll() is not None:raise AssertionError(child.stderr.read())
                time.sleep(.01)
            raise AssertionError('No request record')
        child,request_root,token=start_request()
        assert good('request-get',{'id':token})['request']['tool']=='Bash'
        assert tool('request-reply',{'id':token,'action':'always'})['ok'] is False
        assert good('request-reply',{'id':token,'action':'allow'})['message']=='Response delivered'
        child.wait(timeout=3);reply=json.loads(child.stdout.read());assert reply['hookSpecificOutput']['decision']['behavior']=='allow'
        assert not list(request_root.glob('*.json')) and not list(request_root.glob('*.sock'))
        child,_,token=start_request();child.terminate();child.wait(timeout=3)
        assert not list(request_root.glob('*.json')) and not list(request_root.glob('*.sock'))
        child,_,token=start_request('opencode')
        result=[]
        def respond():result.append(tool('request-reply',{'id':token,'action':'allow'}))
        thread=threading.Thread(target=respond);thread.start()
        assert select.select([child.stdout],[],[],3)[0]
        assert json.loads(child.stdout.readline())=={'response':'once'}
        child.stdin.write('{"delivered":true}\n');child.stdin.flush();thread.join(timeout=3);child.wait(timeout=3)
        assert result[0]['ok'] is True and not list(request_root.glob('*.json'))
        # Relay is private, rejects a duplicate owner, strips remote targets, cleans up.
        relay=subprocess.Popen([str(ROOT/'scripts/perch-relay'),'serve'],text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env)
        assert select.select([relay.stdout],[],[],3)[0]
        endpoint=Path(json.loads(relay.stdout.readline())['ready']);assert endpoint.stat().st_mode&0o777==0o600
        assert call('relay','serve').returncode==1 and endpoint.exists()
        with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as conn:
            conn.settimeout(2);conn.connect(str(endpoint));conn.sendall(json.dumps({'source':'laptop','event':{'id':'claude.1','state':'waiting','title':'Work','target':'0x123','requestId':'secret'}}).encode()+b'\n');assert json.loads(conn.recv(128))['ok'] is True
        assert select.select([relay.stdout],[],[],2)[0];remote=json.loads(relay.stdout.readline())['event'];assert 'target' not in remote and 'requestId' not in remote
        relay.terminate();relay.wait(timeout=3);assert not endpoint.exists()
    # Task copy/download are bounded and never overwrite, including truncated HTTP.
    destination=home/'copied';assert call('task','copy',str(source),str(destination)).returncode==0
    assert destination.read_bytes()==source.read_bytes()
    assert call('task','copy',str(source),str(destination)).returncode==1
    assert call('task','--max-bytes','2','copy',str(source),str(home/'too-big')).returncode==1
    assert not (home/'too-big').exists()
    if sockets_available:
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                data=b'download';self.send_response(200);self.send_header('Content-Length',str(len(data)+(10 if self.path=='/truncated' else 0)));self.end_headers();self.wfile.write(data)
            def log_message(self,*args):pass
        server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler);thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        try:
            url=f'http://127.0.0.1:{server.server_port}'
            assert call('task','download',url+'/ok',str(home/'download')).returncode==0
            assert (home/'download').read_bytes()==b'download'
            assert call('task','download',url+'/truncated',str(home/'incomplete')).returncode==1
            assert not (home/'incomplete').exists()
        finally:server.shutdown();server.server_close();thread.join()
    assert call('task','run','--',sys.executable,'-c','raise SystemExit(7)').returncode==7
    assert call('task','--timeout','1','run','--',sys.executable,'-c','import time;time.sleep(20)').returncode==130
    assert not list(home.glob('.perch-transfer-*'))
    assert call('request-setup','--remove','--apply').returncode==0
    assert call('request-setup','--agent','codex','--remove','--apply').returncode==0
    for agent in agents:assert call('agent-setup',agent,'--remove','--apply').returncode==0
    assert good('integration-worker',{'name':'claude','enabled':False})['status']=='done'
    report=json.loads(call('support').stdout);assert report['backend']=='Rust' and 'python' not in report and 'PRIVATE' not in json.dumps(report)
print('Rust backend state, setup upgrades, cards and task contracts passed; live socket checks run where permitted.')
