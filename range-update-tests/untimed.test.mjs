import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const script=fs.readFileSync('test-results/patched-fixture.js','utf8');
const results=[];
function check(label,fn){fn();results.push({label,passed:true});}
for(const mode of ['pistol','rifle','zero']){
 const ctx=vm.createContext({});vm.runInContext(script,ctx);
 const run=x=>vm.runInContext(x,ctx);
 run(`settings.mode='${mode}';settings.shotLimit=5;settings.totalLimit=30;renderSetup();startRange();`);
 check(mode+': saved time settings neutralized',()=>assert.ok(run('settings.shotLimit===0&&settings.totalLimit===0&&session.config.shotLimit===0&&session.config.totalLimit===0')));
 // Even an old nonzero session value cannot trigger a hidden countdown.
 run('session.config.shotLimit=5;session.config.totalLimit=30;now=600000;advance();renderClocks();');
 check(mode+': no shot timeout or automatic end after ten minutes',()=>assert.ok(run('session.started&&!session.ended&&!session.shotExpired&&events.length===0')));
 check(mode+': no fabricated zero-score shot',()=>assert.equal(run('session.shots.length'),0));
 check(mode+': elapsed timestamp preserved',()=>assert.equal(run('session.elapsed'),600));
 check(mode+': ordinary hit still accepted',()=>assert.equal(run('BattleZoneInput.hit(0,0)'),true));
 check(mode+': hit timestamp not reset or lost',()=>assert.equal(run('session.shots[0].time'),600));
 check(mode+': deleted controls are not bound',()=>assert.equal(run('bindings.join(",")'),'startGameButton,liveResult'));
 check(mode+': input conversion untouched',()=>assert.equal(run('inputCoordinateUnchanged(10,20).y'),11));
}
for(const count of [10,40,60,0]){
 const ctx=vm.createContext({});vm.runInContext(script,ctx);
 vm.runInContext(`settings.limit=${count};startRange();for(let n=0;n<${count||75};n++)receiveHit(n,0);`,ctx);
 check('Shot mode '+(count||'unlimited')+' retained',()=>assert.equal(vm.runInContext('session.shots.length',ctx),count||75));
 check('Shot mode '+(count||'unlimited')+' ending retained',()=>assert.equal(vm.runInContext('session.ended',ctx),!!count));
}
const ctx=vm.createContext({});vm.runInContext(script,ctx);vm.runInContext('startRange();session.paused=true;now=10000;advance();',ctx);
check('Pause behavior retained',()=>assert.equal(vm.runInContext('session.elapsed',ctx),0));
fs.writeFileSync('test-results/untimed.json',JSON.stringify({scope:'Patched synthetic game contract executed in JavaScript; not full game or device testing',passed:results.length,results},null,2));
console.log(JSON.stringify({passed:results.length}));
