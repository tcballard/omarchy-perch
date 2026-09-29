const assert = require('node:assert/strict');
const m = require('../ModulePolicy.js');
assert.deepEqual(m.clean(['stats','../evil.qml','stats','weather']), ['stats','weather']);
assert.deepEqual(m.clean([]), m.defaults);
assert.deepEqual(m.clean(null), m.defaults);
assert.equal(m.clean(m.catalog.map(x=>x.id)).length, 8);
assert.deepEqual(m.move(['stats','weather','clipboard'],'stats',2), ['weather','clipboard','stats']);
assert.deepEqual(m.move(['stats','weather'],'stats',-1), ['stats','weather']);
assert.deepEqual(m.toggle(['stats'],'stats'), ['stats']);
assert.deepEqual(m.toggle(['stats'],'weather'), ['stats','weather']);
assert.equal(m.get('file:///tmp/bad.qml'), null);
console.log('Native module registry bounds, allowlist, reorder and last-item preservation passed.');

const prefs = require("../PreferencesPolicy.js");
assert.equal(prefs.clean({layoutMode:"pill"}).layoutMode,"strip");
assert.equal(prefs.clean({}).layoutMode,"strip");
