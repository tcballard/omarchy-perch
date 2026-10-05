// Versioned, bounded user layouts. No executable code or credentials in profiles.
var profileKeys = ['modules','moduleShortcuts','dockItems','tileSizes','layoutMode','dockScale','showRunningApps','hoverOpen','dockAutoHide','moduleWeather','weatherInstances','businessTiles','moduleStatsInterval'];
function name(value) { return typeof value === 'string' ? value.replace(/[\u0000-\u001f]/g,' ').trim().slice(0,60) : ''; }
function customId(id) { return typeof id === 'string' && /^dock:[a-z0-9][a-z0-9-]{0,63}$/.test(id); }
function items(raw) {
    var out = [], seen = {};
    (Array.isArray(raw) ? raw : []).slice(0,48).forEach(function(p) {
        if (!p || !customId(p.id) || seen[p.id] || ['app','file','link','spacer'].indexOf(p.kind)<0) return;
        var target = typeof p.target === 'string' ? p.target : '';
        if (p.kind === 'app' && !/^[A-Za-z0-9._][A-Za-z0-9._-]*\.desktop$/.test(target)) return;
        if (p.kind === 'link' && (target.length>2048 || !/^https?:\/\/[^\s/@]+(?:[/:?#]|$)/.test(target))) return;
        if (p.kind === 'file' && (target.length>4096 || !/^(\/|~\/)[^\u0000-\u001f]+$/.test(target))) return;
        seen[p.id]=true;
        out.push({id:p.id,kind:p.kind,name:name(p.name) || (p.kind==='spacer'?'Spacer':target.split('/').pop()),target:p.kind==='spacer'?'':target});
    });
    return out;
}
function snapshot(record) {
    var result={};
    profileKeys.forEach(function(k){ if(Object.prototype.hasOwnProperty.call(record,k)) result[k]=JSON.parse(JSON.stringify(record[k])); });
    return result;
}
function profiles(raw) {
    var out=[], seen={};
    (Array.isArray(raw)?raw:[]).slice(0,12).forEach(function(p){
        if (!p || typeof p.id!=='string' || !/^[a-z0-9-]{1,64}$/.test(p.id) || seen[p.id] || !name(p.name) || !p.layout || typeof p.layout!=='object' || Array.isArray(p.layout)) return;
        seen[p.id]=true; out.push({id:p.id,name:name(p.name),layout:snapshot(p.layout),schedule:p.schedule && typeof p.schedule==='object' ? {enabled:p.schedule.enabled===true,days:Array.isArray(p.schedule.days)?p.schedule.days.filter(d=>Number.isInteger(d)&&d>=0&&d<=6).slice(0,7):[],start:p.schedule.start,end:p.schedule.end} : {enabled:false}});
    });
    return out;
}
function update(record, patch) {
    var next=Object.assign({},record,patch);
    if (patch.dockProfiles === undefined && profileKeys.some(function(k){return Object.prototype.hasOwnProperty.call(patch,k);})) {
        next.dockProfiles=profiles(record.dockProfiles).map(function(p){return p.id===record.activeDockProfile?Object.assign({},p,{layout:snapshot(next)}):p;});
    }
    return next;
}
function activate(record,id) {
    var rows=profiles(record.dockProfiles), selected=rows.find(function(p){return p.id===id;});
    if(!selected) return null;
    // Store the outgoing profile and replace every profile-owned field.
    rows=rows.map(function(p){return p.id===record.activeDockProfile?Object.assign({},p,{layout:snapshot(record)}):p;});
    var result=Object.assign({},record);
    profileKeys.forEach(function(k){delete result[k];});
    return Object.assign(result,selected.layout,{dockProfiles:rows,activeDockProfile:id});
}
function backup(record) { return JSON.stringify({format:'perch-docks',version:1,profiles:profiles(record.dockProfiles),current:snapshot(record)},null,2); }
function restore(encoded) {
    if(typeof encoded!=='string' || encoded.length>131072) throw Error('Backup exceeds 128 KiB');
    var data=JSON.parse(encoded);
    if(!data || data.format!=='perch-docks' || data.version!==1 || !Array.isArray(data.profiles) || data.profiles.length>12) throw Error('Not a supported Perch dock backup');
    var rows=profiles(data.profiles);
    if(rows.length!==data.profiles.length) throw Error('Backup contains invalid profiles');
    return {dockProfiles:rows,activeDockProfile:'',current:snapshot(data.current||{})};
}
function template(kind) {
    var choices={everyday:['music','calendar','weather','reminders','shelf'],building:['activity','usage','stats','timer','clipboard'],presenting:['timer','calendar','system'],wellbeing:['hydration','timer','reminders','music']};
    return {layoutMode:'strip',modules:(choices[kind]||choices.everyday).slice(),dockItems:[],tileSizes:{},showRunningApps:false};
}
if(typeof module!=='undefined') module.exports={profileKeys,name,customId,items,snapshot,profiles,update,activate,backup,restore,template};
// Weekday schedule matching is local-time and never alters system Focus settings.
function scheduled(rows, date) {
    var minutes=date.getHours()*60+date.getMinutes(), day=date.getDay();
    return profiles(rows).find(function(p){
        var r=(rows.find(x=>x.id===p.id)||{}).schedule;
        return r && r.enabled===true && Array.isArray(r.days) && r.days.indexOf(day)>=0 && Number.isInteger(r.start) && Number.isInteger(r.end) && r.start>=0 && r.end<=1440 && r.start<r.end && minutes>=r.start && minutes<r.end;
    }) || null;
}
if(typeof module!=='undefined') module.exports.scheduled=scheduled;
