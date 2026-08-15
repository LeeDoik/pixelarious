"""절차적 균열(cracks) 오버레이 생성.

PixelLab이 추상적인 선 오버레이(cracks) 생성을 두 번 연속 "빛나는 스파클/렌즈 플레어"로
오인해 생성했기 때문에(중앙에 꽉 찬 밝은 코어 -> "피해"가 아니라 "파워업"으로 읽힘),
이 텍스처만 gen_icons.py 계보를 따라 절차적으로(PIL + stdlib random, 고정 시드) 생성한다.

사용: python scripts/gen_cracks.py [seed]
  seed 생략 시 눈으로 검수해 확정한 기본 시드(SEED)를 사용한다.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "games-src", "starfall-drift", "assets", "img", "cracks.png")

SIZE = 32
CENTER = (16, 16)
COLOR_MAIN = (0xFF, 0xF1, 0xE8, 255)
COLOR_BRANCH = (0xFF, 0xF1, 0xE8, 200)
COLOR_DEBRIS = (0xFF, 0xF1, 0xE8, 150)

# 여러 시드를 눈으로 검수한 뒤 "spiderweb 균열"로 명확히 읽히는 시드를 확정해 고정했다.
SEED = 7


def _walk_main(draw, direction_deg, target_radius, rng):
    """중심(16,16)에서 바깥으로 방향을 ±25도씩 흔들며 걷는 jagged polyline.
    각 세그먼트의 (시작점, 끝점, 그 시점의 방향)을 리스트로 반환한다 (분기 생성용)."""
    x, y = CENTER
    direction = direction_deg
    segments = []
    while math.hypot(x - CENTER[0], y - CENTER[1]) < target_radius:
        direction += rng.uniform(-25, 25)
        step = rng.uniform(2, 3)
        nx = x + step * math.cos(math.radians(direction))
        ny = y + step * math.sin(math.radians(direction))
        p0 = (round(x), round(y))
        p1 = (round(nx), round(ny))
        if p0 != p1:
            draw.line([p0, p1], fill=COLOR_MAIN, width=1)
        segments.append(((x, y), (nx, ny), direction))
        x, y = nx, ny
    return segments


def _walk_branch(draw, start, direction_deg, total_len, rng):
    """분기: 부모 방향 ±45도로 꺾여 4~7px를 짧게 걷는다."""
    x, y = start
    direction = direction_deg
    remaining = total_len
    while remaining > 0.5:
        direction += rng.uniform(-12, 12)
        step = min(rng.uniform(2, 3), remaining)
        nx = x + step * math.cos(math.radians(direction))
        ny = y + step * math.sin(math.radians(direction))
        p0 = (round(x), round(y))
        p1 = (round(nx), round(ny))
        if p0 != p1:
            draw.line([p0, p1], fill=COLOR_BRANCH, width=1)
        x, y = nx, ny
        remaining -= step


def generate(seed):
    rng = random.Random(seed)
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    n_main = rng.randint(5, 7)
    base_spacing = 360.0 / n_main
    for i in range(n_main):
        angle = i * base_spacing + rng.uniform(-15, 15)
        target_r = rng.uniform(13, 15)
        segs = _walk_main(draw, angle, target_r, rng)
        if segs and rng.random() < 0.35:
            mid_start, mid_end, mid_dir = segs[len(segs) // 2]
            branch_dir = mid_dir + rng.choice([-45, 45])
            branch_len = rng.uniform(4, 7)
            _walk_branch(draw, mid_end, branch_dir, branch_len, rng)

    n_debris = rng.randint(3, 5)
    for _ in range(n_debris):
        angle = rng.uniform(0, 360)
        r = rng.uniform(8, 14)
        dx = CENTER[0] + r * math.cos(math.radians(angle))
        dy = CENTER[1] + r * math.sin(math.radians(angle))
        px, py = round(dx), round(dy)
        if 0 <= px < SIZE and 0 <= py < SIZE:
            draw.point((px, py), fill=COLOR_DEBRIS)

    return img


def main():
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else SEED
    img = generate(seed)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print(f"OK cracks (seed={seed}) -> {OUT}")


if __name__ == "__main__":
    main()
