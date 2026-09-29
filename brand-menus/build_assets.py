from pathlib import Path
import base64, json, subprocess, math, xml.etree.ElementTree as ET
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
import cairosvg
from PIL import Image

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'payload'
OUT.mkdir(exist_ok=True)
font_path=subprocess.check_output(['fc-match','-f','%{file}','DejaVu Sans:style=Bold']).decode().strip()
f=TTFont(font_path); gs=f.getGlyphSet(); cmap=f.getBestCmap(); upem=f['head'].unitsPerEm

def word_paths(word):
    advance=0; paths=[]
    for char in word:
        name=cmap[ord(char)]; pen=SVGPathPen(gs); gs[name].draw(pen)
        paths.append((advance,pen.getCommands()))
        advance+=gs[name].width+65
    return paths,advance-65

def word(word,x,baseline,width,color):
    paths,units=word_paths(word); scale=width/units
    return ''.join(f'<path fill="{color}" d="{p}" transform="translate({x+dx*scale:.4f},{baseline}) scale({scale:.6f},-{scale:.6f})"/>' for dx,p in paths)

def circle(x,y,r,fill='none',stroke='none',sw=1):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'

def target(mode,x,y,size):
    paper=170 if mode=='pistol' else 80
    black=59.5 if mode=='pistol' else 30.5
    factor=size/paper
    p=[f'<rect x="{x-size/2}" y="{y-size/2}" width="{size}" height="{size}" fill="#f4f3ed"/>',circle(x,y,black/2*factor,'#141414')]
    diam=lambda n:11.5+(10-n)*16 if mode=='pistol' else .5+(10-n)*5
    for n in range(1,11):
        d=diam(n)
        if mode=='rifle' and n==10:p.append(circle(x,y,.25*factor,'#f4f3ed'))
        else:p.append(circle(x,y,d/2*factor,'none','#f4f3ed' if d<=black else '#858880',max(.65,.15*factor)))
    if mode=='pistol':p.append(circle(x,y,2.5*factor,'none','#f4f3ed',.7))
    for n in range(1,9):
        r=(diam(n)+diam(n+1))/4*factor
        col='#f4f3ed' if r*2<=black*factor else '#50554f'
        fs=2.1*factor if mode=='pistol' else 1.2*factor
        for dx,dy in [(r,0),(-r,0),(0,r),(0,-r)]:
            p.append(f'<text x="{x+dx}" y="{y+dy}" fill="{col}" font-family="DejaVu Sans" font-size="{fs}" text-anchor="middle" dominant-baseline="central">{n}</text>')
    return ''.join(p)

def zero(x,y,height):
    k=height/297
    p=[f'<g transform="translate({x},{y}) scale({k})">','<rect x="-105" y="-148.5" width="210" height="297" fill="#d7d9d4"/>']
    for i in range(-100,101,5):p.append(f'<path d="M{i},-135V135" stroke="'+('#89918b' if i%25==0 else '#a3aaa3')+'" stroke-width=".5"/>')
    for i in range(-135,136,5):p.append(f'<path d="M-100,{i}H100" stroke="'+('#89918b' if i%25==0 else '#a3aaa3')+'" stroke-width=".5"/>')
    p.extend(['<rect x="-15" y="-49" width="30" height="34" rx="7" fill="#14171c"/>','<rect x="-29" y="-23" width="58" height="61" rx="4" fill="#14171c"/>',circle(0,0,20,'none','#f0f2eb',1.4),'<path d="M-24,0H24M0,-24V24" stroke="#f0f2eb" stroke-width="1.1"/>','</g>'])
    return ''.join(p)

splash=['<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">','<rect width="1920" height="1080" fill="#000"/>']
splash.extend([word('BATTLE',625,210,670,'#fff'),word('ZONE',723,327,474,'#f20d20')])
for x,mode,label in [(420,'pistol','ISSF 공기권총'),(960,'rifle','ISSF 공기소총'),(1500,'zero','영점사격')]:
    splash.append(target(mode,x,647,366) if mode!='zero' else zero(x,647,405))
    splash.append(f'<text x="{x}" y="928" fill="#fff" font-family="Noto Sans CJK KR" font-size="42" font-weight="700" text-anchor="middle">{label}</text>')
splash.append('</svg>')
svg=''.join(splash)
(OUT/'bz-clean-splash.svg').write_text(svg,encoding='utf-8')
cairosvg.svg2png(bytestring=svg.encode(),write_to=str(OUT/'bz-clean-splash.png'))
encoded=base64.b64encode((OUT/'bz-clean-splash.png').read_bytes()).decode()
(OUT/'splash-data.js').write_text('/* BZ_CLEAN_SPLASH_V1 — artwork only; loading duration unchanged. */\nconst BZ_SPLASH_IMAGE="data:image/png;base64,'+encoded+'";\nconst splashElement=document.getElementById("splashImage");if(splashElement)splashElement.src=BZ_SPLASH_IMAGE;\n',encoding='utf-8')

# Adaptive foreground: all visible letters fit in the central 66dp safety circle.
android='http://schemas.android.com/apk/res/android'
ET.register_namespace('android',android)
def vector():
    root=ET.Element('vector',{f'{{{android}}}width':'108dp',f'{{{android}}}height':'108dp',f'{{{android}}}viewportWidth':'108',f'{{{android}}}viewportHeight':'108'})
    for text,x,y,w,color in [('BATTLE',28,51,52,'#FFFFFF'),('ZONE',31,72,46,'#F20D20')]:
        paths,units=word_paths(text);s=w/units
        for dx,p in paths:
            g=ET.SubElement(root,'group',{f'{{{android}}}translateX':str(x+dx*s),f'{{{android}}}translateY':str(y),f'{{{android}}}scaleX':str(s),f'{{{android}}}scaleY':str(-s)})
            ET.SubElement(g,'path',{f'{{{android}}}fillColor':color,f'{{{android}}}pathData':p})
    return ET.tostring(root,encoding='unicode')
res=OUT/'res'
(res/'drawable').mkdir(parents=True,exist_ok=True)
(res/'drawable/bz_launcher_foreground.xml').write_text(vector(),encoding='utf-8')
icon='<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="18 18 72 72"><rect x="18" y="18" width="72" height="72" fill="#000"/>'+word('BATTLE',28,51,52,'#fff')+word('ZONE',31,72,46,'#f20d20')+'</svg>'
cairosvg.svg2png(bytestring=icon.encode(),write_to=str(OUT/'bz-app-icon.png'))
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    d=res/('mipmap-'+density);d.mkdir(exist_ok=True)
    Image.open(OUT/'bz-app-icon.png').resize((size,size),Image.Resampling.LANCZOS).save(d/'bz_launcher.png')
v26=res/'mipmap-anydpi-v26';v26.mkdir(exist_ok=True)
(v26/'bz_launcher.xml').write_text('<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@android:color/black"/><foreground android:drawable="@drawable/bz_launcher_foreground"/></adaptive-icon>\n',encoding='utf-8')
print('Artwork generated: clean splash, legacy and adaptive icons; no font files packaged.')
