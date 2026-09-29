#!/usr/bin/env python3
"""Exercise the explicit helper with a fake IPC executable, never the live shell."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as directory:
    folder=Path(directory)
    log=folder/'argv.json'
    fake=folder/'omarchy-shell'
    fake.write_text('#!/usr/bin/env python3\nimport json,os,sys\nopen(os.environ["PERCH_TEST_LOG"],"w").write(json.dumps(sys.argv[1:]))\nprint("error: rejected" if os.environ.get("PERCH_TEST_FAIL") else "ok")\n')
    fake.chmod(0o755)
    env={**os.environ,'PATH':str(folder)+os.pathsep+os.environ['PATH'],'PERCH_TEST_LOG':str(log)}
    title='literal $(not-a-command) `text` "quotes"'
    result=subprocess.run([str(root/'scripts/perch-activity'),'build','--title',title,'--progress','0.5'],env=env,capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    args=json.loads(log.read_text())
    assert args[:2]==['io.github.tcballard.perch','activity']
    assert json.loads(args[2])['title']==title
    assert json.loads(args[2])['progress']==0.5
    result=subprocess.run([str(root/'scripts/perch-activity'),'build','--dismiss'],env=env,capture_output=True,text=True)
    assert result.returncode==0
    assert json.loads(log.read_text())==['io.github.tcballard.perch','dismiss','build']
    result=subprocess.run([str(root/'scripts/perch-activity'),'build'],env={**env,'PERCH_TEST_FAIL':'1'},capture_output=True,text=True)
    assert result.returncode==1
    result=subprocess.run([str(root/'examples/build-with-perch.sh'),'python3','-c','raise SystemExit(7)'],env=env,capture_output=True,text=True)
    assert result.returncode==7
    assert json.loads(json.loads(log.read_text())[2])['state']=='error'
print('Activity helper argument quoting, rejection and wrapped exit status passed.')
