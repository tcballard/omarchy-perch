function clean(p) {
    p = p && typeof p === "object" && !Array.isArray(p) ? p : {}
    return {edge:["top","bottom","left","right"].indexOf(p.edge)>=0?p.edge:"top", hideIdle:p.hideIdle===true,
        reducedMotion:p.reducedMotion===true, edgeAttached:p.edgeAttached===true,
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
