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
    e=QQmlExpression(QQmlEngine.contextForObject(host),host,code)
    result=e.evaluate()
    assert not e.hasError(), e.error().toString()
    return result[0] if isinstance(result,tuple) else result
assert evaluate('service.playerKey')=='player.b'
assert evaluate('service.desktop.addLink("Docs","https://example.org/docs")') is True
assert evaluate('service.desktop.links.length') == 1
assert evaluate('service.desktop.addLink("Bad","file:///etc/passwd")') is False
assert evaluate('service.desktop.removeLink("https://example.org/docs")') is True
assert evaluate('service.desktop.links.length') == 0

# Request controls remain disabled until a live record is loaded, and expire locally.
request_component=QQmlComponent(engine,QUrl.fromLocalFile(str(root.parent/'RequestCard.qml')))
request_card=request_component.create(); assert request_card is not None,request_component.errors()
from PySide6.QtCore import QObject
request_state=request_card.findChild(QObject,'request-state');assert request_state is not None
allow=request_card.findChild(QQuickItem,'request-allow');assert allow is not None
assert not allow.isEnabled()
def request_eval(code):
    e=QQmlExpression(QQmlEngine.contextForObject(request_card),request_card,code)
    result=e.evaluate()
    assert not e.hasError(),e.error().toString()
    return result[0] if isinstance(result,tuple) else result
request_eval('choose("__proto__","Red, green",true); choose("__proto__","Blue",true); choose("__proto__","Red, green",true)')
assert request_eval('answers["__proto__"]')=='Blue'
assert request_eval('choices["__proto__"].length')==1
import time
request_state.setProperty('request',{'id':'a'*32,'kind':'approval','tool':'Bash','input':{'command':'printf example'},'cwd':'/work','expiresAt':time.time()+60})
assert allow.isEnabled()
request_state.setProperty('now',time.time()+120)
assert not allow.isEnabled()
request_card.deleteLater()
# Remote receiver is off by default and follows the explicit saved preference.
assert evaluate('service.codexServer.optedIn') is False
evaluate('service.codexServer.configure("/tmp/perch-fixture-codex.sock",true)')
QTest.qWait(10)
assert evaluate('service.codexServer.optedIn') is True
observer_job=host.findChild(QObject,'codex-server-job');assert observer_job is not None
evaluate('service.codexServer.configure("/tmp/perch-fixture-codex.sock",false)')
e=QQmlExpression(QQmlEngine.contextForObject(observer_job),observer_job,'finish({ok:true,sessions:[{id:"codex.stale",kind:"agent",agent:"Codex",state:"running"}]})')
e.evaluate();assert not e.hasError(),e.error().toString()
assert evaluate('service.live.items.some(function(p){return p.id==="codex.stale"})') is False
assert evaluate('service.codexServer.count')==0
assert evaluate('service.relay.optedIn') is False
evaluate('service.preferences.update({remoteStatus:true})')
assert evaluate('service.relay.optedIn') is True
evaluate('service.preferences.update({remoteStatus:false})')
assert evaluate('service.relay.optedIn') is False

# Quiet/DND suppress sound dispatch; bursts are coalesced and settings remain distinct.
evaluate('service.preferences.update({activitySound:true,timerSound:true,soundPreset:"bell",quietMode:true}); service.queueAlert("Tea",true)')
assert evaluate('service.alarmQueue.length') == 0
assert evaluate('service.previewSound()') is False
evaluate('service.preferences.update({quietMode:false}); service.notifications.dnd=true; service.queueAlert("Tea",true)')
assert evaluate('service.alarmQueue.length') == 0
evaluate('service.notifications.dnd=false; service.queueAlert("Build",false); service.queueAlert("Build again",false)')
assert evaluate('service.alarmQueue.length') == 1
assert evaluate('service.alarmQueue[0].preset') == 'bell'
evaluate('service.alarmQueue=[]; service.preferences.update({activitySound:false,timerSound:false})')
# An identical inbox sync must not resurrect an expired preview.
evaluate('service.notifications.accept(JSON.stringify({version:1,session:"test",items:[],preview:"New mail",previewKey:"a"}))')
assert evaluate('service.notifications.preview') == 'New mail'
from PySide6.QtCore import QObject, QMetaObject
expiry=host.findChild(QObject,'notification-preview-expiry');assert expiry is not None
QMetaObject.invokeMethod(expiry,'triggered')
assert evaluate('service.notifications.preview') == ''
evaluate('service.notifications.accept(JSON.stringify({version:1,session:"test",items:[],preview:"New mail",previewKey:"a"}))')
assert evaluate('service.notifications.preview') == ''
evaluate('service.notifications.accept(JSON.stringify({version:1,session:"test",items:[],preview:"New mail",previewKey:"b"}))')
assert evaluate('service.notifications.preview') == 'New mail'
evaluate('service.notifications.accept(JSON.stringify({version:1,session:"test",items:[],preview:"Hidden",dnd:true}))')
assert evaluate('service.notifications.preview') == ''
evaluate('service.notifications.dnd=false')

# Repeated status pulses do not reopen a dismissed event; a new turn does.
for state, key, count in [('running','',0),('done','one',1),('done','one',1),('done','two',2),('waiting','three',3)]:
    import json
    payload=json.dumps({'id':'events.test','state':state,'eventKey':key})
    evaluate('service.live.activity('+json.dumps(payload)+')')
    assert evaluate('eventCount') == count
evaluate('service.live.dismiss("events.test")')

# Native card state ignores responses from an older selection and closed views.
def card_job_eval(code):
    from PySide6.QtCore import QObject
    job=host.findChild(QObject,'plugin-card-job')
    assert job is not None
    worker=next(child for child in job.children() if child.metaObject().indexOfProperty('command') >= 0)
    worker.setProperty('running',False)
    e=QQmlExpression(QQmlEngine.contextForObject(job),job,code)
    value=e.evaluate()
    assert not e.hasError(),e.error().toString()
    return value
evaluate('service.pluginCards.select("example.first"); service.pluginCards.select("example.second")')
card_job_eval('finish({ok:true,card:{title:"Old"}})')
QTest.qWait(20)
assert evaluate('service.pluginCards.card === null') is True
assert evaluate('service.pluginCards.selectedId') == 'example.second'
assert evaluate('service.pluginCards.busy') is True
card_job_eval('finish({ok:true,card:{title:"Current",revision:"r1"}})')
assert evaluate('service.pluginCards.card.title') == 'Current'
evaluate('service.pluginCards.refresh(); service.pluginCards.clear()')
card_job_eval('finish({ok:true,card:{title:"Late"}})')
QTest.qWait(20)
assert evaluate('service.pluginCards.card === null') is True
assert evaluate('service.pluginCards.selectedId') == ''
assert evaluate('service.pluginCards.busy') is False
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
    assert 220 <= visual_eval('notch.implicitHeight') <= 468
    assert visual_eval('notch.rotation') == 0
visual_eval('notch.settingsOpen=true')
assert 220 <= visual_eval('notch.implicitHeight') <= 468
# Settings are a separate view; Escape returns to media before dismissing.
visual_eval('notch.forceActiveFocus()')
QTest.keyClick(view, Qt.Key_Escape); QTest.qWait(30)
assert visual_eval('notch.settingsOpen') is False
assert visual_eval('notch.expanded') is True
visual_eval('demoMedia.setState("playing")')
assert 220 <= visual_eval('notch.implicitHeight') <= 468
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
visual_eval('notch.settingsOpen=false; notch.displaySettings={layoutMode:"strip",modules:["timer","system","activity","music"]}; demoMedia.setState("playing")')
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
assert visual_eval('notch.live.attentionItems.length') == 1
one_activity_height = visual_eval('notch.implicitHeight')
assert 220 <= one_activity_height < 468
visual_eval('demoMedia.live.activity(JSON.stringify({id:"claude.1",state:"waiting",title:"Perch",detail:"Needs permission",kind:"agent",agent:"Claude",project:"perch",target:"0x123"})); notch.page="activity"')
QTest.qWait(60)
assert visual_eval('notch.live.attentionItems.length') == 2
assert one_activity_height < visual_eval('notch.implicitHeight') <= 468
assert visual_item(visual,'jump-session-claude.1') is not None
visual_eval('demoMedia.live.dismiss("claude.1")')
visual_eval('demoMedia.live.dismiss("test"); demoMedia.live.cancel()')
# Dedicated native event pages fit their content, retain explicit actions and navigate.
visual_eval('demoMedia.live.activity(JSON.stringify({id:"event.test",state:"waiting",attention:"approval",title:"Perch",detail:"Review a requested tool action",kind:"agent",agent:"Claude",project:"perch",target:"0x123"})); notch.eventId="event.test"; notch.page="event"')
QTest.qWait(60)
assert visual_eval('notch.selectedEvent.attention') == 'approval'
assert 220 <= visual_eval('notch.implicitHeight') < 468
assert visual_item(visual,'module-tile-music') is None
assert visual_item(visual,'event-return') is not None
browse=visual_item(visual,'event-browse'); assert browse is not None
point=browse.mapToScene(QPointF(browse.width()/2,browse.height()/2)).toPoint()
QTest.mouseClick(view,Qt.LeftButton,Qt.NoModifier,point);QTest.qWait(30)
assert visual_eval('notch.page') == 'activity'
visual_eval('notch.page="event"; demoMedia.live.activity(JSON.stringify({id:"event.test",state:"done",title:"Perch",detail:"Turn complete"}))')
QTest.qWait(30)
assert visual_eval('notch.selectedEvent.state') == 'done'
assert visual_item(visual,'event-return') is None
assert visual_item(visual,'event-dismiss') is not None
visual_eval('notch.page="activity"; demoMedia.live.dismiss("event.test")')

# Load every migrated card, including secondary pages, through the shared host.
for page in ['usage','music','timer','system','activity','players','lyrics','hub','shelf','calendar','desktop','inbox','setup']:
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
visual_eval('notch.surfaceVisible=true; notch.edge="top"; notch.expanded=true; notch.settingsOpen=false; notch.hoverOpen=true; notch.displaySettings={layoutMode:"strip",modules:["music","plugin:example.notes"]}')
QTest.qWait(60)
tile=visible_named(visual,'module-tile-plugin:example.notes'); assert tile is not None
point=tile.mapToScene(QPointF(tile.width()/2,tile.height()/2)).toPoint()
QTest.mouseMove(view,point); QTest.qWait(220)
assert visual_eval('demoMedia.pluginPins.lastOpened') == ''
QTest.mouseClick(view,Qt.LeftButton,Qt.NoModifier,point); QTest.qWait(60)
assert visual_eval('demoMedia.pluginPins.lastOpened') == ''
assert visual_eval('notch.settingsOpen') is False
assert visual_eval('notch.page') == 'plugin:example.notes'
assert visual_eval('demoMedia.pluginCards.selectedId') == 'example.notes'
card_action=visible_named(visual,'plugin-card-action-first'); assert card_action is not None
card_action.forceActiveFocus(); QTest.keyClick(view,Qt.Key_Space); QTest.qWait(30)
assert visual_eval('demoMedia.pluginCards.lastAction') == 'open:0'
# Opening the existing panel remains an explicit separate action.
full_open=action_by_text(visual,'Open'); assert full_open is not None
full_open.forceActiveFocus(); QTest.keyClick(view,Qt.Key_Space); QTest.qWait(30)
assert visual_eval('demoMedia.pluginPins.lastOpened') == 'example.notes'
# Missing/disabled pins survive cleanup and can be removed; no silent launch.
visual_eval('demoMedia.pluginPins.plugins=[]; notch.settingsOpen=false; demoMedia.pluginPins.lastOpened=""; notch.activateModule("plugin:example.notes",false)')
assert visual_eval('demoMedia.pluginPins.lastOpened') == ''
assert visual_eval('demoMedia.pluginCards.selectedId') == 'example.notes'
assert visual_eval('notch.moduleItems.length') == 2
visual_eval('notch.page="music"')
assert visual_eval('demoMedia.pluginCards.selectedId') == ''
# Sectioned settings use the same controls in wide and constrained panels.
visual_eval('notch.settingsOpen=true; notch.expanded=true; notch.reducedMotion=true')
QTest.qWait(50)
settings=visible_named(visual,'perch-settings'); assert settings is not None
assert settings.property('wide') is True
for section in ['display','behavior','alerts','modules','plugins']:
    button=visible_named(visual,'settings-nav-'+section); assert button is not None
    button.forceActiveFocus(); QTest.keyClick(view,Qt.Key_Space); QTest.qWait(30)
    assert settings.property('section') == section
settings.setProperty('section','behavior'); QTest.qWait(30)
toggle=visible_named(visual,'settings-reducedMotion'); assert toggle is not None
toggle.forceActiveFocus(); QTest.keyClick(view,Qt.Key_Space); QTest.qWait(30)
assert visual_eval('notch.displaySettings.reducedMotion') is False
# Keep the compositor envelope constant while switching cards/settings.
assert visual_eval('notch.maximumWidth') == 600
visual_eval('notch.width=344')
QTest.qWait(30)
assert settings.property('wide') is False
for section in ['display','behavior','alerts','modules','plugins']:
    button=visible_named(visual,'settings-compact-'+section); assert button is not None
    button.forceActiveFocus(); QTest.keyClick(view,Qt.Key_Space); QTest.qWait(30)
    assert settings.property('section') == section
    assert settings.width() <= 344
visual_eval('notch.forceActiveFocus()'); QTest.keyClick(view,Qt.Key_Escape)
assert visual_eval('notch.settingsOpen') is False
assert visual_eval('notch.maximumWidth') == 600
# The notch is a quiet compact presentation of the same expanded cards/pins.
visual_eval('notch.width=Qt.binding(function(){return notch.implicitWidth;}); previewState="compact"; notch.expanded=Qt.binding(function(){return previewState !== "compact";}); notch.settingsOpen=false; notch.displaySettings={layoutMode:"notch",modules:["music","plugin:example.notes","stats","weather"]}; demoMedia.live.items=[]; demoMedia.live.timers=[]; demoMedia.live.cancel(); demoMedia.setState("empty")')
QTest.qWait(50)
assert visual_eval('notch.perchMode') is False
assert visual_eval('notch.implicitWidth') == 100
assert visual_eval('demoMedia.modules.statsVisible') is False
assert visual_eval('demoMedia.modules.weatherVisible') is False
assert visible_named(visual,'module-tile-music') is None
for edge in ['top','bottom','left','right']:
    visual_eval('notch.edge='+repr(edge))
    assert visual_eval('notch.implicitWidth') == (48 if edge in ['left','right'] else 100)
    assert visual_eval('notch.implicitHeight') == (76 if edge in ['left','right'] else 36)
visual_eval('notch.edge="top"; demoMedia.setState("playing"); notch.hoverOpen=false')
assert visual_eval('notch.notchContext.id') == 'music'
assert visual_eval('notch.implicitWidth') == 210
notch_button=visible_named(visual,'context-notch'); assert notch_button is not None
notch_button.forceActiveFocus(); QTest.keyClick(view,Qt.Key_Space); QTest.qWait(40)
assert visual_eval('notch.expanded') is True
assert visual_eval('notch.page') == 'music'
assert visible_named(visual,'module-tile-plugin:example.notes') is not None
# Choosing either presentation preserves pins and shared state.
visual_eval('notch.settingsOpen=true')
settings=visible_named(visual,'perch-settings'); settings.setProperty('section','behavior'); QTest.qWait(30)
button=visible_named(visual,'presentation-perch'); assert button is not None
button.forceActiveFocus(); QTest.keyClick(view,Qt.Key_Space); QTest.qWait(30)
assert visual_eval('notch.perchMode') is True
assert visual_eval('notch.moduleItems.indexOf("plugin:example.notes")') == 1
button=visible_named(visual,'presentation-notch');button.forceActiveFocus();QTest.keyClick(view,Qt.Key_Space);QTest.qWait(30)
assert visual_eval('notch.perchMode') is False
assert visual_eval('notch.moduleItems.length') == 4

# Search is shared by built-ins and installed plugins, with real native navigation.
visual_eval('demoMedia.pluginPins.plugins=[{id:"example.notes",name:"Demo Notes",enabled:true},{id:"example.disabled",name:"Disabled",enabled:false}]; notch.settingsOpen=false; notch.expanded=true; notch.showTools(true)');QTest.qWait(50)
search=visible_named(visual,'tools-search');assert search is not None and search.hasActiveFocus()
search.setProperty('text','clipboard');QTest.qWait(30)
assert visible_named(visual,'tool-open-clipboard') is not None
QTest.keyClick(view,Qt.Key_Return);QTest.qWait(30)
assert visual_eval('notch.page') == 'clipboard'
visual_eval('notch.forceActiveFocus()');QTest.keyClick(view,Qt.Key_K,Qt.ControlModifier);QTest.qWait(30)
assert visual_eval('notch.page') == 'hub'
search=visible_named(visual,'tools-search');assert search is not None
search.setProperty('text','Demo Notes');QTest.qWait(30)
assert visible_named(visual,'tool-open-plugin:example.notes') is not None
pin=visible_named(visual,'tool-pin-plugin:example.notes');assert pin is not None
before=visual_eval('notch.moduleItems.indexOf("plugin:example.notes") >= 0')
pin.forceActiveFocus();QTest.keyClick(view,Qt.Key_Space);QTest.qWait(30)
assert visual_eval('notch.moduleItems.indexOf("plugin:example.notes") >= 0') is not before
search.setProperty('text','nothing matches');QTest.qWait(30)
assert visible_named(visual,'tool-open-plugin:example.notes') is None
# Following the light theme retains its actual background, dark-island remains selectable.
visual_eval('Color.lightTheme=true; notch.displaySettings=Object.assign({},notch.displaySettings,{chromeMode:"theme"})')
assert visual_eval('notch.surface.r > notch.ink.r') is True
visual_eval('notch.displaySettings=Object.assign({},notch.displaySettings,{chromeMode:"dark"})')
assert visual_eval('notch.surface.r < notch.ink.r') is True
visual_eval('Color.lightTheme=false; notch.reducedMotion=false; notch.page="music"; notch.reducedMotion=true')
assert visual_eval('notch.pageOpacity') == 1
assert visual_eval('notch.pageOffset') == 0

# Real keyboard dispatch switches cards only outside Settings.
visual_eval('notch.expanded=true; notch.settingsOpen=false; notch.displaySettings={modules:["music","timer"],moduleShortcuts:{timer:"Ctrl+Alt+T"}}; notch.page="music"; notch.forceActiveFocus()')
QTest.keyClick(view,Qt.Key_T,Qt.ControlModifier | Qt.AltModifier);QTest.qWait(30)
assert visual_eval('notch.page') == 'timer'
visual_eval('notch.settingsOpen=true; notch.page="music"; notch.forceActiveFocus()')
QTest.keyClick(view,Qt.Key_T,Qt.ControlModifier | Qt.AltModifier);QTest.qWait(30)
assert visual_eval('notch.page') == 'music'
visual_eval('notch.settingsOpen=false')
recorder_component=QQmlComponent(engine,QUrl.fromLocalFile(str(root.parent/'ShortcutRecorder.qml')))
recorder=recorder_component.create();assert recorder is not None,recorder_component.errors()
recorder.setParentItem(visual);recorder.setProperty('visible',True)
chords=[];recorder.recorded.connect(chords.append)
recorder.setProperty('recording',True);recorder.forceActiveFocus()
QTest.keyClick(view,Qt.Key_M,Qt.ControlModifier | Qt.AltModifier)
assert chords == ['Ctrl+Alt+M'] and not recorder.property('recording')
recorder.setProperty('recording',True)
QTest.keyClick(view,Qt.Key_Escape)
assert not recorder.property('recording') and len(chords)==1
recorder.deleteLater()

# Language follows the persisted preference, and changes existing UI bindings.
evaluate('service.preferences.update({language:"zh-CN"})')
assert evaluate('PerchStrings.language')=='zh-CN'
assert evaluate('PerchStrings.t("Settings")')=='设置'
evaluate('service.preferences.update({language:"en"})')
visual_eval('PerchStrings.language="zh-CN"; notch.width=344; notch.expanded=true; notch.settingsOpen=true');QTest.qWait(30)
assert visible_named(visual,'settings-compact-behavior').property('text')=='行为'
visual_eval('PerchStrings.language="en"')
assert visible_named(visual,'settings-compact-behavior').property('text')=='Behaviour'

# Long question sets scroll independently while decision controls remain visible.
request_view=QQuickView();request_view.engine().addImportPath(str(root/'stubs'))
request_view.setSource(QUrl.fromLocalFile(str(root/'NewCardsReview.qml')))
assert request_view.status()!=QQuickView.Error,request_view.errors()
request_view.show();QTest.qWait(60)
question_card=request_view.rootObject().findChild(QQuickItem,'question-review')
assert question_card is not None
for name in ('request-allow','request-deny','request-session'):
    button=question_card.findChild(QQuickItem,name);assert button is not None and button.isVisible()
    point=button.mapToItem(question_card,QPointF(0,0))
    assert 0 <= point.y() and point.y()+button.height() <= question_card.height()+1,(name,point.y(),question_card.height())
scroll=question_card.findChild(QQuickItem,'request-scroll')
assert scroll.property('contentHeight') > scroll.height()
send=question_card.findChild(QQuickItem,'request-allow');assert not send.isEnabled()
question_card.setProperty('answers',{f'Which option should question {i} use?':'Recommended' for i in range(1,5)})
assert send.isEnabled()
question_card.setProperty('answers',{'Which option should question 1 use?':'Recommended'})
assert not send.isEnabled()

assert not messages, '\n'.join(messages)
print('Production QML: service selection/actions, capability guards, removal/rebinding, empty state, Escape and view settings passed (host stubs).')
