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
