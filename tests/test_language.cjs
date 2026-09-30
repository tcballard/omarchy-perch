const assert=require('node:assert/strict');
const L=require('../LanguagePolicy.js'),P=require('../PreferencesPolicy.js');
assert.equal(P.clean({language:'zh-CN'}).language,'zh-CN');
assert.equal(P.clean({language:'invalid'}).language,'en');
assert.equal(L.translate('Settings','zh-CN'),'设置');
assert.equal(L.translate('Settings','en'),'Settings');
assert.equal(L.translate('User-authored project','zh-CN'),'User-authored project');
for(const [english,chinese] of Object.entries(L.chinese)) {
 assert.ok(english && typeof chinese==='string' && chinese);
 assert.equal((english.match(/\n/g)||[]).length,(chinese.match(/\n/g)||[]).length);
}
console.log('English/Chinese interface dictionary, fallback and preference normalization passed.');
