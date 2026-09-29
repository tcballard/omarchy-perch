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
        return {id:p.id, title:text(p.title, "Activity", 120), detail:text(p.detail, "", 240), state:p.state, progress:progress, kind:kind, project:text(p.project, "", 100), agent:text(p.agent, "", 40), target:target, attention:attention, eventKey:text(p.eventKey,"",80), expiresAt:now + ttl * 1000, updatedAt:now}
    } catch (_) { return null }
}
function upsert(items, item, now) {
    var next = items.filter(function(p) { return p.expiresAt > now && p.id !== item.id })
    if (next.length >= 8) return null
    next.push(item)
    return next
}
function focus(items) {
    var rank = {error:4, waiting:3, running:2, done:1}
    return items.slice().sort(function(a,b) { return rank[b.state] - rank[a.state] || b.updatedAt - a.updatedAt })[0] || null
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
if (typeof module !== "undefined") module.exports = {normalize,upsert,focus,attention,timer}
