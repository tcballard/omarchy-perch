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
assert ev('dock.profiles.length')==1
assert ev('dock.create("Building","building")')
assert ev('dock.profiles.length')==2
assert ev('dock.activeName')=='Building'
ev('service.preferences.update({modules:["timer","stats"]})')
ev('dock.activate(dock.profiles[0].id)')
assert ev('service.preferences.values.modules[0]')=='music'
ev('dock.activate(dock.profiles[1].id)')
assert ev('service.preferences.values.modules.join(",")')=='timer,stats'
assert ev('dock.add("link","Docs","https://example.org")')
assert not ev('dock.add("link","Bad","javascript:alert(1)")')
assert ev('dock.add("spacer","Spacer","")')
assert ev('dock.addWeather()')
ev('notch.page=service.weatherInstances.ids[0]')
QTest.qWait(30)
assert ev('service.weatherInstances.get(service.weatherInstances.ids[0]) !== null')
ev('service.weatherInstances.get(service.weatherInstances.ids[0]).saveWeather("London",51.5,-0.1,false)')
assert ev('service.weatherInstances.get(service.weatherInstances.ids[0]).weatherConfig.name')=='London'
ev('notch.page="dock";dock.error="";dock.exportBackup()')
assert ev('dock.importBackup(dock.backupText)')
assert not ev('dock.importBackup("invalid")')
ev('dock.error=""')
ev('service.preferences.shell=null')
assert not ev('dock.create("Cannot save","")')
ev('service.preferences.shell=live.fakeShell;dock.error=""')
# Every new production card and every editor tab loads at ordinary and narrow sizes.
for width in [344,600]:
    ev(f'notch.preferredWidth={width}')
    for page in ['dock','reminders','hydration','windows','storage','business','folder','weather','usage','trash','stats']:
        ev(f'notch.page="{page}"');QTest.qWait(30)
        assert ev('notch.width')>=344
    ev('notch.page="dock"');QTest.qWait(30)
    for tab in ['library','profiles','backup','layout']:
        ev(f'notch.children;')
        # The loader-owned editor is found through the production visual tree.
        def walk(obj):
            yield obj
            for c in obj.children():yield from walk(c)
        editors=[o for o in walk(host) if o.metaObject().className().startswith('DockEditor')]
        assert editors
        editors[-1].setProperty('tab',tab);QTest.qWait(30)
# Optional capture surface loads with its documented compositor interface stub.
ev('service.utilities.windows=[{address:"0x123",title:"Notes",class:"editor",workspace:"1",pid:42}];service.preferences.update({windowPreviews:true});notch.page="windows"')
QTest.qWait(50)
ev('service.preferences.update({windowPreviews:false})')
# Hidden docks do not leave utility/network pollers running.
ev('service.preferences.update({layoutMode:"strip",dockAutoHide:true,modules:["stats","weather","usage","business","windows"]});notch.expanded=false')
QTest.qWait(20)
assert ev('notch.dockHidden')
assert not ev('service.modules.statsVisible')
assert not ev('service.business.active')
assert not ev('service.utilities.windowsVisible')
ev('service.preferences.update({dockAutoHide:false});notch.expanded=true')
# Deterministic review render, keeping all data fictional and IO stubbed.
ev('dock.activate(dock.profiles[0].id);notch.page="dock";notch.preferredWidth=600')
QTest.qWait(100)
output=root.parent/'test-results';output.mkdir(exist_ok=True)
view.grabWindow().save(str(output/'dock-editor.png'))
ev('notch.expanded=false');QTest.qWait(100)
view.grabWindow().save(str(output/'dock-strip.png'))
assert not messages,'\n'.join(messages)
print('Production dock profile switching, save failures, all new cards, editor tabs and narrow layouts passed.')
