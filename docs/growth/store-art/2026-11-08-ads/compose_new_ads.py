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
