#!/usr/bin/env python3
"""REINA RTS control-plane health stub. NOT a playable multiplayer server.

Loopback-only; real match simulation and authentication are future milestones.
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os

HOST = "127.0.0.1"
PORT = int(os.environ.get("REINA_RTS_PORT", "18777"))


class Handler(BaseHTTPRequestHandler):
    server_version = "REINA-RTS-prealpha"

    def do_GET(self):
        if self.path not in ("/healthz", "/readyz"):
            self.send_error(404, "Not found")
            return
        payload = {
            "service": "reina-dead-signal-rts",
            "phase": "bootstrap",
            "healthy": True,
            "match_server": False,
            "online_gameplay": False,
            "listen": "loopback",
        }
        raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(200 if self.path == "/healthz" else 503)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)


if __name__ == "__main__":
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
