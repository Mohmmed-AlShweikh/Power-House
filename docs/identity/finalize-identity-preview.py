"""Approved A artwork and final Step 1 review; no app/platform integration."""
from pathlib import Path
import runpy,base64,re,json
R=Path(__file__).resolve().parents[2]; D=R/'docs/identity'; O=R/'assets/brand/approved-a'; O.mkdir(exist_ok=True)
src=runpy.run_path(str(D/'refine-generator.py'))
mark,svg=src['mark'],src['svg']
warm='#F3F1EB'
for name,ink,accent in [('primary','#173E43','#14756B'),('black','#000000','#000000'),('white','#FFFFFF','#FFFFFF'),('reversed','#F3F7F4','#8AD8C7')]:
    (O/f'mark-{name}.svg').write_text(svg(mark(ink,accent)))
(O/'lockup.svg').write_bytes((R/'assets/brand/a-refined/lockup.svg').read_bytes())
# 108dp layer canvas; 66dp circular guaranteed safe area (Android convention).
# Artwork's farthest polygon point from optical centre (52,50) is <59 units.
# .56 scale keeps even that point within 33dp of the layer centre.
transform='translate(24.88 26) scale(.56)'
foreground=f'<g transform="{transform}">{mark("#173E43","#14756B")}</g>'
mono=f'<g transform="{transform}">{mark("#000000","#000000")}</g>'
(O/'adaptive-foreground.svg').write_text(svg(foreground,108,108))
(O/'adaptive-background.svg').write_text(svg(f'<rect width="108" height="108" fill="{warm}"/>',108,108))
(O/'adaptive-monochrome.svg').write_text(svg(mono,108,108))
for shape,clip in [('circle','<circle cx="54" cy="54" r="36"/>'),('rounded','<rect x="18" y="18" width="72" height="72" rx="17"/>')]:
    body=f'<defs><clipPath id="launcher">{clip}</clipPath></defs><g clip-path="url(#launcher)"><rect width="108" height="108" fill="{warm}"/>{foreground}</g>'
    (O/f'launcher-{shape}.svg').write_text(svg(body,108,108).replace('viewBox="0 0 108 108"','viewBox="18 18 72 72"'))
for mode,bg,fg in [('light','#D5E8E1','#173E43'),('dark','#25443F','#A1D9C9')]:
    body=f'<defs><clipPath id="launcher"><rect x="18" y="18" width="72" height="72" rx="17"/></clipPath></defs><g clip-path="url(#launcher)"><rect width="108" height="108" fill="{bg}"/><g transform="{transform}">{mark(fg,fg)}</g></g>'
    (O/f'launcher-themed-{mode}.svg').write_text(svg(body,108,108).replace('viewBox="0 0 108 108"','viewBox="18 18 72 72"'))
(O/'safe-area.svg').write_text(svg(f'<rect width="108" height="108" fill="{warm}"/><circle cx="54" cy="54" r="33" fill="none" stroke="#AA3F36" stroke-width=".5" stroke-dasharray="2 2"/>{foreground}',108,108))

def img(path,size=108,attrs=''):
    raw=(R/path).read_bytes();uri=base64.b64encode(raw).decode()
    return f'<img data-asset-src="{path}" src="data:image/svg+xml;base64,{uri}" width="{size}" height="{size}" {attrs}>'
font=''.join(f"@font-face{{font-family:Portal;src:url('../../assets/fonts/NotoSansArabic-{n}.ttf');font-weight:{w}}}" for w,n in [(400,'Regular'),(600,'SemiBold')])
panels=''
for mode,label in [('light','خلفية فاتحة'),('dark','خلفية داكنة')]:
    row=''.join(f'<figure>{img("assets/brand/approved-a/launcher-rounded.svg",s)}<figcaption dir="ltr">{s}px</figcaption></figure>' for s in [192,96,48])
    extra=''.join(f'<figure>{img("assets/brand/approved-a/"+f,96)}<figcaption>{label}</figcaption></figure>' for f,label in [('launcher-circle.svg','قناع دائري'),(f'launcher-themed-{mode}.svg','أحادي · أندرويد 13+')])
    panels+=f'<section class="panel {mode}"><h2>{label}</h2><div class="sizes">{row}</div><div class="extra">{extra}</div></section>'
html=f'''<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><title>الأيقونة المعتمدة — المنطقة الآمنة</title><style>{font}
*{{box-sizing:border-box}}body{{width:1440px;margin:0;padding:48px;background:{warm};color:#173E43;font:14px/1.8 Portal,sans-serif}}h1,h2,p,figure{{margin:0}}h1{{font-size:30px}}header{{margin-bottom:28px}}header p{{color:#53696D}}main{{display:grid;grid-template-columns:1fr 1fr;gap:24px}}.panel{{padding:28px;border:1px solid #CCD8D4;border-radius:20px;background:#FFFFFF}}.panel.dark{{background:#13262A;border-color:#3F5A5C;color:#ECF3EF}}.sizes{{display:flex;align-items:end;justify-content:space-around;gap:20px;height:310px}}figure{{display:flex;flex-direction:column;align-items:center;gap:16px}}figcaption{{font-size:13px}}.extra{{border-top:1px solid #CCD8D4;display:flex;justify-content:space-around;align-items:center;padding-top:24px;margin-top:28px}}.proof{{margin-top:24px;padding:24px;background:#FFFFFF;border:1px solid #CCD8D4;border-radius:16px;display:flex;gap:32px;align-items:center}}.proof p{{color:#53696D}}code{{direction:ltr;unicode-bidi:isolate;display:inline-block}}
</style><header><h1>أيقونة A — طبقات مستقلة ومساحة آمنة</h1><p>الرمز المعتمد بفتحتَي تهوية · لون ثابت دون تدرجات · الأحجام الفعلية عند عرض الصورة بنسبة 100%</p></header><main>{panels}</main><div class="proof">{img('assets/brand/approved-a/safe-area.svg',162)}<p>طبقة أصلية <code>108 × 108dp</code>؛ الدائرة المتقطعة توضح المنطقة الآمنة <code>66dp</code>.<br>كل أجزاء الرمز داخلها. لقطات الأعلى تحاكي قناع المشغّل، وليست صورًا من جهاز أندرويد.<br>ملفات منفصلة: المقدّمة، الخلفية، والطبقة الأحادية. الألوان الأحادية التوضيحية يحددها المشغّل.</p></div></html>'''
(D/'adaptive-icon-preview.html').write_text(html)

# Refresh the full component sheet rather than showing an old candidate.
p=D/'theme-preview.html';s=p.read_text()
s=re.sub(r'<img data-asset-src="[^"]+" src="[^"]+"([^>]*)>',lambda m:img('assets/brand/approved-a/launcher-rounded.svg' if ('mini' in m.group(1) or 'brand-icon' in m.group(1)) else 'assets/brand/approved-a/lockup.svg',attrs=m.group(1)),s)
s=s.replace('الشعار الرئيسي · البديل A للعرض فقط، لم يُعتمد','الشعار المعتمد A · مراجعة العرض النهائي قبل الخطوة 2').replace('أيقونة A المقترحة','أيقونة A المعتمدة').replace('بوابة المولدات — البديل A غير معتمد','بوابة المولدات — الشعار المعتمد')
s=s.replace('#F4F6F3',warm).replace('Light','').replace('Dark','').replace('VISUAL IDENTITY / 01','مراجعة الهوية / 04').replace('مقترح للمراجعة · لم يُطبّق على التطبيق','مراجعة نهائية · لم يُطبّق على التطبيق')
# Replace the two status panels with actual semantic on/off examples.
newcss='''.status{border:1px solid var(--border);border-right-width:1px;background:#E9F3ED;color:#246B4C}.status p,.status .eyebrow{color:inherit!important}.status .power{color:inherit;border:0}.status.off{background:#EDF1EF;color:#53696D;margin-top:12px}.dark .status{background:#234338;color:#A0D9B8}.dark .status.off{background:#263D40;color:#B3C5C3}.status h2{font-size:20px}.brand-proof img{height:auto}.brand-proof .brand-icon{height:108px}'''
if 'FINAL-STATUS-REVIEW' not in s:
    s=s.replace('</style>','/* FINAL-STATUS-REVIEW */'+newcss+'</style>')
    s=s.replace('<div class="row"><div><h3>فاتورة نوفمبر</h3>', '<div class="status off"><div><div class="eyebrow">حالة التشغيل · مثال بديل</div><h2>المولد متوقف</h2><p>متوقف · رمز الإيقاف مع النص</p></div><div class="power">⏻</div></div><div class="row"><div><h3>فاتورة نوفمبر</h3>')
    s=s.replace('<section class="palette"><div class="panel-head"','<section class="palette"><div class="panel-head"',1)
# Old image attributes can have duplicate widths; browsers use the first value.
# Fix header/brand lockup sizes deliberately, leaving icon sizes independent.
s=re.sub(r'(data-asset-src="assets/brand/approved-a/lockup.svg"[^>]*?) width="108" height="108"',r'\1',s)
p.write_text(s)
print('Approved artwork, separate adaptive layers, monochrome and final full preview generated.')
