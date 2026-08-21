"""PixelLab으로 BEAT SHIFT 스프라이트 생성. 실행: python scripts/gen_pixellab_beatshift.py [이름...]"""
import base64, io, json, os, sys, time, urllib.request

from PIL import Image

# PixelLab API는 OpenAPI 스키마상 width/height >= 16을 허용한다고 명시하지만,
# 실제로는 "Canvas must be size 32x32 area or larger" (width*height >= 1024)를 강제한다.
# 이 미만인 스프라이트는 정수 배율로 확대 생성한 뒤 NEAREST로 다운스케일한다.
# (scripts/gen_pixellab.py와 동일한 검증된 로직)
MIN_AREA = 1024

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "games-src", "beat-shift", "assets", "img")
API = "https://api.pixellab.ai/v1/generate-image-pixflux"

STYLE = ("pixel art, crisp 1px dark outline, retro arcade sprite, warm forge night palette, "
         "clean readable silhouette, centered, no background")
NEG = "blurry, anti-aliasing, photorealistic, text, watermark, gradient banding"

SPRITES = {
    "smith_idle":  (48, 48, f"stocky bearded dwarf blacksmith, thick reddish-brown beard, bare muscular arms, orange #ffa300 apron over bare chest, brown boots, holding hammer raised ready, side view facing left, {STYLE}"),
    "smith_swing": (48, 48, f"stocky bearded dwarf blacksmith, thick reddish-brown beard, bare muscular arms, orange #ffa300 apron over bare chest, brown boots, mid downward hammer strike dynamic lean, side view facing left, {STYLE}"),
    "assistant":   (32, 32, f"small pixel apprentice kid mid-throw gesture, teal #29adff cap and gloves, side view facing right, {STYLE}"),
    "ingot":       (16, 16, f"rectangular glowing hot metal ingot bar, elongated block shape not round, orange #ffa300 core with yellow #ffec27 heat edges, {STYLE}"),
    "blade":       (24, 24, f"freshly forged short sword blade sparkling, pale #fff1e8 steel, diagonal orientation, {STYLE}"),
    "anvil":       (48, 24, f"sturdy iron blacksmith anvil, dark blue-gray #1d2b53 metal with lighter top face, side view, {STYLE}"),
    "furnace":     (64, 64, f"stone forge furnace with glowing orange #ffa300 fire mouth, dark brick, embers, {STYLE}"),
    "emblem":      (48, 48, f"emblem of pixel hammer crossed with a music note, yellow #ffec27 and orange #ffa300 on transparent, {STYLE}"),
}

def read_key():
    with open(os.path.join(ROOT, ".env.local"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("PIXELLAB_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("PIXELLAB_API_KEY not found in .env.local")

def find_base64(obj):
    """응답 어디에 있든 base64 이미지 문자열을 찾는다 (스키마 변화 방어)."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == "base64" and isinstance(v, str):
                return v
            r = find_base64(v)
            if r:
                return r
    elif isinstance(obj, list):
        for v in obj:
            r = find_base64(v)
            if r:
                return r
    return None

def generate(key, name, w, h, desc):
    # API가 32x32(=1024px^2) 미만 캔버스를 거부하므로, 목표 크기의 면적이 그
    # 미만이면 정수 배율로 확대 생성한 뒤 다운스케일한다.
    mult = 1
    while (w * mult) * (h * mult) < MIN_AREA:
        mult += 1
    gen_w, gen_h = w * mult, h * mult

    body = json.dumps({
        "description": desc,
        "negative_description": NEG,
        "image_size": {"width": gen_w, "height": gen_h},
        "no_background": True,
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
    raw = base64.b64decode(b64)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{name}.png")
    if mult > 1:
        im = Image.open(io.BytesIO(raw)).convert("RGBA")
        im = im.resize((w, h), Image.NEAREST)
        im.save(path)
        print(f"OK {name} -> {path} (generated {gen_w}x{gen_h}, downscaled {mult}x)")
    else:
        with open(path, "wb") as f:
            f.write(raw)
        print(f"OK {name} -> {path}")

def main():
    key = read_key()
    targets = sys.argv[1:] or list(SPRITES)
    for name in targets:
        w, h, desc = SPRITES[name]
        generate(key, name, w, h, desc)
        time.sleep(1)

if __name__ == "__main__":
    main()
