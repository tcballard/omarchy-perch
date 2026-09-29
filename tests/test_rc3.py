#!/usr/bin/env python3
"""Production helper regressions; isolated XDG state and fake shell IPC."""
import datetime as dt
import http.server
import threading
import importlib.machinery
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from perchlib import calendar,media,process,shelf
from perchlib.storage import Store,read_file

def call(script,*args,input=None):
    return subprocess.run([sys.executable,str(ROOT/script),*args],input=input,text=True,capture_output=True,timeout=8)

with tempfile.TemporaryDirectory() as temporary:
    temp=Path(temporary)
    with patch.dict(os.environ,{'XDG_STATE_HOME':str(temp/'state'),'XDG_CACHE_HOME':str(temp/'cache')}):
        source=temp/'notes with spaces.txt';source.write_text('Hello shelf')
        result=shelf.handle('shelf-add',{'urls':[source.as_uri()]})
        row=result['items'][0]
        assert shelf.handle('shelf-preview',{'id':row['id']})['preview']=='Hello shelf'
        assert shelf.handle('shelf-list',{})['items'][0]['id']==row['id']
        shelf.handle('shelf-remove',{'id':row['id']})
        assert source.read_text()=='Hello shelf'
        assert not shelf.handle('shelf-list',{})['items']
        assert Store('shelf').path.stat().st_mode&0o777==0o600
        link=temp/'link';link.symlink_to(source)
        try:read_file(link);raise AssertionError('symlink accepted')
        except OSError:pass
        huge=temp/'huge';huge.write_bytes(b'a'*100)
        try:read_file(huge,50);raise AssertionError('oversized file accepted')
        except ValueError:pass
        try:shelf.handle('shelf-add',{'urls':['https://example.com/a']});raise AssertionError('remote file accepted')
        except ValueError:pass
        now=dt.datetime(2026,9,29,9,tzinfo=dt.timezone.utc)
        ics=b'BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART:20260929T100000Z\nDTEND:20260929T110000Z\nSUMMARY:Daily review\nRRULE:FREQ=DAILY;COUNT=3\nEXDATE:20260930T100000Z\nURL:https://example.com/meeting\nEND:VEVENT\nEND:VCALENDAR'
        events,partial=calendar.parse(ics,now)
        assert len(events)==2 and partial==0
        assert events[0]['start']==int(dt.datetime(2026,9,29,10,tzinfo=dt.timezone.utc).timestamp()*1000)
        assert calendar.date('20261101T100000',{'TZID':'America/New_York'}).utcoffset()==dt.timedelta(hours=-5)
        try:calendar.parse(b'garbage',now);raise AssertionError('invalid calendar accepted')
        except ValueError:pass
        lyr=temp/'song.lrc';lyr.write_text('[00:01.50]One\n[00:03]Two\n')
        assert media.lyrics(str(lyr))['lyrics'][0]=={'time':1.5,'text':'One'}
        for url in ('http://example.com/a','https://127.0.0.1/a','https://user:pass@example.com/a'):
            try:media.artwork(url);raise AssertionError('unsafe artwork accepted')
            except (ValueError,OSError):pass
        assert process.run([sys.executable,'-c','print("ok")']).strip()=='ok'
        for code,timeout in [('print("x"*5000)',2),('import time; time.sleep(5)',0.1)]:
            start=time.monotonic()
            try:process.run([sys.executable,'-c',code],timeout=timeout,limit=1024);raise AssertionError('bound not enforced')
            except ValueError:pass
            assert time.monotonic()-start<3
        persisted={'rows':[{'key':'session.1','title':'hello','actions':[{'id':'bad'}],'reply':True,'unread':True}],'dnd':True,'blocked':['Chat']}
        response=call('companions/notifications/store.py','write',input=json.dumps(persisted));assert json.loads(response.stdout)['ok']
        restored=json.loads(call('companions/notifications/store.py','read').stdout)
        assert restored['dnd'] and restored['blocked']==['Chat']
        assert restored['rows'][0]['actions']==[] and restored['rows'][0]['reply'] is False
        path=Store('notifications').path;path.write_text('broken')
        assert json.loads(call('companions/notifications/store.py','read').stdout)['ok'] is False
        assert path.read_text()=='broken'
        fake=temp/'bin';fake.mkdir();shell=fake/'omarchy-shell'
        shell.write_text('#!/bin/sh\nprintf "ok\\n"\n');shell.chmod(0o755)
        with patch.dict(os.environ,{'PATH':str(fake)+':'+os.environ['PATH']}):
            dest=temp/'copied.txt'
            assert call('scripts/perch-task','copy',str(source),str(dest)).returncode==0
            assert dest.read_text()==source.read_text()
            assert call('scripts/perch-task','copy',str(source),str(dest)).returncode==1
            assert call('scripts/perch-task','--max-bytes','2','copy',str(source),str(temp/'too-big')).returncode==1
            assert not list(temp.glob('.perch-transfer-*'))
            class Handler(http.server.BaseHTTPRequestHandler):
                def do_GET(self):
                    self.send_response(200)
                    self.send_header('Content-Length','50' if self.path=='/truncated' else '5')
                    self.end_headers();self.wfile.write(b'hello')
                def log_message(self,*args):pass
            server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
            thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
            try:
                base='http://127.0.0.1:'+str(server.server_port)
                target=temp/'downloaded'
                assert call('scripts/perch-task','download',base+'/ok',str(target)).returncode==0
                assert target.read_bytes()==b'hello'
                outcome=call('scripts/perch-task','download',base+'/truncated',str(temp/'incomplete'))
                assert outcome.returncode==1 and 'Traceback' not in outcome.stderr
                assert not (temp/'incomplete').exists() and not list(temp.glob('.perch-transfer-*'))
            finally:server.shutdown();server.server_close();thread.join()
            assert call('scripts/perch-task','run','--',sys.executable,'-c','raise SystemExit(7)').returncode==7
            assert call('scripts/perch-task','--timeout','1','run','--',sys.executable,'-c','import time;time.sleep(20)').returncode==130
print('rc3: private durable shelf/history, calendar recurrence/timezone, lyrics/artwork bounds, helper timeout/output limits and task cleanup passed.')
