#!/usr/bin/env python3
"""Execute the production service and view with documented host stubs."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
os.environ.setdefault('QT_QUICK_CONTROLS_STYLE','Basic')
from pathlib import Path
from PySide6.QtCore import QUrl, qInstallMessageHandler, Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent, QQmlExpression
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest
root=Path(__file__).resolve().parent
messages=[]
qInstallMessageHandler(lambda kind,ctx,message: messages.append(message))
app=QGuiApplication([])
engine=QQmlEngine();engine.addImportPath(str(root/'stubs'))
component=QQmlComponent(engine,QUrl.fromLocalFile(str(root/'ServiceHarness.qml')))
assert not component.isError(), component.errors()
host=component.create(); assert host is not None, component.errors()
def evaluate(code):
    e=QQmlExpression(engine.rootContext(),host,code)
    result=e.evaluate()
    assert not e.hasError(), e.error().toString()
    return result[0] if isinstance(result,tuple) else result
assert evaluate('service.playerKey')=='player.b'
assert evaluate('service.art')==''
assert evaluate('service.choose("player.a")')
assert evaluate('service.playerKey')=='player.a'
assert evaluate('service.act("toggle")')
assert evaluate('first.isPlaying') is True
assert evaluate('service.act("toggle")')
assert evaluate('first.isPlaying') is False
assert evaluate('service.act("previous")') is False
assert evaluate('first.previousCalls')==0
assert evaluate('service.act("next")')
assert evaluate('first.nextCalls')==1
evaluate('first.canControl=false')
assert evaluate('service.act("next")') is False
assert evaluate('first.nextCalls')==1
assert evaluate('service.choose("missing")') is False
evaluate('service.choose("player.b"); setPlayers(1)')
assert evaluate('service.playerKey')=='player.a'
assert evaluate('service.preferred')==''
evaluate('setPlayers(0)')
assert evaluate('service.state')=='empty'
assert evaluate('service.canToggle') is False
assert evaluate('service.act("toggle")') is False
# Live property bindings react when a player begins playing.
evaluate('first.canControl=true; first.isPlaying=false; second.isPlaying=false; setPlayers(2)')
assert evaluate('service.playerKey')=='player.a'
evaluate('second.isPlaying=true')
assert evaluate('service.playerKey')=='player.b'
view=QQuickView(); view.engine().addImportPath(str(root/'stubs'))
view.setSource(QUrl.fromLocalFile(str(root/'Preview.qml')))
assert view.status()!=QQuickView.Error, view.errors()
view.show(); QTest.qWait(100)
visual=view.rootObject()
def visual_eval(code):
    e=QQmlExpression(QQmlEngine.contextForObject(visual),visual,code)
    result=e.evaluate(); assert not e.hasError(),e.error().toString()
    return result[0] if isinstance(result,tuple) else result
assert visual_eval('notch.expanded') is True
visual_eval('notch.forceActiveFocus()')
QTest.keyClick(view, Qt.Key_Escape); QTest.qWait(30)
assert visual_eval('notch.expanded') is False
visual_eval('notch.expandRequested()')
assert visual_eval('notch.expanded') is True
visual_eval('demoMedia.setState("empty")')
assert visual_eval('notch.hasPlayer') is False
assert visual_eval('demoMedia.act("toggle")') is False
visual_eval('notch.settingsChanged(true,true,true)')
assert visual_eval('notch.hideIdle && notch.reducedMotion && notch.edgeAttached') is True
for edge in ['top','bottom','left','right']:
    visual_eval('notch.edgeRequested("'+edge+'")')
    visual_eval('previewState="compact"')
    assert visual_eval('notch.sideTab') is (edge in ['left','right'])
    assert visual_eval('notch.implicitWidth') == (36 if edge in ['left','right'] else 140)
    assert visual_eval('notch.implicitHeight') == (108 if edge in ['left','right'] else 36)
    visual_eval('previewState="playing"')
    assert visual_eval('notch.implicitWidth') == 380
    assert visual_eval('notch.implicitHeight') == 250
    assert visual_eval('notch.rotation') == 0
visual_eval('notch.settingsOpen=true')
assert visual_eval('notch.implicitHeight') == 376
assert not messages, '\n'.join(messages)
print('Production QML: service selection/actions, capability guards, removal/rebinding, empty state, Escape and view settings passed (host stubs).')
