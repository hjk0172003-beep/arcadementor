const fs=require('node:fs');const path=require('node:path');const vm=require('node:vm');const assert=require('node:assert/strict');
const {chromium}=require('playwright');const root=path.resolve(__dirname,'..');
const source=fs.readFileSync(path.join(root,'payload/drawMarks.js'),'utf8');const checks=[];
function ok(name,value){assert.ok(value,name);checks.push(name);}
let calls=[],stack=[];
const ctx={font:'12px serif',fillStyle:'#abcdef',textAlign:'left',textBaseline:'top',shadowBlur:9,shadowOffsetX:3,shadowOffsetY:4,
 save(){stack.push({font:this.font,fillStyle:this.fillStyle,textAlign:this.textAlign,textBaseline:this.textBaseline,shadowBlur:this.shadowBlur,shadowOffsetX:this.shadowOffsetX,shadowOffsetY:this.shadowOffsetY});},
 restore(){Object.assign(this,stack.pop());},measureText(t){return {width:parseFloat(this.font.match(/[\d.]+px/)[0])*.62*t.length};},
 fillText(label,x,y,maxWidth){calls.push({kind:'number',label,x,y,maxWidth,font:this.font,color:this.fillStyle});}};
const context={circle(c,x,y,r,fill,stroke,width=1){calls.push({kind:'circle',x,y,r,fill,stroke,width});},isImpact(p){return !!p&&!p.timeout&&Number.isFinite(p.x)&&Number.isFinite(p.y);}};
vm.createContext(context);vm.runInContext(source,context);const render=context.drawMarks;
const shots=[{n:1,x:-10,y:8},{n:60,x:5,y:-2},{n:61,timeout:true,x:null,y:null}];const before=JSON.stringify(shots);
for(const scale of [.2,.5,1,2.7102696482311743,4,10]){
 calls=[];render(ctx,shots,514,418,scale,true,null);
 const circles=calls.filter(x=>x.kind==='circle'),numbers=calls.filter(x=>x.kind==='number');
 ok('Only real impacts rendered at scale '+scale,circles.length===2&&numbers.length===2);
 for(let i=0;i<circles.length;i++){
  const mark=circles[i],label=numbers[i],p=shots[i];
  ok('Original 4.5mm outer marker diameter, scale '+scale+' index '+i,Math.abs((mark.r+mark.width/2)*2-4.5*scale)<1e-9);
  ok('Input center preserved, scale '+scale+' index '+i,mark.x===514+p.x*scale&&mark.y===418+p.y*scale&&label.x===mark.x&&label.y===mark.y);
  ok('Number fits inside small marker, scale '+scale+' index '+i,label.maxWidth<=4.5*scale&&parseFloat(label.font.match(/[\d.]+px/)[0])<=4.5*scale);
 }
 ok('Green previous, red latest at scale '+scale,circles[0].stroke==='#3ea85b'&&circles[1].stroke==='#ed4f43'&&numbers[0].color==='#3ea85b'&&numbers[1].color==='#ed4f43');
}
ok('No shot or record mutation',before===JSON.stringify(shots));
ok('Canvas state restored',ctx.font==='12px serif'&&ctx.fillStyle==='#abcdef'&&ctx.shadowBlur===9&&ctx.textAlign==='left'&&stack.length===0);
calls=[];render(ctx,shots,0,0,2.7102696482311743,true,1);
const labels=calls.filter(x=>x.kind==='number');ok('Selected shot painted last',labels.at(-1).label==='1');ok('Selected older shot stays green',labels.at(-1).color==='#3ea85b');
ok('Thin selection outline retained',calls.some(x=>x.kind==='circle'&&x.stroke==='#46c9ed'&&x.width===1));
calls=[];render(ctx,shots,0,0,.25,false,null);ok('Thumbnails omit numbers',calls.length===2&&calls.every(x=>x.kind==='circle'));ok('Thumbnail dimensions also scale',calls.every(x=>Math.abs(x.r*2-4.5*.25)<1e-9));
for(const value of [0,-1,Infinity,NaN]){calls=[];render(ctx,shots,0,0,value,true);ok('Invalid scale rejected '+value,calls.length===0);}
calls=[];render(ctx,[{n:1,timeout:true,x:null,y:null}],0,0,2,true);ok('Timeout alone has no marker or number',calls.length===0);
(async()=>{
 const browser=await chromium.launch();const page=await browser.newPage({viewport:{width:1920,height:1080}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 try{
  await page.setContent('<canvas id="view" width="1920" height="1080"></canvas>');
  await page.addScriptTag({content:'function isImpact(p){return !!p&&!p.timeout&&Number.isFinite(p.x)&&Number.isFinite(p.y)}\nfunction circle(c,x,y,r,fill,stroke,width=1){c.beginPath();c.arc(x,y,Math.max(0,r),0,Math.PI*2);if(fill){c.fillStyle=fill;c.fill()}if(stroke){c.strokeStyle=stroke;c.lineWidth=width;c.stroke()}}\n'+source});
  const result=await page.evaluate(()=>{
   const c=document.getElementById('view').getContext('2d');const evidence=[];
   const original=c.fillText;c.fillText=function(t,x,y,maxWidth){evidence.push({text:t,x,y,width:this.measureText(t).width,maxWidth,font:this.font});return original.apply(this,arguments)};
   c.fillStyle='#c8cdc7';c.fillRect(0,0,1920,1080);
   const scale=1920/(32*25.4*16/Math.hypot(16,9));
   for(const [i,bg] of ['#ffffff','#f3eddc','#dfd1ad','#161a1f'].entries()){
    c.fillStyle=bg;c.fillRect(60+i*460,60,400,800);
    drawMarks(c,[{n:1,x:-20,y:-20},{n:9,x:15,y:0},{n:60,x:0,y:22}],260+i*460,440,scale,true,null);
   }
   return {scale,evidence};
  });
  ok('Actual Chromium Canvas renders all numbers',result.evidence.length===12);
  ok('Actual measured glyph width stays inside footprint',result.evidence.every(e=>e.width<=e.maxWidth+.01));
  ok('Browser has no execution errors',errors.length===0);
  const out=path.join(root,'verification');fs.mkdirSync(out,{recursive:true});
  fs.writeFileSync(path.join(out,'render.json'),JSON.stringify({scope:'drawing function in isolation with real Chromium; not full APK or device testing',passed:checks.length,nominalDiameterMM:4.5,mainTargetDiameterPx:result.scale*4.5,checks},null,2));
  await page.screenshot({path:path.join(out,'drawing-test.png')});
  console.log('DRAWING CHECKS PASSED: '+checks.length);
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1});
