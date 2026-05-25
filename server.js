const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 5000;
const WEB_DIR = path.join(__dirname, 'build', 'web');
const STATIC_DIR = path.join(__dirname, 'web');

const MIME = {
  '.html': 'text/html',
  '.js':   'application/javascript',
  '.mjs':  'application/javascript',
  '.css':  'text/css',
  '.json': 'application/json',
  '.png':  'image/png',
  '.ico':  'image/x-icon',
  '.wasm': 'application/wasm',
  '.ttf':  'font/ttf',
  '.otf':  'font/otf',
  '.svg':  'image/svg+xml',
  '.webmanifest': 'application/manifest+json',
};

http.createServer((req, res) => {
  let urlPath = req.url.split('?')[0];

  // Portfolio page
  if (urlPath === '/portfolio' || urlPath === '/portfolio.html') {
    const portfolioPath = path.join(STATIC_DIR, 'portfolio.html');
    fs.readFile(portfolioPath, (err, data) => {
      if (err) {
        res.writeHead(404); res.end('Not found'); return;
      }
      res.writeHead(200, {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
      });
      res.end(data);
    });
    return;
  }

  if (urlPath === '/') urlPath = '/index.html';

  const filePath = path.join(WEB_DIR, urlPath);
  const base = path.basename(filePath);

  const noCache = base === 'index.html' || base.startsWith('flutter_service_worker');
  const cacheHeader = noCache
    ? 'no-cache, no-store, must-revalidate'
    : 'public, max-age=31536000, immutable';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      fs.readFile(path.join(WEB_DIR, 'index.html'), (err2, data2) => {
        if (err2) { res.writeHead(404); res.end('Not found'); return; }
        res.writeHead(200, {
          'Content-Type': 'text/html',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
        });
        res.end(data2);
      });
      return;
    }
    const ext = path.extname(filePath);
    const ct = MIME[ext] || 'application/octet-stream';
    res.writeHead(200, {
      'Content-Type': ct,
      'Cache-Control': cacheHeader,
    });
    res.end(data);
  });
}).listen(PORT, '0.0.0.0', () => {
  console.log(`Serving Flutter web build at http://0.0.0.0:${PORT}`);
});
