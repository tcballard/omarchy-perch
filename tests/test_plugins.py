import json
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from perchlib import plugins

rows = [dict(id='example.notes',name='Notes',enabled=True,firstParty=False,kinds=['panel']),
        dict(id='example.disabled',name='Disabled',enabled=False,firstParty=False,kinds=['overlay']),
        dict(id='example.service',name='Service',enabled=True,firstParty=False,kinds=['service']),
        dict(id=plugins.SELF,name='Perch',enabled=True,firstParty=False,kinds=['panel']),
        dict(id='omarchy.lock',name='Lock',enabled=True,firstParty=True,kinds=['overlay']),
        dict(id='../bad;id',name='Bad',enabled=True,firstParty=False,kinds=['panel'])]
calls = []
def run(argv, **kwargs):
    calls.append(argv)
    return json.dumps(rows) if argv[-1] == 'listPlugins' else 'ok\n'
plugins.run = run
assert [p['id'] for p in plugins.catalog()] == ['example.disabled','example.notes']
assert plugins.handle('plugin-open', {'id':'example.notes'})['message'] == 'Opened Notes'
assert calls[-1] == ['omarchy-shell','shell','summon','example.notes','{}']
for id in ['example.disabled','example.service',plugins.SELF,'omarchy.lock','../bad;id','example.missing']:
    before = len([x for x in calls if 'summon' in x])
    try: plugins.handle('plugin-open', {'id': id})
    except ValueError: pass
    else: raise AssertionError(id)
    assert len([x for x in calls if 'summon' in x]) == before
# Removal and disable after discovery must be rechecked at activation.
rows[0]['enabled'] = False
try: plugins.handle('plugin-open', {'id':'example.notes'})
except ValueError: pass
else: raise AssertionError('stale enabled state')
rows.pop(0)
try: plugins.handle('plugin-open', {'id':'example.notes'})
except ValueError: pass
else: raise AssertionError('stale installed state')
plugins.run = lambda *a, **kw: '{}'
try: plugins.catalog()
except ValueError: pass
else: raise AssertionError('malformed catalog')
print('Plugin pins: catalog filtering, argv launch, stale state and invalid target rejection passed.')
