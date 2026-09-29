function text(value, limit) {
    return typeof value === "string" ? value.slice(0, limit).replace(/[\x00-\x1f\x7f]/g, " ") : "";
}
function parse(payload) {
    if (typeof payload !== "string" || payload.length > 48000) return null;
    try {
        var p = JSON.parse(payload);
        if (!p || p.version !== 1 || !Array.isArray(p.items) || p.items.length > 20 || typeof p.session !== "string" || !/^[a-zA-Z0-9.-]{1,80}$/.test(p.session)) return null;
        var seen = {};
        var items = p.items.map(function (row) {
            if (!row || typeof row.key !== "string" || !/^[a-zA-Z0-9.-]{1,100}$/.test(row.key) || seen[row.key]) throw new Error("key");
            seen[row.key] = true;
            return {key:row.key, app:text(row.app,64), title:text(row.title,120), body:text(row.body,400), actions:Array.isArray(row.actions) ? row.actions.slice(0,4).filter(function(a) { return a && typeof a.id === "string" && a.id.length <= 128; }).map(function(a) {return {id:a.id,label:text(a.label,32)};}) : []};
        });
        return {session:p.session, dnd:p.dnd === true, preview:text(p.preview,100), items:items};
    } catch (_) { return null; }
}
