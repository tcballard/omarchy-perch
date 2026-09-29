const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const p=vm.createContext({});vm.runInContext(fs.readFileSync(__dirname+'/../NotificationPolicy.js','utf8'),p);
const valid={version:1,session:'abc',items:[{key:'abc.1',app:'App',title:'<b>Title</b>',body:'x'.repeat(900),actions:[{id:'default',label:'Open'}]}]};
const result=p.parse(JSON.stringify(valid));assert.equal(result.items[0].body.length,400);assert.equal(result.items[0].title,'<b>Title</b>');
for(const data of ['x'.repeat(48001),'{}','null',JSON.stringify({...valid,items:Array(21).fill(valid.items[0])}),JSON.stringify({...valid,session:'../bad'}),JSON.stringify({...valid,items:[valid.items[0],valid.items[0]]})]) assert.equal(p.parse(data),null);
console.log('Inbox IPC bounds, shape, unique identity and text truncation passed.');
