"""Step 1 review only: new symbols, preserving the existing outlined wordmark."""
from pathlib import Path
from copy import deepcopy
from html import escape
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/brand/alternatives'
OUT.mkdir(exist_ok=True)
NS = 'http://www.w3.org/2000/svg'
ET.register_namespace('', NS)
original = ET.parse(ROOT / 'assets/brand/lockup-primary.svg').getroot()
wordmark = ''.join(ET.tostring(c, encoding='unicode') for c in list(original)[-2:])

def mark(name, ink, accent):
    if name == 'a-generator':
        # Three compact houses behind an unmistakable filled generator body.
        houses = 'M8 36V24L18 14L28 24V36Z M36 36V16L48 4L60 16V36Z M68 36V24L78 14L88 24V36Z'
        return f'''<defs><mask id="cut"><rect width="96" height="96" fill="white"/>
        <path d="M48 44H60L52 56H64L48 76H36L44 60H32Z" fill="black"/>
        <rect x="16" y="48" width="8" height="8" fill="black"/>
        <rect x="72" y="48" width="8" height="8" fill="black"/>
        </mask></defs><path d="{houses}" fill="{ink}"/>
        <g fill="{accent}" mask="url(#cut)"><rect x="8" y="36" width="80" height="48" rx="8"/>
        <rect x="16" y="80" width="16" height="12" rx="2"/><rect x="64" y="80" width="16" height="12" rx="2"/></g>'''
    if name == 'b-power':
        # Dominant circular power source, solid mass with a broad knockout.
        return f'''<defs><mask id="cut"><rect width="96" height="96" fill="white"/>
        <path d="M34 44A20 20 0 1 0 62 44" fill="none" stroke="black" stroke-width="8" stroke-linecap="butt"/>
        <rect x="44" y="30" width="8" height="24" fill="black"/>
        </mask></defs><path d="M8 40V24L18 14L28 24V40Z M36 32V16L48 4L60 16V32Z M68 40V24L78 14L88 24V40Z" fill="{ink}"/>
        <circle cx="48" cy="56" r="36" fill="{accent}" mask="url(#cut)"/>'''
    # Plug silhouette: the actual supply connection stands in front of homes.
    return f'''<defs><mask id="cut"><rect width="96" height="96" fill="white"/>
    <path d="M44 44H56L48 56H60L44 72H36L44 60H32Z" fill="black"/>
    </mask></defs><path d="M4 72V40L16 28L28 40V72Z M68 72V40L80 28L92 40V72Z" fill="{ink}"/>
    <g fill="{accent}" mask="url(#cut)"><rect x="24" y="36" width="48" height="44" rx="8"/>
    <rect x="32" y="12" width="8" height="28" rx="2"/><rect x="56" y="12" width="8" height="28" rx="2"/>
    <rect x="40" y="76" width="16" height="16" rx="2"/></g>'''

def svg(body, width=96, height=96, title='بوابة المولدات — مقترح رمز'):
    return f'<svg xmlns="{NS}" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title"><title id="title">{escape(title)}</title>{body}</svg>\n'

for name in ['a-generator','b-power','c-plug']:
    for variant,ink,accent in [('primary','#173E43','#14756B'),('black','#000000','#000000'),('white','#FFFFFF','#FFFFFF')]:
        body=mark(name,ink,accent)
        (OUT/f'{name}-{variant}.svg').write_text(svg(body,title=name+' '+variant))
    body=mark(name,'#173E43','#14756B')
    (OUT/f'{name}-lockup.svg').write_text(svg(f'<g transform="translate(450 22)">{body}</g>'+wordmark,566,138,'بوابة المولدات | Generator Portal — '+name))
    (OUT/f'{name}-icon.svg').write_text(svg('<rect width="108" height="108" fill="#F4F6F3"/><g transform="translate(14 14) scale(.833333)">'+body+'</g>',108,108,name+' — أيقونة مقترحة'))

# Confirm wordmark geometry/transforms are unchanged for every candidate.
for p in OUT.glob('*-lockup.svg'):
    elements=list(ET.parse(p).getroot())[-2:]
    assert [ET.tostring(e) for e in elements]==[ET.tostring(e) for e in list(original)[-2:]]
print('15 SVG proposals generated; original wordmark paths/transforms preserved exactly.')
