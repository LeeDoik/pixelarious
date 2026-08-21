# -*- coding: utf-8 -*-
"""필사 1~3 손글씨 사진 생성 — 성진이 제출 전에 디카로 찍어둔 제출본.

docs.json의 필사 본문에서 교리부만 뽑아(사적 주석 '(옮겨 적…)' 이후 제외)
나눔손글씨 가람연꽃으로 줄공책에 앉히고, 디카 열화를 통과시킨다.
문서는 읽혀야 하므로 기존 사진(0.3MP·q35)보다 약하게 잡는다(0.7MP·q58).

  python scripts/gen_pilsa_photos.py [--clean <dir>]

--clean을 주면 열화 전 원본도 그 폴더에 남긴다(검수용).
페이지마다 시드가 촬영일로 고정돼 있어 몇 번을 돌려도 같은 그림이 나온다.

폰트는 scripts/font_src/garam_yeonkkot.ttf (나눔손글씨 가람연꽃, SIL OFL 1.1).
폰트 파일 자체는 게임에 실리지 않는다 — 래스터 결과물만 실린다.
"""
import io as _io
import json, math, os, random, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

FONT = os.path.join("scripts", "font_src", "garam_yeonkkot.ttf")
DOCS = os.path.join("games-src", "last-login", "content", "docs.json")
OUT = os.path.join("games-src", "last-login", "assets", "img", "photos")

INK = (28, 38, 92)            # 파란 볼펜
PAPER = (246, 243, 232)
RULING = (150, 175, 205, 190)  # 하늘색 괘선
MARGIN_RED = (215, 120, 120, 190)

# 페이지 정의: (fs용 파일이름 밑동, cid, 제목, 서명, 시드=촬영일)
# 제목의 한자(新光曆)는 뺀다 — 손글씨 폰트에 한자가 없고, 손으로 옮기며 뺐다고 보면 된다.
PAGES = [
    ("pilsa_1", "doc:doctrine_1", "빛과 그릇",        "새빛력 4년 7월 28일  성진", 20020728),
    ("pilsa_2", "doc:doctrine_2", "새빛력에 대하여",   "새빛력 4년 8월 11일  성진", 20020811),
    ("pilsa_3", "doc:doctrine_3", "비움의 실제",      "새빛력 4년 9월 22일  성진", 20020922),
]

PUNCT = ".,·\"'」)!?"   # 줄 머리에 오면 안 되는 것들


def doctrine_lines(body):
    """교리부만 — 머리글 두 줄과 '(옮겨 적…)' 이후의 사적 주석을 뺀다."""
    for marker in ["(옮겨 적으며)", "(옮겨 적음)"]:
        if marker in body:
            body = body.split(marker)[0]
    lines = []
    for ln in body.split("\n"):
        t = ln.strip()
        if t.startswith("필사 ") or t.startswith("(2002"):
            continue
        if t.startswith("──"):
            t = t.strip("─ ").strip()   # "── 인도자님 말씀 ──" → "인도자님 말씀"
        lines.append(t)
    while lines and lines[0] == "":
        lines.pop(0)
    while lines and lines[-1] == "":
        lines.pop()
    return lines


def ink_color():
    n = random.randint(-10, 14)
    return (max(0, INK[0] + n), max(0, INK[1] + n), min(255, INK[2] + n * 2))


def measure(font, text):
    return ImageDraw.Draw(Image.new("RGB", (8, 8))).textlength(text, font=font)


def draw_flow_char(canvas, font, ch, x, y_base, size):
    """글자 하나를 베이스라인에 앉힌다 — 회전·크기·농담·위치 지터 포함."""
    f = font.font_variant(size=int(size * random.uniform(0.94, 1.05)))
    pad = size * 2
    tile = Image.new("RGBA", (int(size * 4), int(size * 4)), (0, 0, 0, 0))
    td = ImageDraw.Draw(tile)
    td.text((pad, pad), ch, font=f, anchor="ls",
            fill=ink_color() + (random.randint(170, 235),))
    tile = tile.rotate(random.uniform(-2.4, 2.4), resample=Image.BICUBIC,
                       center=(pad, pad))
    if random.random() < 0.10:   # 가끔 잉크가 살짝 번진다
        tile = tile.filter(ImageFilter.GaussianBlur(0.5))
    canvas.alpha_composite(tile, (int(x - pad + random.randint(-1, 2)),
                                  int(y_base - pad + random.randint(-2, 2))))


def draw_flow_text(canvas, font, text, x, y_base, size, space_mul=1.7):
    for ch in text:
        adv = measure(font, ch)
        if ch != " ":
            # 이·그 같은 좁은 글자가 다음 글자에 바짝 붙으면 한 글자처럼 읽힌다 — 최소 전진폭
            adv = max(adv, size * 0.52)
            draw_flow_char(canvas, font, ch, x, y_base, size)
            x += adv + random.uniform(1.5, 3.2)
        else:
            x += adv * space_mul + random.uniform(0.0, 1.5)
    return x


def wrap_flow(font, lines, limit, space_mul=1.7):
    """자 단위로 접되, 줄 머리에 문장부호가 오지 않게 한다."""
    out = []
    for ln in lines:
        if ln == "":
            out.append("")
            continue
        cur, w = "", 0.0
        for ch in ln:
            adv = measure(font, ch) * space_mul if ch == " " else max(measure(font, ch), 46 * 0.52) + 2.4
            if w + adv > limit and cur != "" and ch not in PUNCT and ch != " ":
                out.append(cur)
                cur, w = "", 0.0
            if ch == " " and cur == "":
                continue   # 줄 머리 공백은 버린다
            cur += ch
            w += adv
        out.append(cur)
    return out


def paper_base(w, h):
    img = Image.new("RGB", (w, h), PAPER)
    px = img.load()
    for _ in range(w * h // 22):   # 종이 섬유
        x, y = random.randrange(w), random.randrange(h)
        r, g, b = px[x, y]
        n = random.randint(-6, 5)
        px[x, y] = (r + n, g + n, b + n)
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(5):             # 옅은 눌림 얼룩
        cx, cy = random.randrange(w), random.randrange(h)
        rr = random.randint(60, 200)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(180, 168, 140, 7))
    return img


def make_page(title, lines, sign):
    W, LINE, TOP, SIZE = 1440, 68, 150, 46
    body_font = ImageFont.truetype(FONT, SIZE)
    title_font = ImageFont.truetype(FONT, 54)
    body = wrap_flow(body_font, lines, W - 210 - 90)
    n = 2 + len(body) + 3          # 제목·공백 + 본문 + 공백·서명·여유
    H = TOP + n * LINE + 120
    img = paper_base(W, H)
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(1, n + 1):
        y = TOP + i * LINE
        d.line([70, y, W - 60, y], fill=RULING, width=2)
    d.line([180, 60, 180, H - 50], fill=MARGIN_RED, width=2)
    canvas = img.convert("RGBA")
    # 제목 — 가운데
    x = (W - measure(title_font, title)) / 2
    draw_flow_text(canvas, title_font, title, x, TOP + LINE - 12, 54)
    # 본문 — 괘선 위에 얹되 베이스라인이 조금씩 출렁인다
    row = 2
    for ln in body:
        y = TOP + (row + 1) * LINE - 10 + int(3 * math.sin(row * 1.7))
        draw_flow_text(canvas, body_font, ln, 210, y, SIZE)
        row += 1
    # 서명 — 오른쪽 아래
    y = TOP + (row + 2) * LINE - 10
    x = W - 90 - measure(body_font, sign) * 1.12
    draw_flow_text(canvas, body_font, sign, x, y, 44)
    return canvas.convert("RGB")


def degrade(img):
    """degrade_photo.py와 같은 단계, 문서 가독성을 위해 약한 값 + 기울여 찍힘."""
    img = img.rotate(random.uniform(-1.1, 1.1), resample=Image.BICUBIC,
                     expand=True, fillcolor=(212, 206, 192))
    target = 960 * 720
    scale = math.sqrt(target / (img.width * img.height))
    w, h = max(1, round(img.width * scale)), max(1, round(img.height * scale))
    img = img.resize((w, h))
    px = img.load()
    for _ in range(w * h // 45):
        x, y = random.randrange(w), random.randrange(h)
        r, g, b = px[x, y]
        n = random.randint(-9, 9)
        px[x, y] = (max(0, min(255, r + n)),
                    max(0, min(255, g + n)),
                    max(0, min(255, b + n)))
    buf = _io.BytesIO()
    img.save(buf, "JPEG", quality=58)
    return Image.open(buf)


def main():
    clean_dir = None
    if "--clean" in sys.argv:
        clean_dir = sys.argv[sys.argv.index("--clean") + 1]
        os.makedirs(clean_dir, exist_ok=True)
    docs = json.load(_io.open(DOCS, encoding="utf-8"))
    os.makedirs(OUT, exist_ok=True)
    for stem, cid, title, sign, seed in PAGES:
        random.seed(seed)
        page = make_page(title, doctrine_lines(docs[cid]["body"]), sign)
        if clean_dir:
            page.save(os.path.join(clean_dir, stem + "_clean.png"))
        out = os.path.join(OUT, stem + ".png")
        degrade(page).save(out)
        print(stem, "->", out, os.path.getsize(out), "bytes")
    print("ok")


if __name__ == "__main__":
    main()
