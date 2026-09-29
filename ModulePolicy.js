// Built-in cards and validated plugin launch IDs; never executable paths.
var catalog = [
    {id:"music", title:"Music", glyph:"♫", page:"music"},
    {id:"timer", title:"Timers", glyph:"◷", page:"timer"},
    {id:"clipboard", title:"Clipboard", glyph:"▤", page:"clipboard"},
    {id:"stats", title:"System stats", glyph:"▥", page:"stats"},
    {id:"weather", title:"Weather", glyph:"☀", page:"weather"},
    {id:"shelf", title:"Files", glyph:"▱", page:"shelf"},
    {id:"calendar", title:"Calendar", glyph:"▦", page:"calendar"},
    {id:"activity", title:"Activity", glyph:"◉", page:"activity"},
    {id:"system", title:"Devices", glyph:"☷", page:"system"},
    {id:"inbox", title:"Inbox", glyph:"◇", page:"inbox"},
    {id:"desktop", title:"Apps", glyph:"⊞", page:"desktop"}
];
var defaults = ["music", "timer", "clipboard", "stats", "weather"];
function pluginId(id) {
    if (typeof id !== "string" || id.indexOf("plugin:") !== 0) return "";
    var value = id.slice(7);
    return value.length <= 160 && /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(value) && value !== "io.github.tcballard.perch" && value.indexOf("omarchy.") !== 0 ? value : "";
}
function get(id) {
    var target = pluginId(id);
    if (target) return {id:id, title:target, glyph:"◇", page:"plugins", pluginId:target};
    return catalog.find(function(m) { return m.id === id; }) || null;
}
function clean(value) {
    if (!Array.isArray(value)) return defaults.slice();
    var result = [];
    value.slice(0, 64).forEach(function(id) {
        if (get(id) && result.indexOf(id) < 0 && result.length < 8) result.push(id);
    });
    return result.length ? result : defaults.slice();
}
function move(value, id, target) {
    var result = clean(value), from = result.indexOf(id);
    if (from < 0 || !Number.isInteger(target) || target < 0 || target >= result.length) return result;
    result.splice(from, 1); result.splice(target, 0, id); return result;
}
function toggle(value, id) {
    var result = clean(value), index = result.indexOf(id);
    if (!get(id)) return result;
    if (index >= 0) { if (result.length > 1) result.splice(index, 1); }
    else if (result.length < 8) result.push(id);
    return result;
}
if (typeof module !== "undefined") module.exports = {catalog,defaults,get,clean,move,toggle,pluginId};
