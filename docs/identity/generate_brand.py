"""Rebuild proposal SVGs from local fonts. Tooling: fontTools + uharfbuzz.

Run from repository root. This does not alter application code or platform icons.
"""
from pathlib import Path
from html import escape
import json
import uharfbuzz as hb
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/brand'
OUT.mkdir(parents=True, exist_ok=True)

def mark(ink='#173E43', accent='#14756B'):
    return f'''<g fill="none" stroke="{ink}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round">
    <path d="M10 73V47L23 37L36 47V60 M35 60V29L48 19L61 29V60 M60 60V47L73 37L86 47V73 M10 73H86 M48 43V73"/>
    </g><circle cx="48" cy="73" r="8" fill="{accent}"/><circle cx="48" cy="73" r="3" fill="{ink}"/>'''

def outlined(text, size, x, y, color, weight='Bold', direction='rtl'):
    path = ROOT / f'assets/fonts/NotoSansArabic-{weight}.ttf'
    raw = path.read_bytes(); face=hb.Face(raw); font=hb.Font(face)
    font.scale=(face.upem,face.upem); hb.ot_font_set_funcs(font)
    buf=hb.Buffer(); buf.add_str(text); buf.guess_segment_properties(); buf.direction=direction
    hb.shape(font,buf)
    tt=TTFont(path); glyphs=tt.getGlyphSet(); order=tt.getGlyphOrder()
    scale=size/face.upem; advance=sum(p.x_advance for p in buf.glyph_positions)*scale
    cursor=0; parts=[]
    for info,pos in zip(buf.glyph_infos,buf.glyph_positions):
        pen=SVGPathPen(glyphs); glyphs[order[info.codepoint]].draw(pen)
        parts.append(f'<path transform="translate({x+(cursor+pos.x_offset)*scale:.4f} {y-pos.y_offset*scale:.4f}) scale({scale:.6f} {-scale:.6f})" d="{pen.getCommands()}"/>')
        cursor+=pos.x_advance
    return f'<g fill="{color}" aria-hidden="true">'+''.join(parts)+'</g>',advance

def svg(body, w, h, title):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" aria-labelledby="title"><title id="title">{escape(title)}</title>{body}</svg>\n'

for name,ink,accent in [('primary','#173E43','#14756B'),('reversed','#F3F7F4','#8AD8C7'),('mono','#173E43','#173E43')]:
    (OUT/f'mark-{name}.svg').write_text(svg(mark(ink,accent),96,96,'بوابة المولدات — رمز وصلة الحي'))
    ar,aw=outlined('بوابة المولدات',42,0,0,ink)
    en,ew=outlined('Generator Portal',19,0,0,ink,weight='Regular',direction='ltr')
    body=f'<g transform="translate(450 22)">{mark(ink,accent)}</g>'
    body+=f'<g transform="translate({420-aw:.2f} 66)">{ar}</g>'
    body+=f'<g transform="translate({420-ew:.2f} 102)">{en}</g>'
    (OUT/f'lockup-{name}.svg').write_text(svg(body,566,138,'بوابة المولدات | Generator Portal'))

# Candidate icon/splash artwork, deliberately not installed before approval.
(OUT/'icon-proposal.svg').write_text(svg('<rect width="108" height="108" fill="#173E43"/><g transform="translate(22 22) scale(.666667)">'+mark('#F3F7F4','#8AD8C7')+'</g>',108,108,'مقترح أيقونة بوابة المولدات'))
(OUT/'adaptive-foreground-proposal.svg').write_text(svg('<g transform="translate(22 22) scale(.666667)">'+mark('#F3F7F4','#8AD8C7')+'</g>',108,108,'مقدمة الأيقونة التكيفية المقترحة'))
(OUT/'splash-proposal.svg').write_text(svg('<rect width="390" height="844" fill="#F4F6F3"/><g transform="translate(147 300)">'+mark()+'</g>',390,844,'مقترح شاشة البداية'))

def luminance(hex):
    rgb=[int(hex[i:i+2],16)/255 for i in (1,3,5)]
    rgb=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    return sum(a*b for a,b in zip(rgb,[.2126,.7152,.0722]))
pairs=[('light text','#233D42','#FFFFFF'),('light muted','#53696D','#F4F6F3'),('primary button','#FFFFFF','#14756B'),('success','#246B4C','#E9F3ED'),('warning','#8C581B','#FFF2DC'),('error','#AA3F36','#FBEDEA'),('dark text','#ECF3EF','#1B3337'),('dark muted','#B3C5C3','#1B3337'),('dark primary button','#113C35','#8AD8C7'),('dark success','#A0D9B8','#234338'),('dark warning','#F1CC8A','#493B26'),('dark error','#FFB8AD','#4C302F')]
results=[]
for name,fg,bg in pairs:
    a,b=sorted([luminance(fg),luminance(bg)])
    ratio=(b+.05)/(a+.05)
    assert ratio>=4.5,(name,ratio)
    results.append(dict(pair=name,foreground=fg,background=bg,ratio=round(ratio,2)))
(ROOT/'docs/identity/contrast.json').write_text(json.dumps(results,indent=2)+'\n')
print('SVG proposal variants generated; all',len(results),'specified text pairs pass 4.5:1')
