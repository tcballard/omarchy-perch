function key(p) { return p ? String(p.dbusName || "") : "" }
function select(players, preferred) {
    var chosen = null, playing = null, fallback = null
    for (var i = 0; i < players.length; i++) {
        var p = players[i]
        if (!p || key(p).indexOf("playerctld") !== -1) continue
        if (key(p) === preferred) chosen = p
        if (!playing && p.isPlaying) playing = p
        if (!fallback) fallback = p
    }
    return chosen || playing || fallback
}
function allowed(p, action) {
    if (!p || !p.canControl) return false
    if (action === "next") return !!p.canGoNext
    if (action === "previous") return !!p.canGoPrevious
    if (action === "toggle") return p.isPlaying ? !!p.canPause : !!p.canPlay
    return false
}
function bounded(value, fallback) { return typeof value === "string" && value.length ? value.slice(0, 256) : fallback }
function localArt(value) {
    // Avoid implicit network fetches and arbitrary image providers.
    var s = typeof value === "string" ? value : ""
    return s.length <= 4096 && /^file:\/\/\//.test(s) ? s : ""
}
function seconds(value) { return isFinite(value) && value > 0 ? Number(value) : 0 }
function progress(position, length) { return length > 0 ? Math.max(0, Math.min(1, seconds(position) / length)) : 0 }
function time(value) { var n = Math.floor(seconds(value)); return Math.floor(n / 60) + ":" + (n % 60 < 10 ? "0" : "") + n % 60 }
function payload(encoded) {
    if (typeof encoded !== "string" || encoded.length > 2048) return {}
    try { var p = JSON.parse(encoded); return p && typeof p === "object" && !Array.isArray(p) ? p : {} } catch (_) { return {} }
}
if (typeof module !== "undefined") module.exports = { key, select, allowed, bounded, localArt, seconds, progress, time, payload }
