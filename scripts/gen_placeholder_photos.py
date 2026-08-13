"""플레이스홀더 사진 생성 — LAST LOGIN 사진 뷰어용.

절차 생성: 어둡고 채도 낮은 구도(그라데이션 하늘/벽, 실루엣 도형, 창빛)를
640x480으로 그린 뒤 노이즈 + JPEG q=30 재압축으로 2000년대 디카 느낌을 낸다.
결과는 scripts/photo_src/ 에 저장되고, 이어서 scripts/degrade_photo.py 가
game/assets/img/photos/*.png 를 만든다.

주의: 이 이미지들은 사람이 나중에 AI 생성 사진으로 교체할 수 있는 대역(stand-in)이다.
실존 인물·브랜드 없음. 표준 라이브러리 + PIL만 사용.

사용: python scripts/gen_placeholder_photos.py
"""
from __future__ import annotations

import io
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

W, H = 640, 480
OUT = os.path.join("scripts", "photo_src")


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def gradient(top: tuple, bottom: tuple) -> Image.Image:
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        d.line(
            [(0, y), (W, y)],
            fill=(
                int(lerp(top[0], bottom[0], t)),
                int(lerp(top[1], bottom[1], t)),
                int(lerp(top[2], bottom[2], t)),
            ),
        )
    return img


def glow(img: Image.Image, cx: int, cy: int, radius: int, color: tuple, strength: float) -> None:
    """부드러운 광원 한 점을 더한다(창빛·형광등)."""
    px = img.load()
    r2 = float(radius * radius)
    x0, x1 = max(0, cx - radius), min(W, cx + radius)
    y0, y1 = max(0, cy - radius), min(H, cy + radius)
    for y in range(y0, y1):
        for x in range(x0, x1):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if d2 >= r2:
                continue
            k = (1.0 - math.sqrt(d2) / radius) ** 2 * strength
            r, g, b = px[x, y]
            px[x, y] = (
                min(255, int(r + color[0] * k)),
                min(255, int(g + color[1] * k)),
                min(255, int(b + color[2] * k)),
            )


def silhouette(d: ImageDraw.ImageDraw, cx: int, base: int, scale: float, tone: tuple) -> None:
    """사람 형태의 단순 실루엣(머리+어깨). 얼굴 없음."""
    head = int(26 * scale)
    d.ellipse([cx - head, base - int(150 * scale), cx + head, base - int(150 * scale) + head * 2],
              fill=tone)
    body_w = int(58 * scale)
    d.polygon(
        [
            (cx - body_w, base),
            (cx - int(body_w * 0.72), base - int(96 * scale)),
            (cx, base - int(112 * scale)),
            (cx + int(body_w * 0.72), base - int(96 * scale)),
            (cx + body_w, base),
        ],
        fill=tone,
    )


def finish(img: Image.Image, name: str, seed: int) -> None:
    rnd = random.Random(seed)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    px = img.load()
    # 굵은 노이즈(필름 그레인 + 저조도 센서 노이즈)
    for _ in range(60000):
        x, y = rnd.randrange(W), rnd.randrange(H)
        n = rnd.randint(-22, 22)
        r, g, b = px[x, y]
        px[x, y] = (
            max(0, min(255, r + n)),
            max(0, min(255, g + n)),
            max(0, min(255, b + int(n * 0.8))),
        )
    # 비네팅
    for y in range(H):
        for x in range(0, W, 2):
            dx = (x - W / 2) / (W / 2)
            dy = (y - H / 2) / (H / 2)
            v = 1.0 - min(1.0, (dx * dx + dy * dy) * 0.42)
            r, g, b = px[x, y]
            px[x, y] = (int(r * v), int(g * v), int(b * v))
            if x + 1 < W:
                r, g, b = px[x + 1, y]
                px[x + 1, y] = (int(r * v), int(g * v), int(b * v))
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=30)
    Image.open(buf).convert("RGB").save(os.path.join(OUT, name))
    print("wrote", os.path.join(OUT, name))


def family_photo() -> None:
    """2001년 설 — 창을 등지고 선 세 사람. 역광이라 얼굴이 보이지 않는다."""
    img = gradient((38, 40, 52), (22, 21, 26))
    d = ImageDraw.Draw(img)
    d.rectangle([70, 60, 330, 300], fill=(126, 128, 118))   # 창
    d.rectangle([70, 60, 330, 300], outline=(52, 50, 46), width=6)
    d.line([(200, 60), (200, 300)], fill=(52, 50, 46), width=6)
    d.line([(70, 180), (330, 180)], fill=(52, 50, 46), width=6)
    d.rectangle([0, 372, W, H], fill=(46, 38, 33))          # 상
    d.rectangle([360, 120, 600, 300], fill=(58, 50, 44))    # 장롱
    silhouette(d, 210, 400, 1.05, (20, 19, 22))
    silhouette(d, 330, 402, 0.92, (24, 22, 25))
    silhouette(d, 440, 398, 1.0, (18, 18, 21))
    glow(img, 200, 170, 240, (70, 66, 52), 1.0)
    finish(img, "family_photo.jpg", 11)


def bomi_photo() -> None:
    """2002.03.16 — 신문지 위 강아지. 형광등 아래."""
    img = gradient((58, 55, 48), (34, 32, 30))
    d = ImageDraw.Draw(img)
    d.polygon([(0, 300), (W, 250), (W, H), (0, H)], fill=(96, 92, 80))   # 장판
    d.polygon([(150, 320), (470, 300), (500, 430), (120, 450)], fill=(146, 143, 132))  # 신문지
    for i in range(9):                                                    # 신문 활자 흉내
        y = 336 + i * 12
        d.line([(175 + i * 3, y), (455 - i * 4, y - 3)], fill=(96, 94, 88), width=2)
    d.ellipse([268, 322, 372, 402], fill=(74, 62, 50))                    # 몸
    d.ellipse([246, 300, 316, 366], fill=(84, 71, 57))                    # 머리
    d.polygon([(250, 306), (238, 344), (266, 336)], fill=(60, 50, 40))    # 귀
    d.polygon([(310, 304), (322, 342), (296, 334)], fill=(60, 50, 40))
    d.ellipse([352, 372, 402, 392], fill=(70, 59, 48))                    # 꼬리
    glow(img, 320, 40, 300, (48, 46, 38), 1.0)
    finish(img, "bomi_2002.jpg", 22)


def desk_photo() -> None:
    """공부방 — 스탠드 하나 켜진 책상. 밤."""
    img = gradient((26, 27, 34), (16, 16, 19))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 330, W, H], fill=(62, 48, 36))                        # 책상
    d.rectangle([40, 150, 300, 336], fill=(40, 38, 40))                   # 책 더미
    for i in range(7):
        y = 336 - (i + 1) * 24
        d.rectangle([52 + (i % 3) * 6, y, 288 - (i % 2) * 14, y + 20],
                    fill=(72 - i * 4, 66 - i * 3, 58 - i * 3))
    d.rectangle([360, 176, 570, 322], fill=(48, 50, 52))                  # 모니터
    d.rectangle([374, 190, 556, 300], fill=(96, 106, 96))
    d.rectangle([440, 322, 490, 344], fill=(44, 46, 48))
    d.line([(150, 120), (230, 210)], fill=(70, 68, 62), width=8)          # 스탠드 목
    d.polygon([(120, 96), (196, 96), (176, 140), (140, 140)], fill=(78, 74, 66))
    glow(img, 158, 150, 210, (86, 78, 56), 1.0)
    glow(img, 465, 245, 170, (34, 44, 40), 0.9)
    finish(img, "desk_2002.jpg", 33)


def retreat_photo() -> None:
    """수련회 단체 사진 — 새벽 마당, 안개, 뒷모습."""
    img = gradient((52, 58, 62), (30, 34, 34))
    d = ImageDraw.Draw(img)
    d.polygon([(0, 250), (180, 150), (360, 245), (0, 300)], fill=(40, 46, 46))   # 산 세 겹
    d.polygon([(220, 260), (400, 158), (600, 258), (220, 300)], fill=(46, 52, 52))
    d.polygon([(430, 268), (560, 190), (W, 262), (430, 300)], fill=(52, 58, 57))
    d.rectangle([0, 292, W, H], fill=(58, 60, 52))                               # 마당
    d.rectangle([120, 214, 300, 296], fill=(112, 112, 104))                      # 흰 건물 두 동
    d.rectangle([330, 222, 470, 296], fill=(104, 104, 98))
    tone = (26, 28, 30)
    for i, cx in enumerate([90, 175, 258, 342, 424, 508, 578]):
        silhouette(d, cx, 430 + (i % 3) * 6, 0.82 + (i % 4) * 0.05, tone)
    glow(img, 320, 120, 380, (54, 56, 50), 1.0)
    finish(img, "retreat_2002.jpg", 44)


def window_photo() -> None:
    """창밖 — 새벽 4시. 맞은편 동에 켜진 창 몇 개."""
    img = gradient((18, 20, 30), (10, 11, 15))
    d = ImageDraw.Draw(img)
    d.rectangle([60, 90, 580, 400], fill=(14, 15, 20))                     # 맞은편 건물
    rnd = random.Random(7)
    for row in range(6):
        for col in range(9):
            x = 78 + col * 56
            y = 108 + row * 48
            if rnd.random() < 0.22:
                d.rectangle([x, y, x + 34, y + 30], fill=(122, 108, 72))
                glow(img, x + 17, y + 15, 46, (60, 52, 30), 0.9)
            else:
                d.rectangle([x, y, x + 34, y + 30], fill=(24, 25, 32))
    d.rectangle([0, 0, W, 40], fill=(8, 9, 12))                            # 창틀
    d.rectangle([0, H - 46, W, H], fill=(8, 9, 12))
    d.rectangle([0, 0, 26, H], fill=(8, 9, 12))
    d.rectangle([W - 26, 0, W, H], fill=(8, 9, 12))
    d.rectangle([308, 0, 332, H], fill=(8, 9, 12))
    finish(img, "window_night.jpg", 55)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    family_photo()
    bomi_photo()
    desk_photo()
    retreat_photo()
    window_photo()
    print("done - next: python scripts/degrade_photo.py")


if __name__ == "__main__":
    main()
