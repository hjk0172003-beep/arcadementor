/* BATTLEZONE_BRAND_MENUS_V1 — presentation only. */
(function () {
 'use strict';
 if(window.BZBrandMenusInstalled)return;
 var setup=document.getElementById('setup');if(!setup)return;
 window.BZBrandMenusInstalled=true;
 var style=document.createElement('style');style.id='bz-clean-loading-style';
 style.textContent='#splash{background:#000!important}#splashImage{object-fit:contain!important;background:#000!important}#splash #loadTrack,#splash #loadCaption{display:none!important}';
 document.head.appendChild(style);
 function update(){
  var zero=setup.querySelector('[data-sport="zero"]');
  var isZero=!!zero && (zero.classList.contains('selected') || zero.getAttribute('aria-pressed')==='true');
  var decimal=setup.querySelector('[data-decimal]');
  var row=decimal && decimal.closest('.settingRow');
  if(row && row.hidden!==isZero)row.hidden=isZero;
  // The original game already manages the sum row. Only enforce hiding for zeroing.
  var sum=document.getElementById('sumRow');if(isZero && sum && !sum.hidden)sum.hidden=true;
 }
 new MutationObserver(update).observe(setup,{subtree:true,attributes:true,attributeFilter:['class','aria-pressed'],childList:true});
 update();
})();
