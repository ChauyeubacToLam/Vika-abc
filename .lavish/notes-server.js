// Tiny dependency-free save-server for the ExerciseBase artifact's private notes.
// lavish serves the artifact in a sandboxed iframe (no allow-same-origin), so the
// browser blocks localStorage. This gives the page a real place to persist notes:
// a JSON file on disk. CORS-open so the opaque-origin iframe (Origin: null) can reach it.
const http = require('http');
const fs = require('fs');
const path = require('path');

const FILE = path.join(__dirname, 'exercise-base-notes.json');
const PORT = 4599;

function readNotes() {
  try { return fs.readFileSync(FILE, 'utf8'); } catch (e) { return '[]'; }
}

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

  if (req.url.split('?')[0] === '/notes') {
    if (req.method === 'GET') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(readNotes());
      return;
    }
    if (req.method === 'POST') {
      let body = '';
      req.on('data', (c) => { body += c; if (body.length > 5e6) req.destroy(); });
      req.on('end', () => {
        try {
          JSON.parse(body); // validate
          fs.writeFileSync(FILE, body);
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

server.listen(PORT, '127.0.0.1', () => console.log('[notes-server] listening on http://127.0.0.1:' + PORT + '  file: ' + FILE));
