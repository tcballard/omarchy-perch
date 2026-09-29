import copy
import json
import sys
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from perchlib import cards

sample = dict(version=1, revision='r1', status='ready', title='Notes', summary='<b>plain</b>',
              actions=[dict(id='refresh', label='Refresh')],
              rows=[dict(id='one', title='A note', detail='Local', action=dict(id='open:0', label='Read'))])
clean = cards.normalize(dict(sample, command='rm -rf', url='file:///etc/passwd'))
assert 'command' not in clean and 'url' not in clean and clean['summary'] == '<b>plain</b>'
for updates in [dict(version=True),dict(version=2),dict(revision='../bad'),dict(rows=[{}]),dict(actions=[dict(id='x;id',label='Bad')]),dict(actions=[dict(id='refresh',label='a')]*2),dict(rows=sample['rows']*9),dict(status='unknown')]:
    try: cards.normalize(dict(sample, **updates))
    except ValueError: pass
    else: raise AssertionError(updates)

installed=[dict(id='example.notes',enabled=True)]
with patch.object(cards.plugins,'catalog',return_value=installed):
    with patch.object(cards,'run',return_value=json.dumps(sample)) as run:
        assert cards.handle('card-read',{'id':'example.notes'})['card']==clean
        run.assert_called_once_with(['omarchy-shell','example.notes','perchCard'],timeout=2,limit=32768)
    for payload in [dict(action='unknown',revision='r1'),dict(action='open:0',revision='old')]:
        with patch.object(cards,'run',return_value=json.dumps(sample)) as run:
            try: cards.handle('card-action',dict(id='example.notes',**payload))
            except ValueError: pass
            else: raise AssertionError(payload)
            assert run.call_count==1  # Never executes stale/unadvertised actions.
    with patch.object(cards,'run',side_effect=[json.dumps(sample),'{"ok":true}',json.dumps(sample)]) as run:
        assert cards.handle('card-action',dict(id='example.notes',action='open:0',revision='r1'))['message']=='Action completed'
        argv=run.call_args_list[1].args[0]
        assert argv[:3]==['omarchy-shell','example.notes','perchAction']
        assert json.loads(argv[3])==dict(version=1,revision='r1',action='open:0')
    with patch.object(cards,'run',side_effect=[json.dumps(sample),'{"ok":true}',ValueError('offline')]):
        assert cards.handle('card-action',dict(id='example.notes',action='open:0',revision='r1'))['card'] is None
    installed[0]['enabled']=False
    with patch.object(cards,'run') as run:
        try: cards.handle('card-read',{'id':'example.notes'})
        except ValueError: pass
        else: raise AssertionError('disabled')
        run.assert_not_called()
print('Native cards: bounded schema, fixed IPC, stale actions and disabled plugins passed.')
