#!/usr/bin/env python3
from unittest.mock import patch
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from perchlib import sessions

for bad in ('', '123', '0x', '0x123;notify-send bad', 'address:0x123'):
    try:
        sessions.handle('agent-jump', {'address':bad})
        raise AssertionError('invalid address accepted')
    except ValueError:
        pass

with patch.object(sessions.shutil,'which',return_value='/usr/bin/hyprctl'), patch.object(sessions,'run',side_effect=['[{"address":"0xabc123"}]', 'ok']) as execute:
    result=sessions.handle('agent-jump',{'address':'0xabc123'})
    assert result['message']=='Returned to session'
    assert execute.call_count == 2
    execute.assert_called_with(['hyprctl','dispatch','focuswindow','address:0xabc123'],timeout=1,limit=4096)

for clients, reply in [('[]', 'ok'), ('{}', 'ok'), ('[{"address":"0xabc123"}]', 'Window not found')]:
    with patch.object(sessions.shutil,'which',return_value='/usr/bin/hyprctl'), patch.object(sessions,'run',side_effect=[clients,reply]) as execute:
        try:
            sessions.handle('agent-jump', {'address':'0xabc123'})
            raise AssertionError('stale or rejected target accepted')
        except ValueError:
            pass
        if clients in ('[]','{}'):
            assert execute.call_count == 1

print('Agent session jump validates one Hyprland address and uses fixed argv.')
boot=Path('/proc/sys/kernel/random/boot_id').read_text().strip()
with patch.object(sessions, 'process_start', return_value='100'):
    rows=[{'id':'session.'+str(i),'pid':100+i,'start':'100','boot':boot} for i in range(32)]
    assert sessions.liveness(rows)['ended']==[]
    try:
        sessions.liveness(rows+[rows[0]])
        raise AssertionError('Unbounded liveness batch accepted')
    except ValueError:
        pass
for pid, saved_boot, start, succeeds in [(123,boot,"100",True),(124,boot,"100",False),(123,"old-boot","100",False),(123,boot,"999",False),(123,boot,"",False)]:
    with patch.object(sessions,'process_start',return_value='100'), patch.object(sessions.shutil,'which',return_value='/usr/bin/hyprctl'), patch.object(sessions,'run',side_effect=['[{"address":"0xabc123","pid":123}]','ok']) as execute:
        try:
            sessions.handle('agent-jump', {'address':'0xabc123','targetPid':pid,'targetBoot':saved_boot,'targetStart':start})
            assert succeeds
        except ValueError:
            assert not succeeds
        assert execute.call_count == (2 if succeeds else 1)
print('Recovered session PID and boot identity checked before focus.')

thread='12345678-1234-1234-1234-123456789abc'
for current,ident,ok in [('codex.desktop',thread,True),('other.desktop',thread,False),('',thread,False),('codex.desktop','new?prompt=bad',False),('codex.desktop',thread+'?host=remote',False)]:
    with patch.object(sessions,'codex_handler',return_value=current),patch.object(sessions,'launch') as launch:
        try:sessions.handle('agent-codex-open',{'targetCodex':{'thread':ident,'handler':'codex.desktop'}});assert ok
        except ValueError:assert not ok
        if ok:launch.assert_called_once_with(['xdg-open','codex://threads/'+thread])
        else:launch.assert_not_called()
print('Codex desktop return accepts only a local UUID and the unchanged registered handler.')

# tmux commands target a captured pane and a specific attached client; no keystrokes.
import os
import stat
from types import SimpleNamespace
import runpy
hook = runpy.run_path(str(ROOT/'scripts/perch-agent-hook'))
tmux = {'socket':'/tmp/tmux-1000/default','pane':'%3','panePid':123,
        'paneStart':'100','client':'/dev/pts/2','clientPid':456,'clientStart':'200'}
for pane_pid, client_line, starts, ok in [
    ('123','456 /dev/pts/2',['100','200'],True),
    ('124','456 /dev/pts/2',['100','200'],False),
    ('123','457 /dev/pts/2',['100','200'],False),
    ('123','456 /dev/pts/2',['999'],False),
]:
    with patch.object(sessions.os,'lstat',return_value=SimpleNamespace(st_mode=stat.S_IFSOCK|0o600,st_uid=os.getuid())), patch.object(sessions.shutil,'which',return_value='/usr/bin/tmux'), patch.object(sessions,'process_start',side_effect=starts), patch.object(sessions,'run',side_effect=[pane_pid,client_line,'']) as execute:
        try:
            sessions.select_tmux(tmux)
            assert ok
        except ValueError:
            assert not ok
        if ok:
            assert execute.call_args.args[0] == ['tmux','-S',tmux['socket'],'switch-client','-c','/dev/pts/2','-t','%3']
        else:
            assert not any('switch-client' in call.args[0] for call in execute.call_args_list)

namespace=hook['tmux_target'].__globals__
for rows, expected in [('456 /dev/pts/2 $1',True),('456 /dev/pts/2 $1\n789 /dev/pts/4 $1',False),('456 /dev/pts/2 $2',False)]:
    answers=[SimpleNamespace(returncode=0,stdout=b'123 $1'),SimpleNamespace(returncode=0,stdout=rows.encode())]
    with patch.dict(os.environ,TMUX='/tmp/tmux-1000/default,50,0',TMUX_PANE='%3'), patch.object(os,'lstat',return_value=SimpleNamespace(st_mode=stat.S_IFSOCK|0o600,st_uid=os.getuid())), patch.dict(namespace,parent_pids=lambda pid:[123,999],process_start=lambda pid:'100'), patch.object(namespace['subprocess'],'run',side_effect=answers):
        result=hook['tmux_target']([{'address':'0xabc','pid':999}])
        assert bool(result) == expected
        if expected:assert result['targetTmux']['pane'] == '%3'
print('tmux pane/client identities, PID reuse and ambiguous attached-terminal rejection passed.')

wez={'socket':'/tmp/wezterm.sock','pane':3,'device':'1','inode':'2','windowStart':'100'}
for rows,ino,start,ok in [('[{"pane_id":3}]',2,'100',True),('[]',2,'100',False),('[{"pane_id":3}]',3,'100',False),('[{"pane_id":3}]',2,'999',False)]:
    with patch.object(sessions.os,'lstat',return_value=SimpleNamespace(st_mode=stat.S_IFSOCK|0o600,st_uid=os.getuid(),st_dev=1,st_ino=ino)),patch.object(sessions,'process_start',return_value=start),patch.object(sessions.shutil,'which',return_value='/usr/bin/wezterm'),patch.object(sessions,'run',side_effect=[rows,'']) as execute:
        try:sessions.select_wezterm(wez,123);assert ok
        except ValueError:assert not ok
        if ok:assert execute.call_args.args[0]==['env','WEZTERM_UNIX_SOCKET=/tmp/wezterm.sock','wezterm','cli','activate-pane','--pane-id','3']
        else:assert not any('activate-pane' in c.args[0] for c in execute.call_args_list)
print('WezTerm verifies instance socket, window process start and live pane before fixed-argv activation.')

with __import__('tempfile').TemporaryDirectory() as d:
    target={'app':'code','path':d,'pid':123,'start':'100','boot':boot}
    with patch.object(sessions,'process_start',return_value='100'),patch.object(sessions.os,'readlink',return_value='/opt/code/code'),patch.object(sessions,'launch') as launch:
        assert sessions.open_workspace(target)['message']=='Opened session workspace'
        launch.assert_called_once_with(['code',d])
    for patch_target in [dict(target,app='bash'),dict(target,path='--execute'),dict(target,boot='old')]:
        with patch.object(sessions,'launch') as launch:
            try:sessions.open_workspace(patch_target);raise AssertionError('invalid workspace accepted')
            except ValueError:pass
            launch.assert_not_called()
print('Workspace return restricts editor commands, verifies process identity and passes only an existing absolute folder.')

for start,expected in [('100',[]),('101',['codex.one'])]:
    with patch.object(sessions,'process_start',return_value=start):
        assert sessions.liveness([{'id':'codex.one','pid':123,'start':'100','boot':boot}])['ended']==expected
for error,expected in [(FileNotFoundError(),['codex.one']),(PermissionError(),[])]:
    with patch.object(sessions,'process_start',side_effect=error):
        assert sessions.liveness([{'id':'codex.one','pid':123,'start':'100','boot':boot}])['ended']==expected
print('Session liveness distinguishes exit/PID reuse from unreadable process identity.')
