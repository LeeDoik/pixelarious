"""절차적 균열(cracks) 오버레이 생성.

PixelLab이 추상적인 선 오버레이(cracks) 생성을 두 번 연속 "빛나는 스파클/렌즈 플레어"로
오인해 생성했기 때문에(중앙에 꽉 찬 밝은 코어 -> "피해"가 아니라 "파워업"으로 읽힘),
이 텍스처만 gen_icons.py 계보를 따라 절차적으로(PIL + stdlib random, 고정 시드) 생성한다.

별 종류마다 캔버스와 원 지름이 달라서(star_*.png는 캔버스에 여백이 있다) 한 장을 늘려 쓰면
금이 별 밖으로 삐져나온다. 게다가 이 프로젝트는 nearest 필터라 축소하면 1px 선이 점으로 부서진다.
그래서 종류별로 그 별의 캔버스·원 중심·반지름에 맞춰 각각 원본 해상도로 뽑는다.

사용: python scripts/gen_cracks.py [seed]
  seed 생략 시 눈으로 검수해 확정한 기본 시드(SEED)를 사용한다.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG_DIR = os.path.join(ROOT, "games-src", "starfall-drift", "assets", "img")

# star_*.png에서 실제로 칠해진 원을 재서 넣은 값. canvas는 별 스프라이트와 같게 두어야
# Sprite2D 두 장이 원점만 맞추면 겹친다. center/radius는 그 캔버스 안 원의 중심·반지름.
STARS = {
    "dwarf": {"canvas": 16, "center": (7.5, 7.5), "radius": 3.5, "mains": (3, 4)},
    "standard": {"canvas": 32, "center": (16.0, 16.0), "radius": 12.0, "mains": (5, 7)},
    "giant": {"canvas": 48, "center": (24.5, 23.0), "radius": 18.5, "mains": (6, 8)},
}

COLOR_MAIN = (0xFF, 0xF1, 0xE8, 255)
COLOR_BRANCH = (0xFF, 0xF1, 0xE8, 200)
COLOR_DEBRIS = (0xFF, 0xF1, 0xE8, 150)

# 여러 시드를 눈으로 검수한 뒤 "spiderweb 균열"로 명확히 읽히는 시드를 확정해 고정했다.
SEED = 7


def _walk_main(draw, center, direction_deg, target_radius, step_scale, rng):
    """원 중심에서 바깥으로 방향을 ±25도씩 흔들며 걷는 jagged polyline.
    각 세그먼트의 (시작점, 끝점, 그 시점의 방향)을 리스트로 반환한다 (분기 생성용)."""
    x, y = center
    direction = direction_deg
    segments = []
    while math.hypot(x - center[0], y - center[1]) < target_radius:
        direction += rng.uniform(-25, 25)
        step = rng.uniform(2, 3) * step_scale
        nx = x + step * math.cos(math.radians(direction))
        ny = y + step * math.sin(math.radians(direction))
        p0 = (round(x), round(y))
        p1 = (round(nx), round(ny))
        if p0 != p1:
            draw.line([p0, p1], fill=COLOR_MAIN, width=1)
        segments.append(((x, y), (nx, ny), direction))
        x, y = nx, ny
    return segments


def _walk_branch(draw, start, direction_deg, total_len, step_scale, rng):
    """분기: 부모 방향 ±45도로 꺾여 짧게 걷는다(길이는 원 크기에 비례)."""
    x, y = start
    direction = direction_deg
    remaining = total_len
    while remaining > 0.5:
        direction += rng.uniform(-12, 12)
        step = min(rng.uniform(2, 3) * step_scale, remaining)
        nx = x + step * math.cos(math.radians(direction))
        ny = y + step * math.sin(math.radians(direction))
        p0 = (round(x), round(y))
        p1 = (round(nx), round(ny))
        if p0 != p1:
            draw.line([p0, p1], fill=COLOR_BRANCH, width=1)
        x, y = nx, ny
        remaining -= step


def generate(cfg, seed):
    rng = random.Random(seed)
    size = cfg["canvas"]
    center = cfg["center"]
    radius = cfg["radius"]
    # 원본 32px(반지름 14)에서 잡은 획 길이를 그대로 쓰면 작은 별에서는 한 획이 원을 넘는다.
    step_scale = max(0.4, min(1.0, radius / 14.0))
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    n_main = rng.randint(*cfg["mains"])
    base_spacing = 360.0 / n_main
    for i in range(n_main):
        angle = i * base_spacing + rng.uniform(-15, 15)
        target_r = radius * rng.uniform(0.86, 0.98)
        segs = _walk_main(draw, center, angle, target_r, step_scale, rng)
        if segs and rng.random() < 0.35:
            _mid_start, mid_end, mid_dir = segs[len(segs) // 2]
            branch_dir = mid_dir + rng.choice([-45, 45])
            branch_len = radius * rng.uniform(0.28, 0.5)
            _walk_branch(draw, mid_end, branch_dir, branch_len, step_scale, rng)

    n_debris = rng.randint(3, 5)
    for _ in range(n_debris):
        angle = rng.uniform(0, 360)
        r = radius * rng.uniform(0.55, 0.95)
        px = round(center[0] + r * math.cos(math.radians(angle)))
        py = round(center[1] + r * math.sin(math.radians(angle)))
        if 0 <= px < size and 0 <= py < size:
            draw.point((px, py), fill=COLOR_DEBRIS)

    return _clip_to_disc(img, center, radius)


def _clip_to_disc(img, center, radius):
    """원 밖으로 삐져나온 획을 잘라낸다 — 걷기가 마지막 한 획에서 반지름을 넘길 수 있다."""
    size = img.size[0]
    px = img.load()
    for y in range(size):
        for x in range(size):
            # 픽셀 중심(x+0.5, y+0.5)이 원 안에 있어야 남긴다.
            if math.hypot(x + 0.5 - center[0], y + 0.5 - center[1]) > radius:
                px[x, y] = (0, 0, 0, 0)
    return img


def main():
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else SEED
    os.makedirs(IMG_DIR, exist_ok=True)
    for i, (name, cfg) in enumerate(STARS.items()):
        img = generate(cfg, seed + i)
        out = os.path.join(IMG_DIR, f"cracks_{name}.png")
        img.save(out)
        print(f"OK cracks_{name} {cfg['canvas']}px (seed={seed + i}) -> {out}")


if __name__ == "__main__":
    main()
