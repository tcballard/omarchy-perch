const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(require('node:path').join(__dirname,'../Panel.qml'),'utf8');
const policy=require('../MediaPolicy.js');
const clock=()=>({running:false,restart(){this.running=true},stop(){this.running=false}});
const screen={name:'eDP-1'};
const c={Policy:policy,Edges:require("../EdgePolicy.js"),edge:"top",edgeRemapping:false,edgeRemapTimer:clock(),Qt:{callLater:f=>f()},Hyprland:{focusedMonitor:{name:'eDP-1'}},fixture:{state:'',setState(s){this.state=s}},view:{focused:0,forceActiveFocus(){this.focused++}},screens:[screen],fullscreen:false,targetScreen:null,opened:false,expanded:false,keyboardMode:false,demo:false,focusPrimed:false,hoverTimer:clock(),leaveTimer:clock(),focusPrimeTimer:clock(),shell:null,service:null};
vm.createContext(c);
for(const name of ['open','close','collapse','reveal','setEdge']) {
 const match=source.match(new RegExp('    function '+name+'\\([^]*?\\n    }'));
 assert.ok(match,name+' missing');vm.runInContext(match[0],c);
}
c.open('{"demo":true,"state":"paused"}');
assert.equal(c.opened,true);assert.equal(c.expanded,true);assert.equal(c.demo,true);
assert.equal(c.fixture.state,'paused');assert.equal(c.keyboardMode,true);assert.equal(c.focusPrimeTimer.running,true);assert.equal(c.view.focused,1);
c.focusPrimed=true;c.open('{}');assert.equal(c.focusPrimed,false);assert.equal(c.demo,false);assert.equal(c.view.focused,2);
c.leaveTimer.restart();c.hoverTimer.restart();c.close();
for(const field of ['opened','expanded','keyboardMode','demo','focusPrimed']) assert.equal(c[field],false);
for(const field of ['leaveTimer','hoverTimer','focusPrimeTimer']) assert.equal(c[field].running,false);
c.open('{"pointer":true}');assert.equal(c.keyboardMode,false);assert.equal(c.focusPrimeTimer.running,false);assert.equal(c.view.focused,2);
c.close();c.open('{broken');assert.equal(c.expanded,true);assert.equal(c.demo,false);
c.close();c.open('x'.repeat(3000));assert.equal(c.demo,false);
c.close();c.reveal(true);assert.equal(c.expanded,true);assert.equal(c.keyboardMode,false);
c.close();let hidden=0;c.shell={hide(id){assert.equal(id,'io.github.tcballard.perch');hidden++}};c.collapse();assert.equal(hidden,1);
c.fullscreen=true;c.open('{}');assert.equal(c.expanded,false);assert.equal(c.keyboardMode,false);
console.log('Panel production lifecycle methods: open/reopen, focus prime, pointer mode, malformed payload, timer cleanup and host hide passed.');

c.fullscreen=false;c.shell=null;
for (const edge of ['bottom','left','right','top']) {
 c.open('{"demo":true}');c.setEdge(edge);assert.equal(c.demo,true);assert.equal(c.edge,edge);assert.equal(c.expanded,true);assert.equal(c.edgeRemapping,true);assert.equal(c.edgeRemapTimer.running,true);assert.equal(c.keyboardMode,true);assert.equal(c.focusPrimed,false);assert.equal(c.leaveTimer.running,false);
}
c.setEdge('invalid');assert.equal(c.edge,'top');

// A pointer reveal stays on its current display even if another has keyboard focus.
c.close(); c.targetScreen=screen; c.screens=[screen,{name:"HDMI-A-1"}]; c.Hyprland.focusedMonitor={name:"HDMI-A-1"};
c.open('{"pointer":true}'); assert.equal(c.targetScreen.name,"eDP-1");
c.open("{}"); assert.equal(c.targetScreen.name,"HDMI-A-1");
