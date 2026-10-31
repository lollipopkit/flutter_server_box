#!/usr/bin/env python3
"""Ollama's API as Local inference uses it, for the e2e on a throwaway
machine (`scripts/desk-vm-e2e.sh <node> inference_app`): version, tags, ps,
a streamed pull and delete, the models kept in memory. Listens on
127.0.0.1:11434, where Ollama's own install does."""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import time

models = {'tiny:latest': 1_000_000}


class Handler(BaseHTTPRequestHandler):
    def _json(self, value, status=200):
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header('content-type', 'application/json')
        self.send_header('content-length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _body(self):
        return json.loads(self.rfile.read(int(self.headers.get('content-length') or 0)) or b'{}')

    def do_GET(self):
        if self.path == '/api/version':
            return self._json({'version': '0.12.0'})
        if self.path == '/api/tags':
            return self._json({'models': [{'name': n, 'size': s, 'details': {'parameter_size': '1M', 'quantization_level': 'Q4_0'}} for n, s in models.items()]})
        if self.path == '/api/ps':
            return self._json({'models': [{'name': 'tiny:latest'}]})
        self._json({'error': 'not found'}, 404)

    def do_POST(self):
        if self.path != '/api/pull':
            return self._json({'error': 'not found'}, 404)
        name = self._body().get('model', '')
        self.send_response(200)
        self.send_header('content-type', 'application/x-ndjson')
        self.end_headers()
        steps = [{'status': 'pulling manifest'}] + [{'status': 'downloading', 'completed': c, 'total': 100} for c in (0, 50, 100)] + [{'status': 'success'}]
        for s in steps:
            self.wfile.write(json.dumps(s).encode() + b'\n')
            self.wfile.flush()
            time.sleep(0.3)
        models[name] = 2_000_000

    def do_DELETE(self):
        name = self._body().get('model', '')
        if models.pop(name, None) is None:
            return self._json({'error': 'not found'}, 404)
        self._json({})


ThreadingHTTPServer(('127.0.0.1', 11434), Handler).serve_forever()
