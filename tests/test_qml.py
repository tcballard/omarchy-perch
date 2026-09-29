#!/usr/bin/env python3
"""Execute the production service and view with documented host stubs."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
os.environ.setdefault('QT_QUICK_CONTROLS_STYLE','Basic')
from pathlib import Path
from PySide6.QtCore import QUrl, qInstallMessageHandler, Qt, QPointF
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent, QQmlExpression
from PySide6.QtQuick import QQuickView, QQuickItem
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
# Production preferences persist only through the own-id host callback.
assert evaluate('service.preferences.ready') is True
assert evaluate('service.preferences.update({edge:"right", unknownSetting:17})') is True
assert evaluate('fakeShell.saved.edge') == 'right'
assert evaluate('service.preferences.update({showClock:false})') is True
assert evaluate('fakeShell.saved.unknownSetting') == 17
assert evaluate('service.preferences.values.showClock') is False
assert evaluate('service.preferences.accept("{bad")') is False
writes=evaluate('fakeShell.writes')
assert evaluate('service.preferences.update({edge:"left"})') is False
assert evaluate('fakeShell.writes') == writes
assert evaluate('service.preferences.accept(JSON.stringify({plugins:[{id:"io.github.tcballard.perch",edge:"bottom"}]}))') is True
# Capability and race guarded seeking; raising only on explicit action.
evaluate('service.choose("player.a")')
assert evaluate('service.seekTo(50,"player.a","1")') is True
assert evaluate('first.position') == 50
assert evaluate('service.seekTo(70,"player.b","1")') is False
assert evaluate('service.seekTo(70,"player.a","2")') is False
evaluate('first.canSeek=false')
assert evaluate('service.seekTo(70,"player.a","1")') is False
evaluate('first.canSeek=true')
assert evaluate('service.raisePlayer()') is True
assert evaluate('first.raiseCalls') == 1
# Native audio controls; explicit bounds; no fake percentage when absent.
assert evaluate('service.system.setVolume(2)') is True
assert evaluate('service.system.volume') == 1
assert evaluate('service.system.toggleMute()') is True
assert evaluate('service.system.muted') is True
assert evaluate('service.system.batteryPercent') == 78
evaluate('service.system.device.isPresent=false')
assert evaluate('service.system.batteryAvailable') is False
assert evaluate('service.system.batteryPercent') == 0
evaluate('service.system.sink.audio=null')
assert evaluate('service.system.audioAvailable') is False
assert evaluate('service.system.setVolume(0.5)') is False
# Timer state changes persist, ticks do not write once a second.
assert evaluate('service.live.start(60,"Focus")') is True
assert evaluate('fakeShell.saved.timer.status') == 'running'
assert evaluate('service.live.start(20,"Replacement")') is False
writes=evaluate('fakeShell.writes')
evaluate('service.live.tick(service.live.now + 1000)')
assert evaluate('fakeShell.writes') == writes
assert evaluate('service.live.pause()') is True
assert evaluate('service.live.timerStatus') == 'paused'
assert evaluate('service.live.resume()') is True
evaluate('service.live.tick(service.live.timerState.deadline + 1)')
assert evaluate('service.live.timerStatus') == 'done'
assert evaluate('fakeShell.saved.timer.status') == 'done'
assert evaluate('service.live.cancel()') is True
# Failed persistence does not pretend a timer was started.
evaluate('fakeShell.failWrites=true')
assert evaluate('service.live.start(60,"Focus")') is False
assert evaluate('service.live.timerStatus') == 'idle'
evaluate('fakeShell.failWrites=false')
assert evaluate('service.live.activity(JSON.stringify({id:"build",title:"Build",state:"running",progress:0.3,ttl:5}))') == 'ok'
assert evaluate('service.live.items.length') == 1
evaluate('service.live.tick(service.live.now+5001)')
assert evaluate('service.live.items.length') == 0
# Recover a saved running deadline exactly once across settings reloads.
evaluate('service.preferences.accept(JSON.stringify({plugins:[{id:"io.github.tcballard.perch",timer:{status:"running",deadline:Date.now()+60000,total:60,remaining:60,label:"Restored"}}]})); service.live.restored=false; service.live.restore()')
assert evaluate('service.live.timerStatus') == 'running'
assert evaluate('service.live.timerState.label') == 'Restored'
assert evaluate('service.live.cancel()') is True
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
    assert visual_eval('notch.implicitWidth') == (28 if edge in ['left','right'] else 96)
    assert visual_eval('notch.implicitHeight') == (80 if edge in ['left','right'] else 30)
    visual_eval('previewState="playing"')
    assert visual_eval('notch.implicitWidth') == 344
    assert visual_eval('notch.implicitHeight') == 212
    assert visual_eval('notch.rotation') == 0
visual_eval('notch.settingsOpen=true')
assert visual_eval('notch.implicitHeight') == 468
# Settings are a separate view; Escape returns to media before dismissing.
visual_eval('notch.forceActiveFocus()')
QTest.keyClick(view, Qt.Key_Escape); QTest.qWait(30)
assert visual_eval('notch.settingsOpen') is False
assert visual_eval('notch.expanded') is True
visual_eval('demoMedia.setState("playing")')
assert visual_eval('notch.implicitHeight') == 270
assert visual_eval('notch.hasPlayer') is True
playback = visual.findChild(QQuickItem, 'playback')
assert playback is not None
QTest.qWait(120)
point = playback.mapToScene(QPointF(playback.width()/2, playback.height()/2)).toPoint()
QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, point)
assert visual_eval('notch.playing') is False
visual_eval('demoMedia.setState("empty")')
transport = visual.findChild(QQuickItem, 'transport')
assert transport is not None and not transport.isVisible()
assert not playback.isEnabled()
visual_eval('Color.lightTheme=true')
assert visual_eval('notch.lightTheme') is True
assert visual_eval('notch.surface.r < notch.ink.r') is True
visual_eval('Color.lightTheme=false')
assert visual_eval('notch.surface.r < notch.ink.r') is True
# Navigate each real view using pointer clicks, then verify timer/activities.
visual_eval('notch.settingsOpen=false; demoMedia.setState("playing")')
def visual_item(item,name):
    if item.objectName() == name: return item
    for child in item.childItems():
        found=visual_item(child,name)
        if found is not None: return found
    return None
for page in ['timer','system','activity','music']:
    tab=visual_item(visual,'tab-'+page)
    assert tab is not None, page
    point=tab.mapToScene(QPointF(tab.width()/2,tab.height()/2)).toPoint()
    QTest.mouseClick(view,Qt.LeftButton,Qt.NoModifier,point)
    QTest.qWait(30)
    assert visual_eval('notch.page') == page
visual_eval('demoMedia.live.start(30,"Demo timer"); notch.page="timer"')
assert visual_eval('demoMedia.live.timerActive') is True
visual_eval('demoMedia.live.activity(JSON.stringify({id:"test",state:"waiting",title:"Build needs input",detail:"Plain text",progress:0.5})); notch.page="activity"')
QTest.qWait(60)
assert visual_eval('notch.liveAttention') is True
assert visual_eval('notch.compactText') == 'Build needs input'
visual_eval('demoMedia.live.dismiss("test"); demoMedia.live.cancel()')
assert not messages, '\n'.join(messages)
print('Production QML: service selection/actions, capability guards, removal/rebinding, empty state, Escape and view settings passed (host stubs).')
