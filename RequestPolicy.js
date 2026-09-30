function put(record, key, value) {
    var next = Object.create(null)
    Object.keys(record || {}).forEach(function(k) { next[k] = record[k] })
    next[key] = value
    return next
}
function select(values, label, multiple) {
    if (!multiple) return [label]
    var next = Array.isArray(values) ? values.slice() : []
    var index = next.indexOf(label)
    if (index < 0) next.push(label)
    else next.splice(index, 1)
    return next
}
if (typeof module !== "undefined") module.exports = {put,select}
