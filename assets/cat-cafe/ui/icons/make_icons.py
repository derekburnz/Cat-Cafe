# Generates the Cat Cafe UI icon sheet (4 x 4 cells of 256 px) as SVG snippets and an HTML page to render.
import math, json, sys
O = "#2A1C15"   # Theme.colors.outline
SW = 22         # outline stroke, about 11 px outside each shape at 256 px

def sil(shapes):
    """The dark silhouette under the colours: every shape stroked and filled in the outline colour."""
    return f'<g fill="{O}" stroke="{O}" stroke-width="{SW}" stroke-linejoin="round" stroke-linecap="round">{shapes}</g>'

def gloss(cx, cy, rx, ry, rot=-20, op=0.38):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({rot} {cx} {cy})" fill="#fff" opacity="{op}"/>'

def grad(id_, top, bottom):
    return f'<linearGradient id="{id_}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>'

icons = {}

# 1. cats: a tabby cat face with the W mouth
ears = '<path d="M46,118 L66,28 L122,80 Z"/><path d="M210,118 L190,28 L134,80 Z"/>'
head = '<ellipse cx="128" cy="150" rx="94" ry="80"/>'
icons["cats"] = f'''<defs>{grad("catG", "#FFC56E", "#F59A3A")}</defs>
{sil(ears + head)}
<g fill="url(#catG)">{ears}{head}</g>
<path d="M66,96 L74,52 L104,80 Z" fill="#FF9FB2"/><path d="M190,96 L182,52 L152,80 Z" fill="#FF9FB2"/>
<g fill="#E07F25"><rect x="120" y="74" width="16" height="34" rx="8"/><rect x="92" y="82" width="14" height="26" rx="7" transform="rotate(-14 99 95)"/><rect x="150" y="82" width="14" height="26" rx="7" transform="rotate(14 157 95)"/></g>
{gloss(92, 112, 40, 18)}
<ellipse cx="74" cy="178" rx="18" ry="11" fill="#FF8FA8" opacity="0.7"/><ellipse cx="182" cy="178" rx="18" ry="11" fill="#FF8FA8" opacity="0.7"/>
<ellipse cx="94" cy="148" rx="14" ry="19" fill="{O}"/><ellipse cx="162" cy="148" rx="14" ry="19" fill="{O}"/>
<circle cx="99" cy="140" r="6" fill="#fff"/><circle cx="167" cy="140" r="6" fill="#fff"/>
<path d="M118,166 L138,166 L128,178 Z" fill="#FF7F9A" stroke="{O}" stroke-width="5" stroke-linejoin="round"/>
<path d="M106,186 Q117,200 128,186 Q139,200 150,186" fill="none" stroke="{O}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>'''

# 2. collection (Index): a purple book with a gold paw on the cover
pages = '<rect x="66" y="46" width="150" height="186" rx="16"/>'
cover = '<rect x="40" y="28" width="156" height="186" rx="18"/>'
paw = '<ellipse cx="128" cy="138" rx="28" ry="23"/><ellipse cx="96" cy="104" rx="11" ry="14" transform="rotate(-20 96 104)"/><ellipse cx="116" cy="88" rx="11" ry="14"/><ellipse cx="142" cy="88" rx="11" ry="14"/><ellipse cx="162" cy="104" rx="11" ry="14" transform="rotate(20 162 104)"/>'
icons["collection"] = f'''<defs>{grad("bookG", "#A98BFF", "#7A4FE6")}</defs>
{sil(pages + cover)}
<rect x="66" y="46" width="150" height="186" rx="16" fill="#FFF3DC"/>
<g stroke="#E3C9A0" stroke-width="5"><line x1="196" y1="70" x2="196" y2="214"/><line x1="206" y1="74" x2="206" y2="210"/></g>
<rect x="40" y="28" width="156" height="186" rx="18" fill="url(#bookG)"/>
<rect x="40" y="28" width="34" height="186" rx="16" fill="#5E36C2"/>
<line x1="74" y1="34" x2="74" y2="208" stroke="{O}" stroke-width="6"/>
{gloss(118, 56, 46, 14, -8, 0.35)}
<g fill="#FFC94D" stroke="{O}" stroke-width="6">{paw}</g>'''

# 3. upgrades: a big green up arrow
arrow = '<path d="M128,22 L228,126 L174,126 L174,228 L82,228 L82,126 L28,126 Z"/>'
icons["upgrades"] = f'''<defs>{grad("upG", "#8CF06A", "#2FAE36")}</defs>
{sil(arrow)}
<g fill="url(#upG)" stroke="url(#upG)" stroke-width="6" stroke-linejoin="round">{arrow}</g>
<path d="M128,46 L74,104" stroke="#fff" stroke-width="14" stroke-linecap="round" opacity="0.45"/>
<rect x="96" y="138" width="16" height="74" rx="8" fill="#fff" opacity="0.35"/>'''

# 4. decor: a potted plant
leaves = '<path d="M128,148 C 92,116 90,62 128,26 C 166,62 164,116 128,148 Z"/><path d="M118,152 C 78,148 40,116 34,76 C 78,74 112,104 118,152 Z"/><path d="M138,152 C 178,148 216,116 222,76 C 178,74 144,104 138,152 Z"/>'
pot = '<path d="M76,150 L180,150 L166,230 L90,230 Z"/><rect x="62" y="134" width="132" height="34" rx="12"/>'
icons["decor"] = f'''<defs>{grad("leafG", "#7EDB5C", "#3FA83A")}{grad("potG", "#F49A57", "#C9622A")}</defs>
{sil(leaves + pot)}
<g fill="url(#leafG)">{leaves}</g>
<g fill="none" stroke="#2F8A2C" stroke-width="6" stroke-linecap="round"><path d="M128,140 L128,52"/><path d="M114,146 C 96,124 76,106 54,90"/><path d="M142,146 C 160,124 180,106 202,90"/></g>
{gloss(114, 60, 10, 26, 10, 0.4)}
<path d="M76,150 L180,150 L166,230 L90,230 Z" fill="url(#potG)"/>
<rect x="62" y="134" width="132" height="34" rx="12" fill="#F7A468"/>
<line x1="70" y1="168" x2="186" y2="168" stroke="{O}" stroke-width="6"/>
{gloss(96, 146, 26, 7, 0, 0.45)}'''

# 5. home (My Cafe): a little house
chimney = '<rect x="168" y="42" width="28" height="56" rx="4"/>'
roof = '<path d="M20,126 L128,30 L236,126 Z"/>'
walls = '<rect x="50" y="110" width="156" height="120" rx="10"/>'
icons["home"] = f'''<defs>{grad("roofG", "#FF6E6A", "#D93B38")}</defs>
{sil(chimney + walls + roof)}
<rect x="168" y="42" width="28" height="56" rx="4" fill="#B83532"/>
<rect x="50" y="110" width="156" height="120" rx="10" fill="#FFF1DC"/>
<path d="M20,126 L128,30 L236,126 Z" fill="url(#roofG)" stroke="url(#roofG)" stroke-width="4" stroke-linejoin="round"/>
<line x1="34" y1="126" x2="222" y2="126" stroke="{O}" stroke-width="6" stroke-linecap="round"/>
{gloss(96, 84, 34, 10, -40, 0.4)}
<path d="M106,230 L106,176 C106,152 150,152 150,176 L150,230 Z" fill="#A86F3E" stroke="{O}" stroke-width="7" stroke-linejoin="round"/>
<circle cx="140" cy="196" r="5" fill="#FFC94D"/>
<g stroke="{O}" stroke-width="6"><rect x="64" y="146" width="30" height="30" rx="6" fill="#8FD3FF"/><rect x="162" y="146" width="30" height="30" rx="6" fill="#8FD3FF"/></g>
<g stroke="{O}" stroke-width="4"><line x1="79" y1="146" x2="79" y2="176"/><line x1="64" y1="161" x2="94" y2="161"/><line x1="177" y1="146" x2="177" y2="176"/><line x1="162" y1="161" x2="192" y2="161"/></g>'''

# 6. travel (Areas): a compass
icons["travel"] = f'''<defs>{grad("rimG", "#FFE07A", "#E2A21F")}</defs>
{sil('<circle cx="128" cy="128" r="100"/>')}
<circle cx="128" cy="128" r="100" fill="url(#rimG)"/>
<circle cx="128" cy="128" r="74" fill="#FFF9F2" stroke="{O}" stroke-width="7"/>
<g fill="{O}"><rect x="123" y="58" width="10" height="16" rx="4"/><rect x="123" y="182" width="10" height="16" rx="4"/><rect x="58" y="123" width="16" height="10" rx="4"/><rect x="182" y="123" width="16" height="10" rx="4"/></g>
<g stroke="{O}" stroke-width="6" stroke-linejoin="round"><path d="M128,72 L150,128 L106,128 Z" fill="#F0524F"/><path d="M128,184 L150,128 L106,128 Z" fill="#8E97B2"/></g>
<circle cx="128" cy="128" r="11" fill="#FFC94D" stroke="{O}" stroke-width="6"/>
{gloss(92, 64, 38, 12, -30, 0.45)}'''

# 7. alley: a paw print
pads = '<ellipse cx="128" cy="168" rx="58" ry="48"/><ellipse cx="62" cy="108" rx="23" ry="29" transform="rotate(-24 62 108)"/><ellipse cx="102" cy="62" rx="24" ry="31" transform="rotate(-8 102 62)"/><ellipse cx="154" cy="62" rx="24" ry="31" transform="rotate(8 154 62)"/><ellipse cx="194" cy="108" rx="23" ry="29" transform="rotate(24 194 108)"/>'
icons["alley"] = f'''<defs>{grad("pawG", "#FFA9C4", "#F2679E")}</defs>
{sil(pads)}
<g fill="url(#pawG)">{pads}</g>
{gloss(106, 150, 24, 10, -20, 0.45)}{gloss(96, 48, 8, 12, -8, 0.5)}{gloss(148, 48, 8, 12, 8, 0.5)}{gloss(56, 96, 7, 11, -24, 0.5)}{gloss(188, 96, 7, 11, 24, 0.5)}'''

# 8. equipBest: a gold sparkle
def star(cx, cy, r, k=0.18):
    a = r * k
    return (f'<path d="M{cx},{cy-r} C{cx+a},{cy-a} {cx+a},{cy-a} {cx+r},{cy} C{cx+a},{cy+a} {cx+a},{cy+a} {cx},{cy+r} '
            f'C{cx-a},{cy+a} {cx-a},{cy+a} {cx-r},{cy} C{cx-a},{cy-a} {cx-a},{cy-a} {cx},{cy-r} Z"/>')
stars = star(116, 136, 100) + star(204, 52, 34) + star(206, 196, 22)
icons["equipBest"] = f'''<defs>{grad("starG", "#FFF08A", "#FFB21F")}</defs>
{sil(stars)}
<g fill="url(#starG)">{stars}</g>
{gloss(102, 108, 10, 26, 0, 0.55)}'''

# 9. gifts: a red gift box with a gold bow
bow = '<ellipse cx="96" cy="66" rx="36" ry="22" transform="rotate(-28 96 66)"/><ellipse cx="160" cy="66" rx="36" ry="22" transform="rotate(28 160 66)"/>'
box = '<rect x="44" y="112" width="168" height="118" rx="12"/><rect x="30" y="82" width="196" height="44" rx="12"/>'
icons["gifts"] = f'''<defs>{grad("boxG", "#FF6E6A", "#D93B38")}</defs>
{sil(bow + box)}
<g fill="#FFC94D">{bow}</g>
<g fill="#E9A92C"><ellipse cx="102" cy="68" rx="16" ry="8" transform="rotate(-28 102 68)"/><ellipse cx="154" cy="68" rx="16" ry="8" transform="rotate(28 154 68)"/></g>
<rect x="44" y="112" width="168" height="118" rx="12" fill="url(#boxG)"/>
<rect x="30" y="82" width="196" height="44" rx="12" fill="#FF7C78" stroke="{O}" stroke-width="6"/>
<rect x="110" y="82" width="36" height="148" fill="#FFC94D" stroke="{O}" stroke-width="6"/>
<circle cx="128" cy="80" r="16" fill="#FFD866" stroke="{O}" stroke-width="6"/>
{gloss(70, 98, 26, 7, 0, 0.5)}'''

# 10. settings: a steel gear
pts = []
for k in range(8):
    a = math.radians(k * 45 - 90)
    for ang, r in ((-17, 80), (-10, 108), (10, 108), (17, 80)):
        t = a + math.radians(ang)
        pts.append(f"{128 + r*math.cos(t):.1f},{128 + r*math.sin(t):.1f}")
gear = f'<polygon points="{" ".join(pts)}"/>'
icons["settings"] = f'''<defs>{grad("gearG", "#DCE4EE", "#8C99AD")}</defs>
{sil(gear)}
<g fill="url(#gearG)" stroke="url(#gearG)" stroke-width="6" stroke-linejoin="round">{gear}</g>
<circle cx="128" cy="128" r="56" fill="none" stroke="#7A879B" stroke-width="6" opacity="0.6"/>
<circle cx="128" cy="128" r="30" fill="#4A5568" stroke="{O}" stroke-width="8"/>
{gloss(96, 84, 30, 12, -35, 0.5)}'''

# 11. invite: an envelope with a heart seal
env = '<rect x="24" y="62" width="208" height="146" rx="18"/>'
heart = '<path d="M128,190 C 80,160 76,120 102,114 C 116,111 125,120 128,128 C 131,120 140,111 154,114 C 180,120 176,160 128,190 Z"/>'
icons["invite"] = f'''{sil(env)}
<rect x="24" y="62" width="208" height="146" rx="18" fill="#FFF9F2"/>
<path d="M36,198 L104,138 M220,198 L152,138" stroke="#D9C3A5" stroke-width="8" stroke-linecap="round"/>
<path d="M34,74 L128,148 L222,74" fill="#F3E6D4" stroke="{O}" stroke-width="8" stroke-linejoin="round" stroke-linecap="round"/>
<g fill="#F2679E" stroke="{O}" stroke-width="7" stroke-linejoin="round">{heart}</g>
{gloss(108, 132, 10, 6, -30, 0.6)}'''

# 12. tutorial: a blue badge with a question mark
icons["tutorial"] = f'''<defs>{grad("tutG", "#7CC4FF", "#2E8FEA")}</defs>
{sil('<circle cx="128" cy="128" r="102"/>')}
<circle cx="128" cy="128" r="102" fill="url(#tutG)"/>
{gloss(94, 70, 40, 16, -30, 0.4)}
<path d="M90,98 C90,52 166,50 166,96 C166,126 128,128 128,158" fill="none" stroke="{O}" stroke-width="48" stroke-linecap="round" stroke-linejoin="round"/>
<circle cx="128" cy="200" r="24" fill="{O}"/>
<path d="M90,98 C90,52 166,50 166,96 C166,126 128,128 128,158" fill="none" stroke="#fff" stroke-width="28" stroke-linecap="round" stroke-linejoin="round"/>
<circle cx="128" cy="200" r="14" fill="#fff"/>'''

# 13. spin: a prize wheel with a pointer
colours = ["#F0524F", "#FFC94D", "#5FA8FF", "#7EDB5C", "#F2679E", "#C07CFF"]
wedges = []
for k, c in enumerate(colours):
    a0 = math.radians(k * 60 - 120); a1 = math.radians((k + 1) * 60 - 120)
    x0, y0 = 128 + 96*math.cos(a0), 136 + 96*math.sin(a0)
    x1, y1 = 128 + 96*math.cos(a1), 136 + 96*math.sin(a1)
    wedges.append(f'<path d="M128,136 L{x0:.1f},{y0:.1f} A96,96 0 0 1 {x1:.1f},{y1:.1f} Z" fill="{c}"/>')
pointer = '<path d="M128,64 L106,22 L150,22 Z"/>'
icons["spin"] = f'''{sil('<circle cx="128" cy="136" r="96"/>' + pointer)}
{"".join(wedges)}
<g stroke="{O}" stroke-width="5">{"".join(f'<line x1="128" y1="136" x2="{128 + 96*math.cos(math.radians(k*60-120)):.1f}" y2="{136 + 96*math.sin(math.radians(k*60-120)):.1f}"/>' for k in range(6))}</g>
<circle cx="128" cy="136" r="20" fill="#FFC94D" stroke="{O}" stroke-width="7"/>
<path d="M128,64 L106,22 L150,22 Z" fill="#FF6E6A" stroke="#FF6E6A" stroke-width="4" stroke-linejoin="round"/>
{gloss(92, 84, 30, 12, -35, 0.4)}'''

# 14. lock: a gold padlock
shackle = '<path d="M84,124 L84,86 C84,26 172,26 172,86 L172,124" fill="none" stroke-width="54"/>'
body = '<rect x="50" y="112" width="156" height="118" rx="24"/>'
icons["lock"] = f'''<defs>{grad("lockG", "#FFE07A", "#E2A21F")}</defs>
<g fill="{O}" stroke="{O}" stroke-linecap="round" stroke-linejoin="round"><path d="M84,124 L84,86 C84,26 172,26 172,86 L172,124" fill="none" stroke-width="56"/>{body.replace('/>', f' stroke-width="{SW}"/>')}</g>
<path d="M84,124 L84,86 C84,26 172,26 172,86 L172,124" fill="none" stroke="#C3CDDA" stroke-width="30" stroke-linecap="round"/>
<path d="M90,96 C92,56 116,46 128,46" fill="none" stroke="#fff" stroke-width="8" stroke-linecap="round" opacity="0.6"/>
<rect x="50" y="112" width="156" height="118" rx="24" fill="url(#lockG)"/>
{gloss(92, 130, 30, 9, 0, 0.5)}
<circle cx="128" cy="162" r="17" fill="{O}"/><rect x="119" y="164" width="18" height="38" rx="7" fill="{O}"/>'''

# 15. crate: a wooden crate
crate = '<rect x="34" y="46" width="188" height="176" rx="14"/>'
icons["crate"] = f'''<defs>{grad("woodG", "#E0A465", "#B87638")}</defs>
{sil(crate)}
<rect x="34" y="46" width="188" height="176" rx="14" fill="url(#woodG)"/>
<g fill="#9C6330"><rect x="34" y="46" width="36" height="176" rx="12"/><rect x="186" y="46" width="36" height="176" rx="12"/></g>
<path d="M70,206 L186,62" stroke="#9C6330" stroke-width="26" stroke-linecap="round"/>
<g stroke="{O}" stroke-width="6" stroke-linecap="round"><line x1="70" y1="50" x2="70" y2="218"/><line x1="186" y1="50" x2="186" y2="218"/><line x1="40" y1="106" x2="66" y2="106"/><line x1="40" y1="162" x2="66" y2="162"/><line x1="190" y1="106" x2="216" y2="106"/><line x1="190" y1="162" x2="216" y2="162"/></g>
<g fill="{O}"><circle cx="52" cy="66" r="5"/><circle cx="204" cy="66" r="5"/><circle cx="52" cy="202" r="5"/><circle cx="204" cy="202" r="5"/></g>
{gloss(110, 66, 34, 8, 0, 0.4)}'''

# 16. potion: a round flask with pink liquid
flask = '<rect x="102" y="36" width="52" height="64" rx="8"/><circle cx="128" cy="160" r="76"/>'
icons["potion"] = f'''<defs><clipPath id="flaskC"><circle cx="128" cy="160" r="76"/></clipPath>{grad("liqG", "#FF8FC0", "#E0407F")}</defs>
{sil(flask + '<rect x="92" y="18" width="72" height="34" rx="10"/>')}
<rect x="102" y="36" width="52" height="64" rx="8" fill="#DDF3FF"/>
<circle cx="128" cy="160" r="76" fill="#DDF3FF"/>
<g clip-path="url(#flaskC)"><path d="M40,150 C 76,132 104,166 128,150 C 152,134 180,166 216,148 L216,240 L40,240 Z" fill="url(#liqG)"/></g>
<path d="M40,150 C 76,132 104,166 128,150 C 152,134 180,166 216,148" fill="none" stroke="{O}" stroke-width="5" clip-path="url(#flaskC)"/>
<rect x="92" y="18" width="72" height="34" rx="10" fill="#C98A4B" stroke="{O}" stroke-width="6"/>
<g fill="#fff" opacity="0.85"><circle cx="104" cy="186" r="9"/><circle cx="148" cy="200" r="6"/><circle cx="160" cy="176" r="4"/></g>
{gloss(96, 120, 14, 30, 30, 0.55)}'''

ORDER = ["cats", "collection", "upgrades", "decor", "home", "travel", "alley", "equipBest",
         "gifts", "settings", "invite", "tutorial", "spin", "lock", "crate", "potion"]

def svg(name, size=256):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="{size}" height="{size}">{icons[name]}</svg>'

if __name__ == "__main__":
    out = sys.argv[1]
    cells = "".join(f'<div style="position:absolute;left:{(i%4)*256}px;top:{(i//4)*256}px;width:256px;height:256px">{svg(n)}</div>' for i, n in enumerate(ORDER))
    open(out + "/atlas.html", "w").write(f'<!doctype html><html><body style="margin:0;background:transparent"><div style="position:relative;width:1024px;height:1024px">{cells}</div></body></html>')
    json.dump({"order": ORDER}, open(out + "/order.json", "w"))
    for n in ORDER:
        open(f"{out}/{n}.svg", "w").write(svg(n))
