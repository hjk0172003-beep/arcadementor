function drawMarks(c,a,cx,cy,scale,numbers=true,selected=null){
 /* BZ_SMALL_IMPACT_V1: original 2.25mm drawing radius; no oversized numbered badge. */
 if(!Array.isArray(a)||!Number.isFinite(scale)||scale<=0)return;
 const impacts=a.filter(isImpact);
 if(!impacts.length)return;
 const latest=impacts[impacts.length-1];
 const picked=impacts.find(p=>p.n===selected);
 const ordered=picked?impacts.filter(p=>p!==picked).concat(picked):impacts;
 const radius=2.25*scale,diameter=radius*2;
 for(const p of ordered){
  const x=cx+p.x*scale,y=cy+p.y*scale;
  const color=p===latest?'#ed4f43':'#3ea85b';
  c.save();
  c.shadowBlur=0;c.shadowOffsetX=0;c.shadowOffsetY=0;
  if(numbers){
   const border=Math.min(radius*.18,1);
   circle(c,x,y,Math.max(0,radius-border/2),'#11151b',color,border);
   const label=String(p.n);
   let size=diameter*.92;
   c.font=`800 ${size}px system-ui,"Noto Sans CJK KR",sans-serif`;
   const width=c.measureText(label).width;
   if(width>diameter*.84){size*=diameter*.84/width;c.font=`800 ${size}px system-ui,"Noto Sans CJK KR",sans-serif`;}
   c.fillStyle=color;c.textAlign='center';c.textBaseline='middle';
   c.fillText(label,x,y,diameter*.84);
  }else{
   circle(c,x,y,radius,color);
  }
  if(p===picked)circle(c,x,y,radius+1.5,null,'#46c9ed',1);
  c.restore();
 }
}
