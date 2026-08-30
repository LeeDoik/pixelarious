# -*- coding: utf-8 -*-
"""필사 1~3 + 서원문 + 비움기록 손글씨 사진 생성 — 성진이 제출 전에 디카로 찍어둔 것.

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
PRINT_FONT = os.path.join("games-src", "last-login", "assets", "fonts", "Galmuri11.ttf")  # 교단 양식의 인쇄 글자
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


def vow_lines(body):
    """서원문 원본에 적혀 있던 것 — ※ 각주(타이핑 사본에만 있는 말)는 뺀다.
    한자 조항 번호(一~五)는 폰트에 없어 한글로 — 손으로 쓸 때 그렇게 썼다고 본다.
    (인)은 글자가 아니라 지장이 찍힐 자리다."""
    hanja = {"一.": "하나.", "二.": "둘.", "三.": "셋.", "四.": "넷.", "五.": "다섯."}
    out = []
    for ln in body.split("\n"):
        t = ln.strip()
        if t.startswith("※"):
            break
        for h, k in hanja.items():
            if t.startswith(h):
                t = k + t[len(h):]
        out.append(t.replace("(인)", "").rstrip())
    while out and out[0] == "":
        out.pop(0)
    while out and out[-1] == "":
        out.pop()
    return out


def draw_stamp(canvas, x, y):
    """인주 지장 — 거의 꽉 찬 붉은 타원에 융선이 결로 비치고,
    마디 주름이 가로지르며, 가장자리가 고르지 않게 뜩긴다."""
    W2, H2 = 150, 180
    mask = Image.new("L", (W2, H2), 0)
    d = ImageDraw.Draw(mask)
    cx, cy, rx, ry = 72, 92, 40, 60
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=138)        # 바탕은 통짜로
    for i in range(2, 14):                                           # 융선 결 — 진한 금과 옆은 금
        erx, ery = rx * i / 14.0, ry * i / 14.0
        for _ in range(random.randint(2, 4)):
            a0 = random.randint(0, 360)
            d.arc([cx - erx, cy - ery, cx + erx, cy + ery], a0,
                  a0 + random.randint(40, 130), fill=random.randint(190, 235), width=2)
        for _ in range(random.randint(1, 3)):
            a0 = random.randint(0, 360)
            d.arc([cx - erx, cy - ery, cx + erx, cy + ery], a0,
                  a0 + random.randint(30, 90), fill=random.randint(50, 85), width=2)
    for _ in range(2):                                               # 마디 주름
        yy = cy + random.randint(-24, 36)
        d.line([cx - rx - 5, yy, cx + rx + 5, yy + random.randint(-9, 9)],
               fill=random.randint(0, 30), width=random.randint(3, 4))
    for _ in range(130):                                             # 가장자리 뜩김
        a = random.uniform(0.0, 6.283)
        rr = random.uniform(0.94, 1.10)
        px_ = cx + math.cos(a) * rx * rr
        py_ = cy + math.sin(a) * ry * rr
        r2 = random.uniform(1.5, 5.0)
        d.ellipse([px_ - r2, py_ - r2, px_ + r2, py_ + r2], fill=0)
    for _ in range(70):                                              # 속의 잖은 빈 점
        a = random.uniform(0.0, 6.283)
        rr = random.uniform(0.0, 0.9) ** 0.5
        px_ = cx + math.cos(a) * rx * rr
        py_ = cy + math.sin(a) * ry * rr
        r2 = random.uniform(0.8, 2.2)
        d.ellipse([px_ - r2, py_ - r2, px_ + r2, py_ + r2], fill=random.randint(30, 70))
    mask = mask.filter(ImageFilter.GaussianBlur(0.7))
    st = Image.new("RGBA", (W2, H2), (172, 38, 30, 255))
    st.putalpha(mask)
    st = st.rotate(random.uniform(-14, 10), resample=Image.BICUBIC)
    canvas.alpha_composite(st, (int(x), int(y)))


def make_vow_page(lines):
    """민무늬 종이의 정식 문서 — 필사보다 또박또박, 셋으로 접었던 자국."""
    W, LINE, TOP, SIZE = 1440, 86, 190, 46
    title, rest = lines[0], lines[1:]
    while rest and rest[0] == "":
        rest.pop(0)
    body_font = ImageFont.truetype(FONT, SIZE)
    title_font = ImageFont.truetype(FONT, 66)
    body = wrap_flow(body_font, rest, W - 160 - 130)
    n = 3 + len(body)
    H = TOP + n * LINE + 170
    img = paper_base(W, H)
    d = ImageDraw.Draw(img, "RGBA")
    for fy in (H / 3.0, H * 2 / 3.0):   # 셋으로 접어 갖고 다닌 자국
        y = fy + random.uniform(-14, 14)
        d.line([30, y, W - 30, y], fill=(150, 138, 112, 34), width=2)
        d.line([30, y + 2, W - 30, y + 2], fill=(255, 255, 252, 40), width=1)
    canvas = img.convert("RGBA")
    x = (W - measure(title_font, title)) / 2
    draw_flow_text(canvas, title_font, title, x, TOP, 60)
    row = 2
    for ln in body:
        y = TOP + row * LINE + int(3 * math.sin(row * 1.9))
        if ln == "":
            row += 1
            continue
        if ln.startswith("새빛력"):
            x = (W - measure(body_font, ln) * 1.15) / 2      # 날짜는 가운데
            row += 1
        elif ln.startswith("서원자") or ln.startswith("입회인"):
            x = W * 0.34                                     # 서명부는 들여서
        else:
            x = 160
        x_end = draw_flow_text(canvas, body_font, ln, x, y, SIZE)
        if ln.startswith("서원자"):
            draw_stamp(canvas, x_end + 26, y - 118)          # (인) 자리의 지장
        row += 1
    return canvas.convert("RGB")


# 비움기록 — 교단 양식(인쇄된 칸·지시문)에 성진이 손으로 채운 것. §5.6 확정 텍스트.
# 필사 1의 순서(미련 → 계획 → 이름 → 가족). 가족 칸은 비어 있다. 지장 없음.
BIEUM_ROWS = [
    ("미련", "낙방 수기 지움. 채점표 지움. 봄이 일지 지움."),
    ("계획", "2002년 계획 지움. 이력서 지움. 자기소개서 지움."),
    ("이름", "마이홈 글 셋 지움."),
    ("가족", ""),
]
PRINT_INK = (46, 44, 48)         # 복사기 토너 — 검정에 가깝지만 완전한 검정은 아니다
FORM_RULE = (96, 92, 96, 220)


def draw_print(canvas, font, text, x, y, size, spacing=0.0):
    """인쇄 글자 — 지터 없이 또박또박. 복사본이라 토너가 살짝 튄다."""
    d = ImageDraw.Draw(canvas)
    f = font.font_variant(size=size)
    for ch in text:
        d.text((x, y), ch, font=f, fill=PRINT_INK + (random.randint(225, 255),))
        x += f.getlength(ch) + spacing
    return x


def print_width(font, text, size, spacing=0.0):
    f = font.font_variant(size=size)
    return sum(f.getlength(ch) + spacing for ch in text)


def make_form_page():
    """복사기로 뽑은 양식 한 장. 인쇄 칸은 게임 폰트(갈무리), 손글씨는 가람연꽃."""
    W, H = 1440, 1560
    HAND = 44
    img = paper_base(W, H)
    px = img.load()
    for _ in range(W * H // 900):     # 복사기 토너 가루
        x, y = random.randrange(W), random.randrange(H)
        px[x, y] = (random.randint(150, 200),) * 3
    canvas = img.convert("RGBA")
    pf = ImageFont.truetype(PRINT_FONT, 40)
    hf = ImageFont.truetype(FONT, HAND)
    d = ImageDraw.Draw(canvas, "RGBA")
    # 제목
    title = "비 움 기 록"
    tw = print_width(pf, title, 64, 6)
    draw_print(canvas, pf, title, (W - tw) / 2, 120, 64, 6)
    # 지시문
    guide = "비운 것을 적으십시오. 비우지 못한 것은 비워 두십시오."
    gw = print_width(pf, guide, 30)
    draw_print(canvas, pf, guide, (W - gw) / 2, 232, 30)
    # 표 — 라벨 칸 + 적는 칸
    left, right, top, row_h, label_w = 120, W - 120, 330, 160, 190
    rows = len(BIEUM_ROWS)
    for i in range(rows + 1):
        y = top + i * row_h
        d.line([left, y, right, y], fill=FORM_RULE, width=3)
    d.line([left, top, left, top + rows * row_h], fill=FORM_RULE, width=3)
    d.line([left + label_w, top, left + label_w, top + rows * row_h], fill=FORM_RULE, width=3)
    d.line([right, top, right, top + rows * row_h], fill=FORM_RULE, width=3)
    for i, (label, hand) in enumerate(BIEUM_ROWS):
        y = top + i * row_h
        lw = print_width(pf, label, 40, 4)
        draw_print(canvas, pf, label, left + (label_w - lw) / 2, y + 58, 40, 4)
        if hand == "":
            continue
        lines = wrap_flow(hf, [hand], right - (left + label_w) - 70)
        for j, ln in enumerate(lines):
            by = y + 66 + j * 62 + random.randint(-2, 3)
            draw_flow_text(canvas, hf, ln, left + label_w + 34 + random.randint(0, 6), by, HAND)
    # 날짜 — "새빛력    년    월    일"에 손으로 4 / 9 / 30
    y_date = top + rows * row_h + 150
    x = W * 0.42
    x = draw_print(canvas, pf, "새빛력", x, y_date, 36, 2) + 40
    x_gap = x
    x = draw_print(canvas, pf, "년", x + 70, y_date, 36) + 40
    draw_flow_text(canvas, hf, "4", x_gap + 18, y_date + 40, 44)
    x_gap = x
    x = draw_print(canvas, pf, "월", x + 70, y_date, 36) + 40
    draw_flow_text(canvas, hf, "9", x_gap + 18, y_date + 40, 44)
    x_gap = x
    x = draw_print(canvas, pf, "일", x + 100, y_date, 36)
    draw_flow_text(canvas, hf, "30", x_gap + 14, y_date + 40, 44)
    # 서명 — "비운 자 ________ (인)"에 손으로 새 벽. 지장은 없다.
    y_sign = y_date + 110
    x = W * 0.42
    x = draw_print(canvas, pf, "비운 자", x, y_sign, 36, 2) + 60
    x_blank0 = x
    d.line([x, y_sign + 52, x + 300, y_sign + 52], fill=FORM_RULE, width=2)
    draw_print(canvas, pf, "(인)", x + 330, y_sign, 36)
    draw_flow_text(canvas, hf, "새 벽", x_blank0 + 70, y_sign + 42, 50, space_mul=2.2)
    return canvas.convert("RGB")


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
    # 서원문 — 제출 전에 찍어둔 원본. 교단이 가진 그 한 장을 그도 갖고 있었다.
    random.seed(20020930)
    page = make_vow_page(vow_lines(docs["doc:vow"]["body"]))
    if clean_dir:
        page.save(os.path.join(clean_dir, "vow_photo_clean.png"))
    out = os.path.join(OUT, "vow_photo.png")
    degrade(page).save(out)
    print("vow_photo ->", out, os.path.getsize(out), "bytes")
    # 비움기록 — 서원한 그 밤(backup_0930 삭제 00:03과 같은 밤)에 찍어둔 제출본.
    random.seed(20021001)
    page = make_form_page()
    if clean_dir:
        page.save(os.path.join(clean_dir, "bieum_record_clean.png"))
    out = os.path.join(OUT, "bieum_record.png")
    degrade(page).save(out)
    print("bieum_record ->", out, os.path.getsize(out), "bytes")
    print("ok")


if __name__ == "__main__":
    main()
