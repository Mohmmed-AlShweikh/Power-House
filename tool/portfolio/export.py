"""Render the static portfolio locally with Chromium; no hosting or network needed.
Requires Playwright and local Chromium (presentation tooling only, no app dependency).
"""
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
import threading, json, zipfile
from playwright.sync_api import sync_playwright

ROOT=Path(__file__).resolve().parents[2]
PORTFOLIO=ROOT/'docs/portfolio'
OUT=PORTFOLIO/'exports'
class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args): pass

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    server=ThreadingHTTPServer(('127.0.0.1',0),partial(QuietHandler,directory=str(ROOT)))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    base=f'http://127.0.0.1:{server.server_port}/docs/portfolio/'
    result={'externalRequests':[], 'brokenResources':[], 'checks':[]}
    try:
        with sync_playwright() as p:
            browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage'])
            page=browser.new_page(viewport={'width':1200,'height':1500},device_scale_factor=1)
            page.on('request',lambda r:result['externalRequests'].append(r.url) if not r.url.startswith(('http://127.0.0.1:', 'data:')) else None)
            page.on('response',lambda r:result['brokenResources'].append(r.url) if r.status>=400 else None)
            def ready(url):
                page.goto(url,wait_until='networkidle')
                page.evaluate('document.fonts.ready')
                page.evaluate("Promise.all([...document.images].map(i=>i.decode().catch(()=>null)))")
            ready(base+'slides.html')
            slides=page.locator('.slide')
            for i in range(slides.count()):
                slides.nth(i).screenshot(path=str(OUT/f'slide-{i+1:02d}.png'))
            page.pdf(path=str(OUT/'Generator-Portal-Case-Study.pdf'),prefer_css_page_size=True,print_background=True)
            result['checks'].append('6 slide PNGs + matching PDF rendered')
            ready(base+'slides.html?cover')
            page.set_viewport_size({'width':1600,'height':1200})
            page.locator('.cover-slide').screenshot(path=str(OUT/'portfolio-cover.png'))
            page.evaluate("""() => {
                const copy=document.querySelector('.cover-copy');copy.style.direction='ltr';copy.style.textAlign='left';
                copy.querySelector('h1').innerHTML='Community power.<br><em>Clearly connected.</em>';copy.querySelector('h1').style.fontSize='64px';
                copy.querySelector('p').innerHTML='Arabic-first generator management.<br>Meter readings, billing and payments.';
                copy.querySelector('.tags').style.justifyContent='flex-start';
                document.querySelector('footer span:nth-child(2)').textContent='Fictional demo data · Actual Flutter UI';
            }""")
            page.locator('.cover-slide').screenshot(path=str(OUT/'portfolio-cover-en.png'))
            ready(base+'index.html')
            page.set_viewport_size({'width':1440,'height':1000})
            page.screenshot(path=str(OUT/'website-preview.png'),full_page=True)
            for width in [1440,768,390,320]:
                page.set_viewport_size({'width':width,'height':1000})
                assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), f'horizontal overflow at {width}'
                result['checks'].append(f'responsive layout: {width}px no horizontal overflow')
            page.get_by_role('button',name='داكن',exact=True).click()
            assert page.locator('[data-shot=owner] img').get_attribute('src').endswith('_dark.png')
            page.locator('[data-shot=owner]').click()
            assert page.locator('dialog').evaluate('(d)=>d.open')
            page.get_by_role('button',name='إغلاق',exact=True).click()
            assert not page.locator('dialog').evaluate('(d)=>d.open')
            result['checks'].append('light/dark gallery switch + full-size preview open/close')
            assert not result['externalRequests'],result['externalRequests']
            assert not result['brokenResources'],result['brokenResources']
            browser.close()
    finally:
        server.shutdown()
    (PORTFOLIO/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    (ROOT/'web/portfolio.html').write_text((PORTFOLIO/'index.html').read_text().replace('<head>','<head><base href="/portfolio-assets/">',1).replace('href="#','href="/portfolio#'))
    archive=OUT/'Generator-Portal-Portfolio.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as bundle:
        for path in sorted(PORTFOLIO.rglob('*')):
            if path.is_file() and path.suffix!='.zip':
                bundle.write(path, path.relative_to(PORTFOLIO))
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
    print(json.dumps(result,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
