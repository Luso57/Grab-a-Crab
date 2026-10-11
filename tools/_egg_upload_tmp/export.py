import base64
import compression.zstd
import http.server
import json
import pathlib
import struct
import zlib

root = pathlib.Path(__file__).parent
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(root), **kwargs)
    def do_POST(self):
        item = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        name = item["name"]
        width, height = item["w"], item["h"]
        pixels = compression.zstd.decompress(base64.b64decode(item["data"]["zbase64"]))
        if len(pixels) != width * height * 4:
            raise ValueError(f"{name}: bad pixel count {len(pixels)}")
        stride = width * 4
        rows = b"".join(b"\x00" + pixels[y * stride:(y + 1) * stride] for y in range(height))
        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b"")
        (root / (name + ".png")).write_bytes(png)
        print(f"saved {name} {len(png)} bytes", flush=True)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(str(len(png)).encode())

http.server.ThreadingHTTPServer(("127.0.0.1", 8765), Handler).serve_forever()
