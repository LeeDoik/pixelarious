"""크롬 확장 아이콘 생성. 사용: python scripts/gen_extension_icons.py

16x16 픽셀 아트 한 장을 그린 뒤 니어리스트로 정수배 확대해 16/32/48/128을 뽑는다
(x1, x2, x3, x8 — 모두 정수배라 픽셀이 뭉개지지 않는다).
모티프는 게임 엠블럼(games-src/starfall-drift/assets/img/emblem.png)의 떨어지는 별:
노란 별 머리 + 마젠타 꼬리, 게임 배경색 톤의 어두운 타일 위.
"""
from PIL import Image
import os

OUT = os.path.join("extension", "starfall-drift", "icons")
SIZES = (16, 32, 48, 128)

BG = (20, 17, 39, 255)       # 사이트 --bg #141127
Y = (252, 208, 29, 255)       # 별 머리
L = (253, 249, 177, 255)      # 머리 하이라이트
O = (242, 118, 5, 255)        # 머리 가장자리
P = (254, 53, 169, 255)       # 꼬리
M = (179, 0, 97, 255)         # 꼬리 끝
W = (251, 246, 246, 255)      # 배경 별
T = (0, 0, 0, 0)              # 투명(모서리)

PALETTE = {".": BG, "Y": Y, "L": L, "O": O, "P": P, "M": M, "W": W, " ": T}

# 16x16. 오른쪽 위 별 머리에서 왼쪽 아래로 흐르는 꼬리.
ART = [
    "................",
    "...........O....",
    "..........OYYO..",
    "...W.....OYLLYO.",
    "........OYLLYYO.",
    ".......PPYYYO...",
    "......PPPYO...W.",
    ".....PPPP.......",
    "....PPPM........",
    "...MPPM.........",
    "..MMPM..........",
    "..MM....W.......",
    ".M..............",
    "................",
    "................",
    "................",
]
WIDTH = 16


def build_base() -> Image.Image:
    rows = [line.ljust(WIDTH, ".")[:WIDTH] for line in ART]
    assert len(rows) == 16, len(rows)

    img = Image.new("RGBA", (WIDTH, 16), BG)
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            px[x, y] = PALETTE[ch]

    # 모서리 1px씩 잘라 타일을 살짝 둥글게
    for x, y in ((0, 0), (15, 0), (0, 15), (15, 15)):
        px[x, y] = T
    return img


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    base = build_base()
    for size in SIZES:
        assert size % 16 == 0 or size == 48, size
        img = base.resize((size, size), Image.NEAREST)
        path = os.path.join(OUT, f"icon{size}.png")
        img.save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
