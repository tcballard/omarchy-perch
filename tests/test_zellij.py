import io,json,os,runpy,stat,sys
from contextlib import ExitStack
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from perchlib import sessions
boot=Path('/proc/sys/kernel/random/boot_id').read_text().strip()
target={'session':'work','pane':3,'socket':'/run/user/1000/zellij/protocol/work',
    'device':'1','inode':'2','serverPid':123,'serverStart':'100','boot':boot,
    'binary':'/usr/bin/zellij','binaryDevice':'1','binaryInode':'9'}
one='CLIENT_ID ZELLIJ_PANE_ID RUNNING_COMMAND\n1 terminal_3 vim'
panes='[{"id":3,"is_plugin":false,"exited":false}]'
for changes,clients,rows,ok in [({},one,panes,True),({},one+'\n2 terminal_4 bash',panes,False),({},'CLIENT_ID ZELLIJ_PANE_ID RUNNING_COMMAND',panes,False),({},one,'[]',False),({},one,'[{"id":3,"is_plugin":false,"exited":true}]',False),({'serverStart':'999'},one,panes,False),({'inode':'3'},one,panes,False),({'binaryInode':'10'},one,panes,False),({'pane':-1},one,panes,False),({'socket':'/run/user/1000/zellij/protocol/other'},one,panes,False)]:
    with ExitStack() as stack:
        stack.enter_context(patch.object(sessions,'process_start',return_value='100'))
        stack.enter_context(patch.object(sessions.os,'lstat',return_value=SimpleNamespace(st_mode=stat.S_IFSOCK|0o600,st_uid=os.getuid(),st_dev=1,st_ino=2)))
        stack.enter_context(patch.object(Path,'stat',return_value=SimpleNamespace(st_dev=1,st_ino=9)))
        stack.enter_context(patch.object(Path,'resolve',return_value=Path('/usr/bin/zellij')))
        stack.enter_context(patch.object(sessions.os,'readlink',return_value='/usr/bin/zellij'))
        stack.enter_context(patch.object(sessions.shutil,'which',return_value='/usr/bin/zellij'))
        stack.enter_context(patch('builtins.open',return_value=io.BytesIO(b'zellij\0--server\0/run/user/1000/zellij/protocol/work\0')))
        execute=stack.enter_context(patch.object(sessions,'run',side_effect=[clients,rows,'']))
        try:sessions.select_zellij({**target,**changes});assert ok
        except ValueError:assert not ok
        if ok:assert execute.call_args.args[0]==['env','ZELLIJ_SOCKET_DIR=/run/user/1000/zellij','zellij','--session','work','action','focus-pane-id','terminal_3']
        else:assert not any('focus-pane-id' in c.args[0] for c in execute.call_args_list)

hook=runpy.run_path(str(ROOT/'scripts/perch-agent-hook'));ns=hook['zellij_target'].__globals__
with patch.dict(os.environ,{'ZELLIJ_SESSION_NAME':'work','ZELLIJ_PANE_ID':'3'},clear=True),patch.dict(ns,parent_pids=lambda pid:[123],process_start=lambda pid:'100'),patch.object(os,'readlink',return_value='/usr/bin/zellij'),patch.object(Path,'lstat',return_value=SimpleNamespace(st_mode=stat.S_IFSOCK|0o600,st_uid=os.getuid(),st_dev=1,st_ino=2)),patch.object(Path,'stat',return_value=SimpleNamespace(st_dev=1,st_ino=9)),patch('builtins.open',return_value=io.BytesIO(b'zellij\0--server\0/run/user/1000/zellij/protocol/work\0')):
    assert hook['zellij_target']()=={'targetZellij':target}
    assert hook['hyprland_target']()=={} # The server's creator window is not its attached client.
    with patch.dict(os.environ,TMUX='/tmp/tmux,1,0'):assert hook['zellij_target']()=={}
print('Zellij selects only a live pane on the captured server with one attached client; stale or ambiguous targets never focus.')
