#!/usr/bin/env python3
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software');os.environ.setdefault('QT_QUICK_CONTROLS_STYLE','Basic')
from pathlib import Path
from PySide6.QtCore import QUrl,qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlExpression,QQmlEngine
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest
root=Path(__file__).resolve().parent
messages=[]
def message_handler(k,c,m):
    messages.append(m)
    if len(messages)<8: print(m,flush=True)
    if len(messages)>100: os._exit(1)
qInstallMessageHandler(message_handler)
app=QGuiApplication([]);view=QQuickView();view.engine().addImportPath(str(root/'stubs'));view.setSource(QUrl.fromLocalFile(str(root/'DockReview.qml')))
assert view.status()!=QQuickView.Error,view.errors()
view.show();QTest.qWait(100);host=view.rootObject()
def ev(code):
    e=QQmlExpression(QQmlEngine.contextForObject(host),host,code);result=e.evaluate();assert not e.hasError(),e.error().toString();return result[0] if isinstance(result,tuple)else result

import json,time
manager='service.businessManager'
a={'id':'a'*24,'revision':'one','provider':'stripe','name':'AsDecided','color':'#85b8d9','sandbox':True,'storage':'keyring'}
b={'id':'b'*24,'revision':'two','provider':'paddle','name':'Second business','color':'#c6a2ea','sandbox':False,'storage':'file'}
ev(f'{manager}.accounts={json.dumps([a,b])};{manager}.loaded=true')
ev('service.business.configure({accountId:"'+a['id']+'",metric:"MRR estimate",period:"7d",currency:"GBP",timeZone:"Europe/London"})')
assert ev('dock.addBusiness()')
id=ev('service.businessInstances.ids[0]')
ev('service.businessInstances.get("'+id+'").configure({accountId:"'+b['id']+'",metric:"Net revenue",period:"mtd",currency:"GBP"})')
assert ev('service.business.config.accountId')==a['id']
assert ev('service.businessInstances.get("'+id+'").config.accountId')==b['id']
instance=ev('service.businessInstances.get("'+id+'")')
ev('notch.page="'+id+'"');QTest.qWait(20)
ev('service.businessInstances.get("'+id+'").configure({metric:"MRR"})')
QTest.qWait(20)
assert ev('service.businessInstances.get("'+id+'")')==instance
assert ev('service.businessInstances.get("'+id+'").config.metric')=='MRR'

report={'ok':True,'provider':'stripe','currency':'GBP','updatedAt':int(time.time()),'metrics':[{'label':'MRR estimate','currency':'GBP','value':1250,'previous':1000,'changePercent':25,'comparisonKind':'Last observation on prior end date'}],'series':{'MRR estimate':[{'date':d,'value':v} for d,v in [('2026-09-29',None),('2026-09-30',None),('2026-10-01',None),('2026-10-02',None),('2026-10-03',None),('2026-10-04',1100),('2026-10-05',1250)]]},'historyStarted':'2026-10-04','period':{'first':'2026-09-29','last':'2026-10-05','timeZone':'Europe/London','previousFirst':'2026-09-22','previousLast':'2026-09-28','comparisonLabel':'Previous calendar period'},'note':'Fictional fixture data'}
ev('service.businessManager.reportReady(service.business.configKey,'+json.dumps(report)+')')
assert ev('service.business.selectedMetric.value')==1250
ev('service.businessManager.reportReady("late-old-key",{ok:true,metrics:[]})')
assert ev('service.business.selectedMetric.value')==1250
ev('service.businessManager.reportReady(service.business.configKey,{ok:false,error:"Offline fixture"})')
assert ev('service.business.selectedMetric.value')==1250
assert ev('service.business.error')=='Offline fixture'
ev('service.businessManager.reportReady(service.business.configKey,'+json.dumps(report)+')')
from PySide6.QtCore import QObject
def walk(obj):
    yield obj
    for c in obj.children():yield from walk(c)
for width in [344,600]:
    ev(f'notch.preferredWidth={width};notch.page="business";notch.expanded=true');QTest.qWait(30)
    cards=[o for o in walk(host) if o.metaObject().className().startswith('BusinessCard')]
    assert cards
    for mode in ['tile','accounts','report']:
        cards[-1].setProperty('mode',mode);QTest.qWait(30)
    for obj in walk(host):
        if obj.metaObject().className().startswith('BusinessAccounts'):
            obj.setProperty('editingId',a['id']);obj.setProperty('disconnectId',b['id'])
    cards[-1].setProperty('mode','accounts');QTest.qWait(30)
    cards[-1].setProperty('mode','report')
# Metric-only changes reuse the same report; account changes discard it.
key=ev('service.business.configKey')
ev('service.business.configure({chart:false})')
assert ev('service.business.configKey')==key and ev('service.business.selectedMetric.value')==1250
ev('service.business.configure({chart:true})')
ev('notch.preferredWidth=600;notch.page="business"');QTest.qWait(80)
ev('service.businessManager.cache=({[service.business.configKey]:'+json.dumps(report)+'});service.business.refresh(false)')
QTest.qWait(40)
output=root.parent/'test-results';output.mkdir(exist_ok=True)
view.grabWindow().save(str(output/'business-report.png'))
ev('service.business.configure({accountId:"'+b['id']+'",metric:"MRR"})')
assert ev('service.business.report===null')
ev('service.businessManager.accounts=[]')
assert ev('service.business.account===null')
# Complete the real manager job against the Process stub to exercise legacy migration.
mgr=ev('service.businessManager')
job=next(c for c in mgr.children() if c.metaObject().className().startswith('ToolJob') and c.property('timeout')==200000)
def finish_account(op,result):
    for c in job.children():
        if c.metaObject().className().startswith('Process'):c.setProperty('running',False)
    job.setProperty('operation',op);job.setProperty('busy',True)
    e=QQmlExpression(QQmlEngine.contextForObject(job),job,'finish('+json.dumps(result)+')');e.evaluate();assert not e.hasError(),e.error().toString()
ev('service.preferences.update({business:{enabled:true,path:"/fixture/legacy.json",days:30,currency:"GBP"},businessTiles:{}})')
finish_account('business-account-list',{'ok':True,'accounts':[],'capabilities':{}})
QTest.qWait(20)
assert ev('service.businessManager.migrationPath')=='/fixture/legacy.json'
finish_account('business-account-import',{'ok':True,'accountId':a['id'],'accounts':[a],'capabilities':{}})
assert ev('service.business.config.accountId')==a['id']
assert ev('service.business.config.period')=='30d'
assert ev('service.business.config.timeZone')=='UTC'
assert not ev('service.preferences.record.business.enabled')
assert not messages,'\n'.join(messages)
print('Business QML: independent tiles, stale replies, retained reports, account removal, all setup tabs and narrow layouts passed.')
