"""PixelLab으로 누리넷(LAST LOGIN 브라우저) 웹 그래픽의 '그림' 부분을 생성.
실행: python scripts/gen_pixellab_lastlogin.py [이름...]

한글 글자는 AI가 못 그리므로 여기서는 그림만 만들고, 배너 조립(한글 워드마크·
그라데이션 틀)은 scripts/gen_web_banners.py가 게임 폰트로 얹는다.
"""
import base64, io, json, os, sys, time, urllib.request

from PIL import Image

MIN_AREA = 1024  # API가 32x32 미만 캔버스를 거부한다 (gen_pixellab.py와 같은 제약)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "games-src", "last-login", "assets", "img", "web")
API = "https://api.pixellab.ai/v1/generate-image-pixflux"

STYLE = ("pixel art, crisp 1px dark outline, early 2000s web graphic, "
         "flat clean shapes, readable silhouette, centered, no background")
NEG = "blurry, anti-aliasing, photorealistic, text, letters, watermark, gradient banding, modern flat design"

ART = {
    # 새빛수련회 엠블럼 — diary/17의 "차 뒷유리에 빛 모양 스티커"와 같은 표식
    "emblem_saebit": (48, 48,
        f"simple emblem of a radiating light burst with eight straight rays from a small "
        f"round core, warm gold and pale cream, perfectly symmetrical, calm and formal, "
        f"like a quiet organization logo, {STYLE}"),
    # 누리넷 포털 마크
    "mark_portal": (32, 32,
        f"glossy blue globe with a single white swoosh arc across it, cheerful early-2000s "
        f"internet portal logo mark, {STYLE}"),
    # 벨소리 광고 그림
    "art_ringtone": (48, 48,
        f"chunky silver flip phone seen from the front, open, small screen on the upper half "
        f"and a keypad grid on the lower half, short antenna, two yellow music notes beside it, "
        f"year 2002 mobile phone, thick bold shapes filling the canvas, {STYLE}"),
    # 공시생 카페 대문 그림
    "art_study": (48, 48,
        f"stack of three thick study books with a yellow pencil resting on top and a small "
        f"desk lamp beside them, exam preparation, warm brown green and cream, {STYLE}"),
}


def read_key():
    with open(os.path.join(ROOT, ".env.local"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("PIXELLAB_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("PIXELLAB_API_KEY not found in .env.local")


def find_base64(obj):
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
    im = Image.open(io.BytesIO(raw)).convert("RGBA")
    if mult > 1:
        im = im.resize((w, h), Image.NEAREST)
    im.save(path)
    print(f"OK {name} -> {path} ({im.size[0]}x{im.size[1]})")


def main():
    key = read_key()
    for name in (sys.argv[1:] or list(ART)):
        w, h, desc = ART[name]
        generate(key, name, w, h, desc)
        time.sleep(1)


if __name__ == "__main__":
    main()
