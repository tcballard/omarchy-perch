const assert=require('node:assert/strict'), e=require('../EdgePolicy.js');
for(const edge of ['top','bottom','left','right']) {
 assert.equal(e.edge(edge),edge);
 assert.equal(e.vertical(edge),edge==='left'||edge==='right');
 for(const bar of ['top','bottom','left','right']) {
  assert.equal(e.inset(edge,false,bar,false,30,8),edge===bar?38:8);
  assert.equal(e.inset(edge,false,bar,true,30,8),8);
  assert.equal(e.inset(edge,true,bar,false,30,8),0);
 }
}
for(const bad of ['',null,{},'TOP','diagonal']) assert.equal(e.edge(bad),'top');
console.log('Four-edge geometry policy: orientation, bar clearance, auto-hide and edge attachment passed.');
