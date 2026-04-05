#!/usr/bin/env python3
"""DESTROYER HTTPS Webhook — self-signed cert, no tunnel needed."""
import json, ssl, time, urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime, timezone
from pathlib import Path

PORT = 8723
TOKEN = "destroyer-sig-2026"
DATA = Path("/home/ubuntu/.openclaw/workspace/trading/webhook-server/data")
DATA.mkdir(exist_ok=True)

class H(BaseHTTPRequestHandler):
    def _ok(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type,X-Signal-Token")
        self.end_headers()
        self.wfile.write(b)

    def _save(self, data):
        tok = data.pop("token", data.pop("t", ""))
        if tok != TOKEN:
            self._ok(401, {"error": "bad token"})
            return
        data["_received"] = datetime.now(timezone.utc).isoformat()
        sid = data.get("signal_id") or f"sig-{int(time.time())}"
        data["signal_id"] = sid
        (DATA / f"{sid}.json").write_text(json.dumps(data, indent=2))
        (DATA / "latest.json").write_text(json.dumps(data, indent=2))
        self._ok(200, {"ok": True, "signal_id": sid, "symbol": data.get("symbol")})

    def do_OPTIONS(self):
        self._ok(204, {})

    def do_GET(self):
        if self.path == "/health":
            self._ok(200, {"ok": True, "count": len(list(DATA.glob("*.json")))});
        elif self.path == "/signal/latest":
            lb = DATA / "latest.json"
            self._ok(200, json.loads(lb.read_text()) if lb.exists() else {"error": "none"});
        elif self.path.startswith("/push?"):
            qs = urllib.parse.parse_qs(self.path.split("?", 1)[1])
            raw = qs.get("data", [None])[0]
            if not raw:
                self._ok(400, {"error": "no data"}); return
            payload = json.loads(urllib.parse.unquote(raw))
            if "token" not in payload and "token" in qs:
                payload["token"] = qs["token"][0]
            self._save(payload)
        else:
            self._ok(404, {"error": "use /health /signal/latest or POST /push"})

    def do_POST(self):
        try:
            tok = self.headers.get("X-Signal-Token")
            n = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(n)
            data = json.loads(raw.decode())
            if tok: data["token"] = tok
            self._save(data)
        except Exception as e:
            self._ok(400, {"error": str(e)})

    def log_message(self, *a): pass

if __name__ == "__main__":
    s = HTTPServer(("0.0.0.0", PORT), H)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain("/tmp/dest-cert.pem", "/tmp/dest-key.pem")
    s.socket = ctx.wrap_socket(s.socket, server_side=True)
    print(f"[DESTROYER HTTPS] port {PORT} ready")
    s.serve_forever()
