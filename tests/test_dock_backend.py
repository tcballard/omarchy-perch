#!/usr/bin/env python3
"""Real compiled helper, isolated state, fake compositor/provider processes."""
import json,os,subprocess,tempfile,time
from pathlib import Path
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='perch-dock-') as temp:
    home=Path(temp);fake=home/'bin';fake.mkdir()
    env={**os.environ,'HOME':temp,'XDG_STATE_HOME':str(home/'state'),'PATH':str(fake)+os.pathsep+os.environ['PATH']}
    def call(op,p={}):
        run=subprocess.run([str(root/'scripts/perch-tools'),op,json.dumps(p)],env=env,capture_output=True,text=True,timeout=15)
        assert run.returncode==0,run.stderr
        return json.loads(run.stdout)
    def good(op,p={}):
        result=call(op,p);assert result['ok'],(op,result);return result
    assert good('dock-reminders-list')['rows']==[]
    row=good('dock-reminders-add',{'title':'Ship Perch','list':'Work'})['rows'][0]
    assert good('dock-reminders-toggle',{'id':row['id'],'done':True})['rows'][0]['done']
    assert not good('dock-reminders-toggle',{'id':row['id'],'done':False})['rows'][0]['done']
    assert not call('dock-reminders-add',{'title':''})['ok']
    assert not call('dock-reminders-toggle',{'id':'missing','done':True})['ok']
    assert not call('dock-hydration-log',{'amount':-1})['ok']
    drink=good('dock-hydration-log',{'amount':250})['rows'][0]
    assert good('dock-hydration-remove',{'id':drink['id']})['rows']==[]
    assert len(good('dock-hydration-restore',{'entry':drink})['rows'])==1
    assert len(good('dock-hydration-restore',{'entry':drink})['rows'])==1
    assert not call('dock-hydration-restore',{'entry':{'id':'../bad','at':time.time(),'amount':100}})['ok']
    folder=home/'files';folder.mkdir();(folder/'notes.txt').write_text('keep original');(folder/'child').mkdir();(folder/'link').symlink_to('/etc')
    listing=good('dock-browse',{'path':str(folder)})
    assert [r['name'] for r in listing['rows']]==['child','notes.txt']
    scan=good('dock-storage',{'path':str(folder)})
    assert scan['scanned']>0 and (folder/'notes.txt').read_text()=='keep original'
    assert not call('dock-browse',{'path':'../invalid'})['ok']
    (fake/'hyprctl').write_text('''#!/usr/bin/env python3
import json,sys
if sys.argv[1:]==['-j','clients']:print(json.dumps([{'address':'0x123','mapped':True,'pid':321,'class':'editor','title':'Notes','workspace':{'name':'2'}}]))
elif sys.argv[1:]==['dispatch','focuswindow','address:0x123']:print('ok')
else:raise SystemExit(1)
''');(fake/'hyprctl').chmod(0o755)
    win=good('dock-windows')['rows'][0]
    assert good('dock-window-focus',win)['message']=='Window focused'
    assert not call('dock-window-focus',{'address':'0x123','pid':999})['ok']
    assert not call('dock-window-focus',{'address':'0x123;exec x','pid':321})['ok']
    assert not call('business-metrics',{'path':str(home/'missing'),'days':7,'currency':'GBP'})['ok']
    # Exercise the actual provider request boundary without accounts or network.
    (fake/'curl').write_text("""#!/usr/bin/env python3
import json,sys
config=sys.stdin.read()
assert sys.argv[1:]==['--disable','--config','-','--silent','--proto','=https','--max-time','7','--max-filesize','1048576','--write-out','\\n%{http_code}']
if '/admin/oauth/access_token' in config:
    assert 'Content-Type: application/x-www-form-urlencoded' in config
    assert 'data-urlencode = "client_secret=fixture-secret"' in config
    print(json.dumps({'access_token':'fixture-token'}))
elif '/graphql.json' in config:
    assert 'X-Shopify-Access-Token: fixture-token' in config
    print(json.dumps({'data':{'shop':{'currencyCode':'USD','ianaTimezone':'America/New_York'},'orders':{'nodes':[],'pageInfo':{'hasNextPage':False}}}}))
else: raise SystemExit(1)
print('200')
""");(fake/'curl').chmod(0o755)
    credentials=home/'business.json'
    credentials.write_text(json.dumps({'provider':'shopify','shop':'fixture.myshopify.com','clientId':'fixture-client','clientSecret':'fixture-secret'}));credentials.chmod(0o600)
    report=good('business-metrics',{'path':str(credentials),'days':7,'currency':'USD'})
    assert report['provider']=='shopify' and report['metrics'][0]['value']==0
    credentials.chmod(0o644)
    assert not call('business-metrics',{'path':str(credentials),'days':7,'currency':'USD'})['ok']
    for path in (home/'state/omarchy-perch').glob('*.json'):assert path.stat().st_mode&0o077==0
print('Dock persistence, undo, path boundaries, bounded scans and window identity passed.')
