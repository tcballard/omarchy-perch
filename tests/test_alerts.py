#!/usr/bin/env python3
"""Sound presets use fixed argv and expose missing helper feedback."""
import sys
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from perchlib.integrations import alarm
for preset in ['complete', 'message-new-instant', 'bell']:
    with patch('perchlib.integrations.shutil.which', return_value='/usr/bin/canberra-gtk-play'), patch('perchlib.integrations.run') as run:
        alarm({'sound': True, 'preset': preset})
        assert run.call_args.args[0] == ['canberra-gtk-play', '-i', preset]
with patch('perchlib.integrations.run') as run:
    try:
        alarm({'sound': True, 'preset': '$(touch unwanted)'})
        raise AssertionError('Unknown sound accepted')
    except ValueError:
        pass
    run.assert_not_called()
with patch('perchlib.integrations.shutil.which', return_value=None):
    assert 'unavailable' in alarm({'sound': True})['message']
print('Alert sound presets: fixed argv, unknown preset rejection and unavailable feedback passed.')
