import base64,sys
S=sys.argv[1]
def b64(p): return 'data:image/png;base64,'+base64.b64encode(open(p,'rb').read()).decode()
sets=[
 ("Golden fish", [("v196 (before #1224)",S+'/png/v196_fish.png'),("now (v197+)",S+'/old_Fish.png'),("NEW",S+'/png/Icon_Clean_FishGold.png')], "12"),
 ("Money coin", [("now",S+'/old_Coin.png'),("NEW",S+'/png/Icon_Clean_CoinGold.png')], "$270M"),
 ("Money bag (prize tiles)", [("now",S+'/old_Bag.png'),("NEW",S+'/png/Icon_Clean_BagGold.png')], "$1.13M"),
]
rows=[]
for title,items,num in sets:
  cells=[]
  for label,p in items:
    src=b64(p)
    cells.append(f'''<div class="cell"><div class="lab">{label}</div><img src="{src}" width="128" height="128">
<div class="row dark"><img src="{src}" width="30" height="30"><span class="hud">{num}</span></div>
<div class="row light"><img src="{src}" width="18" height="18"><span class="price">{num}</span></div>
<div class="row dark"><div class="chip"><img src="{src}" width="48" height="48"><span>x3</span></div></div></div>''')
  rows.append(f'<div class="set"><h2>{title}</h2><div class="cells">{"".join(cells)}</div></div>')
html=f'''<html><head><style>
body{{margin:0;padding:20px;background:#efe3d2;font-family:Arial,sans-serif;width:760px}}
h1{{margin:0 0 6px;color:#3a2618}} p{{margin:0 0 14px;color:#6b5240}}
.set{{background:#fff8ef;border:3px solid #2a1a12;border-radius:14px;padding:12px;margin-bottom:14px}}
h2{{margin:0 0 8px;color:#3a2618}} .cells{{display:flex;gap:18px}}
.cell{{width:220px;text-align:center}} .lab{{font-weight:bold;color:#3a2618;margin-bottom:4px}}
.row{{display:flex;align-items:center;justify-content:center;gap:6px;border-radius:10px;padding:6px;margin-top:6px}}
.dark{{background:#3b2a20}} .light{{background:#fff}}
.hud{{font:900 26px Arial;color:#fff;-webkit-text-stroke:1px #000}} .price{{font:bold 16px Arial;color:#3a2618}}
.chip{{display:flex;flex-direction:column;align-items:center;background:#ffcf4d;border:3px solid #2a1a12;border-radius:12px;padding:4px 8px;font:900 14px Arial;color:#fff;-webkit-text-stroke:1px #000}}
</style></head><body><h1>#1253 currency icons: before / now / new</h1><p>Real sizes: 30 px HUD counter (dark), 18 px price row (light), 48 px prize chip; 128 px for detail.</p>{"".join(rows)}</body></html>'''
open(S+'/sheet.html','w').write(html)
