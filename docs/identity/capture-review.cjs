// UI artifact verification. Requires Playwright and Chromium, not app packages.
// Serve the repository on loopback, then: node docs/identity/capture-review.cjs
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const out = __dirname;
const base = process.env.BRAND_REVIEW_ORIGIN || 'http://127.0.0.1:8765';
(async () => {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/chromium', headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
    env: { ...process.env, XDG_CACHE_HOME: '/tmp/portal-pw-cache', XDG_CONFIG_HOME: '/tmp/portal-pw-config' },
  });
  const evidence = {};
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1600 }, deviceScaleFactor: 1 });
    for (const name of ['logo-alternatives', 'theme-preview']) {
      await page.goto(`${base}/docs/identity/${name}.html`, { waitUntil: 'networkidle' });
      await page.evaluate(() => document.fonts.ready);
      const images = await page.locator('img').evaluateAll(xs => xs.map(x => ({
        alt: x.alt, loaded: x.complete && x.naturalWidth > 0,
        width: x.getBoundingClientRect().width, height: x.getBoundingClientRect().height,
      })));
      if (images.some(x => !x.loaded)) throw Error('Broken image in ' + name);
      evidence[name] = { images, fontLoaded: await page.evaluate(() => document.fonts.check('16px Portal')) };
      if (!evidence[name].fontLoaded) throw Error('Missing bundled font');
      await page.screenshot({ path: path.join(out, `${name}.png`), fullPage: true });
      if (name === 'logo-alternatives') {
        for (const size of [24, 48]) {
          if (images.filter(x => x.width === size && x.height === size).length !== 9)
            throw Error('Incorrect native-size samples');
        }
      } else {
        await page.locator('.brand-proof').screenshot({ path: path.join(out, 'logo-and-icon.png') });
        evidence.codesLTR = await page.locator('code').evaluateAll(xs => xs.every(x => getComputedStyle(x).direction === 'ltr'));
        if (!evidence.codesLTR) throw Error('Non-LTR colour code');
        evidence.chartBars = await page.locator('.bar').evaluateAll(xs => xs.map(x => ({
          fill: getComputedStyle(x).backgroundColor, opacity: getComputedStyle(x).opacity,
          value: x.querySelector('.value')?.textContent,
        })));
        if (evidence.chartBars.length !== 10 || evidence.chartBars.some(x => !x.value || x.opacity !== '1'))
          throw Error('Missing chart value or transparent bar');
        const contrast = JSON.parse(fs.readFileSync(path.join(out, 'review-contrast.json')));
        for (const [mode, index] of [['light', 0], ['dark', 5]]) {
          const expected = contrast.find(x => x.token === 'chartSecondary' && x.mode === mode);
          const rgb = expected.foreground.match(/\w\w/g).map(x => parseInt(x, 16));
          if (evidence.chartBars[index].fill !== `rgb(${rgb.join(', ')})` || expected.ratio < 3)
            throw Error('Chart contrast evidence does not match effective fill');
        }
      }
    }
    fs.writeFileSync(path.join(out, 'review-browser-checks.json'), JSON.stringify(evidence, null, 2) + '\n');
    console.log('40 images loaded; nine actual 24px and nine 48px samples; fonts, LTR codes, ten chart values/opaque fills verified.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
