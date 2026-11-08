"""Ad pictures built from the cat preview renders (docs/concepts/cat-cafe/previews): the collection and golden cats."""
import sys, math, numpy as np
sys.path.insert(0, __import__('os').path.dirname(__file__))
from adtext import *
from PIL import Image, ImageDraw, ImageFilter
PREV = 'docs/concepts/cat-cafe/previews/CatCafe_Cat_%s.png'
RAR = {'Common': (142,151,178), 'Rare': (95,168,255), 'Epic': (192,124,255), 'Legendary': (255,201,77), 'Mythical': (255,94,126)}
def rays(size, c, a, b, n=22, glow=(255,255,255)):
    W,H=size; ys,xs=np.mgrid[0:H,0:W]
    ang=np.arctan2(ys-c[1],xs-c[0]); k=((ang+math.pi)/(2*math.pi)*n*2).astype(int)%2
    A=np.array(a,float); B=np.array(b,float)
    img=np.where(k[...,None]==0,A,B)
    r=np.hypot(xs-c[0],ys-c[1])/math.hypot(W,H)
    g=np.clip(1-r*1.8,0,1)[...,None]*0.35
    img=img*(1-g)+np.array(glow,float)*g
    return Image.fromarray(img.clip(0,255).astype(np.uint8)).convert('RGBA')
def card(name, rarity, w, h, label=None, border=None):
    src=Image.open(PREV%name).convert('RGBA')
    bg=src.getpixel((4,4))
    cw,ch=w-24,h-24
    # crop around the cat, keep aspect
    crop=src.crop((140,70,500,400)); crop=crop.resize((cw, int(cw*crop.height/crop.width)), Image.LANCZOS)
    inner=Image.new('RGBA',(cw,ch),bg); inner.paste(crop,(0,(ch-crop.height)//2-10))
    col=border or RAR[rarity]
    m=Image.new('L',(w,h),0); ImageDraw.Draw(m).rounded_rectangle((0,0,w-1,h-1),radius=28,fill=255)
    c=Image.new('RGBA',(w,h),(0,0,0,0)); d=ImageDraw.Draw(c)
    d.rounded_rectangle((0,0,w-1,h-1),radius=28,fill=(60,34,22,255))
    d.rounded_rectangle((6,6,w-7,h-7),radius=24,fill=col+(255,))
    mi=Image.new('L',(cw,ch),0); ImageDraw.Draw(mi).rounded_rectangle((0,0,cw-1,ch-1),radius=18,fill=255)
    c.paste(inner,(12,12),mi)
    if label:
        c,_=text(c,label,w//2,h-58,30,(255,255,255),outline=(60,34,22),stroke=6,shadow=False)
    return c
def shadowed(base, im, xy, r=14, off=10):
    a=im.split()[-1]; sh=Image.new('RGBA',im.size,(30,15,40,0)); sh.putalpha(a.point(lambda v: v*0.45))
    big=Image.new('RGBA',base.size,(0,0,0,0)); big.paste(sh,(xy[0],xy[1]+off),sh); big=big.filter(ImageFilter.GaussianBlur(r))
    base=Image.alpha_composite(base,big); base.alpha_composite(im,xy); return base

def collection(out):
    im=rays((1920,1080),(960,1300),(64,170,230),(88,190,245))
    im,_=text(im,'50 CATS',960,52,150,YELLOW,outline=(40,40,90),stroke=20)
    im,_=text(im,'TO CATCH!',960,240,70,(255,255,255),outline=(40,40,90),stroke=11)
    picks=[('Toadstool','Epic'),('Blossom','Legendary'),('Comet','Mythical'),('Void','Legendary'),('Glimmer','Epic'),('Bengal','Rare'),
           ('MaineCoon','Epic'),('Bottlecap','Legendary'),('Eclipse','Mythical'),('Ragdoll','Epic'),('Postie','Epic'),('Tabby','Common')]
    w,h,gx,gy=280,300,28,26; x0=(1920-(6*w+5*gx))//2; y0=372
    for i,(n,r) in enumerate(picks):
        x=x0+(i%6)*(w+gx); y=y0+(i//6)*(h+gy)
        im=shadowed(im,card(n,r,w,h,label=r.upper()),(x,y))
    im.convert('RGB').save(out,optimize=True)

def golden(out):
    im=rays((1920,1080),(960,620),(232,150,40),(246,180,60),glow=(255,240,190))
    im,_=text(im,'GOLDEN CATS!',960,60,140,YELLOW,outline=(90,45,10),stroke=18)
    im,_=text(im,'Every cat has a shiny twin',960,245,54,(255,255,255),outline=(90,45,10),stroke=9)
    picks=['Blossom_Gold','Eclipse_Gold','Void_Gold','Comet_Gold','Toadstool_Gold']
    w,h,g=330,380,30; x0=(1920-(5*w+4*g))//2; y0=420
    for i,n in enumerate(picks):
        im=shadowed(im,card(n,None,w,h,border=(255,214,92)),(x0+i*(w+g),y0+(20 if i%2 else 0)))
    im.convert('RGB').save(out,optimize=True)
if __name__=='__main__':
    collection('ad_collection.png'); golden('ad_golden.png')

def golden2(out, name='Blossom'):
    im=rays((1920,1080),(1300,640),(232,150,40),(246,180,60),glow=(255,240,190))
    im,_=text(im,'GOLDEN CATS!',960,46,128,YELLOW,outline=(90,45,10),stroke=17)
    im,_=text(im,'Any cat you meet can be gold',960,222,50,(255,255,255),outline=(90,45,10),stroke=8)
    a=card(name,'Legendary',440,440,label='NORMAL'); b=card(name+'_Gold',None,600,600,label='GOLD x1.5 MONEY',border=(255,214,92))
    im=shadowed(im,a,(250,470)); im=shadowed(im,b,(1060,360))
    d=ImageDraw.Draw(im)
    # arrow
    d.polygon([(760,640),(930,640),(930,600),(1020,690),(930,780),(930,740),(760,740)],fill=(255,255,255),outline=(90,45,10),width=10)
    im.convert('RGB').save(out,optimize=True)

def offline(out, name='Ragdoll_Sit'):
    import random
    W,H=1920,1080
    ys=np.linspace(0,1,H)[:,None,None]
    top=np.array((28,30,88),float); bot=np.array((92,64,160),float)
    bg=(top*(1-ys)+bot*ys)*np.ones((1,W,1))
    im=Image.fromarray(bg.astype(np.uint8)).convert('RGBA')
    d=ImageDraw.Draw(im); rnd=random.Random(7)
    for _ in range(140):
        x,y=rnd.randrange(W),rnd.randrange(H); r=rnd.choice([1,2,2,3])
        d.ellipse((x-r,y-r,x+r,y+r),fill=(255,250,220,rnd.randrange(120,255)))
    # moon
    d.ellipse((1560,70,1800,310),fill=(255,236,170)); d.ellipse((1620,40,1860,280),fill=tuple(int(v) for v in bg[60,1700]))
    im,_=text(im,'EARN WHILE',560,120,112,YELLOW,outline=(30,24,70),stroke=16)
    im,_=text(im,'OFFLINE!',560,290,150,(255,255,255),outline=(30,24,70),stroke=20)
    im,_=text(im,'Your cafe keeps earning',560,520,52,(255,255,255),outline=(30,24,70),stroke=8)
    im,_=text(im,'while you sleep',560,600,52,(255,255,255),outline=(30,24,70),stroke=8)
    c=card(name,None,620,620,border=(140,120,230))
    im=shadowed(im,c,(1130,330))
    for i,(x,y,s) in enumerate([(1660,350,60),(1730,280,80),(1810,190,100)]):
        im,_=text(im,'Z',x,y,s,(255,255,255),outline=(30,24,70),stroke=max(6,s//9),anchor_x='l')
    im.convert('RGB').save(out,optimize=True)

def pcard(path, box, w, h, border):
    """A card from any preview render, cropped to box."""
    src=Image.open(path).convert('RGBA'); bg=src.getpixel((box[0]+4,box[1]+4))
    cw,ch=w-24,h-24
    crop=src.crop(box); s=min(cw/crop.width,ch/crop.height); crop=crop.resize((int(crop.width*s),int(crop.height*s)),Image.LANCZOS)
    inner=Image.new('RGBA',(cw,ch),bg); inner.paste(crop,((cw-crop.width)//2,(ch-crop.height)//2))
    c=Image.new('RGBA',(w,h),(0,0,0,0)); d=ImageDraw.Draw(c)
    d.rounded_rectangle((0,0,w-1,h-1),radius=28,fill=(40,24,60,255)); d.rounded_rectangle((6,6,w-7,h-7),radius=24,fill=border+(255,))
    mi=Image.new('L',(cw,ch),0); ImageDraw.Draw(mi).rounded_rectangle((0,0,cw-1,ch-1),radius=18,fill=255); c.paste(inner,(12,12),mi)
    return c

def dealer(out):
    import random
    W,H=1920,1080; P='docs/concepts/cat-cafe/previews/'
    ys=np.linspace(0,1,H)[:,None,None]; top=np.array((20,22,70),float); bot=np.array((70,40,120),float)
    im=Image.fromarray(((top*(1-ys)+bot*ys)*np.ones((1,W,1))).astype(np.uint8)).convert('RGBA')
    d=ImageDraw.Draw(im); rnd=random.Random(11)
    for _ in range(160):
        x,y=rnd.randrange(W),rnd.randrange(H); r=rnd.choice([1,2,2,3]); d.ellipse((x-r,y-r,x+r,y+r),fill=(255,250,220,rnd.randrange(120,255)))
    im,_=text(im,'THE NIGHT DEALER',960,48,104,YELLOW,outline=(25,20,60),stroke=15)
    im,_=text(im,'Rare foods that bring rare cats',960,200,52,(255,255,255),outline=(25,20,60),stroke=8)
    a=pcard(P+'CatCafe_NPC_Dealer.png',(150,40,490,440),560,620,(150,120,240))
    b=pcard(P+'CatCafe_Street_DealerCart.png',(130,70,560,420),760,620,(150,120,240))
    im=shadowed(im,a,(250,330)); im=shadowed(im,b,(870,330))
    im,_=text(im,'Every night!',1250,880,56,YELLOW,outline=(25,20,60),stroke=9)
    im.convert('RGB').save(out,optimize=True)

def rescue(out):
    P='docs/concepts/cat-cafe/previews/'
    im=rays((1920,1080),(1350,620),(70,170,90),(95,195,110),glow=(240,255,220))
    im,_=text(im,'RESCUE',520,150,150,YELLOW,outline=(30,60,30),stroke=20)
    im,_=text(im,'STUCK CATS!',520,340,110,(255,255,255),outline=(30,60,30),stroke=16)
    im,_=text(im,'Some turn out gold',520,520,54,(255,255,255),outline=(30,60,30),stroke=8)
    c=pcard(P+'CatCafe_Park_RescueTree.png',(140,50,440,330),760,720,(255,214,92))
    im=shadowed(im,c,(1040,230))
    im,_=text(im,'HELP!',1560,330,64,(255,255,255),outline=(160,40,40),stroke=10)
    im.convert('RGB').save(out,optimize=True)

def pill(im, s, xy, cap=40, fill=(255,255,255), bg=(255,94,126), outline=(60,30,20)):
    from PIL import ImageFont
    f=None
    for sz in range(8,300):
        f=ImageFont.truetype(FRED,sz); b=f.getbbox("H")
        if b[3]-b[1]>=cap: break
    bb=f.getbbox(s); w=bb[2]-bb[0]; h=cap
    x,y=xy; pad=int(cap*0.6)
    box=(x,y,x+w+2*pad,y+h+2*pad)
    d=ImageDraw.Draw(im)
    d.rounded_rectangle((box[0]+4,box[1]+8,box[2]+4,box[3]+8),radius=(h+2*pad)//2,fill=(40,20,10,90))
    d.rounded_rectangle(box,radius=(h+2*pad)//2,fill=bg,outline=outline,width=7)
    d.text((x+pad-bb[0],y+pad-f.getbbox("H")[1]),s,font=f,fill=fill)
    return box
def arrow(im, p0, p1, color=(255,255,255), outline=(60,30,20), w=16):
    d=ImageDraw.Draw(im)
    import math
    ang=math.atan2(p1[1]-p0[1],p1[0]-p0[0]); L=46
    head=[p1,(p1[0]-L*math.cos(ang-0.5),p1[1]-L*math.sin(ang-0.5)),(p1[0]-L*math.cos(ang+0.5),p1[1]-L*math.sin(ang+0.5))]
    q=(p1[0]-L*0.7*math.cos(ang),p1[1]-L*0.7*math.sin(ang))
    d.line([p0,q],fill=outline,width=w+12); d.polygon(head,fill=outline,outline=outline,width=12)
    d.line([p0,q],fill=color,width=w); d.polygon(head,fill=color)
def catsatwork(src, out):
    im=Image.open(src).convert('RGBA')
    b=pill(im,'Barista cat makes it',(560,70),cap=42,bg=(80,180,150))
    arrow(im,(b[2]+10,(b[1]+b[3])//2),(1350,170))
    b=pill(im,'Waiter cat brings the cake!',(1060,890),cap=42,bg=(255,140,60))
    arrow(im,(b[0]+40,b[1]-6),(905,610))
    im.convert('RGB').save(out,optimize=True)
def autobox(path, pad=28):
    a=np.asarray(Image.open(path).convert('RGB')).astype(int); bg=a[4,4]
    m=np.abs(a-bg).sum(-1)>40; ys,xs=np.nonzero(m)
    x0,x1,y0,y1=xs.min(),xs.max(),ys.min(),ys.max()
    return (max(0,x0-pad),max(0,y0-pad),min(a.shape[1],x1+pad),min(a.shape[0],y1+pad))
def decor(out):
    P='docs/concepts/cat-cafe/previews/CatCafe_Decor_%s.png'
    im=rays((1920,1080),(960,1250),(255,170,190),(255,195,210),glow=(255,245,250))
    im,_=text(im,'DECORATE YOUR CAFE!',960,40,110,YELLOW,outline=(120,40,70),stroke=16)
    im,_=text(im,'Make it cozy. Make it yours.',960,200,52,(255,255,255),outline=(120,40,70),stroke=8)
    n='RetroJukebox DuckFountain BlossomTree BathtubSofa CatTreeTower IceCreamCounter MushroomLamp PorchSwing'.split()
    w,h,gx,gy=400,330,30,26; x0=(1920-(4*w+3*gx))//2; y0=310
    cols=[(255,214,92),(120,200,255),(255,150,190),(150,220,160)]
    for i,k in enumerate(n):
        c=pcard(P%k,autobox(P%k),w,h,cols[(i+i//4)%4])
        im=shadowed(im,c,(x0+(i%4)*(w+gx),y0+(i//4)*(h+gy)))
    im.convert('RGB').save(out,optimize=True)
def catsatwork2(src, out):
    """Slot 1 v3: Model-Agent's clean render, waiter cat with the tray on its head."""
    im=Image.open(src).convert('RGBA')
    im,_=text(im,'CATCH A',1430,440,70,YELLOW)
    im,_=text(im,'CAT CAFE',1430,530,120,CREAM,stroke=18)
    im,_=text(im,'Your cats take the orders!',1430,690,46,WHITE,stroke=8)
    b=pill(im,'Barista cat makes it',(560,40),cap=42,bg=(80,180,150))
    arrow(im,(b[2]+10,(b[1]+b[3])//2),(1310,190))
    b=pill(im,'Waiter cat brings the cake!',(1150,880),cap=42,bg=(255,140,60))
    arrow(im,(b[0]+30,b[1]-4),(945,650))
    im.convert('RGB').save(out,optimize=True)
