function contexts(media, banners, clock) {
    if(!media)return [];
    var list=[],live=media.live,system=media.system,inbox=media.notifications,work=media.workspace;
    var completed=live&&live.timers?live.timers.find(function(t){return t.status==='done';}):null;
    if(completed)list.push({id:'timer',timerId:completed.id,page:'timer',title:completed.label+' finished',icon:'timer',action:'done'});
    else if(live && live.timerStatus==='done')list.push({id:'timer',page:'timer',title:live.summary,icon:'timer',action:'done'});
    if(live && live.focused && (live.focused.state==='waiting'||live.focused.state==='error'))list.push({id:'attention',page:'activity',title:live.focused.title,icon:'activity',action:'open'});
    if(inbox && inbox.preview)list.push({id:'inbox',page:'inbox',title:inbox.preview,icon:'bell',action:'open'});
    if(banners && system && system.banner)list.push({id:'system',page:'system',title:system.banner,icon:'system',action:'open'});
    if(live && live.timerActive && live.timerStatus!=='done')list.push({id:'timer',page:'timer',title:live.summary,icon:'timer',action:live.timerStatus==='paused'?'resume':'pause'});
    if(work && work.meetingSummary)list.push({id:'meeting',page:'calendar',title:work.meetingSummary,icon:'timer',action:'open'});
    if(live && live.focused && !list.some(function(c){return c.id==='attention';}))list.push({id:'activity',page:'activity',title:live.focused.title,icon:'activity',action:'open'});
    if(media.state!=='empty')list.push({id:'music',page:'music',title:media.title,icon:media.state==='playing'?'wave':'music',action:media.canToggle?'toggle':'open'});
    if(!list.length)list.push({id:'idle',page:'music',title:clock&&live?live.clock:'Perch',icon:clock?'timer':'music',action:'open'});
    return list;
}
if(typeof module!=='undefined')module.exports={contexts};
