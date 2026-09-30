#!/usr/bin/env python3
from pathlib import Path
import sys
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from perchlib import updates as U
for dirty,branch,default,ok in [('', 'main','refs/remotes/origin/main',True),(' M README.md','main','refs/remotes/origin/main',False),('','feat/review','refs/remotes/origin/main',False)]:
    values=[dirty,branch,default,'ok'] if not dirty else [dirty]
    with patch.object(U,'availability',return_value='available'),patch.object(U,'run',side_effect=values) as run:
        try:U.apply();assert ok
        except ValueError:assert not ok
        if ok:run.assert_called_with(['omarchy-plugin-update',U.ID,'--yes'],timeout=75,limit=16384,detail=True)
        else:assert not any(c.args[0][0]=='omarchy-plugin-update' for c in run.call_args_list)
with patch.object(U,'availability',return_value='manual install'),patch.object(U,'run') as run:
    try:U.apply();raise AssertionError('manual install updated')
    except ValueError:pass
    run.assert_not_called()
print('Host updates reject development installs, dirty trees and custom branches; updater targets only Perch.')
