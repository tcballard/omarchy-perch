#!/usr/bin/env python3
import json, os, runpy, subprocess, sys, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from perchlib import extensions
with tempfile.TemporaryDirectory() as tmp:
    env={**os.environ,'HOME':tmp,'XDG_CONFIG_HOME':tmp+'/.config'}
    env.pop('PI_CODING_AGENT_DIR',None)
    for agent,relative in [('pi','.pi/agent/extensions/perch-status.js'),('omp','.omp/agent/extensions/perch-status.js'),('opencode','.config/opencode/plugins/perch-status.js')]:
        args=[sys.executable,str(ROOT/'scripts/perch-extension-setup'),agent]
        path=Path(tmp)/relative
        assert subprocess.run(args,env=env,capture_output=True).returncode==0 and not path.exists()
        for _ in range(2):assert subprocess.run(args+['--apply'],env=env,capture_output=True).returncode==0
        assert path.read_text().startswith(extensions.MARKER)
        assert '__PERCH_' not in path.read_text()
        assert subprocess.run(args+['--apply','--remove'],env=env,capture_output=True).returncode==0 and not path.exists()
        path.write_text('unrelated')
        assert subprocess.run(args+['--apply'],env=env,capture_output=True).returncode!=0 and path.read_text()=='unrelated'
print('Extension preview, idempotent install, owned removal and unrelated-file preservation passed.')
