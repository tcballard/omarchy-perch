"""Read only local usage counters; never return transcript text or credentials."""
import datetime
import json
import math
import os
from pathlib import Path
import stat
import time
from .storage import Store, read_file


def windows(raw, codex=False):
    if not isinstance(raw, dict): return []
    result=[]
    for name,label,minutes in [('primary','5h',300),('secondary','7d',10080)] if codex else [('five_hour','5h',300),('seven_day','7d',10080)]:
        row=raw.get(name)
        if not isinstance(row,dict):continue
        value=row.get('used_percent' if codex else 'used_percentage')
        if isinstance(value,bool) or not isinstance(value,(int,float)) or not math.isfinite(value) or not 0<=value<=100:continue
        reset=row.get('resets_at')
        if isinstance(reset,bool) or not isinstance(reset,(int,float)) or not math.isfinite(reset) or reset<0:reset=None
        duration=row.get('window_minutes',minutes)
        if isinstance(duration,(int,float)) and not isinstance(duration,bool) and math.isfinite(duration) and 0<duration<=525600:
            label=(str(int(duration/60))+'h') if duration%60==0 else str(int(duration))+'m'
            if duration%1440==0:label=str(int(duration/1440))+'d'
        result.append({'label':label,'used':value,'resetsAt':reset})
    return result


def tail(path, limit=262144):
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    with os.fdopen(fd,'rb') as f:
        info=os.fstat(f.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid!=os.getuid():raise ValueError('Unreadable usage source')
        offset=max(0,info.st_size-limit);f.seek(offset)
        data=f.read(limit)
        if offset:data=data.partition(b'\n')[2]
        return data,info.st_mtime


def codex():
    base=Path(os.environ.get('CODEX_HOME',str(Path.home()/'.codex')))/'sessions'
    candidates=[]
    # Fixed-depth year/month/day layout, newest paths first, with bounded enumeration.
    import itertools
    def dirs(path):
        return sorted([p for p in itertools.islice(path.iterdir(),500) if p.is_dir() and not p.is_symlink()],reverse=True) if path.is_dir() and not path.is_symlink() else []
    for year in dirs(base)[:2]:
        for month in dirs(year)[:3]:
            for day in dirs(month)[:10]:
                for p in itertools.islice(day.glob('*.jsonl'),128):
                    if not p.is_symlink():candidates.append(p)
                if len(candidates)>=256:break
            if len(candidates)>=256:break
        if len(candidates)>=256:break
    newest=None
    for p in sorted(candidates,key=lambda p:p.stat().st_mtime,reverse=True)[:12]:
        try:
            raw,modified=tail(p)
            for line in reversed(raw.splitlines()):
                try:row=json.loads(line)
                except (ValueError,UnicodeError):continue
                if not isinstance(row,dict) or row.get('type')!='event_msg':continue
                payload=row.get('payload',{})
                if not isinstance(payload,dict) or payload.get('type')!='token_count':continue
                data=windows(payload.get('rate_limits'),True)
                if not data:continue
                try:observed=datetime.datetime.fromisoformat(row.get('timestamp','').replace('Z','+00:00')).timestamp()
                except (ValueError,TypeError):observed=modified
                if not newest or observed>newest['updatedAt']:newest={'windows':data,'updatedAt':observed}
                break
        except (OSError,ValueError):continue
    return newest


def snapshot():
    sources=[]
    for name in ('Codex','Claude'):
        try:
            if name=='Codex':data=codex()
            else:
                value=Store('usage-claude').load({})
                data={'windows':windows(value.get('rate_limits')),'updatedAt':value.get('updatedAt',0)}
            if not data or not data['windows']:sources.append({'name':name,'windows':[],'status':'No local usage available'});continue
            stamp=data['updatedAt']
            if isinstance(stamp,bool) or not isinstance(stamp,(int,float)) or not math.isfinite(stamp):stamp=0
            sources.append({'name':name,'windows':data['windows'],'updatedAt':stamp,'status':'Stale snapshot' if time.time()-stamp>900 else 'Local snapshot'})
        except (OSError,ValueError,TypeError,AttributeError):sources.append({'name':name,'windows':[],'status':'Local usage unavailable'})
    return {'sources':sources}
