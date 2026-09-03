#!/usr/bin/env python3
"""Minimal harbor API: health check + optional Postgres ping."""

from __future__ import annotations

import json
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


PORT = int(os.environ.get("PORT", "8080"))
DB_HOST = os.environ.get("DB_HOST", "")
DB_PORT = int(os.environ.get("DB_PORT", "5432"))


def postgres_reachable(timeout: float = 2.0) -> bool:
    if not DB_HOST:
        return False
    try:
        with socket.create_connection((DB_HOST, DB_PORT), timeout=timeout):
            return True
    except OSError:
        return False


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        return

    def _json(self, code: int, body: dict) -> None:
        payload = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self) -> None:  # noqa: N802
        if self.path in ("/healthz", "/"):
            ok = postgres_reachable()
            self._json(200 if ok else 503, {"ok": ok, "db_host": DB_HOST})
            return
        self._json(404, {"error": "not_found"})


def main() -> None:
    # Prove /tmp is writable under readonlyRootFilesystem + volume mount.
    with open("/tmp/harbor-boot", "w", encoding="utf-8") as fh:
        fh.write("ok")
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
