/* BATTLEZONE_MENU_MUSIC_V3: existing music; isolated from replay audio. */
(function () {
'use strict';
if (window.BZMenuMusicInstalled) return;
var script=document.currentScript, setup=document.getElementById('setup'), range=document.getElementById('range');
var modal=document.getElementById('modal'), splash=document.getElementById('splash');
var header=setup && setup.querySelector('.setupHeader');
if (!script || !setup || !range || !header) return;
window.BZMenuMusicInstalled=true;
var enabled=true, nativeActive=true, pageActive=true, pending=null, exportButton=null, exportTimer=0;
var key='battlezone_menu_bgm_enabled';
try { enabled=localStorage.getItem(key)!=='off'; } catch (_) {}
var audio=document.createElement('audio');
audio.id='bzMenuMusicAudio'; audio.src=new URL('bz-menu-music.wav',script.src).href;
audio.loop=true; audio.preload='none'; audio.volume=0.25; audio.hidden=true; audio.muted=true;
audio.setAttribute('playsinline',''); document.body.appendChild(audio);
var buttons=[];
function button(parent,before,id) {
 if (!parent) return;
 var b=document.createElement('button'); b.id=id; b.type='button';
 b.style.cssText='white-space:nowrap;min-width:195px;flex:none';
 b.addEventListener('click',function () { enabled=!enabled; try {localStorage.setItem(key,enabled?'on':'off');} catch (_) {} paint(); sync(); });
 parent.insertBefore(b,before && before.parentNode===parent?before:null); buttons.push(b);
}
button(header,document.getElementById('setupRules'),'menuBgmToggle');
button(modal && modal.querySelector('.dialog > header'),document.getElementById('modalClose'),'menuBgmToggleModal');
function shown(e) {return !!e && !e.hidden && e.getClientRects().length>0 && getComputedStyle(e).display!=='none';}
function busy() {
 if (document.getElementById('cancelVideo')) return true;
 if (exportButton && !exportButton.isConnected) exportButton=null;
 return !!exportButton;
}
function allowed() {
 if (!enabled || !nativeActive || !pageActive || document.hidden || busy()) return false;
 if (shown(modal)) return true;
 if (shown(range)) return false;
 return shown(setup) || shown(splash);
}
function paint() {
 buttons.forEach(function (b) {
  b.textContent=enabled?'배경음 ON':'배경음 OFF';
  b.classList.toggle('selected',enabled); b.setAttribute('aria-pressed',String(enabled));
  b.setAttribute('aria-label',enabled?'배경음 끄기':'배경음 켜기');
 });
}
function stop() { audio.muted=true; audio.pause(); pending=null; }
function hook() {
 var life=window.BZLifecycle;
 if (!life || typeof life.handle!=='function' || life.handle.bzMenuMusicHook) return;
 var original=life.handle;
 var wrapped=function (e) {
  if (e && e.active===false) {nativeActive=false;stop();} else if (e && e.active===true) nativeActive=true;
  try {return original.apply(this,arguments);} finally {sync();}
 };
 wrapped.bzMenuMusicHook=true; life.handle=wrapped;
}
function sync() {
 hook(); var saving=busy();
 buttons.forEach(function (b) {if (b.id==='menuBgmToggleModal' && b.hidden!==saving) b.hidden=saving;});
 if (!allowed()) {stop();return;}
 audio.muted=false; if (!audio.paused || pending) return;
 try {
  var p=audio.play();
  if (p && p.then) {pending=p;p.then(function () {if(pending===p)pending=null;if(!allowed())stop();},function(){if(pending===p)pending=null;});}
 } catch (_) {pending=null;}
}
var observer=new MutationObserver(sync);
[setup,range,modal,splash].forEach(function (e) {
 if(e)observer.observe(e,{attributes:true,attributeFilter:['hidden','class','style'],childList:e===modal,subtree:e===modal});
});
document.addEventListener('click',function(e){
 var t=e.target instanceof Element?e.target:null, b=t && t.closest('button');
 if(!b || b.disabled || b.getAttribute('aria-disabled')==='true')return;
 if(b.id==='saveVideo') {
  exportButton=b;stop();clearTimeout(exportTimer);
  exportTimer=setTimeout(function(){if(!document.getElementById('cancelVideo')){exportButton=null;sync();}},8000);
 }
 if(b.id==='enterRange' || b.id==='startGameButton' || (shown(range) && /^(modalClose|resumeShooting|soundDone|analysisReturn|keepShooting)$/.test(b.id)))stop();
},true);
function gesture(e){
 var t=e.target instanceof Element?e.target:null;
 if(t && t.closest('#enterRange,#startGameButton,#menuBgmToggle,#menuBgmToggleModal,#saveVideo'))return;
 if(e.isTrusted && allowed())sync();
}
document.addEventListener('pointerdown',gesture,true);document.addEventListener('keydown',gesture,true);
document.addEventListener('touchend',gesture,{capture:true,passive:true});
audio.addEventListener('play',function(){if(!allowed())stop();});
audio.addEventListener('playing',function(){if(!allowed())stop();});
document.addEventListener('visibilitychange',sync);
window.addEventListener('pagehide',function(){pageActive=false;stop();});
window.addEventListener('pageshow',function(){pageActive=true;sync();});
paint();sync();
})();
