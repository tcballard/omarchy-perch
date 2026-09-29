import importlib.machinery,importlib.util,json,os,sys,tempfile
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from perchlib import usage
from perchlib.storage import Store
assert usage.windows({'primary':{'used_percent':25,'window_minutes':300,'resets_at':2000000000}},True)[0]['label']=='5h'
assert usage.windows({'five_hour':{'used_percentage':float('nan')}})==[]
with tempfile.TemporaryDirectory() as tmp:
    base=Path(tmp);day=base/'sessions/2026/09/29';day.mkdir(parents=True)
    (day/'rollout.jsonl').write_text(json.dumps({'type':'event_msg','timestamp':'2026-09-29T12:00:00Z','payload':{'type':'token_count','rate_limits':{'primary':{'used_percent':20,'window_minutes':300}}},'secret':'DO NOT RETURN'})+'\n')
    with patch.dict(os.environ,{'CODEX_HOME':tmp,'XDG_STATE_HOME':str(base/'state')}):
        result=usage.snapshot()
        assert result['sources'][0]['windows'][0]['used']==20
        assert 'DO NOT RETURN' not in json.dumps(result)
        Store('usage-claude').save({'updatedAt':0,'rate_limits':{'seven_day':{'used_percentage':80}}})
        assert usage.snapshot()['sources'][1]['status']=='Stale snapshot'
loader=importlib.machinery.SourceFileLoader('usage_setup',str(Path(__file__).resolve().parents[1]/'scripts/perch-usage-setup'))
spec=importlib.util.spec_from_loader(loader.name,loader);setup=importlib.util.module_from_spec(spec);loader.exec_module(setup)
try:setup.transform('{"statusLine":{"command":"custom"}}',Path('/owned'),False);assert False
except ValueError:pass
value=setup.transform('{"permissions":{"deny":["Read(.env)"]}}',Path('/owned'),False)
assert json.loads(setup.transform(value,Path('/owned'),True))=={'permissions':{'deny':['Read(.env)']}}
print('Usage: bounded counters, stale data, transcript privacy and status-line ownership passed.')
