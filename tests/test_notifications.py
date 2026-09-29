#!/usr/bin/env python3
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
from pathlib import Path
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent, QQmlExpression
root=Path(__file__).resolve().parent
app=QGuiApplication([]);engine=QQmlEngine();engine.addImportPath(str(root/'stubs'))
c=QQmlComponent(engine,QUrl.fromLocalFile(str(root/'NotificationHarness.qml')))
assert not c.isError(), c.errors()
host=c.create(); assert host is not None,c.errors()
def evaluate(code):
    e=QQmlExpression(engine.rootContext(),host,code);r=e.evaluate();assert not e.hasError(),e.error().toString()
    return r[0] if isinstance(r,tuple) else r
# Sender replacements update the same row. Closed senders invalidate actions.
evaluate('service.receive(notice)')
assert evaluate('notice.tracked') is True
assert evaluate('service.rows.length')==1
assert evaluate('service.rows[0].actions[0].label')=='Open'
evaluate('notice.summary="Replacement"')
assert evaluate('service.rows[0].title')=='Replacement'
assert evaluate('service.invokeAction("stale",service.rows[0].key,"default")')=='error: expired'
assert evaluate('notice.invoked')==0
assert evaluate('service.invokeAction(service.session,service.rows[0].key,"default")')=='ok'
assert evaluate('notice.invoked')==1
assert evaluate('service.rows.length')==0
evaluate('service.receive(notice); service.expireDue(Date.now()+31000)')
assert evaluate('notice.expired')==1
assert evaluate('service.rows.length')==1
assert evaluate('service.rows[0].actions.length')==0
assert evaluate('Object.keys(service.refs).length')==0
assert evaluate('Object.keys(service.deadlines).length')==0
evaluate('service.clearAll(); notice.hints={transient:true}; service.receive(notice); service.expireDue(Date.now()+31000)')
assert evaluate('service.rows.length')==0
evaluate('notice.hints={}; notice.expireTimeout=0; service.receive(notice); service.expireDue(Date.now()+100000)')
assert evaluate('Object.keys(service.refs).length')==1
evaluate('service.setQuiet(true); service.receive(notice)')
assert evaluate('service.preview')==''
evaluate('service.clearAll()')
assert evaluate('service.rows.length')==0
assert evaluate('Object.keys(service.refs).length')==0
print('Notification QML: replacement, generation guards, native actions, expiry, transient cleanup and DND passed (host stubs).')
