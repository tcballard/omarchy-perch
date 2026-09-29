function bounded(n,lo,hi,fallback){return typeof n === "number" && isFinite(n)?Math.max(lo,Math.min(hi,n)):fallback;}
function clean(p) {
    p = p && typeof p === "object" && !Array.isArray(p) ? p : {}
    return {rememberSessions:p.rememberSessions===true, layoutMode:p.layoutMode === "strip" ? "strip" : "notch", modules:p.modules, edge:["top","bottom","left","right"].indexOf(p.edge)>=0?p.edge:"top", hideIdle:p.hideIdle===true,
        reducedMotion:p.reducedMotion===true, edgeAttached:p.edgeAttached===true,
        monitor:typeof p.monitor==="string"?p.monitor.slice(0,120):"", panelWidth:bounded(p.panelWidth,304,544,344), edgeOffset:bounded(p.edgeOffset,0,64,0), perDisplay:p.perDisplay===true, fullscreenPolicy:["hide","alerts","show"].indexOf(p.fullscreenPolicy)>=0?p.fullscreenPolicy:"hide", timerSound:p.timerSound===true, timerNotifications:p.timerNotifications===true, remoteArtwork:p.remoteArtwork===true,
        chromeMode:p.chromeMode === "theme" ? "theme" : "dark", quietMode:p.quietMode===true, activitySound:p.activitySound===true, notificationPreviews:p.notificationPreviews!==false, systemFeedback:p.systemFeedback===undefined?p.eventBanners!==false:p.systemFeedback!==false, soundPreset:["complete","message-new-instant","bell"].indexOf(p.soundPreset)>=0?p.soundPreset:"complete",
        showClock:p.showClock!==false, hoverOpen:p.hoverOpen!==false, eventBanners:p.eventBanners!==false}
}
function entry(encoded) {
    if (typeof encoded !== "string" || encoded.length > 1048576) return null
    try {
        var config = JSON.parse(encoded), list = Array.isArray(config.plugins) ? config.plugins : []
        var layout = config.bar && config.bar.layout ? config.bar.layout : {}
        ;["left","center","right"].forEach(function(s) { if (Array.isArray(layout[s])) list = list.concat(layout[s]) })
        for (var i=0;i<list.length;i++) if (list[i] && list[i].id === "io.github.tcballard.perch") return list[i]
        return {}
    } catch (_) { return null }
}
if (typeof module !== "undefined") module.exports = {clean,entry}
