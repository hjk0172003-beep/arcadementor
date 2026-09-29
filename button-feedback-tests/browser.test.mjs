import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';

const source = path.resolve('button-feedback/ui-button-sound.js');
const results = [];
const browser = await chromium.launch({args:['--autoplay-policy=no-user-gesture-required']});
const fixture = `<!doctype html><meta charset="utf-8"><style>
body{margin:0;background:#171e27;color:white;font-family:sans-serif}button{margin:4px;min-width:105px;height:42px}#stage{width:850px}#range{border:1px solid gray;padding:8px}#target{width:120px;height:40px;background:#faf3d9}#list{height:65px;overflow:auto}#list div{height:40px}#outside{position:absolute;left:10px;top:350px}
</style><div id="stage"><div id="setup"><button id="enterRange">Enter</button><button id="countPlus">+</button><button id="countMinus">-</button><button id="disabled" disabled>Disabled</button><button id="aria" aria-disabled="true">Unavailable</button><button id="voiceFemale" data-voice="female">Female</button><button id="voiceMale" data-voice="male">Male</button><button id="voiceOff" data-voice="off">Voice off</button><button id="sfx1" data-sfx="airgun">Sound 1</button><button id="sfx2" data-sfx="pistol">Sound 2</button><button id="sfxOff" data-sfx="off">Sound off</button></div><div id="range"><button id="startGameButton">START</button><button id="lockButton">Lock</button><button id="liveResult"><span>Results</span></button><button id="liveAnalysis">Analysis</button><button id="rangeRules">Rules</button><canvas id="target"></canvas></div><div id="modal"><button id="modalClose">Close</button><button id="savePhoto">Save</button><div id="list"><div>One</div><div>Two</div><div>Three</div><div>Four</div></div></div></div><button id="outside">Outside game</button>`;

async function setup(options = {}) {
  const context = await browser.newContext({ viewport:{width:915,height:412}, ...options });
  const page = await context.newPage();
  const errors=[];
  page.on('pageerror', e=>errors.push(e.message));
  await page.setContent(fixture);
  await page.evaluate(() => {
    window.audit={starts:[],contexts:0,mixes:0,actions:[],destinationOnly:true,peaks:[],durations:[]};
    window.fixtureState={locked:false,sfx:'airgun',shots:0};
    window.BattleZoneInput={status:()=>({locked:fixtureState.locked})};
    window.BZ={get:()=>({session:{config:{sfx:fixtureState.sfx}}})};
    const Native=window.AudioContext;
    window.AudioContext=function(...args){
      const c=new Native(...args);audit.contexts++;
      const cb=c.createBuffer.bind(c);c.createBuffer=(...x)=>{const b=cb(...x);return b;};
      const mix=c.createMediaStreamDestination.bind(c);c.createMediaStreamDestination=(...x)=>{audit.mixes++;return mix(...x);};
      const original=c.createBufferSource.bind(c);c.createBufferSource=(...x)=>{
        const s=original(...x);const start=s.start.bind(s);const connect=s.connect.bind(s);
        s.connect=(node,...rest)=>{if(node!==c.destination)audit.destinationOnly=false;return connect(node,...rest);};
        s.start=(...rest)=>{audit.starts.push(performance.now());audit.durations.push(s.buffer.duration);audit.peaks.push(Math.max(...s.buffer.getChannelData(0).map(Math.abs)));return start(...rest);};
        return s;
      };
      return c;
    };
    for(const b of document.querySelectorAll('button'))b.addEventListener('click',e=>{audit.actions.push(b.id);e.stopPropagation();});
    document.getElementById('target').addEventListener('pointerdown',()=>fixtureState.shots++);
  });
  await page.addScriptTag({path:source});
  await context.setOffline(true);
  return {page,context,errors};
}
async function count(page){return page.evaluate(()=>audit.starts.length);}
async function verify(page, label, delta, action){const before=await count(page);await action();await page.waitForTimeout(110);assert.equal((await count(page))-before,delta,label);results.push({label,passed:true});}

try {
  const {page,context,errors}=await setup();
  await verify(page,'First normal click is audible',1,()=>page.locator('#enterRange').click());
  await verify(page,'Plus click',1,()=>page.locator('#countPlus').click());
  await verify(page,'Minus click',1,()=>page.locator('#countMinus').click());
  await verify(page,'Clicking nested span works once',1,()=>page.locator('#liveResult span').click());
  await verify(page,'Analysis click',1,()=>page.locator('#liveAnalysis').click());
  await verify(page,'Rules click',1,()=>page.locator('#rangeRules').click());
  await verify(page,'Close click',1,()=>page.locator('#modalClose').click());
  await verify(page,'Save click',1,()=>page.locator('#savePhoto').click());
  await verify(page,'START keeps only its existing beep',0,()=>page.locator('#startGameButton').click());
  await verify(page,'Female selection keeps voice preview, no extra tone',0,()=>page.locator('#voiceFemale').click());
  await verify(page,'Male selection keeps voice preview, no extra tone',0,()=>page.locator('#voiceMale').click());
  await verify(page,'Firing sound 1 keeps preview',0,()=>page.locator('#sfx1').click());
  await verify(page,'Firing sound 2 keeps preview',0,()=>page.locator('#sfx2').click());
  await verify(page,'OFF choice has a confirmation',1,()=>page.locator('#sfxOff').click());
  await verify(page,'Voice OFF has a confirmation',1,()=>page.locator('#voiceOff').click());
  await verify(page,'Existing lock tone is not duplicated',0,()=>page.locator('#lockButton').click());
  await page.evaluate(()=>fixtureState.sfx='off');
  await verify(page,'Lock confirms even if firing sound is off',1,()=>page.locator('#lockButton').click());
  await page.evaluate(()=>fixtureState.locked=true);
  await verify(page,'Locked range cannot generate a success click tone',0,()=>page.locator('#liveAnalysis').click());
  await verify(page,'Unlock can confirm while range is locked',1,()=>page.locator('#lockButton').click());
  await page.evaluate(()=>fixtureState.locked=false);
  await verify(page,'Unavailable aria-disabled button is silent',0,()=>page.locator('#aria').click({force:true}));
  const disabledBox=await page.locator('#disabled').boundingBox();
  await verify(page,'Disabled button is silent',0,()=>page.mouse.click(disabledBox.x+20,disabledBox.y+20));
  await verify(page,'Non-game button is silent',0,()=>page.locator('#outside').click());
  await verify(page,'Target shot does not get a menu tone',0,()=>page.locator('#target').click());
  assert.equal(await page.evaluate(()=>fixtureState.shots),1);results.push({label:'Target input handler preserved',passed:true});
  await verify(page,'Programmatic click is silent',0,()=>page.evaluate(()=>document.getElementById('countPlus').click()));
  await page.locator('#countPlus').focus();
  await verify(page,'Keyboard Enter activates once',1,()=>page.keyboard.press('Enter'));
  await verify(page,'Keyboard Space activates once',1,()=>page.keyboard.press('Space'));
  await page.evaluate(()=>{const b=document.createElement('button');b.id='dynamic';b.innerHTML='<span>Dynamic result tab</span>';document.getElementById('modal').append(b);b.onclick=()=>audit.actions.push('dynamic');});
  await verify(page,'Newly created modal button works',1,()=>page.locator('#dynamic').click());
  await page.addScriptTag({path:source});
  await verify(page,'Duplicate script is harmless',1,()=>page.locator('#dynamic').click());
  await verify(page,'Two rapid deliberate taps give two confirmations',2,async()=>{await page.locator('#countPlus').click();await page.locator('#countMinus').click();});
  const box=await page.locator('#countPlus').boundingBox();
  await page.mouse.move(box.x+10,box.y+15);await page.mouse.down();
  await verify(page,'Holding button is not a repeat sound',0,()=>page.waitForTimeout(300));
  await verify(page,'Releasing a held button confirms once',1,()=>page.mouse.up());
  const state=await page.evaluate(()=>audit);
  assert.equal(state.contexts,1);assert.equal(state.mixes,0);assert.equal(state.destinationOnly,true);
  assert.ok(state.durations.every(d=>d>=0.055&&d<0.056));
  assert.ok(state.peaks.every(p=>p>0.05&&p<1));
  assert.ok(state.actions.includes('enterRange')&&state.actions.includes('liveResult')&&state.actions.includes('dynamic'));
  assert.deepEqual(errors,[]);
  results.push({label:'One reusable real WebAudio context, non-silent 55ms sound, not connected to replay mix',passed:true});
  await context.close();

  const touch=await setup({isMobile:true,hasTouch:true,deviceScaleFactor:2});
  await verify(touch.page,'Mobile first touch produces one sound, not two',1,()=>touch.page.locator('#enterRange').tap());
  await verify(touch.page,'Mobile subsequent touch',1,()=>touch.page.locator('#countPlus').tap());
  const cdp=await touch.context.newCDPSession(touch.page);
  const list=await touch.page.locator('#list').boundingBox();
  await verify(touch.page,'Scrolling records never plays a button sound',0,async()=>{
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:list.x+80,y:list.y+55,id:1}]});
    for(let i=1;i<=8;i++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:list.x+80,y:list.y+55-i*8,id:1}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  });
  await verify(touch.page,'Mobile target hit is still silent from add-on',0,()=>touch.page.locator('#target').tap());
  assert.equal(await touch.page.evaluate(()=>fixtureState.shots),1);
  assert.deepEqual(touch.errors,[]);
  results.push({label:'Mobile original input handlers remain operational',passed:true});
  await touch.context.close();

  const noAudio=await setup();
  await noAudio.page.evaluate(()=>{window.AudioContext=undefined;window.webkitAudioContext=undefined;});
  await verify(noAudio.page,'Unsupported audio does not break buttons',0,()=>noAudio.page.locator('#enterRange').click());
  assert.ok(await noAudio.page.evaluate(()=>audit.actions.includes('enterRange')));
  assert.deepEqual(noAudio.errors,[]);
  results.push({label:'Audio failure leaves original action working',passed:true});
  await noAudio.context.close();
} finally { await browser.close(); }
await fs.mkdir('test-results',{recursive:true});
await fs.writeFile('test-results/browser.json',JSON.stringify({scope:'Isolated add-on, actual Chromium mouse/keyboard/touch and WebAudio. Not full game or physical phone test.',passed:results.length,results},null,2));
console.log(JSON.stringify({passed:results.length,scope:'Isolated add-on browser tests'},null,2));
