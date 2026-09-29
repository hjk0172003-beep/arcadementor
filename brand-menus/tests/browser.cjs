const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');const path=require('node:path');const http=require('node:http');
const root=path.resolve(__dirname,'..');const payload=path.join(root,'payload');
const rows=[];
function ok(name,value){assert.ok(value,name);rows.push(name);}
const html=`<!doctype html><meta charset="utf-8"><style>[hidden]{display:none!important}body{margin:0;background:#10141b;color:white;font:24px sans-serif}#stage{width:1920px;height:1080px;position:relative}.setupHeader,.dialog>header{display:flex;gap:12px;align-items:center}button{font-size:24px;padding:16px}.selected{background:#ffd400}#splash{position:absolute;inset:0}#splashImage{width:100%;height:100%}#modal{position:absolute;inset:80px;background:#222;z-index:3}.settingRow{padding:20px}</style>
<div id="stage"><section id="splash"><img id="splashImage"><div id="loadTrack">old bar</div><div id="loadCaption">old text</div></section>
<section id="setup" hidden><header class="setupHeader"><b>BATTLE ZONE</b><button id="setupRules">Rules</button><button id="setupHistory">History</button></header><button class="selected" data-sport="pistol">Pistol</button><button data-sport="rifle">Rifle</button><button data-sport="zero">Zero</button><div class="settingRow" id="decimalRow"><label>소수점 표시</label><button data-decimal="on">ON</button><button data-decimal="off">OFF</button></div><div class="settingRow" id="sumRow">Sum</div><button id="enterRange">Range</button></section>
<section id="range" hidden><button id="startGameButton">START</button><button id="target">Target</button></section><div id="modal" hidden><div class="dialog"><header><h2 id="modalTitle">Rules</h2><button id="modalClose">Close</button></header><div id="modalBody"></div><footer id="modalFooter"></footer></div></div></div>
<script>window.events=[];window.BZLifecycle={handle(e){events.push(e.active);return 'original-value'}};document.getElementById('enterRange').onclick=()=>{setup.hidden=true;range.hidden=false};document.getElementById('modalClose').onclick=()=>{modal.hidden=true};document.querySelectorAll('[data-sport]').forEach(b=>b.onclick=()=>{document.querySelectorAll('[data-sport]').forEach(x=>x.classList.toggle('selected',x===b));sumRow.hidden=b.dataset.sport==='zero'});</script><script src="/splash-data.js"></script><script src="/bz-brand-menus.js"></script><script src="/bz-menu-music.js"></script>`;
function wav(){const n=24000,b=Buffer.alloc(44+n*2);b.write('RIFF');b.writeUInt32LE(36+n*2,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(24000,24);b.writeUInt32LE(48000,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(n*2,40);for(let i=0;i<n;i++)b.writeInt16LE(Math.round(800*Math.sin(i*2*Math.PI*220/24000)),44+i*2);return b;}
(async()=>{
 const server=http.createServer((q,r)=>{if(q.url==='/'){r.setHeader('Content-Type','text/html;charset=utf-8');r.end(html);return;}if(q.url==='/bz-menu-music.wav'){r.setHeader('Content-Type','audio/wav');r.end(wav());return;}const name=path.basename(q.url);const f=path.join(payload,name);if(!fs.existsSync(f)){r.statusCode=404;r.end();return;}r.setHeader('Content-Type',name.endsWith('.js')?'text/javascript;charset=utf-8':'image/png');r.end(fs.readFileSync(f));});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({args:['--autoplay-policy=no-user-gesture-required']});
 const page=await browser.newPage({viewport:{width:1920,height:1080}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const playing=async()=>{await page.waitForFunction(()=>{const a=document.getElementById('bzMenuMusicAudio');return a&&!a.paused&&!a.muted&&a.currentTime>0;});};
 const silent=async()=>{await page.waitForFunction(()=>{const a=document.getElementById('bzMenuMusicAudio');return a&&a.paused&&a.muted;});};
 async function scene(mode,dialog){await page.evaluate(([mode,dialog])=>{splash.hidden=mode!=='splash';setup.hidden=mode!=='setup';range.hidden=mode!=='range';modal.hidden=!dialog;modal.dataset.type=dialog||'';document.getElementById('modalTitle').textContent=dialog||'';document.getElementById('modalBody').innerHTML='';document.getElementById('modalFooter').innerHTML='';},[mode,dialog]);}
 try {
  await page.goto('http://127.0.0.1:'+server.address().port+'/');await playing();ok('loading music ON',true);
  ok('old loading explanations hidden',await page.locator('#loadCaption').isHidden());
  await page.locator('#splashImage').evaluate(e=>e.decode());
  fs.mkdirSync(path.join(root,'verification'),{recursive:true});
  await page.screenshot({path:path.join(root,'verification/loading.png')});
  await scene('setup',null);await playing();ok('setup music ON',true);
  for(const type of ['rules','history','result','analysis','sound','sum']){await scene('setup',type);await playing();ok('setup '+type+' music ON',true);}
  await scene('setup',null);await page.locator('#enterRange').click();await silent();ok('enter shooting silences music before START',true);
  await page.locator('#startGameButton').click();await silent();ok('START remains silent except existing game beep',true);
  for(const type of ['rules','history','result','analysis','sound']){await scene('range',type);await playing();ok('range overlay '+type+' music ON',true);await page.locator('#modalClose').click();await silent();ok('close '+type+' returns to silent range',true);}
  await scene('range','result');await playing();
  await page.evaluate(()=>{modalFooter.innerHTML='<button id="saveVideo">Video</button>';saveVideo.onclick=()=>{modalFooter.innerHTML='<button id="cancelVideo">Cancel</button>';};});
  await page.locator('#saveVideo').click();await silent();ok('video generation music OFF',true);ok('modal toggle hidden during recording',await page.locator('#menuBgmToggleModal').isHidden());
  await scene('range','result');await playing();ok('results restore music after export',true);
  await page.locator('#menuBgmToggleModal').click();await silent();ok('modal OFF applies immediately',true);
  await scene('setup',null);await silent();ok('OFF follows back to setup',true);
  await page.reload();await silent();ok('OFF survives restart including loading',true);
  await scene('setup',null);await page.locator('#menuBgmToggle').click();await playing();ok('ON restores music',true);
  await page.locator('[data-sport="zero"]').click();await page.waitForTimeout(50);ok('zero decimal row hidden',await page.locator('#decimalRow').isHidden());ok('zero sum row hidden',await page.locator('#sumRow').isHidden());
  for(const mode of ['pistol','rifle']){await page.locator('[data-sport="'+mode+'"]').click();await page.waitForTimeout(50);ok(mode+' decimal row restored',await page.locator('#decimalRow').isVisible());ok(mode+' sum original behavior retained',await page.locator('#sumRow').isVisible());}
  const nativeResult=await page.evaluate(()=>BZLifecycle.handle({active:false}));await silent();ok('native background silent and original handler retained',nativeResult==='original-value');
  await page.evaluate(()=>BZLifecycle.handle({active:true}));await playing();ok('native return restores ON',true);
  await page.addScriptTag({url:'/bz-menu-music.js'});ok('no duplicate music audio',await page.locator('#bzMenuMusicAudio').count()===1);ok('no duplicate setup toggle',await page.locator('#menuBgmToggle').count()===1);
  ok('no page errors',errors.length===0);
  fs.writeFileSync(path.join(root,'verification/browser.json'),JSON.stringify({scope:'synthetic compatible DOM, real Chromium/WebAudio; not a full APK device test',passed:rows.length,checks:rows,errors},null,2));
  console.log('Browser checks passed: '+rows.length);
 }finally{await browser.close();server.close();}
})().catch(e=>{console.error(e);process.exit(1)});
