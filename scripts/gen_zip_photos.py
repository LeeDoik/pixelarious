# -*- coding: utf-8 -*-
"""정리.zip 안의 사진 두 장 — 절차 생성 대역(stand-in).

  봉고_1029.jpg  밤 골목, 흰 12인승 봉고의 뒤태. 번호판 전체와 뒷유리의 빛 모양 스티커.
                 창밖_1029.jpg(23:11)를 찍고 두 분 뒤 창을 열고 당겨 찍은 것.
  봉투_1102.jpg  11.2 낮에 문틈으로 들어온 봉투 속 사진을 책상 위에 놓고 다시 찍은 것 —
                 슬기 학교 정문. 사람 없음(얼굴 없음 규칙).

gen_placeholder_photos.py와 같은 성격이다: 실존 인물·브랜드 없음, PIL만 사용,
나중에 AI 생성 사진으로 교체할 수 있는 대역. 시드가 고정돼 몇 번을 돌려도 같다.

  python scripts/gen_zip_photos.py [--clean <dir>]
"""
import io, math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join("games-src", "last-login", "assets", "img", "photos")
PLATE_FONT = [p for p in [r"C:\Windows\Fonts\malgunbd.ttf", r"C:\Windows\Fonts\malgun.ttf",
                          os.path.join("scripts", "font_src", "garam_yeonkkot.ttf")] if os.path.exists(p)][0]


def noise(img, amount, strength):
    px = img.load()
    w, h = img.size
    for _ in range(w * h // amount):
        x, y = random.randrange(w), random.randrange(h)
        r, g, b = px[x, y]
        n = random.randint(-strength, strength)
        px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))


def degrade(img, quality=38, target=640 * 480):
    scale = math.sqrt(target / (img.width * img.height))
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))))
    noise(img, 14, 12)
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=quality)
    return Image.open(buf).convert("RGB")


def make_van():
    """밤 골목. 가로등 하나가 봉고 뒤태를 비춘다 — 흰 차체, 어두운 뒷유리, 번호판, 스티커."""
    W, H = 1280, 960
    img = Image.new("RGB", (W, H), (9, 11, 18))
    d = ImageDraw.Draw(img, "RGBA")
    # 가로등 불빛 — 위 오른쪽에서 퍼진다
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(18, 0, -1):
        r = i * 42
        gd.ellipse([W * 0.72 - r, 90 - r, W * 0.72 + r, 90 + r], fill=(232, 200, 120, 9))
    img.paste(Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB"))
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([W * 0.72 - 5, 90, W * 0.72 + 5, H * 0.62], fill=(28, 28, 30))   # 전봇대
    d.ellipse([W * 0.72 - 26, 64, W * 0.72 + 26, 116], fill=(250, 232, 170))
    # 길바닥과 담
    d.rectangle([0, H * 0.62, W, H], fill=(30, 30, 34))
    for i in range(0, W, 6):                                                      # 젖은 아스팔트 결
        d.line([i, H * 0.62, i + random.randint(-3, 3), H], fill=(36 + random.randint(-4, 6),) * 3)
    d.rectangle([0, H * 0.22, W * 0.46, H * 0.62], fill=(44, 40, 38))              # 담벼락
    for y in range(int(H * 0.22), int(H * 0.62), 26):
        d.line([0, y, W * 0.46, y], fill=(52, 48, 44), width=2)
    # 봉고 뒤태
    x0, y0, x1, y1 = W * 0.30, H * 0.20, W * 0.80, H * 0.72
    body = (214, 214, 208)
    d.rounded_rectangle([x0, y0, x1, y1], radius=28, fill=body)
    d.rectangle([x0, y1 - 40, x1, y1], fill=(180, 180, 176))                      # 범퍼
    d.rounded_rectangle([x0 + 34, y0 + 34, x1 - 34, y0 + 250], radius=14, fill=(24, 30, 44))   # 뒷유리
    d.line([W * 0.55, y0 + 250, W * 0.55, y1 - 40], fill=(150, 150, 146), width=4)              # 문 틈
    for dx in (0, 1):                                                              # 후미등
        x = x0 + 40 if dx == 0 else x1 - 120
        d.rounded_rectangle([x, y0 + 290, x + 80, y0 + 400], radius=8, fill=(150, 30, 30))
        d.rounded_rectangle([x + 8, y0 + 300, x + 72, y0 + 340], radius=6, fill=(220, 70, 60))
    # 빛 모양 스티커 — 뒷유리 오른쪽 아래
    cx, cy = x1 - 110, y0 + 200
    for a in range(0, 360, 30):
        ex, ey = cx + math.cos(math.radians(a)) * 34, cy + math.sin(math.radians(a)) * 34
        d.line([cx, cy, ex, ey], fill=(236, 200, 90), width=5)
    d.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=(250, 226, 130))
    # 번호판 — 2002년의 녹색 판, 흰 글씨
    pw, ph = 470, 96
    px0, py0 = W * 0.55 - pw / 2, y1 - 40 - ph - 26
    d.rounded_rectangle([px0, py0, px0 + pw, py0 + ph], radius=6, fill=(26, 96, 60))
    d.rounded_rectangle([px0 + 3, py0 + 3, px0 + pw - 3, py0 + ph - 3], radius=5, outline=(200, 230, 210), width=2)
    f = ImageFont.truetype(PLATE_FONT, 54)
    text = "서울 12 가 4862"
    tw = d.textlength(text, font=f)
    d.text((px0 + (pw - tw) / 2, py0 + 16), text, font=f, fill=(245, 250, 244))
    # 차체에 드는 가로등 빛과 그림자
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    sd.polygon([(x0, y0), (x0 + 220, y0), (x0, y1)], fill=(0, 0, 0, 90))
    sd.rectangle([0, 0, W, H], fill=(10, 14, 30, 70))
    img = Image.alpha_composite(img.convert("RGBA"), shade).convert("RGB")
    img = img.filter(ImageFilter.GaussianBlur(0.8))                                # 손떨림
    return img


def make_envelope():
    """책상 위, 봉투에서 꺼낸 사진 한 장을 디카로 다시 찍었다. 플래시가 인화지에 번진다."""
    W, H = 1280, 960
    img = Image.new("RGB", (W, H), (96, 74, 52))
    d = ImageDraw.Draw(img, "RGBA")
    for y in range(0, H, 3):                                                       # 책상 나뭇결
        d.line([0, y, W, y + random.randint(-2, 2)], fill=(96 + random.randint(-8, 8), 74 + random.randint(-6, 6), 52), width=2)
    # 봉투 — 왼쪽 아래에 비스듬히
    env = Image.new("RGBA", (700, 420), (0, 0, 0, 0))
    ed = ImageDraw.Draw(env)
    ed.rectangle([0, 0, 699, 419], fill=(236, 230, 214))
    ed.polygon([(0, 0), (699, 0), (350, 230)], fill=(222, 214, 196), outline=(200, 190, 170))
    env = env.rotate(-8, expand=True, resample=Image.BICUBIC)
    img.paste(env, (int(W * 0.02), int(H * 0.50)), env)
    # 인화지 — 가운데, 살짝 기울여
    pw, ph = 860, 600
    photo = Image.new("RGB", (pw, ph), (176, 196, 214))
    pd = ImageDraw.Draw(photo, "RGBA")
    for y in range(0, 300):                                                        # 하늘
        t = y / 300
        pd.line([0, y, pw, y], fill=(int(178 - 30 * t), int(198 - 20 * t), int(216 - 10 * t)))
    pd.rectangle([0, 300, pw, ph], fill=(122, 118, 110))                           # 길
    for i in range(0, pw, 40):
        pd.line([i, 300, i + 60, ph], fill=(112, 108, 100), width=2)
    for cx in (80, 190, 700, 790):                                                 # 가로수
        pd.ellipse([cx - 70, 130, cx + 70, 300], fill=(64, 92, 56))
        pd.rectangle([cx - 8, 260, cx + 8, 330], fill=(70, 56, 40))
    for gx in (270, 560):                                                          # 정문 기둥 둘
        pd.rectangle([gx, 150, gx + 46, 340], fill=(150, 146, 140))
        pd.rectangle([gx - 6, 140, gx + 52, 156], fill=(120, 116, 110))
    for x in range(324, 556, 16):                                                  # 철문 살
        pd.line([x, 190, x, 336], fill=(60, 62, 66), width=4)
    pd.line([320, 200, 560, 200], fill=(60, 62, 66), width=5)
    pd.line([320, 300, 560, 300], fill=(60, 62, 66), width=5)
    pd.rectangle([330, 150, 550, 176], fill=(84, 80, 76))                          # 현판 — 글자 없음
    pd.rectangle([0, 0, pw - 1, ph - 1], outline=(250, 250, 246), width=18)        # 인화지 흰 테두리
    noise(photo, 30, 8)
    photo = photo.filter(ImageFilter.GaussianBlur(0.6))
    # 플래시 반사
    glare = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glare)
    for i in range(16, 0, -1):
        r = i * 22
        gd.ellipse([pw * 0.68 - r, ph * 0.28 - r * 0.7, pw * 0.68 + r, ph * 0.28 + r * 0.7], fill=(255, 255, 250, 8))
    photo = Image.alpha_composite(photo.convert("RGBA"), glare)
    photo = photo.rotate(3, expand=True, resample=Image.BICUBIC)
    # 그림자
    sh = Image.new("RGBA", photo.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rectangle([12, 14, photo.width - 4, photo.height - 2], fill=(0, 0, 0, 110))
    sh = sh.filter(ImageFilter.GaussianBlur(10))
    pos = (int(W * 0.14), int(H * 0.12))
    img.paste(sh, pos, sh)
    img.paste(photo, pos, photo)
    vign = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(vign).rectangle([0, 0, W, H], fill=(20, 12, 6, 40))
    return Image.alpha_composite(img.convert("RGBA"), vign).convert("RGB")


def main():
    clean_dir = None
    if "--clean" in sys.argv:
        clean_dir = sys.argv[sys.argv.index("--clean") + 1]
        os.makedirs(clean_dir, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    for stem, fn, seed, q in [("van_1029", make_van, 20021029, 34), ("envelope_1102", make_envelope, 20021102, 40)]:
        random.seed(seed)
        page = fn()
        if clean_dir:
            page.save(os.path.join(clean_dir, stem + "_clean.png"))
        random.seed(seed + 1)
        out = os.path.join(OUT, stem + ".png")
        degrade(page, q).save(out)
        print(stem, "->", out, os.path.getsize(out), "bytes")
    print("ok")


if __name__ == "__main__":
    main()
