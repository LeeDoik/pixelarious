"""누리넷(LAST LOGIN 브라우저)의 웹 그래픽 조립. 실행: python scripts/gen_web_banners.py

PixelLab이 만든 그림(gen_pixellab_lastlogin.py)에 한글 글자와 2002년식 틀을 얹는다.
AI는 한글을 못 그리므로 글자는 게임 폰트(Neo둥근모)로 직접 찍는다.
미니홈피 사진은 이미 있는 assets/img/photos를 잘라 쓴다 — 서사와 같은 사진이라야 한다.
"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, "games-src", "last-login")
OUT = os.path.join(GAME, "assets", "img", "web")
PHOTOS = os.path.join(GAME, "assets", "img", "photos")
FONT = os.path.join(GAME, "assets", "fonts", "neodgm.ttf")

# 둥근모는 16의 배수에서만 또렷하다 (비트맵에서 온 폰트)
BIG, MID, SMALL = 32, 24, 16


def font(size):
    return ImageFont.truetype(FONT, size)


def art(name):
    return Image.open(os.path.join(OUT, name + ".png")).convert("RGBA")


def gradient(size, top, bottom):
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    for y in range(size[1]):
        t = y / max(size[1] - 1, 1)
        d.line([(0, y), (size[0], y)],
               fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return im


def frame(im, color, inner=None):
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, im.width - 1, im.height - 1], outline=color)
    if inner:
        d.rectangle([1, 1, im.width - 2, im.height - 2], outline=inner)
    return im


def star(d, cx, cy, r, color):
    """둥근모에 U+2605가 없어 두부로 나온다 — 별은 직접 찍는다."""
    import math
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rad = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    d.polygon(pts, fill=color)


def paste(base, sprite, xy):
    base.paste(sprite, xy, sprite)


def save(im, name):
    im.convert("RGBA").save(os.path.join(OUT, name + ".png"))
    print("  %-22s %dx%d" % (name, im.width, im.height))


# ── 포털 ──────────────────────────────────────────────────────────────────

def build_logo_nurinet():
    im = gradient((228, 56), (255, 255, 255), (206, 224, 246))
    frame(im, (31, 79, 160))
    paste(im, art("mark_portal"), (10, 12))
    d = ImageDraw.Draw(im)
    d.text((50, 8), "누리넷", font=font(BIG), fill=(20, 56, 140))
    d.text((52, 38), "대한민국 대표 포털", font=font(SMALL), fill=(90, 110, 150))
    save(im, "logo_nurinet")


def build_ad_ringtone():
    # 2002년 띠광고. 두 프레임을 번갈아 띄워 GIF처럼 깜빡인다.
    for idx, (top, bottom, star_color, head) in enumerate([
        ((236, 84, 160), (146, 40, 128), (255, 236, 120), (255, 255, 255)),
        ((146, 40, 128), (236, 84, 160), (255, 255, 255), (255, 236, 120)),
    ]):
        im = gradient((468, 60), top, bottom)
        frame(im, (255, 236, 120), (110, 20, 96))
        paste(im, art("art_ringtone"), (8, 6))
        d = ImageDraw.Draw(im)
        d.text((64, 6), "무료 벨소리 3곡", font=font(BIG), fill=head)
        d.text((66, 40), "컬러링도 공짜!! 지금 바로 신청하세요", font=font(SMALL), fill=(255, 236, 236))
        for x in (432, 450):
            star(d, x, 15, 7, star_color)
        d.text((424, 30), "광고", font=font(SMALL), fill=(255, 220, 220))
        save(im, "ad_ringtone_%s" % "ab"[idx])


# ── 카페 ──────────────────────────────────────────────────────────────────

def build_banner_gongsi():
    im = gradient((468, 72), (252, 252, 236), (206, 220, 172))
    frame(im, (76, 122, 52))
    paste(im, art("art_study"), (10, 12))
    d = ImageDraw.Draw(im)
    d.text((68, 10), "9급 공시생 모임", font=font(BIG), fill=(38, 74, 30))
    d.text((70, 46), "회원 4,102명 · 개설 2000.03.14 · 등급 새싹", font=font(SMALL), fill=(84, 104, 62))
    save(im, "banner_gongsi")


def build_banner_board():
    im = gradient((468, 24), (226, 234, 200), (196, 210, 164))
    frame(im, (120, 140, 96))
    d = ImageDraw.Draw(im)
    # 새글 표시 — 그 시절 게시판의 빨간 N
    d.rectangle([6, 5, 20, 19], fill=(196, 52, 52), outline=(110, 24, 24))
    d.text((9, 4), "N", font=font(SMALL), fill=(255, 255, 255))
    d.text((28, 4), "새 글", font=font(SMALL), fill=(52, 72, 40))
    d.rectangle([72, 5, 86, 19], fill=(238, 238, 226), outline=(110, 120, 96))
    d.text((75, 4), "+", font=font(SMALL), fill=(52, 72, 40))
    d.text((94, 4), "댓글 수", font=font(SMALL), fill=(52, 72, 40))
    d.text((360, 4), "전체글보기", font=font(SMALL), fill=(70, 96, 54))
    save(im, "banner_board")


# ── 새빛수련회 ────────────────────────────────────────────────────────────

def build_banner_saebit():
    # 관문은 카페 껍데기를 그대로 쓰지만, 이 표식만은 저들의 것이다.
    im = gradient((300, 64), (253, 252, 246), (238, 232, 214))
    frame(im, (186, 156, 74))
    paste(im, art("emblem_saebit"), (12, 8))
    d = ImageDraw.Draw(im)
    d.text((70, 8), "새빛수련회", font=font(MID), fill=(96, 76, 28))
    d.text((72, 38), "정회원 전용 · 외부 유출 금지", font=font(SMALL), fill=(140, 120, 70))
    save(im, "banner_saebit")


# ── 미니홈피 ──────────────────────────────────────────────────────────────

def photo(name):
    return Image.open(os.path.join(PHOTOS, name + ".png")).convert("RGBA")


def thumb(src, size):
    im = photo(src)
    scale = max(size[0] / im.width, size[1] / im.height)
    im = im.resize((max(int(im.width * scale), size[0]), max(int(im.height * scale), size[1])), Image.LANCZOS)
    left = (im.width - size[0]) // 2
    top = (im.height - size[1]) // 2
    return im.crop((left, top, left + size[0], top + size[1]))


def build_myhome_profile():
    im = Image.new("RGBA", (96, 112), (246, 250, 253, 255))
    frame(im, (143, 180, 210))
    paste(im, frame(thumb("bomi_2002", (80, 80)), (110, 140, 170)), (8, 8))
    d = ImageDraw.Draw(im)
    d.text((8, 92), "봄이 · 2002", font=font(SMALL), fill=(70, 100, 130))
    save(im, "myhome_profile")


def build_myhome_album():
    shots = [("bomi_2002", "봄이"), ("desk_2002", "내 방"), ("retreat_2002", "수련회")]
    cell = (96, 72)
    im = Image.new("RGBA", (cell[0] * 3 + 16, cell[1] + 30), (238, 246, 252, 255))
    frame(im, (143, 180, 210))
    d = ImageDraw.Draw(im)
    d.text((6, 2), "사진첩", font=font(SMALL), fill=(50, 86, 120))
    for i, (src, label) in enumerate(shots):
        x = 4 + i * (cell[0] + 4)
        paste(im, frame(thumb(src, cell), (110, 140, 170)), (x, 20))
        d.text((x + 2, cell[1] + 22), label, font=font(SMALL), fill=(70, 100, 130))
    save(im, "myhome_album")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("web banners ->", OUT)
    build_logo_nurinet()
    build_ad_ringtone()
    build_banner_gongsi()
    build_banner_board()
    build_banner_saebit()
    build_myhome_profile()
    build_myhome_album()
