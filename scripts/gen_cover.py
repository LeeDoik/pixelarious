"""카트리지 커버 아트 생성 (PixelLab). 실행: python scripts/gen_cover.py [이름...]

커버는 사이트 카트리지 목록의 100x42 캔버스에 그려진다. 2x(200x84)로 생성 후
NEAREST 다운스케일해 디테일을 살린다. 산출물: public/covers/<이름>.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_pixellab import ROOT, STYLE, find_base64, read_key  # noqa: E402

import base64  # noqa: E402
import json  # noqa: E402
import urllib.request  # noqa: E402

from PIL import Image  # noqa: E402

API = "https://api.pixellab.ai/v1/generate-image-pixflux"
OUT = os.path.join(ROOT, "public", "covers")

COVERS = {
    "starfall-drift": (200, 84,
        "wide banner game cover art: tiny cute pink astronaut leaping between planets, "
        "jumping from a round golden glowing star planet on the left toward a large "
        "pink-red giant star on the right, curved pink dotted trail behind the astronaut, "
        "deep dark navy #0c0a1c night sky full of tiny white falling stars, "
        "sense of upward hopeful motion, no text, no letters, "
        f"{STYLE}"),
}

def generate(key, name, w, h, desc):
    body = json.dumps({
        "description": desc,
        "negative_description": "text, letters, words, logo, watermark, blurry, anti-aliasing, photorealistic",
        "image_size": {"width": w, "height": h},
        "no_background": False,
    }).encode()
    req = urllib.request.Request(API, data=body, method="POST", headers={
        "Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=180) as resp:
        data = json.load(resp)
    b64 = find_base64(data)
    if not b64:
        sys.exit(f"{name}: no image in response: {str(data)[:300]}")
    if "," in b64[:80]:
        b64 = b64.split(",", 1)[1]
    os.makedirs(OUT, exist_ok=True)
    raw_path = os.path.join(OUT, f"{name}_2x.png")
    with open(raw_path, "wb") as f:
        f.write(base64.b64decode(b64))
    im = Image.open(raw_path).convert("RGBA")
    im.resize((w // 2, h // 2), Image.NEAREST).save(os.path.join(OUT, f"{name}.png"))
    os.remove(raw_path)
    print(f"OK {name} -> public/covers/{name}.png ({w // 2}x{h // 2})")

def main():
    key = read_key()
    for name in (sys.argv[1:] or list(COVERS)):
        w, h, desc = COVERS[name]
        generate(key, name, w, h, desc)

if __name__ == "__main__":
    main()
