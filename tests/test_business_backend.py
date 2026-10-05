#!/usr/bin/env python3
"""Compiled account/report flows with isolated state and fake native/provider processes."""
import json,os,subprocess,tempfile,time
from pathlib import Path
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='perch-business-') as temp:
    home=Path(temp);fake=home/'bin';fake.mkdir()
    env={**os.environ,'HOME':temp,'XDG_STATE_HOME':str(home/'state'),'PATH':str(fake)+os.pathsep+os.environ['PATH'],'FIXTURE_KEY':'rk_test_fixture_A'}
    def executable(name,code):
        p=fake/name;p.write_text('#!/usr/bin/env python3\n'+code);p.chmod(0o755)
    def call(op,p={}):
        r=subprocess.run([str(root/'scripts/perch-tools'),op,json.dumps(p)],env=env,capture_output=True,text=True,timeout=20)
        assert r.returncode==0,r.stderr
        result=json.loads(r.stdout)
        assert 'rk_test_fixture' not in r.stdout and 'fixture-client-secret' not in r.stdout,r.stdout
        return result
    def good(op,p={}):
        r=call(op,p);assert r['ok'],(op,r);return r
    executable('zenity',"""import os,sys
assert '--forms' in sys.argv and '--add-password' in sys.argv
assert not any('rk_test_' in a for a in sys.argv)
if os.environ.get('DIALOG_CANCEL'):raise SystemExit(1)
print(os.environ['FIXTURE_KEY'])
""")
    executable('secret-tool',"""import os,sys,pathlib
assert sys.argv[-4:-2]==['application','io.github.tcballard.perch']
id=sys.argv[-1];assert len(id)==24
path=pathlib.Path(os.environ['HOME'])/('keyring-'+id)
if os.environ.get('KEYRING_FAIL'):raise SystemExit(1)
if sys.argv[1]=='store':path.write_text(sys.stdin.read())
elif sys.argv[1]=='lookup':print(path.read_text())
elif sys.argv[1]=='clear':path.unlink()
else:raise SystemExit(1)
""")
    executable('curl',r'''import json,os,sys,time
from datetime import datetime,timezone,timedelta
config=sys.stdin.read()
assert '--proto' in sys.argv and '=https' in sys.argv and '--config' in sys.argv
assert not any('rk_test_' in a or 'fixture-token' in a for a in sys.argv)
status=os.environ.get('HTTP_STATUS','200')
if status!='200':print('{}\n'+status);raise SystemExit(0)
now=int(time.time())-120
amount=20000 if 'fixture_B' in config else 10000
if '/balance_transactions?' in config:
    assert 'created%5Bgte%5D=' in config or 'created[gte]=' in config
    row=lambda t,n:{'type':'charge','created':t,'amount':n,'net':n-100,'currency':'gbp'}
    data={'data':[row(now,amount),row(now-7*86400,5000),row(now+86400,999999)],'has_more':False}
elif '/subscriptions?' in config:
    data={'data':[{'status':'active','customer':'cus_fixture','discounts':[],'items':{'has_more':False,'data':[{'quantity':1,'price':{'currency':'gbp','billing_scheme':'per_unit','unit_amount':3000,'recurring':{'usage_type':'licensed','interval':'month','interval_count':1}}}]}}],'has_more':False}
elif '/metrics/' in config:
    dates=[datetime.now(timezone.utc).date()-timedelta(days=i) for i in range(14)]
    data={'data':{'currency_code':'GBP','timeseries':[{'timestamp':str(d)+'T00:00:00Z','amount':'2500'} for d in sorted(dates)],'updated_at':'2026-10-05T00:00:00Z'}}
elif '/admin/oauth/access_token' in config:
    assert 'application/x-www-form-urlencoded' in config
    data={'access_token':'fixture-token'}
elif '/graphql.json' in config:
    if 'ianaTimezone' in config:data={'data':{'shop':{'currencyCode':'GBP','ianaTimezone':'Pacific/Auckland','plan':{'partnerDevelopment':True}}}}
    else:data={'data':{'orders':{'nodes':[],'pageInfo':{'hasNextPage':False}}}}
else:raise SystemExit(1)
print(json.dumps(data));print(status)
''')
    assert good('business-account-list')['accounts']==[]
    args={'provider':'stripe','name':'First business','color':'#aabbcc','storage':'file','currency':'GBP','timeZone':'Europe/London'}
    a=good('business-account-connect',args)['accountId']
    accounts=good('business-account-list')['accounts'];assert len(accounts)==1 and accounts[0]['sandbox'] is True
    assert 'credentials' not in accounts[0] and 'path' not in accounts[0]
    state=home/'state/omarchy-perch/business-accounts.json';assert state.stat().st_mode&0o077==0
    report=good('business-metrics',{'accountId':a,'period':'7d','currency':'GBP','timeZone':'Europe/London'})
    assert report['metrics'][0]['value']==100 and report['metrics'][0]['previous']==50
    assert report['metrics'][0]['changePercent']==100
    assert report['period']['timeZone']=='Europe/London'
    assert len(report['series']['Revenue'])==7 and report['series']['MRR estimate'][-1]['value']==30
    assert report['series']['MRR estimate'][0]['value'] is None
    history=home/f'state/omarchy-perch/business-history-{a}.json';assert history.exists()
    again=good('business-metrics',{'accountId':a,'period':'7d','currency':'GBP','timeZone':'Europe/London'})
    assert again['historyStarted']==report['historyStarted'] and len(json.loads(history.read_text()))==1
    env['FIXTURE_KEY']='rk_test_fixture_B'
    b=good('business-account-connect',{**args,'name':'Second business','storage':'keyring'})['accountId']
    assert 'rk_test_fixture_B' not in state.read_text()
    assert good('business-metrics',{'accountId':b,'period':'7d','currency':'GBP','timeZone':'Europe/London'})['metrics'][0]['value']==200
    good('business-account-rename',{'id':a,'name':'Renamed','color':'#112233'})
    assert good('business-account-list')['accounts'][0]['name']=='Renamed'
    for status,message in [('401','Credentials rejected'),('403','Permission denied'),('429','rate limit'),('500','Provider request failed')]:
        env['HTTP_STATUS']=status;result=call('business-metrics',{'accountId':a,'period':'7d','currency':'GBP','timeZone':'Europe/London'});assert not result['ok'] and message in result['error'],result
    del env['HTTP_STATUS']
    before=state.read_text();env['DIALOG_CANCEL']='1';assert not call('business-account-connect',args)['ok'];del env['DIALOG_CANCEL'];assert state.read_text()==before
    env['KEYRING_FAIL']='1';assert not call('business-account-connect',{**args,'storage':'keyring'})['ok'];del env['KEYRING_FAIL'];assert state.read_text()==before
    assert not call('business-metrics',{'accountId':'../private','period':'today'})['ok']
    external=home/'legacy.json';external.write_text(json.dumps({'provider':'paddle','apiKey':'pdl_sdbx_apikey_fixture'}));external.chmod(0o600)
    c=good('business-account-import',{'path':str(external),'name':'Legacy','color':'#ffffff'})['accountId']
    assert good('business-account-import',{'path':str(external),'name':'Legacy','color':'#ffffff'})['accountId']==c
    paddle=good('business-metrics',{'accountId':c,'period':'7d','currency':'USD','timeZone':'Europe/London'})
    assert paddle['period']['timeZone']=='UTC' and paddle['metrics'][0]['value']==175
    shop=home/'shop.json';shop.write_text(json.dumps({'provider':'shopify','shop':'fixture.myshopify.com','clientId':'fixture-client','clientSecret':'fixture-client-secret'}));shop.chmod(0o600)
    shop_id=good('business-account-import',{'path':str(shop),'name':'Shop','color':'#112233'})['accountId']
    shop_report=good('business-metrics',{'accountId':shop_id,'period':'mtd','currency':'USD','timeZone':'UTC'})
    assert shop_report['period']['timeZone']=='Pacific/Auckland' and shop_report['currency']=='GBP'
    assert shop_report['metrics'][0]['value']==0 and all(p['value'] is None for p in shop_report['series']['Average order value'])
    good('business-account-disconnect',{'id':a});assert not history.exists();assert not call('business-metrics',{'accountId':a})['ok']
    good('business-account-disconnect',{'id':b});assert not (home/('keyring-'+b)).exists()
    good('business-account-disconnect',{'id':c});assert external.exists()
print('Business account isolation, credential transport/storage, cancellation, reports, HTTP errors, history and disconnect passed.')
