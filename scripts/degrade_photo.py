"""사진 열화: ~0.3MP 축소(비율 유지) → 노이즈 → JPEG q=35 재압축 → PNG 저장.
사용: python scripts/degrade_photo.py  (scripts/photo_src/ 의 모든 이미지 처리)
가로 4:3 원본은 640x480이 되고, 세로 사진도 왜곡 없이 같은 화소 수로 맞춰진다."""
from PIL import Image
import io, math, os, random, sys

SRC = os.path.join("scripts", "photo_src")
OUT = os.path.join("game", "assets", "img", "photos")
TARGET_PIXELS = 640 * 480

if not os.path.isdir(SRC):
    print("no photo_src, skipping")
    sys.exit(0)

os.makedirs(OUT, exist_ok=True)
for name in os.listdir(SRC):
    img = Image.open(os.path.join(SRC, name)).convert("RGB")
    scale = math.sqrt(TARGET_PIXELS / (img.width * img.height))
    w = max(1, round(img.width * scale))
    h = max(1, round(img.height * scale))
    img = img.resize((w, h))
    px = img.load()
    for _ in range(w * h // 15):
        x, y = random.randrange(w), random.randrange(h)
        r, g, b = px[x, y]
        n = random.randint(-14, 14)
        px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=35)
    Image.open(buf).save(os.path.join(OUT, os.path.splitext(name)[0] + ".png"))
    print(name, "->", w, "x", h)
print("ok")
