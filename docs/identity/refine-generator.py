"""Step 1 / A revision only. Does not install icons or touch app code."""
from pathlib import Path
import xml.etree.ElementTree as E
import base64
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/brand/a-refined'
OUT.mkdir(exist_ok=True)
NS='http://www.w3.org/2000/svg'
E.register_namespace('',NS)
original=E.parse(ROOT/'assets/brand/lockup-primary.svg').getroot()
wordmark=''.join(E.tostring(x,encoding='unicode') for x in list(original)[-2:])

def mark(ink,accent):
    return f'''<defs>
    <mask id="houses"><rect width="96" height="96" fill="white"/><path d="M20 32H28V40H20Z M60 32H68V40H60Z" fill="black"/></mask>
    <mask id="engine"><rect width="96" height="96" fill="white"/>
    <path d="M36 56H48L40 64H52L36 80H24L32 68H20Z" fill="black"/>
    <path d="M64 56H80V64H64Z M64 72H80V80H64Z" fill="black"/></mask></defs>
    <path fill="{ink}" mask="url(#houses)" d="M8 30L24 14L40 30H32V40H16V30Z M48 20L64 4L80 20H72V40H56V20Z"/>
    <g fill="{accent}" mask="url(#engine)"><path d="M80 48V24H96V32H88V56Z"/>
    <rect x="8" y="48" width="80" height="40" rx="8"/>
    <path d="M16 84H32V96H16Z M64 84H80V96H64Z"/></g>'''

def svg(body,w=96,h=96):
    return f'<svg xmlns="{NS}" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" aria-labelledby="title"><title id="title">بوابة المولدات — تطوير البديل A</title>{body}</svg>\n'
for variant,ink,accent in [('primary','#173E43','#14756B'),('black','#000000','#000000'),('white','#FFFFFF','#FFFFFF'),('reversed','#F3F7F4','#8AD8C7')]:
    (OUT/f'mark-{variant}.svg').write_text(svg(mark(ink,accent)))
(OUT/'lockup.svg').write_text(svg('<g transform="translate(450 22)">'+mark('#173E43','#14756B')+'</g>'+wordmark,566,138))
(OUT/'icon.svg').write_text(svg('<rect width="108" height="108" fill="#F4F6F3"/><g transform="translate(12 12) scale(.875)">'+mark('#173E43','#14756B')+'</g>',108,108))
assert [E.tostring(x) for x in list(E.parse(OUT/'lockup.svg').getroot())[-2:]]==[E.tostring(x) for x in list(original)[-2:]]

def img(file,size,extra=''):
    raw=(OUT/file).read_bytes()
    return f'<img src="data:image/svg+xml;base64,{base64.b64encode(raw).decode()}" width="{size}" height="{size}" alt="{file}" {extra}>'
panels=''
for v,label,cls in [('primary','لون الهوية',''),('black','أسود أحادي',''),('white','أبيض أحادي',' inverse')]:
    samples=''.join(f'<figure>{img("mark-"+v+".svg",size)}<figcaption dir="ltr">{size}px</figcaption></figure>' for size in [192,48,24])
    panels+=f'<section class="panel{cls}"><h2>{label}</h2><div class="samples">{samples}</div></section>'
font=''.join(f"@font-face{{font-family:Portal;src:url('../../assets/fonts/NotoSansArabic-{n}.ttf');font-weight:{w}}}" for w,n in [(400,'Regular'),(600,'SemiBold'),(700,'Bold')])
lockup=img('lockup.svg',566,'style="height:138px"')
html=f'''<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><title>تطوير البديل A</title><style>{font}
*{{box-sizing:border-box}}body{{width:1440px;margin:0;padding:48px;background:#F4F6F3;color:#173E43;font:16px/1.8 Portal,sans-serif}}h1,h2,p,figure{{margin:0}}h1{{font-size:32px}}h2{{font-size:20px}}header{{border-bottom:1px solid #CCD8D4;padding-bottom:24px;display:flex;justify-content:space-between;align-items:center}}header p{{font-size:13px;color:#53696D}}.status{{font-size:13px;color:#53696D;text-align:left}}.explain{{display:flex;gap:48px;margin:28px 0}}.explain p{{flex:1;color:#53696D;font-size:14px}}.explain b{{color:#173E43}}.brand-proof{{background:white;border:1px solid #CCD8D4;border-radius:20px;display:flex;align-items:center;justify-content:space-between;padding:32px 48px;margin-bottom:28px}}.brand-proof p{{color:#53696D;font-size:13px;margin-top:16px}}.brand-proof img{{object-fit:contain}}.icon img{{width:144px;height:144px;border:1px solid #CCD8D4;border-radius:28px}}.columns{{display:grid;grid-template-columns:repeat(3,1fr);gap:24px}}.panel{{background:white;border:1px solid #CCD8D4;border-radius:20px;padding:24px}}.samples{{height:340px;display:flex;align-items:end;justify-content:space-between;gap:12px;padding-bottom:8px}}figure{{display:flex;flex-direction:column;align-items:center;gap:24px}}figcaption{{font-size:13px;color:#53696D}}.inverse{{background:#000;color:white;border-color:#000}}.inverse figcaption{{color:white}}footer{{background:white;border:1px solid #CCD8D4;border-radius:16px;padding:20px 28px;margin-top:28px;font-size:13px;color:#53696D}}code{{direction:ltr;unicode-bidi:isolate;display:inline-block}}
</style><header><div><h1>المولد أولًا — تطوير A</h1><p>بيتان مختلفان · عادم جانبي · فتحات تهوية · كتل ممتلئة دون تدرجات</p></div><div class="status">مراجعة الرمز / 03<br>بانتظار الموافقة قبل الخطوة 2</div></header>
<div class="explain"><p><b>بيوت واضحة:</b> بيت منخفض وآخر أعلى، بأسقف مثلثة بارزة وأبواب مفرّغة. فراغ يفصل البيوت عن جسم المولد، بدل صف أسنان أو تاج.</p><p><b>مولد لا بطارية:</b> عادم جانبي بشكل زاوية، وفتحتا تهوية عريضتان على الجسم، مع الإبقاء على رمز الكهرباء والقواعد السفلية.</p></div>
<section class="brand-proof"><div>{lockup}<p>الكلمة العربية والإنجليزية محفوظتان دون تغيير</p></div><div class="icon">{img('icon.svg',144)}<p>أيقونة التطبيق المقترحة</p></div></section>
<main class="columns">{panels}</main><footer>السماكات الأساسية والعادم والفتحات: <code>8/96</code> ← <code>4px @ 48px</code> و<code>2px @ 24px</code>؛ رؤوس الأسقف والأركان القطرية تتدرج طبيعيًا.<br>الأحجام معروضة فعليًا عند تكبير الصورة إلى 100%. هذه مراجعة للشعار فقط؛ واجهات التطبيق والأيقونات المثبتة لم تتغير.</footer></html>'''
(ROOT/'docs/identity/a-refined.html').write_text(html)
print('Six SVGs generated; original wordmark paths and transforms unchanged.')
