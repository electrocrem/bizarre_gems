#!/usr/bin/env python3
"""Serve a web build locally with the mock Yandex SDK at /sdk.js.
Usage: python3 tools/serve.py [port] [dir]   (dir defaults to build/web; build/webdebug supports ?autoplay)"""
import http.server, os, sys, functools
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOCK = os.path.join(ROOT, "tools", "mock", "sdk.js")
WEB = os.path.join(ROOT, sys.argv[2]) if len(sys.argv) > 2 else os.path.join(ROOT, "build", "web")

class H(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        return MOCK if path.split("?")[0] == "/sdk.js" else super().translate_path(path)
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8060
print(f"http://127.0.0.1:{port}/  (add ?lang=en or ?lang=tr to switch language)")
http.server.ThreadingHTTPServer(("127.0.0.1", port), functools.partial(H, directory=WEB)).serve_forever()
