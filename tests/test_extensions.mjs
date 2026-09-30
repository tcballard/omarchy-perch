import fs from 'node:fs';
import assert from 'node:assert/strict';
const sent=[];
globalThis.perchExec = (program, argv, options, callback) => {
    assert.equal(program,'python3');assert.equal(options.timeout,2500);
    assert.equal(options.maxBuffer,1024);
    return {stdin:{on(){},end(raw){sent.push({argv,data:JSON.parse(raw)});callback(null);}}};
};
async function load(name,agent){
    let source=fs.readFileSync(new URL('../scripts/extensions/'+name+'.js',import.meta.url),'utf8');
    source=source.replace("import { execFile } from 'node:child_process';",'const execFile=globalThis.perchExec;').replace('__PERCH_ADAPTER__','"/owned/hook"').replace('__PERCH_AGENT__',JSON.stringify(agent));
    return import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
}
for(const agent of ['pi','omp']){
    const handlers={};(await load('pi',agent)).default({on(event,fn){handlers[event]=fn;}});
    assert.deepEqual(Object.keys(handlers),['agent_start','agent_end','session_shutdown']);
    for(const event of Object.keys(handlers)){
        await handlers[event]({messages:['PRIVATE']},{cwd:'/work/project',sessionManager:{getSessionId:()=> 'session'}});
        assert.equal(sent.at(-1).data.state,event==='agent_start'?'running':'done');
        assert.equal(sent.at(-1).argv.at(-1),agent);
    }
}
const plugin=await (await load('opencode')).PerchStatus({directory:'/work/project'});
for(const [type,status,state] of [['session.status','busy','running'],['session.status','retry','running'],['session.status','idle','done'],['session.error',null,'error'],['permission.asked',null,'waiting'],['permission.replied',null,'running']]){
    await plugin.event({event:{type,properties:{sessionID:'abc',status:{type:status},input:'PRIVATE'}}});
    assert.equal(sent.at(-1).data.state,state);
}
const n=sent.length;
await plugin.event({event:{type:'message.updated',properties:{sessionID:'abc',message:'PRIVATE'}}});
await plugin.event({event:{type:'session.status',properties:{sessionID:'abc',status:{type:'unknown'}}}});
await plugin.event({event:{type:'permission.asked',properties:{sessionID:'x'.repeat(4097)}}});
assert.equal(sent.length,n);assert(!JSON.stringify(sent).includes('PRIVATE'));
globalThis.perchExec=()=>{throw Error('unavailable')};
const failed=await (await load('opencode','failed')).PerchStatus({});
// The imported module has captured the previous sender; malformed events still do not throw.
await failed.event({event:null});
console.log('Pi/OMP/OpenCode extension lifecycle, fixed argv, bounded transport and content exclusion passed.');
