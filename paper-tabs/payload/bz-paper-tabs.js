/* BATTLEZONE_PAPER_TABS_V1 */
(function(){
  'use strict';
  if(window.BZPaperTabsInstalled)return;
  window.BZPaperTabsInstalled=true;
  function root(){
    const all=[...document.querySelectorAll('section,div,fieldset')];
    return all.find(e=>/표적지\s*색상/.test(e.textContent||'')&&e.querySelectorAll('button').length>=2)
      || document.getElementById('setup') || document.body;
  }
  function buttons(r){
    let b=[...r.querySelectorAll('button[data-paper-color],button[data-paper],button[data-target-paper],button[data-papercolor]')];
    if(b.length>=2)return b;
    return [...r.querySelectorAll('button')].filter(x=>/흰색|색상\s*1|색상\s*2|크림색/.test((x.textContent||'').replace(/\s+/g,' ')));
  }
  function val(b){return String(b.getAttribute('data-paper-color')||b.getAttribute('data-paper')||b.getAttribute('data-target-paper')||b.getAttribute('data-papercolor')||'').toLowerCase();}
  function selected(b){return b.classList.contains('selected')||b.getAttribute('aria-pressed')==='true';}
  function white(b){const t=(b.textContent||'');const v=val(b);return /흰색/.test(t)||/^(white|plain|paper-white)$/.test(v);}
  function c1(b){const t=(b.textContent||'');const v=val(b);return /색상\s*1|밝은\s*크림/.test(t)||/^(1|color1|kruger1|cream1|light-cream)$/.test(v);}
  function c2(b){const t=(b.textContent||'');const v=val(b);return /색상\s*2|진한\s*크림/.test(t)||/^(2|color2|kruger2|cream2|dark-cream)$/.test(v);}
  function relabel(b,label){
    if(!b)return;
    b.setAttribute('aria-label',label); b.title=label;
    const strong=b.querySelector('strong,b'), small=b.querySelector('small');
    if(strong){strong.textContent=label;if(small)small.remove();return;}
    const keep=[...b.children].find(el=>!(el.textContent||'').trim()&&/swatch|color|sample|chip/i.test(String(el.className||'')));
    const span=document.createElement('span'); span.className='bz-paper-label'; span.textContent=label;
    if(keep)b.replaceChildren(keep,span); else b.textContent=label;
  }
  let busy=false;
  function apply(){
    if(busy)return; busy=true;
    try{
      const r=root(), bs=buttons(r); if(bs.length<2)return;
      const w=bs.find(white); const rest=bs.filter(b=>b!==w);
      const one=bs.find(c1)||rest[0]||null;
      const two=bs.find(c2)||rest.find(b=>b!==one)||rest[1]||null;
      const was=!!w&&selected(w);
      if(w&&w.isConnected)w.remove();
      relabel(one,'색상 1'); relabel(two,'색상 2');
      if(was&&one&&one.isConnected&&!selected(one))setTimeout(()=>{try{one.click()}catch(_){ }},0);
    } finally { busy=false; }
  }
  let queued=false;
  function schedule(){if(queued)return;queued=true;requestAnimationFrame(()=>{queued=false;apply()});}
  const setup=document.getElementById('setup')||document.body;
  new MutationObserver(schedule).observe(setup,{subtree:true,childList:true,attributes:true,attributeFilter:['class','aria-pressed','hidden']});
  document.addEventListener('DOMContentLoaded',schedule,{once:true});
  schedule();
})();