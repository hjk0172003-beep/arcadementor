import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const js = await fs.readFile('menu-bgm-update/bz-menu-music.js');
const wav = Buffer.alloc(44 + 44100*2);
wav.write('RIFF'); wav.writeUInt32LE(wav.length-8,4); wav.write('WAVEfmt ',8); wav.writeUInt32LE(16,16); wav.writeUInt16LE(1,20); wav.writeUInt16LE(1,22); wav.writeUInt32LE(44100,24); wav.writeUInt32LE(88200,28); wav.writeUInt16LE(2,32); wav.writeUInt16LE(16,34); wav.write('data',36); wav.writeUInt32LE(wav.length-44,40);
for(let i=0;i<44100;i++) wav.writeInt16LE(Math.round(2000*Math.sin(2*Math.PI*220*i/44100)),44+i*2);
const html = `<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>[hidden]{display:none!important}body{margin:0;background:#10141b;color:white;font-family:sans-serif}#stage{position:relative;width:900px;height:390px}.setupHeader{display:flex;align-items:center;gap:10px;height:75px}.setupHeader>div{flex:1}button{font-size:20px;min-height:50px;padding:8px}.selected{background:#FFD400;color:#11151b}#modal{position:absolute;inset:90px 0 0;background:#171e27}</style></head><body><div id="stage"><div id="splash">LOADING</div><section id="setup" hidden><header class="setupHeader"><div>BATTLE ZONE</div><button id="setupRules">Rules</button><button id="setupHistory">History</button></header><button id="chooseSport">Pistol</button><button id="enterRange">Range</button></section><section id="range" hidden><button id="startGameButton">START</button></section><div id="modal" hidden>Results</div></div><script>window.originalCalls=[];document.getElementById('enterRange').addEventListener('click',function(){var a=document.getElementById('bzMenuMusicAudio');window.silentBeforeRange=a.paused&&a.muted;document.getElementById('setup').hidden=true;document.getElementById('range').hidden=false;});</script><script src="/bz-menu-music.js"></script><script>window.BZLifecycle={handle:function(e){window.originalCalls.push(e);return 42;},back:function(){return false;}};window.goSetup=function(){splash.hidden=true;range.hidden=true;modal.hidden=true;setup.hidden=false;};</script></body></html>`;
const server=http.createServer((req,res)=>{let body,type;if(req.url==='/bz-menu-music.js'){body=js;type='application/javascript';}else if(req.url==='/bz-menu-music.wav'){body=wav;type='audio/wav';}else{body=Buffer.from(html);type='text/html';}res.writeHead(200,{'Content-Type':type,'Content-Length':body.length,'Cache-Control':'no-store'});res.end(body);});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const url=`http://127.0.0.1:${server.address().port}/`;
const browser=await chromium.launch({args:['--autoplay-policy=no-user-gesture-required']});
const results=[];const errors=[];
function ok(value,label){assert.ok(value,label);results.push({test:label,passed:true});}
async function silent(page,label){await page.waitForFunction(()=>{const a=document.getElementById('bzMenuMusicAudio');return a.paused&&a.muted;});ok(true,label);}
async function playing(page,label){await page.waitForFunction(()=>{const a=document.getElementById('bzMenuMusicAudio');return !a.paused&&!a.muted&&a.currentTime>0.04;});ok(true,label);}
async function suite(context,name){
 const page=await context.newPage();page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(url);
 await silent(page,`${name}: no music during loading`);
 ok(await page.locator('#menuBgmToggle').count()===1,`${name}: exactly one ON/OFF control`);
 await page.evaluate(()=>goSetup());
 await playing(page,`${name}: auto play only on selection screen`);
 ok(await page.locator('#menuBgmToggle').textContent()==='배경음 ON',`${name}: Korean ON text`);
 ok(await page.evaluate(()=>bzMenuMusicAudio.loop&&bzMenuMusicAudio.volume===0.25),`${name}: loop and independent playback volume`);
 await page.evaluate(()=>{bzMenuMusicAudio.currentTime=0.92;});await page.waitForTimeout(330);
 ok(await page.evaluate(()=>bzMenuMusicAudio.currentTime<0.8&&!bzMenuMusicAudio.paused),`${name}: actual media loop`);
 await page.locator('#menuBgmToggle').click();
 await silent(page,`${name}: OFF stops immediately`);
 ok(await page.evaluate(()=>localStorage.getItem('battlezone_menu_bgm_enabled'))==='off',`${name}: OFF saved`);
 await page.reload();await page.evaluate(()=>goSetup());await silent(page,`${name}: OFF survives reload`);
 ok(await page.locator('#menuBgmToggle').textContent()==='배경음 OFF',`${name}: OFF text after reload`);
 await page.locator('#menuBgmToggle').click();await playing(page,`${name}: ON restarts`);
 await page.evaluate(()=>{modal.hidden=false;modal.dataset.type='history';});await silent(page,`${name}: history dialog silent`);
 await page.evaluate(()=>{modal.hidden=true;});await playing(page,`${name}: close dialog resumes menu music`);
 await page.evaluate(()=>{modal.hidden=false;modal.dataset.type='result';});await silent(page,`${name}: results silent`);
 await page.evaluate(()=>{modal.hidden=true;});await playing(page,`${name}: selection screen restored`);
 await page.locator('#enterRange').click();
 ok(await page.evaluate(()=>silentBeforeRange),`${name}: muted before original transition handler`);
 await silent(page,`${name}: range/START gate silent`);
 await page.locator('#startGameButton').click();await silent(page,`${name}: no music at START`);
 await page.evaluate(()=>{modal.hidden=false;modal.dataset.type='result';});await silent(page,`${name}: shooting results silent`);
 await page.evaluate(()=>goSetup());await playing(page,`${name}: return to mode selection restarts`);
 const returnValue=await page.evaluate(()=>BZLifecycle.handle({active:false,token:'original'}));
 ok(returnValue===42,`${name}: native lifecycle return value preserved`);
 await silent(page,`${name}: Android background stops music`);
 ok(await page.evaluate(()=>originalCalls.length===1&&originalCalls[0].token==='original'),`${name}: original lifecycle called exactly once`);
 await page.evaluate(()=>BZLifecycle.handle({active:true}));await playing(page,`${name}: Android foreground resumes only menu`);
 await page.evaluate(()=>window.dispatchEvent(new Event('pagehide')));await silent(page,`${name}: pagehide stops`);
 await page.evaluate(()=>window.dispatchEvent(new Event('pageshow')));await playing(page,`${name}: pageshow resumes menu`);
 await page.addScriptTag({url:url+'bz-menu-music.js'});
 ok(await page.locator('#menuBgmToggle').count()===1&&await page.locator('#bzMenuMusicAudio').count()===1,`${name}: duplicate loading harmless`);
 await page.locator('#menuBgmToggle').focus();await page.keyboard.press('Space');await silent(page,`${name}: keyboard OFF`);
 await page.locator('#menuBgmToggle').click();await playing(page,`${name}: click ON`);
 await page.evaluate(()=>{menuBgmToggle.click();menuBgmToggle.click();menuBgmToggle.click();});
 await silent(page,`${name}: rapid toggle race stays OFF`);
 if(name==='touch'){await page.locator('#menuBgmToggle').tap();await playing(page,'touch: touch ON');await page.locator('#enterRange').tap();await silent(page,'touch: tap Range silences music');}
 await page.close();
}
try {
 const desktop=await browser.newContext({viewport:{width:1280,height:720}});await suite(desktop,'desktop');await desktop.close();
 const touch=await browser.newContext({viewport:{width:915,height:412},isMobile:true,hasTouch:true});await suite(touch,'touch');await touch.close();
 ok(errors.length===0,'No unhandled browser exceptions');
 await fs.mkdir('test-results',{recursive:true});await fs.writeFile('test-results/browser.json',JSON.stringify({scope:'Independent add-on tested against a selector-compatible fixture, not the full game APK.',results,errors},null,2));
 console.log('BGM BROWSER CHECKS PASSED:',results.length);
} finally {await browser.close();server.close();}
