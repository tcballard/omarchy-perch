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
# A timer that finished while the shell was down alerts once on restore; a stale one does not.
evaluate('service.preferences.accept(JSON.stringify({plugins:[{id:"io.github.tcballard.perch",timerSound:true,timers:[{id:"late",status:"running",deadline:Date.now()-5000,total:60,remaining:60,label:"Late"},{id:"stale",status:"running",deadline:Date.now()-3600000,total:60,remaining:60,label:"Stale"}]}]})); service.alarmQueue=[]; service.live.restored=false; service.live.restore()')
assert evaluate('service.live.timers.length') == 2
assert evaluate('service.alarmQueue.length') == 1
assert evaluate('service.alarmQueue[0].label') == 'Late'
evaluate('service.alarmQueue=[]; service.live.saveTimers([], "")')
# Concurrent timers preserve independent deadlines and route completion correctly.
assert evaluate('service.live.add(30,"First")') is True
first_timer=evaluate('service.live.selectedTimer')
assert evaluate('service.live.add(60,"Second")') is True
assert evaluate('service.live.timers.length')==2
assert evaluate('service.live.chooseTimer('+repr(first_timer)+')') is True
evaluate('service.live.tick(service.live.timerState.deadline+1)')
assert evaluate('service.live.timerStatus')=='done'
assert evaluate('service.live.timers.filter(function(t){return t.status==="running";}).length')==1
assert evaluate('service.live.snooze(300)') is True
assert evaluate('service.live.timerProgress')<=1
assert evaluate('service.live.cancel()') is True
assert evaluate('service.live.cancel()') is True
# Input capability and persisted profile validation.
assert evaluate('service.system.toggleMicrophone()') is True
assert evaluate('service.system.microphoneMuted') is True
assert evaluate('service.preferences.update({panelWidth:9000,edgeOffset:-20,fullscreenPolicy:"invalid"})') is True
assert evaluate('service.preferences.values.panelWidth')==544
assert evaluate('service.preferences.values.edgeOffset')==0
assert evaluate('service.preferences.values.fullscreenPolicy')=='hide'
# Helper requests serialize instead of failing; identical pending requests collapse.
assert evaluate('service.workspace.request("shelf-list",{})') is True
assert evaluate('service.workspace.busy') is True
assert evaluate('service.workspace.request("calendar-list",{})') is True
assert evaluate('service.workspace.request("calendar-list",{})') is True
assert evaluate('service.workspace.pending.length') == 1
assert evaluate('service.workspace.error') == ''
# All-day and long-running entries never take the compact pill; imminent meetings do.
evaluate('service.workspace.events=[{title:"Holiday",start:Date.now()-3600000,end:Date.now()+3600000,allDay:true,location:"",url:""},{title:"Standup",start:Date.now()+300000,end:Date.now()+1200000,allDay:false,location:"",url:""}]; service.workspace.now=Date.now()')
assert evaluate('service.workspace.meetingSummary').endswith('min · Standup')
evaluate('service.workspace.events=[{title:"Long",start:Date.now()-1200000,end:Date.now()+3600000,allDay:false,location:"",url:""}]; service.workspace.now=Date.now()')
assert evaluate('service.workspace.meetingSummary') == ''
evaluate('service.workspace.events=[{title:"Sync",start:Date.now()-60000,end:Date.now()+600000,allDay:false,location:"",url:""}]; service.workspace.now=Date.now()')
assert evaluate('service.workspace.meetingSummary') == 'Now · Sync'
evaluate('service.workspace.events=[]')
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
    assert visual_eval('notch.implicitWidth') == (52 if edge in ['left','right'] else 238)
    assert visual_eval('notch.implicitHeight') == (238 if edge in ['left','right'] else 52)
    visual_eval('previewState="playing"')
    assert visual_eval('notch.implicitWidth') == 344
    assert visual_eval('notch.implicitHeight') == 468
    assert visual_eval('notch.rotation') == 0
visual_eval('notch.settingsOpen=true')
assert visual_eval('notch.implicitHeight') == 468
# Settings are a separate view; Escape returns to media before dismissing.
visual_eval('notch.forceActiveFocus()')
QTest.keyClick(view, Qt.Key_Escape); QTest.qWait(30)
assert visual_eval('notch.settingsOpen') is False
assert visual_eval('notch.expanded') is True
visual_eval('demoMedia.setState("playing")')
assert visual_eval('notch.implicitHeight') == 468
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
visual_eval('notch.settingsOpen=false; notch.displaySettings={modules:["timer","system","activity","music"]}; demoMedia.setState("playing")')
def visual_item(item,name):
    if item.objectName() == name and item.isVisible(): return item
    for child in item.childItems():
        found=visual_item(child,name)
        if found is not None: return found
    return None
for page in ['timer','system','activity','music']:
    tab=visual_item(visual,'module-tile-'+page)
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
assert visual_eval('notch.live.focused.title') == 'Build needs input'
visual_eval('demoMedia.live.dismiss("test"); demoMedia.live.cancel()')
# Load every migrated card, including secondary pages, through the shared host.
for page in ['music','timer','system','activity','players','lyrics','hub','shelf','calendar','desktop','inbox','setup']:
    visual_eval('notch.page='+repr(page)); QTest.qWait(30)
    card = visual_item(visual, 'module-card')
    assert card is not None and card.property('definition') is not None, page
visual_eval('demoMedia.live.start(30,"Preserved"); notch.page="timer"')
visual_eval('notch.page="music"; notch.page="timer"')
assert visual_eval('demoMedia.live.timerActive') is True
visual_eval('demoMedia.live.cancel()')
# Header controls expose the two rc2 pages; notification actions use the owning row.
visual_eval('demoMedia.setState("inbox")')
for button,page in [('open-inbox','inbox'),('open-desktop','hub')]:
    tab=visual_item(visual,button)
    point=tab.mapToScene(QPointF(tab.width()/2,tab.height()/2)).toPoint()
    QTest.mouseClick(view,Qt.LeftButton,Qt.NoModifier,point);QTest.qWait(30)
    assert visual_eval('notch.page')==page
visual_eval('notch.page="inbox"')
QTest.qWait(60)
def action_by_text(item,text):
    if item.property('text')==text and item.isVisible():return item
    for child in item.childItems():
        match=action_by_text(child,text)
        if match is not None:return match
    return None
action=action_by_text(visual,'Open event');assert action is not None
point=action.mapToScene(QPointF(action.width()/2,action.height()/2)).toPoint()
QTest.mouseClick(view,Qt.LeftButton,Qt.NoModifier,point);QTest.qWait(30)
assert visual_eval('demoMedia.notifications.items.length')==1
# Page changes fade and slide in, then settle exactly; a page set while collapsed leaves no offset.
visual_eval('notch.reducedMotion=true; notch.page="timer"')
assert visual_eval('notch.pageOffset') == 0 and visual_eval('notch.pageOpacity') == 1
visual_eval('notch.reducedMotion=false; notch.page="activity"')
assert visual_eval('notch.pageOpacity') < 1
QTest.qWait(400)
assert visual_eval('notch.pageOffset') == 0 and visual_eval('notch.pageOpacity') == 1
visual_eval('notch.expanded=false; notch.page="system"')
assert visual_eval('notch.pageOffset') == 0 and visual_eval('notch.pageOpacity') == 1
visual_eval('notch.expanded=true; notch.page="music"'); QTest.qWait(400)
# Dropdown popups live outside the masked item: the view reports them so the
# panel can extend its input region and hold the hover grace.
visual_eval('demoMedia.setState("playing"); notch.page="music"; notch.settingsOpen=true')
QTest.qWait(60)
combo=visual_item(visual,'monitor-choice'); assert combo is not None
point=combo.mapToScene(QPointF(combo.width()/2,combo.height()/2)).toPoint()
QTest.mouseClick(view,Qt.LeftButton,Qt.NoModifier,point); QTest.qWait(80)
assert visual_eval('notch.popupOpen') is True
assert visual_eval('notch.overlayItem !== null') is True
visual_eval('notch.expanded=false'); QTest.qWait(80)
assert visual_eval('notch.popupOpen') is False
visual_eval('notch.expanded=true')
# Native module contract and strip, using production cards with isolated demo state.
visual_eval('notch.settingsOpen=false; notch.displaySettings={layoutMode:"strip",modules:["music","clipboard","stats","weather"]}; notch.page="stats"; notch.expanded=true; notch.reducedMotion=true; notch.hoverOpen=false')
QTest.qWait(50)
assert visual_eval('demoMedia.modules.statsVisible') is True
assert visual_eval('demoMedia.modules.weatherVisible') is True
assert visual_eval('demoMedia.modules.clipboardVisible') is False
assert visual_eval('notch.bodyTop') == 116
for module_id in ['clipboard','weather','stats']:
    # Locate the visible strip's actual button and click through to its native card.
    def visible_named(item, name):
        if item.objectName() == name and item.isVisible(): return item
        for child in item.childItems():
            result = visible_named(child, name)
            if result is not None: return result
        return None
    tile = visible_named(visual, 'module-tile-' + module_id)
    assert tile is not None
    point = tile.mapToScene(QPointF(tile.width()/2, tile.height()/2)).toPoint()
    QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, point); QTest.qWait(60)
    assert visual_eval('notch.page') == module_id
    assert visual_eval('notch.expanded') is True
visual_eval('notch.page="clipboard"')
QTest.qWait(60)
assert visual_eval('demoMedia.modules.clipboardVisible') is True
search = visible_named(visual, 'clipboard-search')
assert search is not None
search.forceActiveFocus()
for key in 'omarchy': QTest.keyClick(view, key)
QTest.qWait(30)
assert visual_eval('demoMedia.modules.clips.length') == 1
QTest.keyClick(view, Qt.Key_Return)
assert 'real clipboard is unchanged' in visual_eval('demoMedia.modules.copyMessage')
visual_eval('notch.page="weather"')
QTest.qWait(30)
# The same host switches between a card and its module-specific settings.
card = visible_named(visual, 'module-card')
assert card is not None
card.setProperty('configuring', True); QTest.qWait(30)
card.setProperty('configuring', False)
visual_eval('notch.page="stats"'); QTest.qWait(30)
card.setProperty('configuring', True); QTest.qWait(30)
card.setProperty('configuring', False)
# Persisted order is updated by keyboard reordering, no arbitrary components accepted.
tile = visible_named(visual, 'module-tile-stats')
tile.forceActiveFocus()
QTest.keyClick(view, Qt.Key_Left, Qt.ControlModifier); QTest.qWait(30)
assert visual_eval('notch.moduleItems.join(",")') == 'music,stats,clipboard,weather'
tile = visible_named(visual, 'module-tile-stats')
start = tile.mapToScene(QPointF(tile.width()/2, tile.height()/2)).toPoint()
end = start + QPointF(tile.width() * 2, 0).toPoint()
QTest.mousePress(view, Qt.LeftButton, Qt.NoModifier, start)
QTest.mouseMove(view, start + QPointF(20, 0).toPoint(), 50)
QTest.mouseMove(view, end, 50)
QTest.mouseRelease(view, Qt.LeftButton, Qt.NoModifier, end); QTest.qWait(80)
assert visual_eval('notch.moduleItems.join(",")') == 'music,clipboard,weather,stats'
for edge in ['top','bottom','left','right']:
    visual_eval('notch.edge="'+edge+'"; notch.expanded=false')
    assert visual_eval('notch.implicitWidth') == (52 if edge in ['left','right'] else 192)
    assert visual_eval('notch.implicitHeight') == (192 if edge in ['left','right'] else 52)
visual_eval('notch.surfaceVisible=false')
assert visual_eval('demoMedia.modules.statsVisible') is False
assert visual_eval('demoMedia.modules.weatherVisible') is False
# Real service CPU deltas, initial sample and state validation.
evaluate('service.modules.acceptStats({total:100,idle:50,memory:30,disk:40}); service.modules.acceptStats({total:200,idle:125,memory:31,disk:40})')
assert evaluate('service.modules.cpu') == 25
assert evaluate('service.modules.saveWeather("Test", "", "0", true)') is False
assert evaluate('service.modules.saveWeather("Test", "51", "-1", true)') is True
assert evaluate('fakeShell.saved.moduleWeather.latitude') == 51
# Pinned plugins share the strip but launch only on click, never hover.
visual_eval('notch.surfaceVisible=true; notch.edge="top"; notch.expanded=true; notch.settingsOpen=false; notch.hoverOpen=true; notch.displaySettings={modules:["music","plugin:example.notes"]}')
QTest.qWait(60)
tile=visible_named(visual,'module-tile-plugin:example.notes'); assert tile is not None
point=tile.mapToScene(QPointF(tile.width()/2,tile.height()/2)).toPoint()
QTest.mouseMove(view,point); QTest.qWait(220)
assert visual_eval('demoMedia.pluginPins.lastOpened') == ''
QTest.mouseClick(view,Qt.LeftButton,Qt.NoModifier,point); QTest.qWait(60)
assert visual_eval('demoMedia.pluginPins.lastOpened') == 'example.notes'
assert visual_eval('notch.settingsOpen') is True
# Missing/disabled pins survive cleanup and can be removed; no silent launch.
visual_eval('demoMedia.pluginPins.plugins=[]; notch.settingsOpen=false; demoMedia.pluginPins.lastOpened=""; notch.activateModule("plugin:example.notes",false)')
assert visual_eval('demoMedia.pluginPins.lastOpened') == ''
assert visual_eval('demoMedia.pluginPins.error') == 'Demo plugin unavailable'
assert visual_eval('notch.moduleItems.length') == 2
assert not messages, '\n'.join(messages)
print('Production QML: service selection/actions, capability guards, removal/rebinding, empty state, Escape and view settings passed (host stubs).')
