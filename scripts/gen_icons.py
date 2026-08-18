"""누리OS 아이콘 생성. 사용: python scripts/gen_icons.py

바탕화면/타이틀바용 32x32와 탐색기 도구모음용 16x16을 모두 만든다.
이미 있는 파일은 건드리지 않는다(overwrite=True로 표시한 것만 다시 쓴다).
"""
from PIL import Image, ImageDraw
import os

OUT = os.path.join("games-src", "last-login", "assets", "img", "icons")
os.makedirs(OUT, exist_ok=True)

PAGE = (248, 248, 244)
PAGE_EDGE = (88, 88, 96)
INK = (120, 124, 148)
MANILA = (216, 180, 96)
MANILA_EDGE = (96, 72, 24)
MANILA_LIT = (238, 212, 142)
BRASS = (226, 182, 52)
STEEL = (150, 152, 160)
NAVY = (40, 52, 84)

def canvas(size=32):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))

def save(img, name, overwrite=True):
    path = os.path.join(OUT, name)
    if not overwrite and os.path.exists(path):
        return
    img.save(path)

# 폴더
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([2, 10, 29, 27], fill=(216, 180, 96), outline=(96, 72, 24))
d.rectangle([2, 6, 14, 12], fill=(216, 180, 96), outline=(96, 72, 24))
save(img, "folder.png", overwrite=False)
# 문서
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([6, 3, 25, 29], fill=(240, 240, 232), outline=(90, 90, 90))
for y in (9, 13, 17, 21):
    d.line([9, y, 22, y], fill=(120, 120, 140))
save(img, "doc.png", overwrite=False)
# 메신저(말풍선), 메일(봉투), 브라우저(지구), 휴지통(통), 사진(산) — 같은 방식으로 각각 도형 조합
img = canvas(); d = ImageDraw.Draw(img)
d.ellipse([3, 5, 28, 23], fill=(120, 200, 240), outline=(30, 90, 130))
d.polygon([(10, 22), (12, 28), (16, 22)], fill=(120, 200, 240))
save(img, "messenger.png", overwrite=False)
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([3, 8, 28, 24], fill=(240, 240, 232), outline=(90, 90, 90))
d.line([3, 8, 16, 17], fill=(90, 90, 90)); d.line([28, 8, 16, 17], fill=(90, 90, 90))
save(img, "mail.png", overwrite=False)
img = canvas(); d = ImageDraw.Draw(img)
d.ellipse([4, 4, 27, 27], fill=(90, 170, 220), outline=(20, 70, 110))
d.line([4, 16, 27, 16], fill=(20, 70, 110)); d.arc([9, 4, 22, 27], 0, 360, fill=(20, 70, 110))
save(img, "browser.png", overwrite=False)
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([8, 8, 23, 28], fill=(160, 168, 176), outline=(70, 74, 80))
d.rectangle([6, 5, 25, 8], fill=(160, 168, 176), outline=(70, 74, 80))
save(img, "trash.png", overwrite=False)
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([3, 5, 28, 26], fill=(200, 220, 240), outline=(80, 90, 100))
d.polygon([(6, 24), (14, 12), (20, 20), (24, 15), (27, 24)], fill=(80, 140, 90))
save(img, "photo.png", overwrite=False)

# ── 탐색기용 (2026-08-18 UI 개선) ──────────────────────────────────────────

# 텍스트 문서 — 흰 목록 배경 위에서도 읽히도록 테두리를 또렷하게, 면은 세로 그라데이션
PAPER_TOP = (255, 255, 253)
PAPER_BOTTOM = (222, 222, 214)
PAPER_EDGE = (108, 110, 118)
FOLD_FACE = (200, 200, 190)
LINE = (126, 132, 150)
X0, Y0, X1, Y1, FOLD = 6, 2, 25, 29, 8

img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([X0 + 1, Y1 + 1, X1 + 1, Y1 + 1], fill=(0, 0, 0, 70))   # 바닥 그림자
d.rectangle([X1 + 1, Y0 + FOLD + 1, X1 + 1, Y1 + 1], fill=(0, 0, 0, 70))  # 접힌 모서리 아래부터
for y in range(Y0, Y1 + 1):
    t = (y - Y0) / float(Y1 - Y0)
    d.line([X0, y, X1, y],
           fill=tuple(int(PAPER_TOP[i] + (PAPER_BOTTOM[i] - PAPER_TOP[i]) * t) for i in range(3)))
d.polygon([(X1 - FOLD, Y0), (X1, Y0 + FOLD), (X1, Y0)], fill=(0, 0, 0, 0))  # 접힌 자리를 비운다
d.polygon([(X1 - FOLD, Y0), (X1 - FOLD, Y0 + FOLD), (X1, Y0 + FOLD)], fill=FOLD_FACE)
d.line([(X0, Y0), (X1 - FOLD, Y0)], fill=PAPER_EDGE)
d.line([(X0, Y0), (X0, Y1)], fill=PAPER_EDGE)
d.line([(X0, Y1), (X1, Y1)], fill=PAPER_EDGE)
d.line([(X1, Y0 + FOLD), (X1, Y1)], fill=PAPER_EDGE)
d.line([(X1 - FOLD, Y0), (X1, Y0 + FOLD)], fill=PAPER_EDGE)
d.line([(X1 - FOLD, Y0), (X1 - FOLD, Y0 + FOLD)], fill=PAPER_EDGE)
d.line([(X1 - FOLD, Y0 + FOLD), (X1, Y0 + FOLD)], fill=PAPER_EDGE)
for y, right in ((13, 21), (16, 21), (19, 21), (22, 21), (25, 17)):
    d.line([9, y, right, y], fill=LINE)
save(img, "doc.png")

# 잠긴 폴더 — 이미 폴리시된 folder.png 위에 자물쇠만 얹어 스타일을 맞춘다
folder = Image.open(os.path.join(OUT, "folder.png")).convert("RGBA")
img = folder.copy(); d = ImageDraw.Draw(img)
BRASS_LIT = (252, 222, 124)
BRASS_MID = (230, 188, 66)
BRASS_DIM = (176, 134, 26)
BRASS_EDGE = (116, 86, 16)
STEEL_LIT = (222, 226, 232)
STEEL_MID = (156, 160, 170)
d.rectangle([17, 19, 29, 30], fill=(0, 0, 0, 60))          # 폴더와 분리하는 그림자
d.arc([20, 12, 28, 22], 180, 360, fill=STEEL_MID, width=3)  # 걸쇠
d.arc([21, 13, 27, 21], 180, 360, fill=STEEL_LIT, width=1)
d.rectangle([18, 19, 29, 29], fill=BRASS_MID, outline=BRASS_EDGE)
d.rectangle([19, 20, 28, 21], fill=BRASS_LIT)               # 윗면 하이라이트
d.rectangle([19, 27, 28, 28], fill=BRASS_DIM)               # 아랫면 음영
d.rectangle([23, 23, 24, 26], fill=BRASS_EDGE)              # 열쇠구멍
d.point((23, 22), fill=BRASS_EDGE); d.point((24, 22), fill=BRASS_EDGE)
save(img, "folder_locked.png")

# 도구모음 16x16 — 뒤로 / 위로 (본체+하이라이트 2톤, 주변 아이콘의 부드러운 결에 맞춤)
def _shaded(points, base, lit):
    im = canvas(16); dd = ImageDraw.Draw(im)
    dd.polygon(points, fill=base)
    dd.polygon([(x, y - 1) for (x, y) in points], fill=lit)
    dd.polygon(points, outline=(24, 32, 56))
    return im

save(_shaded([(3, 8), (9, 2), (9, 5), (13, 5), (13, 11), (9, 11), (9, 14)],
             (58, 108, 78), (108, 174, 118)), "nav_back.png")
save(_shaded([(8, 2), (14, 8), (11, 8), (11, 14), (5, 14), (5, 8), (2, 8)],
             (52, 84, 148), (108, 148, 210)), "nav_up.png")

# 보기 전환 16x16 — 납작한 UI 글리프 (사물 아이콘이 아니라 의도적으로 평면)
img = canvas(16); d = ImageDraw.Draw(img)
for bx in (2, 9):
    for by in (2, 9):
        d.rectangle([bx, by, bx + 4, by + 4], fill=PAGE, outline=NAVY)
save(img, "view_icons.png")
img = canvas(16); d = ImageDraw.Draw(img)
for by in (2, 6, 10):
    d.rectangle([2, by, 4, by + 2], fill=NAVY)
    d.line([7, by + 1, 14, by + 1], fill=NAVY)
save(img, "view_details.png")


# ── 위젯 글리프 (2026-08-18 OS 테마 패스) ─────────────────────────────────
# 체크박스·슬라이더 손잡이는 테마가 아이콘으로 받는다(스타일박스로는 못 그린다).

def _bevel_box(w, h, sunken):
    """2픽셀 베벨 상자. sunken이면 빛 방향이 뒤집힌다 (NuriTheme._bevel과 같은 규칙)."""
    lit_out, lit_in = (BEVEL_DIM_HARD, BEVEL_DIM) if sunken else (BEVEL_LIT, BEVEL_LIT_SOFT)
    dim_out, dim_in = (BEVEL_LIT, BEVEL_LIT_SOFT) if sunken else (BEVEL_DIM_HARD, BEVEL_DIM)
    face = FIELD if sunken else FACE
    im = canvas(max(w, h))
    im = Image.new("RGBA", (w, h), face)
    d = ImageDraw.Draw(im)
    d.line([(0, 0), (w - 1, 0)], fill=lit_out); d.line([(0, 0), (0, h - 1)], fill=lit_out)
    d.line([(1, 1), (w - 2, 1)], fill=lit_in);  d.line([(1, 1), (1, h - 2)], fill=lit_in)
    d.line([(0, h - 1), (w - 1, h - 1)], fill=dim_out); d.line([(w - 1, 0), (w - 1, h - 1)], fill=dim_out)
    d.line([(1, h - 2), (w - 2, h - 2)], fill=dim_in);  d.line([(w - 2, 1), (w - 2, h - 2)], fill=dim_in)
    return im

BEVEL_LIT = (251, 249, 242, 255)
BEVEL_LIT_SOFT = (236, 232, 220, 255)
BEVEL_DIM = (110, 106, 96, 255)
BEVEL_DIM_HARD = (56, 53, 46, 255)
FIELD = (253, 253, 248, 255)
FACE = (216, 212, 200, 255)

# 체크박스 — 파인 흰 상자, 켜지면 검은 체크
for on in (False, True):
    img = _bevel_box(14, 14, sunken=True); d = ImageDraw.Draw(img)
    if on:
        for x, y in [(3,7),(4,8),(5,9),(6,8),(7,7),(8,6),(9,5),(10,4)]:
            d.point((x, y), fill=(24, 28, 34)); d.point((x, y + 1), fill=(24, 28, 34))
    save(img, "check_on.png" if on else "check_off.png")

# 슬라이더 손잡이 — 튀어나온 세로 막대
save(_bevel_box(12, 22, sunken=False), "slider_grabber.png")

# 트레이 볼륨 — 어두운 작업표시줄 위에 얹힌다. 16px에서는 PIL의 arc/polygon이
# 뭉개져서 실루엣을 픽셀 집합으로 직접 정의하고 테두리는 팽창으로 만든다.
SPK = (238, 238, 230)
SPK_EDGE = (22, 38, 32)

SPEAKER = set()
for y, xs in [(3, [8]), (4, [7, 8]), (5, [6, 7, 8]),
              (6, range(2, 9)), (7, range(2, 9)), (8, range(2, 9)), (9, range(2, 9)),
              (10, [6, 7, 8]), (11, [7, 8]), (12, [8])]:
    for x in xs:
        SPEAKER.add((x, y))
WAVES = [(10, 5), (11, 6), (11, 7), (11, 8), (10, 9),
         (12, 3), (13, 4), (14, 5), (14, 6), (14, 7), (14, 8), (13, 9), (12, 10)]

img = canvas(16); d = ImageDraw.Draw(img)
for (x, y) in SPEAKER:                       # 테두리 = 실루엣 팽창
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if (x + dx, y + dy) not in SPEAKER and 0 <= x + dx < 16 and 0 <= y + dy < 16:
                d.point((x + dx, y + dy), fill=SPK_EDGE)
for (x, y) in SPEAKER:
    d.point((x, y), fill=SPK)
for (x, y) in WAVES:                          # 파형은 이어진 픽셀 사슬이라야 곡선으로 읽힌다
    d.point((x, y), fill=SPK)
save(img, "tray_volume.png")


# 접속 상태 점 (PC통신 상대 표시줄) — 16px에서 PIL ellipse는 들쭉날쭉해서 거리로 직접 찍는다
def _dot(fill, rim, lit):
    im = canvas(16); d = ImageDraw.Draw(im)
    cx = cy = 7.5
    for y in range(16):
        for x in range(16):
            dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if dist <= 4.6:
                d.point((x, y), fill=fill)
            elif dist <= 5.6:
                d.point((x, y), fill=rim)
    d.point((6, 5), fill=lit); d.point((7, 5), fill=lit); d.point((6, 6), fill=lit)
    return im

save(_dot((82, 192, 90), (24, 74, 34), (176, 232, 176)), "status_on.png")
save(_dot((150, 150, 142), (66, 66, 60), (206, 206, 198)), "status_off.png")

print("ok")
