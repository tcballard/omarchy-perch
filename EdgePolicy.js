function edge(value) { return ['top', 'bottom', 'left', 'right'].indexOf(value) >= 0 ? value : 'top' }
function vertical(value) { return value === 'left' || value === 'right' }
function inset(value, attached, barPosition, barHidden, barSize, gap) {
    return attached ? 0 : (value === barPosition && !barHidden ? Math.max(0, barSize) : 0) + gap
}
if (typeof module !== 'undefined') module.exports = {edge, vertical, inset}
