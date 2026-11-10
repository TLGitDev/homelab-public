#!/usr/bin/env python3
"""Sert la page des services, en HTTP et en HTTPS."""

import http.server
import ssl
import threading
from functools import partial


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".webmanifest": "application/manifest+json",
    }


def serve(port, context=None):
    handler = partial(Handler, directory="/var/www/portail")
    server = http.server.ThreadingHTTPServer(("0.0.0.0", port), handler)
    if context is not None:
        server.socket = context.wrap_socket(server.socket, server_side=True)
    server.serve_forever()


def main():
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain("/etc/portail/cert.pem", "/etc/portail/key.pem")
    threading.Thread(target=serve, args=(80,), daemon=True).start()
    serve(443, context)


if __name__ == "__main__":
    main()
