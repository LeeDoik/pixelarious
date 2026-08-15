"""PixelLab으로 STARFALL DRIFT 스프라이트 생성. 실행: python scripts/gen_pixellab.py [이름...]"""
import base64, io, json, os, sys, time, urllib.request

from PIL import Image

# PixelLab API는 OpenAPI 스키마상 width/height >= 16을 허용한다고 명시하지만,
# 실제로는 "Canvas must be size 32x32 area or larger" (width*height >= 1024)를 강제한다.
# 이 미만인 스프라이트는 정수 배율로 확대 생성한 뒤 NEAREST로 다운스케일한다.
MIN_AREA = 1024

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "games-src", "starfall-drift", "assets", "img")
API = "https://api.pixellab.ai/v1/generate-image-pixflux"

STYLE = ("pixel art, crisp 1px dark outline, retro arcade sprite, night sky palette, "
         "clean readable silhouette, centered, no background")
NEG = "blurry, anti-aliasing, photorealistic, text, watermark, gradient banding"

SPRITES = {
    "player":        (16, 16, f"tiny cute astronaut drifter, round pink #ff77a8 spacesuit, small white visor, {STYLE}"),
    "star_standard": (32, 32, f"round golden star planet, warm yellow #ffec27 glowing core, pale cream rim, subtle surface detail, {STYLE}"),
    "star_dwarf":    (16, 16, f"small dense blue-white dwarf star, bright cyan #29adff core, intense glow, {STYLE}"),
    "star_giant":    (48, 48, f"large soft pink-red giant star, gentle warm #ff77a8 glow, calm majestic sphere, {STYLE}"),
    "asteroid":      (24, 24, f"lumpy irregular rock chunk, asymmetric silhouette, uneven bumpy cratered stone surface, dull gray-blue #1d2b53 with slate gray shading, NOT symmetric, NOT a gem, NOT a diamond, no facets, {STYLE}"),
    "cracks":        (32, 32, f"pixel art crack decal, several thin jagged white cracks branching outward from a central impact point like a spiderweb, on a fully transparent PNG alpha background, no colored fill anywhere, no black square, no solid background plate, {STYLE}"),
    "nebula_a":      (64, 32, f"dark moody nebula cloud, deep indigo #1d2b53 and navy #0c0a1c, very low saturation, dim, barely-lit cosmic dust, {STYLE}"),
    "nebula_b":      (64, 32, f"soft hazy nebula cloud blob, filled uneven puffy silhouette spanning most of the canvas, dark navy blue #1d2b53 haze with a few tiny embedded starlight #fff1e8 specks, dim and low-contrast but clearly a cloud shape not scattered dots, {STYLE}"),
    "emblem":        (48, 48, f"shooting star emblem, yellow #ffec27 star head with pink #ff77a8 sparkling trail, dynamic diagonal, {STYLE}"),
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
