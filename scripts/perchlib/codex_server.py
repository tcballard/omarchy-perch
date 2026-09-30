"""Read-only snapshots from an explicitly selected, same-user Codex control socket."""
import hashlib
import json
import os
from pathlib import Path
import socket
import stat
import struct
import time
from .sessions import THREAD, codex_handler

ALLOWED={'initialize','thread/loaded/list','thread/read'}


def record(thread,handler=''):
    if not isinstance(thread,dict) or not isinstance(thread.get('id'),str) or not THREAD.fullmatch(thread['id']):return None
    if thread.get('parentThreadId'):return None
    status=thread.get('status')
    if not isinstance(status,dict):return None
    kind=status.get('type');flags=status.get('activeFlags',[])
    if kind=='notLoaded':return None
    if kind not in ('active','idle','notLoaded','systemError') or not isinstance(flags,list):return None
    state='running' if kind=='active' else 'error' if kind=='systemError' else 'idle'
    attention='attention'
    if kind=='active' and ('waitingOnApproval' in flags or 'waitingOnUserInput' in flags):
        state='waiting';attention='approval' if 'waitingOnApproval' in flags else 'question'
    cwd=thread.get('cwd','')
    project=Path(cwd).name[:100] if isinstance(cwd,str) and cwd.startswith('/') and len(cwd)<=4096 else ''
    row={'id':'codex.'+hashlib.sha256(thread['id'].encode()).hexdigest()[:20],
        'kind':'agent','agent':'Codex','title':project or 'Codex','project':project,'state':state,
        'detail':{'running':'Working in Codex','waiting':'Needs your attention in Codex','idle':'Idle in Codex','error':'Codex server reported an error'}[state],
        'attention':attention,'ttl':30,'serverSource':True}
    if handler:row['targetCodex']={'thread':thread['id'].lower(),'handler':handler}
    return row


class Reader:
    def __init__(self,connection,deadline):
        self.connection=connection;self.deadline=deadline;self.sequence=0;self.received=0

    def call(self,method,params):
        if method not in ALLOWED:raise ValueError('Unsupported observer operation')
        self.sequence+=1;ident=self.sequence
        self.connection.send(json.dumps({'id':ident,'method':method,'params':params}))
        for _ in range(64):
            remaining=self.deadline-time.monotonic()
            if remaining<=0:raise ValueError('Codex status snapshot timed out')
            raw=self.connection.recv(timeout=remaining)
            if not isinstance(raw,str) or len(raw)>65536:raise ValueError('Invalid Codex response')
            self.received+=len(raw.encode())
            if self.received>1048576:raise ValueError('Codex snapshot exceeded its receive limit')
            data=json.loads(raw)
            if not isinstance(data,dict):raise ValueError('Invalid Codex response')
            # Never become a responder to approval, login, attestation or tool requests.
            if 'method' in data and 'id' in data:raise ValueError('This server requested an interactive client; continue in Codex')
            if data.get('id')!=ident:continue
            if 'error' in data:raise ValueError('Codex rejected a read-only status request')
            result=data.get('result')
            if not isinstance(result,dict):raise ValueError('Invalid Codex result')
            return result
        raise ValueError('Too many unrelated Codex messages')

    def snapshot(self,handler=''):
        self.call('initialize',{'clientInfo':{'name':'perch-status-observer','version':'1.0'},
            'capabilities':{'experimentalApi':False,'requestAttestation':False}})
        self.connection.send(json.dumps({'method':'initialized'}))
        loaded=self.call('thread/loaded/list',{'limit':8}).get('data')
        if not isinstance(loaded,list) or len(loaded)>8:raise ValueError('Invalid loaded thread list')
        rows=[]
        for thread in loaded:
            if not isinstance(thread,str) or not THREAD.fullmatch(thread):continue
            data=self.call('thread/read',{'threadId':thread,'includeTurns':False})
            if not isinstance(data.get('thread'),dict) or data['thread'].get('id')!=thread:raise ValueError('Codex returned a different thread')
            row=record(data.get('thread'),handler)
            if row:rows.append(row)
        return {'sessions':rows}


def snapshot(payload):
    path=payload.get('path')
    if not isinstance(path,str) or not path.startswith('/') or len(path)>1024 or any(ord(c)<32 for c in path):
        raise ValueError('Choose an absolute local Codex control socket path')
    try:
        from websockets.sync.client import unix_connect
        from websockets.exceptions import WebSocketException
    except ImportError:raise ValueError('Install python-websockets (15 or newer) to read Codex server status')
    configured=Path(path);alias=configured.lstat();physical=configured.resolve(strict=True);info=physical.lstat()
    if alias.st_uid!=os.getuid() or not stat.S_ISSOCK(info.st_mode) or info.st_uid!=os.getuid() or stat.S_IMODE(info.st_mode)&0o077:
        raise ValueError('Codex status requires a private socket owned by your user')
    if len(os.fsencode(physical))>107:raise ValueError('The resolved Codex socket path is too long')
    try:handler=codex_handler()
    except (OSError,ValueError):handler=''
    try:
        with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as peer:
            peer.settimeout(1);peer.connect(str(physical))
            _,uid,_=struct.unpack('3i',peer.getsockopt(socket.SOL_SOCKET,socket.SO_PEERCRED,12))
            if uid!=os.getuid():raise ValueError('Codex socket owner changed')
            with unix_connect(sock=peer,uri='ws://localhost/',proxy=False,open_timeout=1,
                    close_timeout=.2,compression=None,ping_interval=None,max_size=65536,max_queue=4) as connection:
                return Reader(connection,time.monotonic()+4).snapshot(handler)
    except (WebSocketException,TimeoutError,TypeError):
        raise ValueError('Codex control socket is unavailable or incompatible; use an existing server and python-websockets 15 or newer')
