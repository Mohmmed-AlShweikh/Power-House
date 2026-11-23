"""Package a standalone offline preview and static source bundle, unchanged images."""
from pathlib import Path
from base64 import b64encode
import json,re,mimetypes,zipfile
ROOT=Path(__file__).resolve().parents[1]
SITE=ROOT/'web/landing'
OUT=Path('/workspace/artifacts')
OUT.mkdir(parents=True,exist_ok=True)
def data_uri(name):
    path=SITE/name
    mime=mimetypes.guess_type(str(path))[0] or 'application/octet-stream'
    return 'data:'+mime+';base64,'+b64encode(path.read_bytes()).decode('ascii')
html=(SITE/'index.html').read_text()
css=(SITE/'style.css').read_text()
css=re.sub(r"url\('([^']+)'\)",lambda m:"url('"+data_uri(m[1])+"')",css)
html=html.replace('<link rel="stylesheet" href="style.css">','<style>'+css+'</style>')
html=re.sub(r'  <link rel="preload"[^>]+>\n','',html)
html=html.replace('<script src="config.js" defer></script>','<script>'+(SITE/'config.js').read_text()+'</script>')
html=html.replace('  <script src="app.js" defer></script>','')
html=re.sub(r'(src|href)="(assets/[^"]+)"',lambda m:m[1]+'="'+data_uri(m[2])+'"',html)
screens={f'{role}_{theme}':data_uri(f'assets/{role}_{theme}.png') for role in ['owner','consumer','reader','superadmin'] for theme in ['light','dark']}
js=(SITE/'app.js').read_text().replace('screen.src = `assets/${role}_${theme}.png`;','screen.src = window.PORTAL_PREVIEW_SCREENS[role + "_" + theme];')
html=html.replace('</body>','<script>window.PORTAL_PREVIEW_SCREENS='+json.dumps(screens)+';\n'+js+'</script></body>')
preview=OUT/'Generator-Portal-Landing.html'
preview.write_text(html)
with zipfile.ZipFile(OUT/'Generator-Portal-Landing.zip','w',zipfile.ZIP_DEFLATED) as archive:
    archive.write(preview,preview.name)
    archive.write(ROOT/'docs/landing/README.md','README.md')
    for file in sorted(SITE.rglob('*')):
        if file.is_file():archive.write(file,'site/'+str(file.relative_to(SITE)))
print(str(preview))
print(str(OUT/'Generator-Portal-Landing.zip'))
