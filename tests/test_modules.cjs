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
assert.equal(prefs.clean({layoutMode:"pill"}).layoutMode,"notch");
assert.equal(prefs.clean({}).layoutMode,"notch");

assert.deepEqual(m.clean(['music','plugin:example.notes','plugin:../bad','plugin:omarchy.lock','plugin:io.github.tcballard.perch']),['music','plugin:example.notes']);
assert.deepEqual(m.move(['music','plugin:example.notes'],'plugin:example.notes',0),['plugin:example.notes','music']);
assert.equal(m.pluginId('plugin:example.notes;id'),'');

const search=require('../ModulePolicy.js').search;
assert.equal(search([{id:'example.rss',name:'RSS Feed',enabled:true}], 'rss')[0].id,'plugin:example.rss');
assert.equal(search([{id:'example.disabled',name:'Disabled',enabled:false}], 'disabled')[0].enabled,false);
assert.equal(search([{id:'../../bad',name:'Bad',enabled:true}], 'bad').length,0);
assert.equal(search([], 'clipboard')[0].id,'clipboard');
assert.equal(search([], 'no matches').length,0);
