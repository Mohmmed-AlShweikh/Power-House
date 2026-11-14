"""Generate self-contained image previews and update the Step 1 theme sheet."""
from pathlib import Path
import base64, json, re
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/identity'

def image(path, **attrs):
    raw=(ROOT/path).read_bytes()
    mime='image/svg+xml' if path.endswith('.svg') else 'image/png'
    extra=' '.join(f'{k}="{v}"' for k,v in attrs.items())
    return f'<img data-asset-src="{path}" src="data:{mime};base64,{base64.b64encode(raw).decode()}" {extra}>'

fontcss=''
for weight,name in [(400,'Regular'),(600,'SemiBold'),(700,'Bold')]:
    fontcss+=f"@font-face{{font-family:Portal;src:url('../../assets/fonts/NotoSansArabic-{name}.ttf');font-weight:{weight}}}"

cards=[]
items=[('a-generator','A','المولد أولًا','كتلة مولد كهربائي ممتلئة تتصدر الرمز، وصاعقة مفرّغة تؤكد الطاقة.','ثلاثة بيوت خلفه تظهر المستفيدين دون أن تنافس مصدر التغذية.'),
('b-power','B','قلب التشغيل','قرص طاقة كبير بعلامة تشغيل سميكة يصبح مركز العلامة.','كتل الحي خلفه ثانوية؛ الشكل الدائري يختلف جذريًا عن جسم المولد.'),
('c-plug','C','وصلة الكهرباء','قابس كهربائي ممتلئ يتقدم بيتين كتليين، فيربط الخدمة بالكهرباء مباشرة.','الشكل الرأسي بسنّين واضحين يجعل الاتصال هو البطل بدل أسقف البيوت.')]
for name,letter,title,line1,line2 in items:
    samples=''
    for variant,label,background in [('primary','لون الهوية',''),('black','أسود أحادي',''),('white','أبيض أحادي',' inverse')]:
        samples+=f'<div class="sample{background}"><span>{label}</span><div class="sizes">'
        for size in [96,48,24]:
            samples+=f'<figure>{image("assets/brand/alternatives/"+name+"-"+variant+".svg",width=size,height=size,alt=title)}<figcaption dir="ltr">{size}px</figcaption></figure>'
        samples+='</div></div>'
    cards.append(f'''<article><div class="card-title"><b>{letter}</b><h2>{title}</h2></div>
    <div class="hero">{image('assets/brand/alternatives/'+name+'-primary.svg',width=192,height=192,alt=title)}</div>
    <div class="reason"><p>{line1}</p><p>{line2}</p></div>
    <div class="lockup">{image('assets/brand/alternatives/'+name+'-lockup.svg',width=366,height=90,alt='بوابة المولدات Generator Portal')}</div>
    {samples}<div class="icon-row"><span>أيقونة تطبيق مقترحة</span>{image('assets/brand/alternatives/'+name+'-icon.svg',width=72,height=72,alt='أيقونة '+letter)}</div></article>''')
html=f'''<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><title>بدائل رمز بوابة المولدات</title><style>{fontcss}
*{{box-sizing:border-box}}body{{width:1440px;margin:0;padding:40px 48px;background:#F4F6F3;color:#173E43;font:14px/1.8 Portal,sans-serif}}h1,h2,p,figure{{margin:0}}h1{{font-size:30px}}h2{{font-size:21px}}header{{display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid #CCD8D4;padding-bottom:24px}}header p{{color:#53696D}}.stamp{{font-size:12px;text-align:left}}main{{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;margin-top:28px}}article{{background:#FFFFFF;border:1px solid #CCD8D4;border-radius:20px;padding:22px;min-width:0}}.card-title{{display:flex;align-items:center;gap:12px}}.card-title b{{background:#173E43;color:white;display:grid;place-items:center;width:36px;height:36px;border-radius:8px;font-size:20px}}.hero{{display:grid;place-items:center;height:230px}}.reason{{font-size:13px;min-height:132px;color:#53696D}}.lockup{{border-top:1px solid #CCD8D4;border-bottom:1px solid #CCD8D4;display:grid;place-items:center;padding:18px 0;margin-bottom:18px}}.lockup img{{max-width:100%;object-fit:contain}}.sample{{padding:12px 14px;border:1px solid #CCD8D4;border-radius:12px;margin-top:12px}}.sample>span{{font-size:12px;color:#53696D}}.sizes{{display:flex;justify-content:space-between;align-items:end;height:140px}}figure{{display:flex;flex-direction:column;align-items:center;justify-content:end;gap:12px;width:100px}}figcaption{{font-size:12px;color:#53696D}}.inverse{{background:#000000;border-color:#000000}}.inverse>span,.inverse figcaption{{color:#F3F7F4}}.icon-row{{display:flex;justify-content:space-between;align-items:center;padding-top:20px;font-size:12px;color:#53696D}}.icon-row img{{border-radius:16px;border:1px solid #CCD8D4}}footer{{background:#FFFFFF;border:1px solid #CCD8D4;border-radius:12px;margin-top:24px;padding:16px 24px;color:#53696D;font-size:13px}}code{{direction:ltr;unicode-bidi:isolate;display:inline-block}}img{{flex-shrink:0}}
</style><header><div><h1>مصدر الطاقة هو البطل</h1><p>ثلاثة بدائل هندسية مختلفة · الكلمة العربية والإنجليزية دون تغيير</p></div><div class="stamp">LOGO REVIEW / 02<br>مقترحات فقط · لا تطبيق قبل الاختيار</div></header><main>{''.join(cards)}</main><footer>السماكة البنيوية والفراغات الأساسية: <code>8/96</code> على الأقل ← <code>4px @ 48px</code> و<code>2px @ 24px</code>.<br>الحجوم الصغيرة معروضة بأبعادها الفعلية في هذه اللوحة عند تكبير الصورة إلى 100%؛ الزوايا والمنحنيات تتدرج طبيعيًا. بلا خطوط رفيعة أو تفاصيل شبابيك.</footer></html>'''
(DOC/'logo-alternatives.html').write_text(html)

def luminance(h):
    c=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return sum(k*(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4) for k,v in zip([.2126,.7152,.0722],c))
def ratio(a,b):
    x,y=sorted([luminance(a),luminance(b)]); return round((y+.05)/(x+.05),2)

roles=[('success','النجاح','#246B4C','#E9F3ED','#A0D9B8','#234338'),('danger','الخطر','#AA3F36','#FBEDEA','#FFB8AD','#4C302F'),('warning','التحذير','#8C581B','#FFF2DC','#F1CC8A','#493B26'),('generatorOn','المولد يعمل','#246B4C','#E9F3ED','#A0D9B8','#234338'),('generatorOff','المولد متوقف','#53696D','#EDF1EF','#B3C5C3','#263D40')]
rows=''; evidence=[]
for key,label,fg,bg,dfg,dbg in roles:
    cells=''
    for mode,a,b in [('light',fg,bg),('dark',dfg,dbg)]:
        r=ratio(a,b); assert r>=4.5
        evidence.append(dict(token=key,mode=mode,foreground=a,background=b,ratio=r,kind='text'))
        cells+=f'<td><span class="semantic-chip" style="color:{a};background:{b}">{label}</span><br><code>{a}</code> / <code>{b}</code><br><b dir="ltr">{r:.2f}:1</b></td>'
    rows+=f'<tr><th>{label}</th>{cells}</tr>'
table=f'''<section class="palette"><h3>الألوان الدلالية وحالات المولد</h3><p class="table-note">التباين محسوب للنص على خلفيته المحددة؛ كل زوج ≥ 4.5:1. القيم: نص / خلفية.</p><table><thead><tr><th>الدور</th><th>الوضع الفاتح</th><th>الوضع الداكن</th></tr></thead><tbody>{rows}</tbody></table></section>'''
css='''
code{direction:ltr;unicode-bidi:isolate;display:inline-block}.swatch code{direction:ltr;unicode-bidi:isolate}
.brand-proof{display:flex;align-items:center;justify-content:space-between;gap:32px;background:#FFFFFF;border:1px solid #CCD8D4;border-radius:16px;padding:24px;margin-bottom:28px}.brand-proof img{object-fit:contain}.brand-proof p{color:#53696D;font-size:12px}.brand-proof .brand-icon{width:108px;height:108px;border-radius:20px;border:1px solid #CCD8D4}
table{width:100%;border-collapse:collapse;margin-top:16px;font-size:13px}td,th{border-top:1px solid #CCD8D4;padding:12px 20px;text-align:right}thead th{color:#53696D}.semantic-chip{display:inline-block;padding:4px 12px;border-radius:8px;font-weight:600;margin-bottom:6px}.table-note{font-size:12px;color:#53696D}
.plot{display:flex;direction:ltr;margin-top:24px;gap:8px}.y-axis{height:150px;display:flex;flex-direction:column;justify-content:space-between;font-size:12px;color:var(--muted);width:32px;text-align:right}.bars{flex:1;height:150px;position:relative;padding:0 8px;border-left:1px solid var(--muted);border-bottom:1px solid var(--muted);background:repeating-linear-gradient(to top,transparent 0,transparent 49px,var(--border) 49px,var(--border) 50px)}.bar{position:relative;background:#14756B;width:28px}.bar.faint{opacity:1;background:#598D85}.dark .bar{background:#8AD8C7}.dark .bar.faint{background:#6EAEA3}.bar .value{position:absolute;bottom:100%;left:50%;transform:translateX(-50%);color:var(--text);font-size:12px;font-weight:600;padding-bottom:4px}.axis{margin-left:40px}.chart .caption{font-size:12px}
'''
p=DOC/'theme-preview.html'; s=p.read_text()
if 'brand-proof' not in s:
    s=s.replace('</style>',css+'</style>')
    # A is a clearly labelled working candidate, not a selected identity.
    proof=f'''<section class="brand-proof"><div>{image('assets/brand/alternatives/a-generator-lockup.svg',width=566,height=138,alt='الشعار الرئيسي — البديل A للمقارنة فقط')}<p>الشعار الرئيسي · البديل A للعرض فقط، لم يُعتمد</p></div><div>{image('assets/brand/alternatives/a-generator-icon.svg',**{'class':'brand-icon','alt':'أيقونة البديل A'})}<p>أيقونة التطبيق</p></div></section>'''
    s=s.replace('<main class="columns">',proof+'<main class="columns">')
    s=s.replace('<footer class="footer">',table+'<footer class="footer">')
    s=s.replace('<div class="bars"><div class="bar faint" style="height:48px"></div><div class="bar faint" style="height:66px"></div><div class="bar faint" style="height:57px"></div><div class="bar faint" style="height:80px"></div><div class="bar" style="height:94px"></div></div>',
    '<div class="plot"><div class="y-axis"><span>150</span><span>100</span><span>50</span><span>0</span></div><div class="bars">'+''.join(f'<div class="bar{" faint" if i<4 else ""}" style="height:{v}px"><span class="value">{v}</span></div>' for i,v in enumerate([60,84,72,102,120]))+'</div></div>')
    s=s.replace('أعمدة مستقيمة دون تنعيم أو تغيير قيم البيانات.','قيم توضيحية · أعمدة ثانوية #598D85 على #FFFFFF: تباين 3.77:1.')
    s=s.replace('الأرقام والحالات تُعرض بالنص، وليس باللون وحده.','قيم توضيحية · أعمدة ثانوية #6EAEA3 على #13262A: تباين 6.16:1.')
    # Explicitly isolate every hex string, including chart notes.
    s=re.sub(r'(?<![>\w])#[0-9A-Fa-f]{6}(?= على|:)',lambda m:'<code>'+m.group()+'</code>',s)
    # Replace the previous small icon SVG image with its real, existing PNG source.
    s=s.replace('<img class="mini" src="../../assets/brand/icon-proposal.svg" alt="رمز التطبيق">',image('assets/brand/alternatives/a-generator-icon.svg',**{'class':'mini','alt':'أيقونة A المقترحة'}))
    # Embed header image too; no image depends on the HTML hosting path.
    s=s.replace('<img src="../../assets/brand/lockup-primary.svg" alt="بوابة المولدات — Generator Portal">',image('assets/brand/alternatives/a-generator-lockup.svg',alt='بوابة المولدات — البديل A غير معتمد'))
    p.write_text(s)
for mode,bar,bg in [('light','#598D85','#FFFFFF'),('dark','#6EAEA3','#13262A')]:
    r=ratio(bar,bg);assert r>=3
    evidence.append(dict(token='chartSecondary',mode=mode,foreground=bar,background=bg,ratio=r,kind='non-text'))
(DOC/'review-contrast.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n')
# Refresh embedded bytes on subsequent runs too, preserving labels and dimensions.
for filename in ['logo-alternatives.html','theme-preview.html']:
    page=DOC/filename
    def refresh(match):
        path=match.group(1)
        mime='image/svg+xml' if path.endswith('.svg') else 'image/png'
        encoded=base64.b64encode((ROOT/path).read_bytes()).decode()
        return f'<img data-asset-src="{path}" src="data:{mime};base64,{encoded}"{match.group(2)}>'
    page.write_text(re.sub(r'<img data-asset-src="([^"]+)" src="[^"]+"([^>]*)>',refresh,page.read_text()))
print('Self-contained logo images embedded; semantic table and chart evidence prepared.')
