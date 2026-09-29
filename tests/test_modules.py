import importlib.util
import json
import math
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch, Mock
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from perchlib import modules
from perchlib.process import run

with tempfile.TemporaryDirectory() as folder:
    home = Path(folder)
    history = home / '.local/state/omarchy/clipboard-history.json'
    history.parent.mkdir(parents=True)
    rows = [{'type': 'text', 'text': 'alpha'}, {'type': 'text', 'text': 'https://example.org'}, {'type': 'image', 'path': str(home / 'test.png'), 'mime': 'image/png'}]
    history.write_text(json.dumps(rows))
    with patch.object(Path, 'home', return_value=home):
        result = modules.clipboard_list({})
        assert result['count'] == 3
        assert [x['kind'] for x in result['rows']] == ['text', 'link', 'image']
        assert len(modules.clipboard_list({'kind':'link'})['rows']) == 1
        selected = result['rows'][0]['id']
        history.write_text(json.dumps([{'type': 'text', 'text': 'new'}] + rows))
        with patch.object(modules, 'copy_bytes', return_value=None) as command:
            modules.clipboard_copy({'id':selected})
            assert command.call_args.args[1] == b'alpha'
            assert command.call_args.args[0] == 'text/plain;charset=utf-8'
        history.write_text('[]')
        try: modules.clipboard_copy({'id':selected}); assert False
        except ValueError: pass
        history.write_bytes(b'x' * (modules.HISTORY_LIMIT + 1))
        try: modules.clipboard_list({}); assert False
        except ValueError: pass
        history.unlink(); target = home / 'elsewhere'; target.write_text('[]'); history.symlink_to(target)
        try: modules.clipboard_list({}); assert False
        except OSError: pass

for point in ({'latitude':91,'longitude':0},{'latitude':True,'longitude':0},{'latitude':math.nan,'longitude':0}):
    try: modules.weather(point); assert False
    except ValueError: pass
response = {'current': {'temperature_2m':18,'weather_code':2,'wind_speed_10m':12}, 'hourly': {'time':['2026-09-29T16:00'],'temperature_2m':[18]}}
with patch.object(modules, 'run', return_value=json.dumps(response)) as command:
    assert modules.weather({'latitude':51.5,'longitude':-0.1})['weather']['temperature'] == 18
    argv = command.call_args.args[0]
    assert argv[-1].startswith('https://api.open-meteo.com/v1/forecast?')
    assert '--max-filesize' in argv and '--location' not in argv
with patch.object(modules, 'run', return_value='{"current":{"temperature_2m":null}}'):
    try: modules.weather({'latitude':0,'longitude':0}); assert False
    except ValueError: pass
sample = modules.stats()['sample']
assert sample['total'] >= sample['idle'] >= 0
assert 0 <= sample['memory'] <= 100 and 0 <= sample['disk'] <= 100
print('Native module adapters: clipboard identity/races and bounds, fixed weather endpoint/validation, live Linux statistics passed.')

# Successful clipboard owners survive the helper; a hung parent is terminated.
child = Mock(); child.wait.return_value = 0
with patch.object(modules.subprocess, 'Popen', return_value=child) as spawn, patch.object(modules.os, 'killpg') as kill:
    modules.copy_bytes('text/plain', b'hello')
    assert spawn.call_args.args[0] == ['/usr/bin/wl-copy', '--type', 'text/plain']
    kill.assert_not_called()
child.wait.side_effect = [modules.subprocess.TimeoutExpired('wl-copy', 3), 0]
with patch.object(modules.subprocess, 'Popen', return_value=child), patch.object(modules.os, 'killpg') as kill:
    try: modules.copy_bytes('text/plain', b'hello'); assert False
    except ValueError: pass
    kill.assert_called_once()

from perchlib import apps
with patch.object(apps,'launch') as launch:
    apps.handle('app-link',{'url':'https://example.org/?a=1&b=2'})
    assert launch.call_args.args[0] == ['xdg-open','https://example.org/?a=1&b=2']
    for url in ['file:///etc/passwd','javascript:alert(1)','https://user:pass@example.org','https://example.org/ bad']:
        try: apps.handle('app-link',{'url':url}); assert False
        except ValueError: pass
