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


# 누리메일 (2026-08-18) — 목록 첫 열의 봉투/클립, 하단 첨부 막대의 잠긴 문서
PAPER = (246, 246, 238)
PAPER_IN = (214, 214, 204)
EDGE = (58, 62, 70)
CLIP = (150, 154, 164)
CLIP_LIT = (206, 210, 218)

def _ascii(rows, palette, scale=1):
    w = max(len(r) for r in rows)
    im = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in palette:
                px[x, y] = palette[ch]
    if scale > 1:
        im = im.resize((w * scale, len(rows) * scale), Image.NEAREST)
    return im

# 안 읽은 메일 = 닫힌 봉투 (덮개가 아래를 향한 V)
save(_ascii([
    "................",
    "................",
    "................",
    "..############..",
    "..#oooooooooo#..",
    "..#Xoooooooo X..",
    "..#oXoooooo Xo..",
    "..#ooXoooo Xoo..",
    "..#oooXoo Xooo..",
    "..#ooooXXXoooo..",
    "..#oooooooooo#..",
    "..############..",
    "................",
    "................",
    "................",
    "................",
], {"#": EDGE, "o": PAPER, "X": (150, 152, 158)}), "mail_unread.png")

# 읽은 메일 = 덮개가 위로 젖혀진 봉투 (몸통은 흰색 + 편지 띠 — 안 그러면 회색 상자로 읽힌다)
save(_ascii([
    "................",
    "................",
    ".......##.......",
    "......#oo#......",
    ".....#oooo#.....",
    "....#oooooo#....",
    "...#oooooooo#...",
    "..############..",
    "..#oooooooooo#..",
    "..#oIIIIIIIIo#..",
    "..#oIIIIIIIIo#..",
    "..#oooooooooo#..",
    "..############..",
    "................",
    "................",
    "................",
], {"#": EDGE, "o": PAPER, "I": PAPER_IN}), "mail_read.png")

# 첨부 클립 — 세로 겹고리는 16px에서 사각형으로 뭉개진다. 대각선이라야 두 줄이 갈린다.
img = canvas(16); d = ImageDraw.Draw(img)
outer = [(x, 13 - x) for x in range(3, 11)]          # 왼쪽-아래 → 오른쪽-위
inner = [(x, 17 - x) for x in range(6, 14)]          # 4px 안쪽으로 나란히
bottom = [(2, 11), (2, 12), (3, 13), (4, 13), (5, 13), (6, 12)]   # 아래를 감아 잇는다
hook = [(11, 2), (12, 2), (13, 2), (14, 3), (14, 4)]              # 위로 넘어가는 고리
tail = [(x, 15 - x) for x in range(8, 13)]           # 안쪽으로 되꺾여 멈추는 끝
for pts in (outer, inner, bottom, hook, tail):
    for (x, y) in pts:
        if 0 <= x < 16 and 0 <= y < 16:
            d.point((x, y), fill=CLIP)
for (x, y) in [(3, 10), (6, 11), (13, 2)]:
    d.point((x, y), fill=CLIP_LIT)
save(img, "clip.png")

# 잠긴 첨부 = 문서 위에 자물쇠 (folder_locked과 같은 합성 방식)
doc = Image.open(os.path.join(OUT, "doc.png")).convert("RGBA")
img = doc.copy(); d = ImageDraw.Draw(img)
d.rectangle([17, 19, 29, 30], fill=(0, 0, 0, 60))
d.arc([20, 12, 28, 22], 180, 360, fill=STEEL_MID, width=3)
d.arc([21, 13, 27, 21], 180, 360, fill=STEEL_LIT, width=1)
d.rectangle([18, 19, 29, 29], fill=BRASS_MID, outline=BRASS_EDGE)
d.rectangle([19, 20, 28, 21], fill=BRASS_LIT)
d.rectangle([19, 27, 28, 28], fill=BRASS_DIM)
d.rectangle([23, 23, 24, 26], fill=BRASS_EDGE)
d.point((23, 22), fill=BRASS_EDGE); d.point((24, 22), fill=BRASS_EDGE)
save(img, "attach_locked.png")


# 누리넷 (2026-08-18) — 도구모음 · 즐겨찾기 막대 · 오프라인 표시
GOLD = (240, 190, 60)
GOLD_EDGE = (140, 100, 12)
GOLD_LIT = (254, 230, 150)
GLOBE = (96, 156, 208)
GLOBE_EDGE = (26, 62, 104)
GLOBE_LIT = (186, 220, 244)
BRICK = (206, 132, 96)
BRICK_EDGE = (96, 52, 32)
SLASH = (196, 52, 52)

# 앞으로 = 뒤로를 좌우 반전 (한 쌍으로 읽히게)
back = Image.open(os.path.join(OUT, "nav_back.png")).convert("RGBA")
save(back.transpose(Image.FLIP_LEFT_RIGHT), "nav_forward.png")

# 홈
save(_ascii([
    "................",
    "................",
    ".......##.......",
    "......#EE#......",
    ".....#EEEE#.....",
    "....#EEEEEE#....",
    "...#EEEEEEEE#...",
    "..#EEEEEEEEEE#..",
    ".##############.",
    "..#..........#..",
    "..#...####...#..",
    "..#...#DD#...#..",
    "..#...#DD#...#..",
    "..############..",
    "................",
    "................",
], {"#": BRICK_EDGE, "E": BRICK, "D": (72, 48, 32)}), "nav_home.png")

# 새로고침 — 열린 고리 + 화살촉 (16px에서 완전한 원은 뭉갠다)
save(_ascii([
    "................",
    "................",
    "....######......",
    "...##....##.....",
    "..##......##.##.",
    "..##.......####.",
    "..##........##..",
    "..##............",
    "..##............",
    "...##....##.....",
    "....######......",
    "................",
    "................",
    "................",
    "................",
    "................",
], {"#": (60, 104, 150)}), "nav_reload.png")

# 즐겨찾기 별 — 위 꼭짓점이 폭을 2→4→6으로 키우다 팔로 벌어져야 별로 읽힌다.
# 얇은 꼭지 밑에 넓은 팔을 바로 붙이면 별이 아니라 받침대처럼 보인다.
save(_ascii([
    "................",
    ".......LL.......",
    ".......LL.......",
    "......LLLL......",
    "......LLLL......",
    ".....LLLLLL.....",
    "################",
    ".##############.",
    "..############..",
    "...##########...",
    "...####..####...",
    "..####....####..",
    ".####......####.",
    "................",
    "................",
    "................",
], {"#": GOLD, "L": GOLD_LIT}), "star.png")

def _globe(extra=None):
    im = _ascii([
        "................",
        "................",
        ".....######.....",
        "...##oooooo##...",
        "..#oooooooooo#..",
        "..#oooooooooo#..",
        ".#oooooooooooo#.",
        ".#############.",
        ".#oooooooooooo#.",
        "..#oooooooooo#..",
        "..#oooooooooo#..",
        "...##oooooo##...",
        ".....######.....",
        "................",
        "................",
        "................",
    ], {"#": GLOBE_EDGE, "o": GLOBE})
    d = ImageDraw.Draw(im)
    for y in range(3, 13):                 # 세로 경선
        d.point((7, y), fill=GLOBE_EDGE)
    d.point((5, 4), fill=GLOBE_LIT); d.point((6, 4), fill=GLOBE_LIT)
    if extra:
        extra(d)
    return im

save(_globe(), "site_portal.png")
save(_globe(lambda d: [d.line([(2, 13), (13, 2)], fill=SLASH), d.line([(2, 12), (12, 2)], fill=SLASH)]), "offline.png")

# 카페 = 게시판
save(_ascii([
    "................",
    "................",
    "..############..",
    "..#oooooooooo#..",
    "..#o########o#..",
    "..#oooooooooo#..",
    "..#o######ooo#..",
    "..#oooooooooo#..",
    "..#o########o#..",
    "..#oooooooooo#..",
    "..############..",
    "....##....##....",
    "...##......##...",
    "................",
    "................",
    "................",
], {"#": (110, 92, 68), "o": (246, 240, 224)}), "site_cafe.png")

# 마이홈 = 작은 창 + 하트 (미니홈피). 각 줄이 정확히 16칸이어야 창틀이 안 깨진다.
save(_ascii([
    "................",
    "................",
    "..############..",
    "..#BBBBBBBBBB#..",
    "..############..",
    "..#oooooooooo#..",
    "..#ooHHooHHoo#..",
    "..#oHHHHHHHHo#..",
    "..#oHHHHHHHHo#..",
    "..#ooHHHHHHoo#..",
    "..#oooHHHHooo#..",
    "..#ooooHHoooo#..",
    "..############..",
    "................",
    "................",
    "................",
], {"#": (120, 96, 132), "B": (176, 150, 190), "o": (250, 244, 250), "H": (168, 72, 96)}), "site_myhome.png")

# 캐시 = 저장된 문서 (상태표시줄)
save(_ascii([
    "................",
    "................",
    "..###########...",
    "..#ooooooooo#...",
    "..#o#######o#...",
    "..#o#######o#...",
    "..#ooooooooo#...",
    "..#ooooooooo#...",
    "..#o#######o#...",
    "..#o#######o#...",
    "..#o#######o#...",
    "..###########...",
    "................",
    "................",
    "................",
    "................",
], {"#": (86, 92, 104), "o": (222, 226, 234)}), "cache.png")

print("ok")

# ── 휴지통 (2026-08-19 UI 개선) ───────────────────────────────────────────
# 휴지통 창은 탐색기 껍데기를 쓴다 — 도구모음의 복원/비우기, 주소줄의 통,
# 복원 실패 대화상자의 경고 표지가 여기서 나온다.

BIN_FACE = (166, 172, 182)
BIN_RIB = (128, 134, 146)
BIN_LIT = (214, 218, 226)
BIN_EDGE = (62, 66, 74)
RED = (198, 46, 46)
RED_EDGE = (108, 18, 18)
GREEN = (86, 166, 78)
GREEN_LIT = (168, 216, 150)
GREEN_EDGE = (26, 82, 30)

def _bin16():
    """16px 휴지통 — 주소줄과 비우기 버튼이 같은 통을 쓴다."""
    im = canvas(16); d = ImageDraw.Draw(im)
    d.rectangle([6, 0, 9, 1], fill=BIN_FACE, outline=BIN_EDGE)     # 뚜껑 손잡이
    d.rectangle([2, 2, 13, 4], fill=BIN_FACE, outline=BIN_EDGE)    # 뚜껑
    d.polygon([(3, 5), (12, 5), (11, 15), (4, 15)], fill=BIN_FACE, outline=BIN_EDGE)
    for x in (6, 8, 10):
        d.line([x, 7, x - 1, 14], fill=BIN_RIB)                    # 통의 세로 홈 (아래로 좁아진다)
    d.line([4, 6, 4, 14], fill=BIN_LIT)                            # 왼쪽 하이라이트
    return im

save(_bin16(), "trash_bin.png")

# 복원 = 위로 꺼내는 화살표 + 바닥 선. 비우기와 한눈에 갈려야 한다.
save(_ascii([
    "................",
    ".......##.......",
    "......#gG#......",
    ".....#gGGG#.....",
    "....#gGGGGG#....",
    "...#gGGGGGGG#...",
    "..#gGGGGGGGGG#..",
    "..###gGGGGG###..",
    "....#gGGGGG#....",
    "....#gGGGGG#....",
    "....#gGGGGG#....",
    "....########....",
    "................",
    "..############..",
    "..#LLLLLLLLLL#..",
    "..############..",
], {"#": GREEN_EDGE, "G": GREEN, "g": GREEN_LIT, "L": (196, 228, 186)}), "restore.png")

# 휴지통 비우기 = 통 + 붉은 X 배지 (통만 두면 주소줄 아이콘과 구별이 안 된다)
img = canvas(16); d = ImageDraw.Draw(img)
d.rectangle([4, 0, 6, 1], fill=BIN_FACE, outline=BIN_EDGE)          # 뚜껑 손잡이
d.rectangle([0, 2, 10, 4], fill=BIN_FACE, outline=BIN_EDGE)         # 뚜껑
d.polygon([(1, 5), (9, 5), (8, 14), (2, 14)], fill=BIN_FACE, outline=BIN_EDGE)
for x in (4, 6):
    d.line([x, 7, x, 13], fill=BIN_RIB)
d.line([2, 6, 3, 13], fill=BIN_LIT)
# 배지는 두 픽셀 두께라야 16px에서 X로 읽힌다 — 어두운 테두리로 통에서 떼어놓는다
for i in range(7):
    for dx, dy in ((0, 0), (1, 0), (0, 1)):
        d.point((9 + i + dx, 9 + i + dy), fill=RED_EDGE)
        d.point((15 - i + dx, 9 + i + dy), fill=RED_EDGE)
for i in range(6):
    d.point((10 + i, 10 + i), fill=RED)
    d.point((15 - i, 10 + i), fill=RED)
save(img, "purge.png")

# 복원 실패 대화상자의 경고 표지 (32px — OSDialog 아이콘 자리)
img = canvas(32); d = ImageDraw.Draw(img)
d.polygon([(16, 2), (31, 29), (1, 29)], fill=(120, 86, 10))
d.polygon([(16, 4), (29, 28), (3, 28)], fill=(246, 206, 58))
d.polygon([(16, 6), (27, 27), (5, 27)], outline=(254, 236, 152))
d.rectangle([14, 12, 17, 21], fill=(28, 22, 4))
d.rectangle([14, 23, 17, 26], fill=(28, 22, 4))
save(img, "warn.png")

# 바탕화면 휴지통 32px 다시 그리기 — 예전 것은 회색 상자 두 개였다
img = canvas(32); d = ImageDraw.Draw(img)
# 뚜껑 밑에서 비스듬히 삐져나온 종이 한 장 (똑바로 세우면 별개 상자로 읽힌다)
d.polygon([(17, 9), (22, 0), (30, 4), (25, 10)], fill=PAGE, outline=PAGE_EDGE)
d.line([21, 4, 26, 6], fill=INK); d.line([20, 6, 24, 8], fill=INK)
d.rectangle([13, 2, 18, 4], fill=BIN_FACE, outline=BIN_EDGE)                   # 뚜껑 손잡이
d.rectangle([4, 5, 27, 9], fill=BIN_FACE, outline=BIN_EDGE)                    # 뚜껑
d.line([5, 6, 26, 6], fill=BIN_LIT)
d.polygon([(6, 10), (25, 10), (22, 30), (9, 30)], fill=BIN_FACE, outline=BIN_EDGE)
for x, x2 in ((11, 12), (15, 15), (19, 18)):
    d.line([x, 12, x2, 28], fill=BIN_RIB)
d.line([8, 12, 10, 28], fill=BIN_LIT)
save(img, "trash.png")
