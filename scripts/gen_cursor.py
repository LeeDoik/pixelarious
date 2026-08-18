"""2002풍 픽셀 마우스 커서 생성 (화살표 · I빔 · 크기조절 4종 · 분할선 2종).
사용: python scripts/gen_cursor.py → games-src/last-login/assets/img/cursor_*.png

크기조절/분할선 커서는 실루엣만 정의하고 검정 테두리는 계산으로 두른다.
손으로 아스키를 그리면 대각선에서 테두리 두께가 들쭉날쭉해진다.
"""
from PIL import Image
import os

OUT = os.path.join("games-src", "last-login", "assets", "img")
BLACK = (16, 20, 24, 255)
WHITE = (240, 241, 232, 255)
SCALE = 2

ARROW = [
    "X..........",
    "XX.........",
    "XoX........",
    "XooX.......",
    "XoooX......",
    "XooooX.....",
    "XoooooX....",
    "XooooooX...",
    "XoooooooX..",
    "XooooooooX.",
    "XoooooXXXXX",
    "XooXooX....",
    "XoX.XooX...",
    "XX..XooX...",
    "X....XooX..",
    ".....XooX..",
    "......XX...",
]
IBEAM = [
    "XX.XX",
    "..X..",
    "..X..",
    "..X..",
    "..X..",
    "..X..",
    "..X..",
    "..X..",
    "..X..",
    "..X..",
    "..X..",
    "..X..",
    "..X..",
    "..X..",
    "..X..",
    "..X..",
    "XX.XX",
]


def save(img, name, overwrite=True):
    path = os.path.join(OUT, name)
    if not overwrite and os.path.exists(path):
        return
    img = img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)
    img.save(path)
    print(name, img.size)


def render(rows, name, overwrite=True):
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "X":
                px[x, y] = BLACK
            elif ch == "o":
                px[x, y] = WHITE
    save(img, name, overwrite)


def outlined(cells, w, h):
    """흰 실루엣에 1픽셀 검정 테두리를 두른 이미지. 캔버스는 사방 1픽셀씩 커진다."""
    img = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    px = img.load()
    for (x, y) in cells:
        px[x + 1, y + 1] = WHITE
    for y in range(h + 2):
        for x in range(w + 2):
            if px[x, y] == WHITE:
                continue
            touching = any(
                0 <= x + dx < w + 2 and 0 <= y + dy < h + 2 and px[x + dx, y + dy] == WHITE
                for dy in (-1, 0, 1) for dx in (-1, 0, 1)
            )
            if touching:
                px[x, y] = BLACK
    return img


def head(cells, tip_x, tip_y, depth, horizontal, sign):
    """꼭짓점에서 depth만큼 퍼지는 삼각 화살촉."""
    for d in range(depth):
        for off in range(-d, d + 1):
            if horizontal:
                cells.add((tip_x + sign * d, tip_y + off))
            else:
                cells.add((tip_x + off, tip_y + sign * d))


def size_arrow(length=13, thickness=7, depth=4, horizontal=True):
    """양쪽에 화살촉이 달린 크기조절 커서. 축은 3픽셀 두께."""
    cells = set()
    c = thickness // 2
    if horizontal:
        head(cells, 0, c, depth, True, 1)
        head(cells, length - 1, c, depth, True, -1)
        for x in range(depth - 1, length - depth + 1):
            for y in range(c - 1, c + 2):
                cells.add((x, y))
        return cells, length, thickness
    head(cells, c, 0, depth, False, 1)
    head(cells, c, length - 1, depth, False, -1)
    for y in range(depth - 1, length - depth + 1):
        for x in range(c - 1, c + 2):
            cells.add((x, y))
    return cells, thickness, length


def diag_arrow(n=13, corner=6, mirror=False):
    """대각 크기조절 커서. 모서리 삼각형 두 개를 3픽셀 대각 축이 잇는다."""
    cells = set()
    for y in range(n):
        for x in range(n):
            if abs(x - y) <= 1 or x + y <= corner - 1 or (n - 1 - x) + (n - 1 - y) <= corner - 1:
                cells.add((x, y))
    if mirror:
        cells = {(n - 1 - x, y) for (x, y) in cells}
    return cells, n, n


def split_arrow(length=15, thickness=7, depth=4, horizontal=True):
    """분할선 커서: 축 대신 가운데 막대, 양옆에 화살촉만. 틈은 테두리가 먹지 않게 3픽셀."""
    cells = set()
    c = thickness // 2
    mid = length // 2
    if horizontal:
        head(cells, 0, c, depth, True, 1)
        head(cells, length - 1, c, depth, True, -1)
        for y in range(thickness):
            cells.add((mid, y))
        return cells, length, thickness
    head(cells, c, 0, depth, False, 1)
    head(cells, c, length - 1, depth, False, -1)
    for x in range(thickness):
        cells.add((x, mid))
    return cells, thickness, length


os.makedirs(OUT, exist_ok=True)
render(ARROW, "cursor_arrow.png", overwrite=False)
render(IBEAM, "cursor_ibeam.png", overwrite=False)

# 창 가장자리를 끌 때 뜨는 커서들 — 여기가 기본 커서로 남으면 창 모서리에서만 2002년이 깨진다
for name, (cells, w, h) in [
    ("cursor_hsize.png", size_arrow(horizontal=True)),
    ("cursor_vsize.png", size_arrow(horizontal=False)),
    ("cursor_fdiag.png", diag_arrow(mirror=False)),   # ↖↘ 오른쪽-아래 모서리
    ("cursor_bdiag.png", diag_arrow(mirror=True)),    # ↗↙ 왼쪽-아래 모서리
    ("cursor_hsplit.png", split_arrow(horizontal=True)),
    ("cursor_vsplit.png", split_arrow(horizontal=False)),
]:
    # 핫스팟은 전부 이미지 정중앙이다 (Fx가 그렇게 등록한다) — 가로세로가 짝수여야 어긋나지 않는다
    img = outlined(cells, w, h)
    assert (img.width * SCALE) % 2 == 0 and (img.height * SCALE) % 2 == 0, name
    save(img, name)
