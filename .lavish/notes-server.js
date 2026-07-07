// Dependency-free save-server for the lavish reviewer-notepad's private notes.
// lavish serves each artifact in a sandboxed iframe (no allow-same-origin), so the
// browser blocks localStorage. This gives the notepad a real place to persist notes:
// a JSON file on disk. CORS-open so the opaque-origin iframe (Origin: null) can reach it.
//
// Notes are keyed by document (the notepad sends ?doc=<document.title>), so every review
// doc gets its own bucket inside ONE store file. Previously this wrote a single flat array,
// so opening a second doc clobbered the first doc's notes.
const http = require('http');
const fs = require('fs');
const path = require('path');

const FILE = path.join(__dirname, 'lavish-notes.json'); // { "<doc title>": [ ...notes ] }
const PORT = 4599;

function readStore() {
  try {
    const obj = JSON.parse(fs.readFileSync(FILE, 'utf8'));
    return obj && typeof obj === 'object' && !Array.isArray(obj) ? obj : {};
  } catch (e) { return {}; }
}
function writeStore(store) { fs.writeFileSync(FILE, JSON.stringify(store)); }

// Pull the doc key out of the querystring. The notepad sends encodeURIComponent(title),
// so %20 -> space and %E2%80%94 -> em dash; URLSearchParams decodes both, giving a key
// that exactly equals document.title.
function docKey(reqUrl) {
  const q = reqUrl.split('?')[1] || '';
  return (new URLSearchParams(q).get('doc') || 'default').trim() || 'default';
}

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

  if (req.url.split('?')[0] === '/notes') {
    const doc = docKey(req.url);
    if (req.method === 'GET') {
      const notes = readStore()[doc];
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(Array.isArray(notes) ? notes : [])); // notepad expects a bare array
      return;
    }
    if (req.method === 'POST') {
      let body = '';
      req.on('data', (c) => { body += c; if (body.length > 5e6) req.destroy(); });
      req.on('end', () => {
        try {
          const notes = JSON.parse(body); // notepad posts the notes array for this doc
          if (!Array.isArray(notes)) throw new Error('expected array');
          const store = readStore();
          store[doc] = notes;
          writeStore(store);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end('{"ok":true}');
        } catch (e) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end('{"ok":false}');
        }
      });
      return;
    }
  }
  res.writeHead(404); res.end();
});

server.listen(PORT, '127.0.0.1', () => console.log('[notes-server] listening on http://127.0.0.1:' + PORT + '  store: ' + FILE));
