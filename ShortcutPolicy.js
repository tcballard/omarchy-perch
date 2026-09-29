// Deliberately one chord: Ctrl+Alt plus a letter/digit. No text-editing or navigation keys.
function clean(value, items) {
    var result = {}, used = [];
    if (!value || typeof value !== "object" || Array.isArray(value)) return result;
    items.forEach(function(id) {
        var chord = value[id];
        if (typeof chord === "string" && /^Ctrl\+Alt\+[A-Z0-9]$/.test(chord) && used.indexOf(chord) < 0) {
            result[id] = chord; used.push(chord);
        }
    });
    return result;
}
function assign(value, items, id, chord) {
    var result = clean(value, items);
    if (items.indexOf(id) < 0) return null;
    if (chord === "") { delete result[id]; return result; }
    if (!/^Ctrl\+Alt\+[A-Z0-9]$/.test(chord) || Object.keys(result).some(function(key) {return key !== id && result[key] === chord;})) return null;
    result[id] = chord; return result;
}
if (typeof module !== "undefined") module.exports = {clean,assign};
