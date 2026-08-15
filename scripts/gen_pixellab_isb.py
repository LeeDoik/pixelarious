"""PixelLab으로 IT SLEEPS BELOW 스프라이트 생성. 실행: python scripts/gen_pixellab_isb.py [이름...]"""
import base64, io, json, os, sys, time, urllib.request

from PIL import Image

MIN_AREA = 1024
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "games-src", "it-sleeps-below", "assets", "img")
API = "https://api.pixellab.ai/v1/generate-image-pixflux"

STYLE = ("pixel art, crisp 1px dark outline, retro game sprite, dark cave palette, "
         "clean readable silhouette, centered, no background")
NEG = "blurry, anti-aliasing, photorealistic, text, watermark, gradient banding, gore, blood"

SPRITES = {
    # 광부 (16x16 프레임별 생성 — 동일 문구 접두로 스타일 고정)
    "miner_idle":   (16, 16, f"small miner in brown overalls holding lantern, standing, warm lamp glow, {STYLE}"),
    "miner_walk1":  (16, 16, f"small miner in brown overalls holding lantern, walking left foot forward, {STYLE}"),
    "miner_walk2":  (16, 16, f"small miner in brown overalls holding lantern, walking right foot forward, {STYLE}"),
    "miner_climb1": (16, 16, f"small miner in brown overalls climbing rock wall, reaching up left arm, seen from behind, {STYLE}"),
    "miner_climb2": (16, 16, f"small miner in brown overalls climbing rock wall, reaching up right arm, seen from behind, {STYLE}"),
    "miner_dig1":   (16, 16, f"small miner in brown overalls swinging pickaxe raised, {STYLE}"),
    "miner_dig2":   (16, 16, f"small miner in brown overalls pickaxe striking down, small debris, {STYLE}"),
    "miner_death":  (16, 16, f"small miner in brown overalls collapsed on ground, dropped lantern dim, {STYLE}"),
    # '그것' — 키가 너무 큰 광부 실루엣 (16x32) + 램프
    "lurker":       (16, 32, f"unnaturally tall thin miner silhouette, pitch black body, faintly glowing pale green lantern held low, elongated limbs, no face, unsettling, {STYLE}"),
    "lurker_frozen":(16, 32, f"unnaturally tall thin miner silhouette frozen mid-step, pitch black, pale green lantern, rigid pose, {STYLE}"),
    # 지층 타일 (16x16)
    # tile_dirt 1차 결과가 짜임(weave) 패턴으로 나와 재생성 (프롬프트에서 "seamless"
    # 대신 "packed dirt floor block"으로, 격자/직조 금지 문구 추가)
    "tile_dirt":    (16, 16, f"packed dirt floor block, loose earth clumps and small round pebbles scattered on brown soil, no grid pattern, no weave, no fabric texture, {STYLE}"),
    "tile_rock":    (16, 16, f"seamless dark blue-grey bedrock block texture, {STYLE}"),
    "tile_deep":    (16, 16, f"seamless dark purple cracked rock texture, faint vein patterns like blood vessels, wrong-looking, {STYLE}"),
    "tile_flesh":   (16, 16, f"seamless dark crimson organic rock texture, subtle rib-like ridges, breathing surface, disturbing but not gory, {STYLE}"),
    "tile_crack":   (16, 16, f"cracked fragile rock block with visible fracture lines, about to collapse, {STYLE}"),
    "tile_border":  (16, 16, f"impenetrable obsidian black rock block, dense, {STYLE}"),
    # tile_bg 1~2차 결과 모두 아치형 구멍으로 나와 재생성 ("tunnel" 단어를 빼고
    # 던전 벽 패널로 재기술)
    "tile_bg":      (16, 16, f"dungeon rock wall panel, flat rough dark stone surface, uniform texture, subtle bumps, no doorway, no cave entrance, no hole, almost black, {STYLE}"),
    # 광석 7종 + 심장 + 픽업 (16x16)
    "ore_coal":     (16, 16, f"coal chunks embedded in rock block, matte black lumps, {STYLE}"),
    "ore_copper":   (16, 16, f"copper ore embedded in rock block, orange metallic specks, {STYLE}"),
    # ore_iron 1차 결과가 ore_silver와 색이 거의 동일해 재생성 (녹슨 적갈색으로 구분)
    "ore_iron":     (16, 16, f"iron ore embedded in rock block, rusty reddish-brown metallic specks, dull ochre highlights, {STYLE}"),
    "ore_silver":   (16, 16, f"silver ore embedded in rock block, bright white metallic veins, {STYLE}"),
    "ore_gold":     (16, 16, f"gold ore embedded in rock block, warm yellow glittering veins, {STYLE}"),
    "ore_amethyst": (16, 16, f"amethyst crystals embedded in rock block, purple glowing crystals, {STYLE}"),
    "ore_glow":     (16, 16, f"pulsing pink glowing ore embedded in dark rock, heartbeat glow, organic, {STYLE}"),
    "heart":        (48, 48, f"giant pulsing crystal heart embedded in flesh-like rock, pink inner glow, veins spreading outward, majestic and terrifying, {STYLE}"),
    "oil_bottle":   (16, 16, f"small glass bottle of golden lamp oil with cork, {STYLE}"),
    "journal":      (16, 16, f"weathered leather journal with strap on cave floor, {STYLE}"),
    "relic_bag":    (16, 16, f"abandoned worn leather mining bag with rope handle, sitting upright, {STYLE}"),
    # 거점/로어 오브젝트
    "merchant":     (24, 24, f"hooded merchant figure sitting by small stall, face hidden in shadow, single visible pale eye glint, {STYLE}"),
    "tent":         (32, 24, f"abandoned weathered canvas mining tent, slightly torn, {STYLE}"),
    # lamp_ui 1~2차 결과 모두 캐릭터로 나와 재생성 ("miner" 단어를 빼고 오브젝트임을 강조)
    "lamp_ui":      (16, 16, f"antique brass oil lantern object, glass panel, warm orange flame inside, hanging handle on top, item icon, still life object, no person, no character, no creature, no face, {STYLE}"),
    "heart_ui":     (8, 8, f"tiny pixel heart icon, red, ui, {STYLE}"),
    # 원경 2버전 (수미상관) + 로고
    # 브리프 원안은 135(홀수)지만 PixelLab API가 "width/height must both be
    # divisible by 2"를 강제하므로 136으로 반올림 (시각적 차이 무시 가능).
    "vista_calm":   (136, 80, f"distant mountain landscape at dusk, single dark mountain silhouette, tiny camp light at base, quiet somber sky, {STYLE}"),
    # vista_alive 1차 결과는 구도는 맞았으나 분홍 발광이 사라져 재생성 (구도 유지 +
    # 봉우리마다 분홍 발광 반점을 명시적으로 다시 추가)
    "vista_alive":  (136, 80, f"same dark mountain silhouette and pine forest treeline composition as a calm dusk view, single mountain view distance, but every peak has faint pink glowing veins and small pulsing pink light spots like a heartbeat, mountains subtly breathing, cosmic horror scale, {STYLE}"),
    # logo: PixelLab 텍스트 렌더링이 4회 시도 모두 철자를 깨뜨려("SLEPS" 등)
    # 텍스트 없는 명판으로 전환 — 타이틀 화면에서 실제 폰트로 텍스트를 오버레이한다.
    "logo":         (96, 48, f"weathered carved stone plaque, rectangular, moss and cracks, faint pink glow seeping from the cracks, empty center area for text overlay, no letters, no text, {STYLE}"),
}

def read_key():
    with open(os.path.join(ROOT, ".env.local"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("PIXELLAB_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("PIXELLAB_API_KEY not found in .env.local")

def find_base64(obj):
    """응답 어디에 있든 base64 이미지 문자열을 찾는다 (스키마 변화 방어)."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == "base64" and isinstance(v, str):
                return v
            r = find_base64(v)
            if r:
                return r
    elif isinstance(obj, list):
        for v in obj:
            r = find_base64(v)
            if r:
                return r
    return None

def generate(key, name, w, h, desc):
    # API가 32x32(=1024px^2) 미만 캔버스를 거부하므로, 목표 크기의 면적이 그
    # 미만이면 정수 배율로 확대 생성한 뒤 다운스케일한다.
    mult = 1
    while (w * mult) * (h * mult) < MIN_AREA:
        mult += 1
    gen_w, gen_h = w * mult, h * mult

    body = json.dumps({
        "description": desc,
        "negative_description": NEG,
        "image_size": {"width": gen_w, "height": gen_h},
        "no_background": True,
    }).encode()
    req = urllib.request.Request(API, data=body, method="POST", headers={
        "Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=180) as resp:
        data = json.load(resp)
    b64 = find_base64(data)
    if not b64:
        sys.exit(f"{name}: no image in response: {str(data)[:300]}")
    if "," in b64[:80]:
        b64 = b64.split(",", 1)[1]
    raw = base64.b64decode(b64)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{name}.png")
    if mult > 1:
        im = Image.open(io.BytesIO(raw)).convert("RGBA")
        im = im.resize((w, h), Image.NEAREST)
        im.save(path)
        print(f"OK {name} -> {path} (generated {gen_w}x{gen_h}, downscaled {mult}x)")
    else:
        with open(path, "wb") as f:
            f.write(raw)
        print(f"OK {name} -> {path}")

def main():
    key = read_key()
    targets = sys.argv[1:] or list(SPRITES)
    for name in targets:
        w, h, desc = SPRITES[name]
        generate(key, name, w, h, desc)
        time.sleep(1)

if __name__ == "__main__":
    main()
