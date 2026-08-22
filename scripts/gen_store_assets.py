"""크롬 웹 스토어 리스팅 이미지 생성. 사용: python scripts/gen_store_assets.py

만드는 것 (extension/store-assets/ 아래, zip에는 안 들어간다):
  promo-440x280.png       소형 프로모 타일 — 전부 코드로 그린다
  screenshot-1..3.png     1280x800 — 실제 게임플레이 캡처를 사이드 패널 목업에 합성

캡처는 사람이 찍어서 extension/store-assets/captures/에 넣어야 한다
(01-title.png / 02-combo.png / 03-gameover.png, 세로 270x480 비율).
없으면 프로모 타일만 만들고 어떤 파일이 필요한지 안내한다.
"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, "games-src", "starfall-drift")
OUT = os.path.join(ROOT, "extension", "store-assets")
CAPTURES = os.path.join(OUT, "captures")
FONT_PATH = os.path.join(GAME, "assets", "fonts", "Galmuri11.ttf")

# 사이트 팔레트 (src/app/globals.css)
BG = (20, 17, 39)
BG_DEEP = (12, 10, 28)
SURFACE = (29, 43, 83)
TEXT = (255, 241, 232)
DIM = (142, 153, 217)
ACCENT = (255, 119, 168)
GOLD = (255, 236, 39)

# 갈무리는 11의 배수에서 또렷하다
F11, F22, F33, F44 = 11, 22, 33, 44

SHOTS = [
    ("01-title.png", "탭 한 번으로 궤도를 바꾼다", "ONE BUTTON. ONE ORBIT."),
    ("02-combo.png", "연속으로 별을 갈아타 콤보를 쌓는다", "CHAIN STARS, STACK COMBOS."),
    ("03-gameover.png", "최고 기록은 브라우저에 남는다", "YOUR BEST RUN STAYS LOCAL."),
]


def font(size):
    return ImageFont.truetype(FONT_PATH, size)


def sprite(name):
    return Image.open(os.path.join(GAME, "assets", "img", name)).convert("RGBA")


def starfield(img, seed=7):
    """의사난수 별. random 대신 고정 수식 — 실행할 때마다 같은 그림이 나와야 한다."""
    d = ImageDraw.Draw(img)
    x, y = seed, seed * 3
    for i in range(140):
        x = (x * 1103515245 + 12345) % 2147483648
        y = (y * 1103515245 + 12345) % 2147483648
        px, py = x % img.width, y % img.height
        shade = (i % 3)
        color = [(90, 96, 150), (150, 158, 210), (235, 240, 255)][shade]
        size = 1 if shade < 2 else 2
        d.rectangle([px, py, px + size - 1, py + size - 1], fill=color)
    return img


def promo_tile():
    """440x280 소형 프로모 타일."""
    im = Image.new("RGBA", (440, 280), BG)
    starfield(im, seed=11)
    d = ImageDraw.Draw(im)

    # 아래쪽 자주빛 성운 띠
    for i, y in enumerate(range(200, 280)):
        t = (y - 200) / 80
        d.line([(0, y), (440, y)], fill=(
            int(BG[0] + (74 - BG[0]) * t * 0.5),
            int(BG[1] + (26 - BG[1]) * t * 0.5),
            int(BG[2] + (70 - BG[2]) * t * 0.5),
        ))

    emblem = sprite("emblem.png")  # 48x48
    emblem = emblem.resize((emblem.width * 3, emblem.height * 3), Image.NEAREST)
    im.alpha_composite(emblem, (28, 62))

    d.text((190, 96), "STARFALL", font=font(F33), fill=GOLD)
    d.text((190, 134), "DRIFT", font=font(F33), fill=ACCENT)
    d.text((191, 182), "ONE BUTTON ARCADE", font=font(F11), fill=TEXT)
    d.text((191, 200), "IN YOUR SIDE PANEL", font=font(F11), fill=DIM)

    d.rectangle([0, 0, 439, 279], outline=SURFACE)
    path = os.path.join(OUT, "promo-440x280.png")
    im.convert("RGB").save(path)
    print("wrote", path)


def panel_mockup(capture: Image.Image, panel_w=300, panel_h=620):
    """캡처를 크롬 사이드 패널 모양 틀에 넣는다. 확장 하단 바까지 재현."""
    footer_h = 24
    im = Image.new("RGBA", (panel_w, panel_h), BG_DEEP)
    d = ImageDraw.Draw(im)

    # 패널 상단 크롬 헤더 (사이드 패널 제목 줄)
    header_h = 32
    d.rectangle([0, 0, panel_w, header_h], fill=(44, 42, 60))
    icon = Image.open(os.path.join(ROOT, "extension", "starfall-drift", "icons", "icon16.png"))
    im.alpha_composite(icon.convert("RGBA"), (10, 8))
    d.text((32, 10), "STARFALL DRIFT", font=font(F11), fill=(220, 220, 232))

    # 게임 영역: 캡처를 폭에 맞춰 니어리스트 확대/축소
    game_h = panel_h - header_h - footer_h
    # 픽셀 아트라 배율이 중요하다: 확대는 니어리스트, 축소는 되도록 1/k 정수배(BOX 평균)로
    # 줄여 픽셀 격자를 유지하고, 정수배가 너무 작아질 때만 임의 배율로 맞춘다.
    fitted = capture.convert("RGBA")
    scale = min(panel_w / fitted.width, game_h / fitted.height)
    if scale >= 1:
        size = (int(fitted.width * scale), int(fitted.height * scale))
        fitted = fitted.resize(size, Image.NEAREST)
    else:
        k = int(1 / scale) + (0 if (1 / scale).is_integer() else 1)
        if fitted.width / k >= panel_w * 0.85:
            fitted = fitted.resize((fitted.width // k, fitted.height // k), Image.BOX)
        else:
            size = (max(1, int(fitted.width * scale)), max(1, int(fitted.height * scale)))
            fitted = fitted.resize(size, Image.BOX)
    size = fitted.size
    im.alpha_composite(fitted, ((panel_w - size[0]) // 2, header_h + (game_h - size[1]) // 2))

    # 확장 하단 바
    fy = panel_h - footer_h
    d.rectangle([0, fy, panel_w, panel_h], fill=BG_DEEP)
    d.line([(0, fy), (panel_w, fy)], fill=(42, 36, 80))
    label = "PIXELARIOUS ↗"
    w = d.textlength(label, font=font(F11))
    d.text(((panel_w - w) / 2, fy + 5), label, font=font(F11), fill=DIM)
    return im


def screenshot(capture: Image.Image, ko: str, en: str, index: int):
    """1280x800 스토어 스크린샷: 왼쪽 문구 + 오른쪽 브라우저·사이드 패널 목업."""
    im = Image.new("RGBA", (1280, 800), BG)
    starfield(im, seed=index * 17 + 3)
    d = ImageDraw.Draw(im)

    # 브라우저 창 목업
    win = (620, 60, 1240, 740)  # x0, y0, x1, y1
    d.rectangle(win, fill=(32, 30, 46), outline=SURFACE)
    d.rectangle([win[0], win[1], win[2], win[1] + 34], fill=(52, 50, 70))
    for i, color in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        cx = win[0] + 16 + i * 18
        d.ellipse([cx, win[1] + 12, cx + 10, win[1] + 22], fill=color)
    d.rounded_rectangle([win[0] + 76, win[1] + 8, win[2] - 16, win[1] + 26], 4, fill=(30, 28, 42))
    d.text((win[0] + 88, win[1] + 11), "pixelarious.online", font=font(F11), fill=DIM)

    # 왼쪽: 평범한 웹페이지 자리표시자 (사이드 패널이 다른 탭을 가리지 않음을 보여준다)
    page = (win[0] + 8, win[1] + 42, win[2] - 316, win[3] - 8)
    d.rectangle(page, fill=(24, 22, 36))
    for i in range(7):
        y = page[1] + 24 + i * 26
        d.rectangle([page[0] + 20, y, page[2] - 20 - (i % 3) * 40, y + 8], fill=(46, 44, 64))

    panel = panel_mockup(capture, panel_w=300, panel_h=win[3] - win[1] - 50)
    im.alpha_composite(panel, (win[2] - 308, win[1] + 42))

    # 왼쪽 문구
    d.text((72, 150), "STARFALL", font=font(F44), fill=GOLD)
    d.text((72, 204), "DRIFT", font=font(F44), fill=ACCENT)
    d.text((74, 300), ko, font=font(F22), fill=TEXT)
    d.text((74, 340), en, font=font(F11), fill=DIM)
    d.text((74, 640), "크롬 사이드 패널에서 바로 플레이", font=font(F11), fill=DIM)
    d.text((74, 662), "PLAY IN THE CHROME SIDE PANEL", font=font(F11), fill=DIM)

    path = os.path.join(OUT, f"screenshot-{index}-1280x800.png")
    im.convert("RGB").save(path)
    print("wrote", path)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(CAPTURES, exist_ok=True)
    promo_tile()

    missing = []
    for i, (name, ko, en) in enumerate(SHOTS, start=1):
        path = os.path.join(CAPTURES, name)
        if not os.path.exists(path):
            missing.append(name)
            continue
        screenshot(Image.open(path), ko, en, i)

    if missing:
        print()
        print("캡처가 없어 건너뛴 스크린샷:", ", ".join(missing))
        print(f"게임을 실제로 플레이해 세로 화면을 캡처하고 {CAPTURES}에 위 이름으로 넣은 뒤")
        print("이 스크립트를 다시 실행하세요. (스토어 규정상 실제 화면이어야 합니다.)")


if __name__ == "__main__":
    main()
