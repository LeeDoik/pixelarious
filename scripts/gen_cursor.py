"""2002풍 픽셀 마우스 커서 생성 (화살표 + I빔).
사용: python scripts/gen_cursor.py → game/assets/img/cursor_*.png"""
from PIL import Image
import os

OUT = os.path.join("game", "assets", "img")
BLACK = (16, 20, 24, 255)
WHITE = (240, 241, 232, 255)

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

def render(rows, name):
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(rows):
        for x, chc in enumerate(row):
            if chc == "X":
                px[x, y] = BLACK
            elif chc == "o":
                px[x, y] = WHITE
    # 2배 확대 (선명한 픽셀 유지)
    img = img.resize((w * 2, len(rows) * 2), Image.NEAREST)
    img.save(os.path.join(OUT, name))
    print(name, img.size)

os.makedirs(OUT, exist_ok=True)
render(ARROW, "cursor_arrow.png")
render(IBEAM, "cursor_ibeam.png")
