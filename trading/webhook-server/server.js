const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8721;
const TOKEN = 'destroyer-sig-2026';
const DATA_DIR = path.join(__dirname, 'data');

if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

const server = http.createServer((req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type,X-Signal-Token');
    res.setHeader('Content-Type', 'application/json');

    if (req.method === 'OPTIONS') {
        res.writeHead(204); res.end(); return;
    }

    const url = new URL(req.url, `http://localhost:${PORT}`);

    // GET /health
    if (url.pathname === '/health') {
        const count = fs.readdirSync(DATA_DIR).filter(f => f.endsWith('.json')).length;
        respond(res, 200, { ok: true, count, ts: Date.now() / 1000 });
        return;
    }

    // GET /signal/latest
    if (url.pathname === '/signal/latest') {
        const latest = path.join(DATA_DIR, 'latest.json');
        if (fs.existsSync(latest)) {
            respond(res, 200, JSON.parse(fs.readFileSync(latest, 'utf8')));
        } else {
            respond(res, 404, { error: 'no signals yet' });
        }
        return;
    }

    // GET /push?data=JSON&token=xxx
    if (url.pathname === '/push' && url.search.startsWith('?')) {
        const params = new URLSearchParams(url.search.slice(1));
        try {
            const raw = params.get('data');
            if (!raw) { respond(res, 400, { error: 'no data' }); return; }
            const data = JSON.parse(decodeURIComponent(raw));
            if (!data.t && params.get('token')) data.t = params.get('token');
            if (data.t === TOKEN) {
                data._received = new Date().toISOString();
                const sid = data.signal_id || `sig-${Math.floor(Date.now()/1000)}`;
                data.signal_id = sid;
                const files = [path.join(DATA_DIR, `${sid}.json`), path.join(DATA_DIR, 'latest.json')];
                const json = JSON.stringify(data, null, 2);
                files.forEach(f => fs.writeFileSync(f, json));
                respond(res, 200, { ok: true, signal_id: sid, symbol: data.symbol });
            } else {
                respond(res, 401, { error: 'bad token' });
            }
        } catch (e) {
            respond(res, 400, { error: e.message });
        }
        return;
    }

    // POST /signal or /push
    if (req.method === 'POST' && (url.pathname === '/signal' || url.pathname === '/push') || (req.method === 'POST' && req.url.startsWith('/signal') || req.url.startsWith('/push'))) {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                const data = JSON.parse(body);
                const tok = req.headers['x-signal-token'] || data.t || data.token;
                if (tok === TOKEN) {
                    data._received = new Date().toISOString();
                    const sid = data.signal_id || `sig-${Math.floor(Date.now()/1000)}`;
                    data.signal_id = sid;
                    const files = [path.join(DATA_DIR, `${sid}.json`), path.join(DATA_DIR, 'latest.json')];
                    const json = JSON.stringify(data, null, 2);
                    files.forEach(f => fs.writeFileSync(f, json));
                    respond(res, 200, { ok: true, signal_id: sid, symbol: data.symbol });
                } else {
                    respond(res, 401, { error: 'unauthorized' });
                }
            } catch (e) {
                respond(res, 400, { error: 'bad JSON: ' + e.message });
            }
        });
        return;
    }

    respond(res, 404, { error: 'not found', paths: ['/health', '/signal/latest', '/signal (POST)', '/push (POST or GET with ?data=)'] });
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`[DESTROYER HTTP] port ${PORT} running`);
    console.log(`  POST /signal  — send signal data`);
    console.log(`  GET  /push?data=...&token=... — send via URL`);
    console.log(`  GET  /health  — health check`);
});

function respond(res, code, obj) {
    res.writeHead(code);
    res.end(JSON.stringify(obj));
}
