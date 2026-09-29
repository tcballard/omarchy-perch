#!/usr/bin/env python3
"""Private bounded notification history. Never restore executable actions."""
import json,os,re,stat,sys,tempfile
from pathlib import Path
root=Path(os.environ.get('XDG_STATE_HOME',str(Path.home()/'.local/state')))/'omarchy-perch'
try:
 root.mkdir(parents=True,exist_ok=True,mode=0o700)
 if root.is_symlink() or root.stat().st_uid!=os.getuid():raise ValueError('Unsafe history directory')
 os.chmod(root,0o700)
 path=root/'notifications.json'
 if sys.argv[1]=='read':
  try:
   fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
   with os.fdopen(fd,'rb') as f:
    st=os.fstat(f.fileno())
    if not stat.S_ISREG(st.st_mode) or st.st_size>131072:raise ValueError('Invalid history file')
    raw=f.read(131073)
    if len(raw)>131072:raise ValueError('History too large')
    data=json.loads(raw)
  except FileNotFoundError:data={'rows':[],'dnd':False,'blocked':[]}
 elif sys.argv[1]=='write':
  raw=sys.stdin.buffer.read(131073)
  if len(raw)>131072:raise ValueError('History too large')
  data=json.loads(raw)
 else:raise ValueError('Unknown history operation')
 if not isinstance(data,dict) or not isinstance(data.get('rows'),list) or len(data['rows'])>20:raise ValueError('Invalid history')
 rows=[]
 for row in data['rows']:
  if not isinstance(row,dict) or not re.fullmatch(r'[A-Za-z0-9._:-]{1,100}',str(row.get('key',''))):continue
  rows.append({k:str(row.get(k,''))[:limit] for k,limit in [('key',100),('app',64),('title',120),('body',400),('icon',100)]}|{'actions':[],'reply':False,'unread':row.get('unread') is True})
 data={'rows':rows,'dnd':data.get('dnd') is True,'blocked':[str(x)[:64] for x in (data.get('blocked',[]) if isinstance(data.get('blocked',[]),list) else [])[:64]]}
 if sys.argv[1]=='write':
  fd,tmp=tempfile.mkstemp(prefix='.history-',dir=root)
  try:
   with os.fdopen(fd,'w') as out:json.dump(data,out);out.flush();os.fsync(out.fileno())
   os.replace(tmp,path)
  finally:
   if os.path.exists(tmp):os.unlink(tmp)
  print('{"ok":true}')
 else:print(json.dumps({'ok':True,**data}))
except (OSError,ValueError,TypeError,KeyError,IndexError,RecursionError):print('{"ok":false,"error":"History unavailable; existing file preserved"}')
