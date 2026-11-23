"""Affected-only browser checks for the static landing page (local server only)."""
from pathlib import Path
from playwright.sync_api import sync_playwright
import json
import urllib.request, urllib.error
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/landing'
OUT.mkdir(parents=True,exist_ok=True)
BASE='http://127.0.0.1:5000'
report={'checks':[],'errors':[],'brokenResources':[],'externalRequests':[]}
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage'])
    page=browser.new_page(viewport={'width':1440,'height':1000},device_scale_factor=1)
    page.on('pageerror',lambda e:report['errors'].append(str(e)))
    page.on('response',lambda r:report['brokenResources'].append(r.url) if r.status>=400 else None)
    page.on('request',lambda r:report['externalRequests'].append(r.url) if not r.url.startswith((BASE,'data:')) else None)
    def ready():
        page.goto(BASE+'/',wait_until='networkidle')
        page.evaluate('document.fonts.ready')
        page.evaluate("Promise.all([...document.images].filter(i=>i.loading!=='lazy').map(i=>i.decode().catch(()=>{})))")
    ready()
    for w in [1440,1024,768,390,320]:
        page.set_viewport_size({'width':w,'height':900})
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'),f'overflow at {w}'
        report['checks'].append(f'no horizontal overflow at {w}px')
    page.set_viewport_size({'width':1440,'height':1000})
    page.screenshot(path=str(OUT/'desktop.png'),full_page=True)
    page.screenshot(path=str(OUT/'hero.png'))
    for role in ['owner','consumer','reader','superadmin']:
        page.locator(f'[data-role={role}]').click()
        assert page.locator(f'[data-role={role}]').get_attribute('aria-selected')=='true'
        assert page.locator('#role-panel').get_attribute('aria-labelledby')==f'tab-{role}'
        for theme in ['dark','light']:
            page.locator(f'[data-theme={theme}]').click()
            page.locator('#role-screen').evaluate('(i)=>i.decode()')
            assert page.locator('#role-screen').get_attribute('src')==f'assets/{role}_{theme}.png'
            assert page.locator(f'[data-theme={theme}]').get_attribute('aria-pressed')=='true'
        report['checks'].append(f'role {role}: correct selection, panel, light/dark images')
    page.locator('[data-role=owner]').click()
    page.locator('[data-role=owner]').focus()
    page.keyboard.press('ArrowLeft')
    assert page.locator('[data-role=consumer]').get_attribute('aria-selected')=='true'
    page.keyboard.press('End')
    assert page.locator('[data-role=superadmin]').get_attribute('aria-selected')=='true'
    page.keyboard.press('Home')
    assert page.locator('[data-role=owner]').get_attribute('aria-selected')=='true'
    report['checks'].append('role tabs: RTL arrow, Home and End keyboard navigation')
    page.locator('.screenshot-button').click()
    assert page.locator('dialog').evaluate('(d)=>d.open')
    page.keyboard.press('Escape')
    assert not page.locator('dialog').evaluate('(d)=>d.open')
    assert page.locator('.screenshot-button').evaluate('(b)=>b===document.activeElement')
    page.locator('.screenshot-button').click()
    page.get_by_role('button',name='إغلاق المعاينة').click()
    assert not page.locator('dialog').evaluate('(d)=>d.open')
    report['checks'].append('screenshot modal opens/closes with Escape/button and restores focus')
    for detail in page.locator('details').all():
        detail.locator('summary').click()
        assert detail.evaluate('(d)=>d.open')
        detail.locator('summary').click()
    report['checks'].append('all six FAQ answers open and close')
    assert page.locator('[data-contact]:visible').count()==0
    page.set_viewport_size({'width':390,'height':844})
    page.goto(BASE+'/',wait_until='networkidle')
    page.evaluate('document.fonts.ready')
    page.screenshot(path=str(OUT/'mobile.png'),full_page=True)
    page.get_by_role('button',name='فتح القائمة').click()
    assert page.locator('#mobile-nav').is_visible()
    page.locator('#mobile-nav').get_by_role('link',name='المزايا',exact=True).click()
    assert page.url.endswith('#features')
    assert not page.locator('#mobile-nav').is_visible()
    page.get_by_role('button',name='فتح القائمة').click()
    page.keyboard.press('Escape')
    assert not page.locator('#mobile-nav').is_visible()
    report['checks'].append('mobile menu: open, anchor navigation, close and Escape')
    page.emulate_media(reduced_motion='reduce')
    assert page.evaluate("getComputedStyle(document.documentElement).scrollBehavior")== 'auto'
    report['checks'].append('reduced-motion preference disables smooth scrolling')
    for config,expected in [({'email':'business@example.invalid'},'mailto:business@example.invalid'),({'whatsapp':'123456789'},'https://wa.me/123456789'),({'email':'<bad>','whatsapp':'javascript:alert(1)'},None)]:
        page.route('**/config.js',lambda r:r.fulfill(status=200,content_type='text/javascript',body='window.PORTAL_CONTACT='+json.dumps(config)+';'))
        page.goto(BASE+'/',wait_until='networkidle')
        if expected:
            assert page.locator('[data-contact]:visible').count()==2
            assert page.locator('[data-contact]').first.get_attribute('href').startswith(expected)
        else:assert page.locator('[data-contact]:visible').count()==0
        page.unroute('**/config.js')
    report['checks'].append('contact: absent by default, valid email/WhatsApp enabled, malformed config ignored')
    assert not report['errors'],report['errors']
    assert not report['brokenResources'],report['brokenResources']
    assert not report['externalRequests'],report['externalRequests']
    browser.close()
for path,expected in [('/landing',200),('/landing/',200),('/landing/assets/product-overview.pdf',200),('/landing/assets/missing.png',404),('/landing/%2e%2e%2fserver.js',403),('/landing/%ZZ',400)]:
    try:
        r=urllib.request.urlopen(BASE+path);status=r.status
    except urllib.error.HTTPError as e:status=e.code
    assert status==expected,(path,status)
report['checks'].append('additive /landing route, PDF, missing files and traversal/malformed path handling')
(OUT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
