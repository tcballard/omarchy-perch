function processTarget(p) {
    if (!p || !Number.isInteger(p.pid) || p.pid <= 1 || typeof p.start !== "string" || !/^[0-9]{1,24}$/.test(p.start) || typeof p.boot !== "string" || !/^[0-9a-f-]{36}$/.test(p.boot)) return null
    return {pid:p.pid,start:p.start,boot:p.boot}
}
function codexTarget(p) {
    if (!p || typeof p.thread !== "string" || !/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/.test(p.thread) || typeof p.handler !== "string" || !/^[A-Za-z0-9][A-Za-z0-9_.-]{0,240}\.desktop$/.test(p.handler)) return null
    return {thread:p.thread,handler:p.handler}
}
function zellijTarget(p) {
    if (!p || typeof p.session !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/.test(p.session) || !Number.isInteger(p.pane) || p.pane < 0 || p.pane >= 4294967296 || !Number.isInteger(p.serverPid) || p.serverPid <= 1) return null
    if (![p.socket,p.binary].every(function(v) { return typeof v === "string" && /^\/[^\u0000-\u001f]{1,1023}$/.test(v) }) || !/\/zellij$/.test(p.binary) || typeof p.boot !== "string" || !/^[0-9a-f-]{36}$/.test(p.boot)) return null
    if (![p.device,p.inode,p.serverStart,p.binaryDevice,p.binaryInode].every(function(v) { return typeof v === "string" && /^[0-9]{1,24}$/.test(v) })) return null
    return {session:p.session,pane:p.pane,socket:p.socket,binary:p.binary,serverPid:p.serverPid,serverStart:p.serverStart,boot:p.boot,device:p.device,inode:p.inode,binaryDevice:p.binaryDevice,binaryInode:p.binaryInode}
}
function workspaceTarget(p) {
    if (!p || ["code","code-insiders","cursor","windsurf","trae","zed","idea","webstorm","pycharm","goland","clion","rubymine","phpstorm","rider","rustrover"].indexOf(p.app) < 0) return null
    if (typeof p.path !== "string" || !/^\/[^\u0000-\u001f]{1,1023}$/.test(p.path) || !Number.isInteger(p.pid) || p.pid <= 1 || !/^[0-9]{1,24}$/.test(p.start || "") || !/^[0-9a-f-]{36}$/.test(p.boot || "")) return null
    return {app:p.app,path:p.path,pid:p.pid,start:p.start,boot:p.boot}
}
function weztermTarget(p) {
    if (!p || typeof p.socket !== "string" || !/^\/[^\u0000-\u001f]{1,1023}$/.test(p.socket) || !Number.isInteger(p.pane) || p.pane < 0 || p.pane >= 1e12) return null
    if (![p.device,p.inode,p.windowStart].every(function(v) { return typeof v === "string" && /^[0-9]{1,24}$/.test(v) })) return null
    return {socket:p.socket,pane:p.pane,device:p.device,inode:p.inode,windowStart:p.windowStart}
}
function tmuxTarget(p) {
    if (!p || typeof p !== "object" || typeof p.socket !== "string" || !/^\/[^\u0000-\u001f]{1,1023}$/.test(p.socket) || !/^%[0-9]+$/.test(p.pane || "") || !/^\/dev\/[A-Za-z0-9/_-]+$/.test(p.client || "")) return null
    if (!Number.isInteger(p.panePid) || p.panePid <= 1 || !Number.isInteger(p.clientPid) || p.clientPid <= 1 || !/^[0-9]{1,24}$/.test(p.paneStart || "") || !/^[0-9]{1,24}$/.test(p.clientStart || "")) return null
    return {socket:p.socket,pane:p.pane,panePid:p.panePid,paneStart:p.paneStart,client:p.client,clientPid:p.clientPid,clientStart:p.clientStart}
}
function text(value, fallback, limit) { return typeof value === "string" && value.trim() ? value.replace(/[\u0000-\u001f]/g, " ").slice(0, limit) : fallback }
function normalize(encoded, now) {
    if (typeof encoded !== "string" || encoded.length > 4096) return null
    try {
        var p = JSON.parse(encoded)
        if (!p || Array.isArray(p) || typeof p !== "object" || typeof p.id !== "string" || !/^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$/.test(p.id || "")) return null
        if (["running", "waiting", "done", "error"].indexOf(p.state) < 0) return null
        var ttl = p.ttl === undefined ? (p.state === "done" ? 30 : 300) : Number(p.ttl)
        if (!isFinite(ttl) || ttl < 5 || ttl > 86400) return null
        var progress = p.progress === undefined ? -1 : Number(p.progress)
        if (!isFinite(progress) || progress < -1 || progress > 1) return null
        var kind = p.kind === "agent" ? "agent" : "task"
        var target = typeof p.target === "string" && /^0x[0-9a-fA-F]{1,16}$/.test(p.target) ? p.target : ""
        var attention = ["approval", "question"].indexOf(p.attention) >= 0 ? p.attention : "attention"
        return {requestId:typeof p.requestId === "string" && /^[0-9a-f]{32}$/.test(p.requestId) ? p.requestId : "",id:p.id, title:text(p.title, "Activity", 120), detail:text(p.detail, "", 240), state:p.state, progress:progress, kind:kind, project:text(p.project, "", 100), agent:text(p.agent, "", 40), target:target, targetTmux:tmuxTarget(p.targetTmux), targetWezterm:weztermTarget(p.targetWezterm), targetWorkspace:workspaceTarget(p.targetWorkspace), targetCodex:codexTarget(p.targetCodex), targetZellij:zellijTarget(p.targetZellij), agentProcess:processTarget(p.agentProcess), targetPid:Number.isInteger(p.targetPid) && p.targetPid > 0 ? p.targetPid : 0, targetStart:typeof p.targetStart === "string" && /^[0-9]{1,24}$/.test(p.targetStart) ? p.targetStart : "", targetBoot:typeof p.targetBoot === "string" && /^[0-9a-f-]{36}$/.test(p.targetBoot) ? p.targetBoot : "", attention:attention, eventKey:text(p.eventKey,"",80), expiresAt:now + ttl * 1000, updatedAt:now}
    } catch (_) { return null }
}
function upsert(items, item, now) {
    var next = items.filter(function(p) { return p.expiresAt > now && p.id !== item.id })
    if (next.length >= 8) return null
    next.push(item)
    return next
}
function focus(items) {
    var rank = {error:4, waiting:3, running:2, done:1, idle:0}
    return items.filter(function(p) { return p.state !== "idle" }).sort(function(a,b) { return rank[b.state] - rank[a.state] || b.updatedAt - a.updatedAt })[0] || null
}
function attention(items) {
    return items.filter(function(p) { return p.state === "waiting" || p.state === "error" }).sort(function(a,b) { return b.updatedAt - a.updatedAt })
}
function timer(value, now) {
    if (!value || typeof value !== "object" || Array.isArray(value)) return {status:"idle", deadline:0, remaining:0, total:0, label:"Timer"}
    var status = ["running", "paused", "done"].indexOf(value.status) >= 0 ? value.status : "idle"
    var remaining = Number(value.remaining), total = Number(value.total), deadline = Number(value.deadline)
    if (!isFinite(remaining) || !isFinite(total) || !isFinite(deadline) || remaining < 0 || total < 0 || remaining > 86400 || total > 86400 || deadline > now + 86400000) return timer(null,now)
    if (status === "running" && deadline <= now) status = "done"
    return {status:status, deadline:deadline, remaining:remaining, total:total, label:text(value.label,"Timer",80)}
}
// Recovery is a last-seen record, never evidence that an agent is still running.
function recover(records, now) {
    if (!Array.isArray(records)) return []
    return records.slice(0,8).map(function(p) {
        if (!p || p.kind !== "agent" || !Number.isFinite(p.updatedAt) || p.updatedAt > now || now - p.updatedAt > 86400000) return null
        var clean = normalize(JSON.stringify(Object.assign({},p,{state:"done",ttl:86400})),now)
        if (!clean) return null
        clean.state = "idle"; clean.detail = "Last seen before shell restart"; clean.progress = -1
        clean.requestId = ""; clean.eventKey = ""; clean.updatedAt = p.updatedAt; clean.expiresAt = p.updatedAt + 86400000
        if (!clean.targetPid || !clean.targetBoot || !clean.targetStart) clean.target = ""
        return clean
    }).filter(function(p) { return p !== null })
}
function discovered(items, records, now, dismissed) {
    if (!Array.isArray(records)) return items
    var next = items.filter(function(p) { return p.expiresAt > now })
    records.slice(0,8).forEach(function(p) {
        if (!p || dismissed.indexOf(p.id) >= 0 || next.some(function(i) { return i.id === p.id }) || next.length >= 8) return
        var recovered = recover([p],now)[0]
        if (!recovered) return
        recovered.detail = "Last seen in local session history"
        recovered.discovered = true
        next.push(recovered)
    })
    return next
}
function endedProcesses(items, result, now) {
    if (!result || !Array.isArray(result.ended) || !Array.isArray(result.checked)) return items
    return items.map(function(item) {
        if (result.ended.indexOf(item.id) < 0 || !item.agentProcess || item.requestId || ["running","waiting"].indexOf(item.state) < 0) return item
        var checked = result.checked.find(function(p) { return p.id === item.id })
        var current = item.agentProcess
        if (!checked || checked.pid !== current.pid || checked.start !== current.start || checked.boot !== current.boot) return item
        return Object.assign({},item,{state:"idle",detail:"Agent process ended",expiresAt:now+86400000})
    })
}
function snapshot(items) {
    return items.filter(function(p) { return p.kind === "agent" }).slice(0,8).map(function(p) {
        return {id:p.id, kind:"agent", title:p.title, project:p.project, agent:p.agent,
            target:p.target, targetTmux:tmuxTarget(p.targetTmux), targetWezterm:weztermTarget(p.targetWezterm), targetWorkspace:workspaceTarget(p.targetWorkspace), targetCodex:codexTarget(p.targetCodex), targetZellij:zellijTarget(p.targetZellij), agentProcess:processTarget(p.agentProcess), targetPid:p.targetPid, targetStart:p.targetStart, targetBoot:p.targetBoot, updatedAt:p.updatedAt}
    })
}
function serverSnapshot(items, records, now) {
    if (!Array.isArray(records) || records.length > 8) return {items:items,events:[]}
    var ids = records.map(function(p) { return p && p.id })
    var next = items.filter(function(p) { return p.expiresAt > now && (!p.serverSource || ids.indexOf(p.id) >= 0) })
    var events = []
    records.forEach(function(p) {
        if (!p || p.kind !== "agent" || p.agent !== "Codex") return
        var previous = next.find(function(i) { return i.id === p.id })
        var idle = p.state === "idle"
        var clean = normalize(JSON.stringify(Object.assign({},p,{state:idle ? "done" : p.state})),now)
        if (!clean) return
        clean.serverSource = true
        if (idle) {
            if (previous && previous.serverSource && previous.state === "done") return
            if (previous && ["running","waiting"].indexOf(previous.state) >= 0) {
                clean.state = "done"; clean.detail = "Turn complete"
            } else clean.state = "idle"
        }
        var updated = upsert(next,clean,now)
        if (!updated) return
        next = updated
        if (["done","waiting","error"].indexOf(clean.state) >= 0 && (!previous || previous.state !== clean.state || previous.attention !== clean.attention)) events.push(clean)
    })
    return {items:next,events:events}
}
if (typeof module !== "undefined") module.exports = {normalize,upsert,focus,attention,timer,recover,snapshot,discovered,endedProcesses,serverSnapshot}
