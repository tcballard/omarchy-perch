#!/usr/bin/env python3
import json,os,sys,tempfile,time
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from perchlib import discovery as D
with tempfile.TemporaryDirectory() as d:
    home=Path(d);now=time.time()
    for agent,folder in [('claude','.claude/projects/proj'),('codex','.codex/sessions/2026/09/30'),('pi','.pi/agent/sessions/proj')]:
        path=home/folder;path.mkdir(parents=True)
        data={'type':'session','id':'one','cwd':'/work/perch','message':'PRIVATE'} if agent=='pi' else {'type':'session_meta','payload':{'id':'one','cwd':'/work/perch','prompt':'PRIVATE'}} if agent=='codex' else {'sessionId':'one','cwd':'/work/perch','message':'PRIVATE'}
        (path/'recent.jsonl').write_text(json.dumps(data)+'\n')
        (path/'old.jsonl').write_text(json.dumps(data));os.utime(path/'old.jsonl',(now-90000,now-90000))
        (path/'link.jsonl').symlink_to(path/'recent.jsonl')
    with patch.object(Path,'home',return_value=home),patch.dict(os.environ,{'CODEX_HOME':str(home/'.codex'),'CLAUDE_CONFIG_DIR':str(home/'.claude')}):
        result=D.discover(now+1)
    assert len(result['sessions'])==3 and 'PRIVATE' not in json.dumps(result)
    assert all('target' not in row and 'state' not in row for row in result['sessions'])
    huge=home/'huge.jsonl';huge.write_text('x'*65536+'\n'+json.dumps({'sessionId':'bad','cwd':'/work'}))
    assert D.metadata(huge,'claude') is None
print('Session discovery bounds, metadata-only output, age filtering and symlink exclusion passed.')
