"""사진 열화: 640x480 축소 → 노이즈 → JPEG q=35 재압축 → PNG 저장.
사용: python scripts/degrade_photo.py  (scripts/photo_src/ 의 모든 이미지 처리)"""
from PIL import Image
import io, os, random, sys

SRC = os.path.join("scripts", "photo_src")
OUT = os.path.join("game", "assets", "img", "photos")

if not os.path.isdir(SRC):
    print("no photo_src, skipping")
    sys.exit(0)

os.makedirs(OUT, exist_ok=True)
for name in os.listdir(SRC):
    img = Image.open(os.path.join(SRC, name)).convert("RGB").resize((640, 480))
    px = img.load()
    for _ in range(20000):
        x, y = random.randrange(640), random.randrange(480)
        r, g, b = px[x, y]
        n = random.randint(-14, 14)
        px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=35)
    Image.open(buf).save(os.path.join(OUT, os.path.splitext(name)[0] + ".png"))
print("ok")
