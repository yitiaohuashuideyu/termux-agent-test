from PIL import Image, ImageDraw, ImageFont
import numpy as np, math, os
W,H=720,540; N=140
os.makedirs('frames',exist_ok=True)
rng=np.random.default_rng(7)
def mk_coin():
    s=Image.new('RGBA',(16,16),(0,0,0,0));d=ImageDraw.Draw(s)
    d.ellipse([1,1,14,14],fill=(200,140,20,255));d.ellipse([2,2,13,13],fill=(245,190,40,255))
    d.ellipse([4,4,11,11],fill=(255,215,90,255));d.rectangle([6,3,8,7],fill=(255,248,210,255))
    return s
def mk_cat():
    s=Image.new('RGBA',(16,16),(0,0,0,0));d=ImageDraw.Draw(s)
    d.rectangle([3,6,12,13],fill=(58,58,70,255));d.rectangle([4,2,11,9],fill=(70,70,84,255))
    d.polygon([(4,2),(6,0),(7,3)],fill=(70,70,84,255));d.polygon([(11,2),(9,0),(8,3)],fill=(70,70,84,255))
    d.rectangle([6,5,7,6],fill=(120,235,180,255));d.rectangle([9,5,10,6],fill=(120,235,180,255))
    d.rectangle([7,8,8,9],fill=(235,120,150,255));return s
def mk_hat():
    s=Image.new('RGBA',(16,16),(0,0,0,0));d=ImageDraw.Draw(s)
    d.rectangle([5,1,10,9],fill=(40,40,52,255));d.rectangle([4,9,11,11],fill=(28,28,36,255))
    d.rectangle([5,6,10,7],fill=(200,60,60,255));return s
def mk_cam():
    s=Image.new('RGBA',(16,16),(0,0,0,0));d=ImageDraw.Draw(s)
    d.rectangle([2,5,13,13],fill=(50,50,62,255));d.rectangle([5,3,9,5],fill=(50,50,62,255))
    d.ellipse([5,6,10,12],fill=(28,28,38,255));d.ellipse([6,7,9,11],fill=(90,155,225,255));return s
SP={'coin':mk_coin(),'cat':mk_cat(),'hat':mk_hat(),'camera':mk_cam()}
yy,xx=np.mgrid[0:H,0:W]; rr=np.sqrt((xx-W/2)**2+(yy-H/2)**2)
glow=np.clip(1-rr/(W*0.75),0,1)**2
def ease(x): x=max(0,min(1,x)); return 1-(1-x)**3
def lerp(a,b,t): return a+(b-a)*t
items=[dict(n='coin',s=5,p0=(360,-90),p1=(185,270),z=7,rot=(-200,0)),
       dict(n='cat',s=28,p0=(-140,320),p1=(350,300),z=8,rot=(0,0)),
       dict(n='hat',s=52,p0=(860,160),p1=(545,235),z=7,rot=(220,0)),
       dict(n='camera',s=76,p0=(360,650),p1=(360,420),z=7,rot=(-120,0))]
try: font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',46)
except: font=ImageFont.load_default()
for f in range(N):
    base=np.zeros((H,W,3),np.float32)
    base[:,:,0]=8+18*glow; base[:,:,1]=9+16*glow; base[:,:,2]=20+30*glow
    fr=Image.fromarray(np.clip(base,0,255).astype(np.uint8)).convert('RGBA')
    for it in items:
        t=ease((f-it['s'])/34.0)
        if t<=0: continue
        cx=lerp(it['p0'][0],it['p1'][0],t); cy=lerp(it['p0'][1],it['p1'][1],t)
        cy+=math.sin(f/9.0+it['s'])*6*t
        ang=lerp(it['rot'][0],it['rot'][1],t)
        sp=SP[it['n']]; scale=it['z']*(0.6+0.4*t)
        sp=sp.resize((max(1,int(sp.width*scale)),max(1,int(sp.height*scale))),Image.NEAREST)
        if abs(ang)>0.5: sp=sp.rotate(ang,expand=True,resample=Image.NEAREST)
        fr.alpha_composite(sp,(int(cx-sp.width/2),int(cy-sp.height/2)))
    d=ImageDraw.Draw(fr)
    if f>90:
        a=int(min(255,(f-90)/25*255))
        d.text((W/2,58),'MOTION  .  RECREATE',font=font,fill=(235,225,200,a),anchor='mm')
    arr=np.array(fr.convert('RGB'),np.float32)
    arr+=rng.normal(0,15,(H,W,1))
    vig=(N-f)/15.0 if f>=N-15 else 1.0
    arr*=vig
    Image.fromarray(np.clip(arr,0,255).astype(np.uint8)).save(f'frames/f{f:04d}.png')
print('frames done', len(os.listdir('frames')))
