from PIL import Image, ImageDraw, ImageFilter, ImageFont
FRED="Fredoka-Bold.ttf"  # Google Fonts Fredoka 700 (OFL), downloaded next to this file
YELLOW=(255,214,92); BROWN=(74,42,28); CREAM=(255,246,230); WHITE=(255,255,255)
def text(im, s, cx, top, cap, fill, outline=BROWN, stroke=None, font=FRED, shadow=True, anchor_x="c"):
    # find size for cap height
    for sz in range(8,600):
        f=ImageFont.truetype(font,sz); b=f.getbbox("H")
        if b[3]-b[1]>=cap: break
    stroke = stroke if stroke is not None else max(3,int(cap*0.13))
    bb=f.getbbox(s, stroke_width=stroke); w=bb[2]-bb[0]
    x = cx-w/2-bb[0] if anchor_x=="c" else cx
    y = top-f.getbbox("H")[1]
    layer=Image.new("RGBA",im.size,(0,0,0,0)); d=ImageDraw.Draw(layer)
    if shadow:
        sh=Image.new("RGBA",im.size,(0,0,0,0)); sd=ImageDraw.Draw(sh)
        sd.text((x,y+stroke*0.7),s,font=f,fill=(40,20,10,160),stroke_width=stroke,stroke_fill=(40,20,10,160))
        sh=sh.filter(ImageFilter.GaussianBlur(max(2,cap//14)))
        layer=Image.alpha_composite(layer,sh); d=ImageDraw.Draw(layer)
    d.text((x,y),s,font=f,fill=fill,stroke_width=stroke,stroke_fill=outline)
    return Image.alpha_composite(im.convert("RGBA"),layer), (x+bb[0], y+bb[1], x+bb[2], y+bb[3])
