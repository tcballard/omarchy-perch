// One useful context. No IO; no pin can trigger an automatic plugin launch.
function context(media) {
    var live = media ? media.live : null;
    var timers = live && Array.isArray(live.timers) ? live.timers : [];
    var done = timers.find(function(t) { return t.status === "done"; });
    if (done) return {id:"timer",page:"timer",timerId:done.id,title:done.label + " finished",glyph:"✓",attention:true};
    if (live && live.focused && ["waiting","error"].indexOf(live.focused.state) >= 0) {
        var attentionCount = live.attentionItems ? live.attentionItems.length : 1;
        return {id:"activity",page:"activity",title:attentionCount > 1 ? attentionCount + " need you" : live.focused.title,glyph:"!",attention:true};
    }
    if (live && live.timerActive)
        return {id:"timer",page:"timer",timerId:live.selectedTimer,title:live.summary || "Timer",glyph:"◷",attention:false};
    if (media && media.state === "playing")
        return {id:"music",page:"music",title:media.title || "Playing",glyph:"♫",attention:false};
    if (media && media.workspace && media.workspace.meetingSummary)
        return {id:"calendar",page:"calendar",title:media.workspace.meetingSummary,glyph:"▦",attention:false};
    if (media && media.notifications && media.notifications.preview)
        return {id:"inbox",page:"inbox",title:media.notifications.preview,glyph:"◇",attention:false};
    if (live && live.focused)
        return {id:"activity",page:"activity",title:live.focused.title,glyph:"◉",attention:false};
    return {id:"idle",page:"hub",title:"Perch",glyph:"⌃",attention:false};
}
if (typeof module !== "undefined") module.exports = {context};
