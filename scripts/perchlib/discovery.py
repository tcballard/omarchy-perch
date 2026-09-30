"""Opt-in, bounded transcript metadata discovery. Never return message content."""
import hashlib
import json
import os
from pathlib import Path
import stat
import time
from .sessions import codex_handler, THREAD


def candidates(base, now):
    pending=[(base,0)]; found=[]; seen=0
    while pending and seen < 4096:
        directory,depth=pending.pop()
        try:
            if directory.is_symlink():continue
            with os.scandir(directory) as entries:
                for entry in entries:
                    seen+=1
                    if seen>4096:break
                    if entry.is_symlink():continue
                    if entry.is_dir(follow_symlinks=False) and depth<4:
                        pending.append((Path(entry.path),depth+1))
                    elif entry.is_file(follow_symlinks=False) and entry.name.endswith('.jsonl'):
                        info=entry.stat(follow_symlinks=False)
                        if now-86400<=info.st_mtime<=now+60 and info.st_uid==os.getuid():
                            found.append((info.st_mtime,Path(entry.path)))
        except OSError:continue
    return sorted(found,reverse=True)[:24]


def metadata(path,agent):
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    try:
        info=os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid!=os.getuid():return None
        with os.fdopen(fd,'rb',closefd=False) as stream:
            raw=stream.read(65536)
        for line in raw.splitlines()[:32]:
            try:data=json.loads(line)
            except (ValueError,UnicodeDecodeError):continue
            if not isinstance(data,dict):continue
            if agent=='codex':
                if data.get('type')!='session_meta':continue
                data=data.get('payload')
                if not isinstance(data,dict):continue
                session=data.get('id')
            elif agent in ('pi','omp'):
                if data.get('type')!='session':continue
                session=data.get('id')
            else:session=data.get('sessionId')
            cwd=data.get('cwd')
            if isinstance(session,str) and 0<len(session)<=4096 and isinstance(cwd,str) and cwd.startswith('/') and len(cwd)<=4096:
                return session,cwd
    finally:os.close(fd)
    return None


def discover(now=None):
    now=time.time() if now is None else now
    home=Path.home()
    roots=[('claude',Path(os.environ.get('CLAUDE_CONFIG_DIR',str(home/'.claude')))/'projects'),
        ('codex',Path(os.environ.get('CODEX_HOME',str(home/'.codex')))/'sessions'),
        ('pi',home/'.pi/agent/sessions'),('omp',home/'.omp/agent/sessions')]
    labels={'claude':'Claude','codex':'Codex','pi':'Pi','omp':'Oh My Pi'}
    rows=[]
    try:handler=codex_handler()
    except (OSError,ValueError):handler=''
    for agent,base in roots:
        for modified,path in candidates(base,now):
            try:pair=metadata(path,agent)
            except (OSError,ValueError,RecursionError):continue
            if not pair:continue
            session,cwd=pair
            row={'id':agent+'.'+hashlib.sha256(session.encode()).hexdigest()[:20],
                'kind':'agent','agent':labels[agent],'title':Path(cwd).name[:100] or labels[agent],
                'project':Path(cwd).name[:100], 'updatedAt':min(modified,now)*1000}
            if agent=='codex' and handler and THREAD.fullmatch(session):
                row['targetCodex']={'thread':session.lower(),'handler':handler}
            rows.append(row)
    unique={}
    for row in sorted(rows,key=lambda r:r['updatedAt'],reverse=True):unique.setdefault(row['id'],row)
    return {'sessions':list(unique.values())[:8]}
