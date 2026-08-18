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

print("ok")
