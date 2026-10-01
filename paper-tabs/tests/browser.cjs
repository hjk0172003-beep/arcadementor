const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
(async()=>{
  const js=fs.readFileSync(path.join(__dirname,'../payload/bz-paper-tabs.js'),'utf8');
  const browser=await chromium.launch();
  const page=await browser.newPage({viewport:{width:1200,height:800}});
  try{
    await page.setContent(`
      <section id="setup">
        <div id="paperGroup"><span>표적지 색상</span>
          <button data-paper-color="white" class="selected"><i class="swatch"></i><span><strong>흰색</strong></span></button>
          <button data-paper-color="kruger1"><i class="swatch"></i><span><strong>색상 1</strong><small>밝은 크림색</small></span></button>
          <button data-paper-color="kruger2"><i class="swatch"></i><span><strong>색상 2</strong><small>진한 크림색</small></span></button>
        </div>
      </section>`);
    await page.evaluate(()=>{document.querySelectorAll('button').forEach(b=>b.addEventListener('click',()=>{document.querySelectorAll('button').forEach(x=>{x.classList.remove('selected');x.setAttribute('aria-pressed','false')});b.classList.add('selected');b.setAttribute('aria-pressed','true')}))});
    await page.addScriptTag({content:js});
    await page.waitForTimeout(100);
    assert.equal(await page.locator('button').count(),2);
    const texts=await page.locator('button').allTextContents();
    assert.deepEqual(texts.map(t=>t.replace(/\s+/g,' ').trim()),['색상 1','색상 2']);
    assert.equal(await page.locator('button[data-paper-color="kruger1"]').getAttribute('aria-pressed'),'true');
    console.log('PASS');
  } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exit(1)});