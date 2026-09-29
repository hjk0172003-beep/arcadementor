import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import {chromium} from 'playwright';

const source=fs.readFileSync('menu-bgm/menu-bgm.js','utf8');
const results=[];
const check=(ok,name)=>{assert.ok(ok,name);results.push({name,passed:true});console.log('PASS: '+name);};
const wav=Buffer.alloc(44+44100*2);wav.write('RIFF');wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(44100,24);wav.writeUInt32LE(88200,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(wav.length-44,40);for(let i=0;i<44100;i++)wav.writeInt16LE(Math.round(6000*Math.sin(2*Math.PI*400*i/44100)),44+i*2);
const fixture=`<!doctype html><html lang="ko"><head><meta charset="utf-8"><style>[hidden]{display:none!important}body{margin:0;background:#10141b;color:white}#stage{width:1920px;height:1080px;touch-action:none}.setupHeader{height:105px;display:flex;align-items:center;padding:0 42px;gap:28px}.setupHeader>div{flex:1}.setupHeader button{font-size:27px}button{background:#1c222b;color:white;border:1px solid #3d4653;border-radius:9px;min-height:60px;padding:10px 19px;font-size:29px}button.selected{background:#FFD400;color:#11151b}#modal{position:absolute;inset:150px 40px;background:#121212}#range{padding:50px}</style></head><body><div id="stage"><div id="splash">Loading</div><section id="setup" hidden><header class="setupHeader"><div><b>BATTLE ZONE</b></div><button id="setupRules">경기룰 보기</button><button id="setupHistory">개인 기록</button></header><button id="modePistol">공기권총</button><button id="sfxOff">효과음 OFF</button><button id="enterRange">사격 화면으로</button></section><section id="range" hidden><button id="startGameButton">START</button><button id="backSetup">모드 선택</button></section><div id="modal" hidden><button id="modalClose">닫기</button></div></div><script>
window.originalGameHandler=function(){window.modeClicks++};window.modeClicks=0;window.savedGameHandler=window.originalGameHandler;window.storageCalls=0;window.BZStorage={setItem(){window.storageCalls++}};window.savedStorage=window.BZStorage;window.settings={sfx:'airgun',shots:0};window.savedSettings=JSON.stringify(window.settings);
const setup=document.getElementById('setup'),range=document.getElementById('range'),modal=document.getElementById('modal');window.showSetup=function(){setup.hidden=false;range.hidden=true;modal.hidden=true;document.getElementById('splash').hidden=true};document.getElementById('modePistol').onclick=window.originalGameHandler;document.getElementById('enterRange').onclick=()=>{window.stoppedBeforeRangeHandler=document.getElementById('bzMenuBgmAudio').paused;setup.hidden=true;range.hidden=false};document.getElementById('backSetup').onclick=window.showSetup;document.getElementById('setupRules').onclick=()=>{modal.hidden=false};document.getElementById('modalClose').onclick=()=>{modal.hidden=true};document.getElementById('sfxOff').onclick=()=>{window.settings.sfx='off'};
</script><script src="/menu-bgm.js"></script></body></html>`;
const server=http.createServer((req,res)=>{if(req.url.startsWith('/menu-bgm.js')){res.setHeader('Content-Type','text/javascript');res.end(source)}else if(req.url.startsWith('/mode-selection-bgm.wav')){res.setHeader('Content-Type','audio/wav');res.end(wav)}else{res.setHeader('Content-Type','text/html; charset=utf-8');res.end(fixture)}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));const url=`http://127.0.0.1:${server.address().port}`;
let browser;
async function playing(page){try{await page.waitForFunction(()=>{const a=document.getElementById('bzMenuBgmAudio');return a&&!a.paused&&a.currentTime>.02},null,{timeout:10000});}catch(e){console.log('MEDIA DIAGNOSTIC',await page.evaluate(()=>{const a=document.getElementById('bzMenuBgmAudio');return {paused:a?.paused,time:a?.currentTime,ready:a?.readyState,network:a?.networkState,src:a?.src,error:a?.error?.message,hidden:document.hidden,focus:document.hasFocus(),setup:document.getElementById('setup').hidden,range:document.getElementById('range').hidden,modal:document.getElementById('modal').hidden}}));throw e;}}
try{
 browser=await chromium.launch({headless:true,args:['--autoplay-policy=no-user-gesture-required']});const context=await browser.newContext({viewport:{width:1920,height:1080}});const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto(url);await page.waitForFunction(()=>window.BZMenuBgmInstalled);
 const state=()=>page.evaluate(()=>({paused:document.getElementById('bzMenuBgmAudio').paused,time:document.getElementById('bzMenuBgmAudio').currentTime,loop:document.getElementById('bzMenuBgmAudio').loop,volume:document.getElementById('bzMenuBgmAudio').volume}));
 check((await state()).paused,'No playback during loading');check(await page.locator('#setupBgmToggle').count()===1,'One ON/OFF button only');await page.evaluate(()=>showSetup());await playing(page);
 check((await state()).time>0,'Audio actually advances on mode selection');check((await state()).loop,'Music loops');check(Math.abs((await state()).volume-.22)<.001,'BGM volume independent and moderate');await page.waitForTimeout(1200);check(!(await state()).paused,'Loop survives track end');
 check(await page.evaluate(()=>window.originalGameHandler===window.savedGameHandler&&window.BZStorage===window.savedStorage&&window.storageCalls===0&&JSON.stringify(window.settings)===window.savedSettings),'Original game functions/settings/storage untouched');
 await page.click('#modePistol');check(await page.evaluate(()=>window.modeClicks===1),'Original mode button handler still runs exactly once');await page.click('#sfxOff');check(!(await state()).paused,'BGM toggle independent of firing effect OFF');
 await page.click('#setupBgmToggle');await page.waitForTimeout(80);check((await state()).paused,'OFF stops playback immediately');check((await state()).time===0,'OFF resets track');check(await page.locator('#setupBgmToggle').textContent()==='배경음 OFF','OFF button label');await page.reload();await page.evaluate(()=>showSetup());await page.waitForTimeout(150);check((await state()).paused,'OFF persists on next launch');
 await page.click('#setupBgmToggle');await playing(page);check(await page.locator('#setupBgmToggle').textContent()==='배경음 ON','ON enables playback');
 await page.click('#setupRules');await page.waitForTimeout(80);check((await state()).paused,'Music off in overlaid rules/history/result dialogs');await page.click('#modalClose');await playing(page);check(true,'Music resumes after returning to menu');
 await page.click('#enterRange');check(await page.evaluate(()=>window.stoppedBeforeRangeHandler),'Stops BEFORE original shooting-screen handler');await page.waitForTimeout(180);check((await state()).paused,'No BGM on START waiting screen');await page.click('#startGameButton');await page.waitForTimeout(150);check((await state()).paused,'No BGM when START activated');
 await page.click('#backSetup');await playing(page);check(true,'Return to mode selection restores ON');
 await page.evaluate(()=>window.dispatchEvent(new Event('blur')));check((await state()).paused,'Window blur stops audio');await page.evaluate(()=>window.dispatchEvent(new Event('focus')));await playing(page);await page.evaluate(()=>window.dispatchEvent(new Event('pagehide')));check((await state()).paused,'Page hide stops audio');await page.evaluate(()=>window.dispatchEvent(new Event('pageshow')));await playing(page);
 await page.addScriptTag({url:url+'/menu-bgm.js'});check(await page.locator('#setupBgmToggle').count()===1&&await page.locator('#bzMenuBgmAudio').count()===1,'Repeated loading creates no duplicate button/player');
 await page.evaluate(()=>{for(let i=0;i<11;i++)document.getElementById('setupBgmToggle').click()});await page.waitForTimeout(200);check((await state()).paused,'Rapid toggles ending OFF never leak delayed audio');
 check(await page.evaluate(()=>window.storageCalls===0),'Game recording/history storage not modified');check(errors.length===0,'No browser JavaScript errors');
 await context.close();await browser.close();browser=null;
 // Headless engines and DevTools evaluations may grant activation implicitly.
 // Inject a deterministic NotAllowedError ONLY in this fixture until a real touch,
 // then restore normal media playback; the distributed addon is never altered.
 browser=await chromium.launch({headless:true,args:['--autoplay-policy=no-user-gesture-required']});
 const touch=await browser.newContext({viewport:{width:915,height:412},hasTouch:true,isMobile:true});
 await touch.addInitScript(()=>{
   const original=HTMLMediaElement.prototype.play;let unlocked=false;window.deniedAutoplayCount=0;
   window.addEventListener('pointerdown',e=>{if(e.isTrusted)unlocked=true},true);
   HTMLMediaElement.prototype.play=function(){
     if(this.id==='bzMenuBgmAudio'&&!unlocked){window.deniedAutoplayCount++;return Promise.reject(new DOMException('Simulated autoplay restriction for this test','NotAllowedError'))}
     return original.call(this);
   };
 });
 const tp=await touch.newPage();const touchErrors=[];tp.on('pageerror',e=>touchErrors.push(e.message));
 await tp.goto(url);await tp.evaluate(()=>showSetup());await tp.waitForTimeout(150);
 check(await tp.evaluate(()=>document.getElementById('bzMenuBgmAudio').paused&&window.deniedAutoplayCount>0),'Simulated autoplay denial is caught and stays silent');
 await tp.tap('#modePistol');await playing(tp);check(true,'Real trusted touch retries and starts original media playback');
 await tp.tap('#enterRange');await tp.waitForTimeout(100);check(await tp.evaluate(()=>document.getElementById('bzMenuBgmAudio').paused),'Touch entry to shooting also stops BGM');
 check(touchErrors.length===0,'No unhandled errors after autoplay denial and recovery');await touch.close();
 fs.mkdirSync('test-results',{recursive:true});fs.writeFileSync('test-results/browser.json',JSON.stringify({scope:'Isolated DOM fixture and generated test WAV; final fallback test injects NotAllowedError before a real touch. Not the user game or supplied recording.',checks:results},null,2));console.log(`BGM browser checks passed: ${results.length}`);
}finally{if(browser)await browser.close();await new Promise(r=>server.close(r));}
