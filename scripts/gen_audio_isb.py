"""VARCO Sound로 IT SLEEPS BELOW 오디오 생성.
실행: python scripts/gen_audio_isb.py [이름...]
- text2sound: 프롬프트 -> 10초 WAV (base64)
- looping: 앰비언트를 심리스 루프로 변환
- ffmpeg: 트리밍 + ogg 인코딩 (wav는 커밋하지 않는다)
"""
import base64, json, os, subprocess, sys, tempfile, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "games-src", "it-sleeps-below", "assets", "sfx")
T2S = "https://openapi.ai.nc.com/sound/varco/v1/api/text2sound"
LOOP = "https://openapi.ai.nc.com/sound/varco/v1/api/looping"

# (프롬프트, loop 여부, 최대 길이 초 — 0이면 자동 트림 없이 전체)
SOUNDS = {
    # ── SFX (트림) ──
    "dig_dirt":    ("shovel digging into soft soil, single strike, short", False, 0.8),
    "dig_rock":    ("pickaxe striking hard rock, single sharp impact with small debris, short", False, 0.8),
    "dig_flesh":   ("pickaxe striking something dense and wet, muffled organic thud, unsettling, short", False, 0.8),
    "ore_pickup":  ("small crystal chime pickup, bright short glassy note", False, 0.6),
    "land":        ("soft thud of boots landing on stone, short", False, 0.5),
    "fall_hurt":   ("heavy body impact on rock with grunt-like air burst, no voice, short", False, 0.7),
    "rockfall":    ("rocks crumbling and falling in a cave, collapse rumble, short", False, 1.5),
    "lamp_toggle": ("old brass lantern metal click and small flame whoosh, very short", False, 0.4),
    "lamp_flicker":("oil lamp flame sputtering and flickering, short", False, 0.8),
    "oil_warning": ("low ominous single bell tone, muffled, short", False, 1.0),
    "climb":       ("hands and boots scraping on rock wall, single scrape, short", False, 0.5),
    "settle":      ("coins pouring onto wooden table, cheerful short jingle", False, 1.2),
    "journal_get": ("old paper page turning with soft dusty rustle, short", False, 0.8),
    "whisper":     ("faint unintelligible whisper echoing in a cave, breathy, creepy, short", False, 2.0),
    "echo_pick":   ("distant pickaxe echo in deep cave, two delayed strikes, eerie", False, 2.0),
    "steps_wall":  ("muffled footsteps behind a stone wall walking in rhythm, unsettling", False, 2.5),
    "heartbeat":   ("slow deep heartbeat thumping, organic, ominous", True, 0),
    "awaken":      ("massive deep rumble of a mountain waking, sub bass groan rising, terrifying", False, 6.0),
    "pulse":       ("single deep organic heart pulse with pink glow feeling, sub bass thump", False, 1.5),
    # ── 앰비언트 (looping API로 루프화) ──
    "amb_surface": ("quiet mountain camp at dusk, soft wind, sparse distant birds, lonely", True, 0),
    "amb_rock":    ("deep cave ambience, water droplets echoing, distant hollow drips", True, 0),
    "amb_fissure": ("very low ominous drone in deep cave, faint sub bass hum, oppressive silence", True, 0),
    "amb_finale":  ("deep pulsing organic drone, heartbeat rhythm inside living cavern, dread", True, 0),
    "bgm_camp":    ("slow melancholic music box lullaby, sparse notes, quiet and slightly sad", True, 0),
}

def read_key():
    with open(os.path.join(ROOT, ".env.local"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("VARCO_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("VARCO_API_KEY not found in .env.local")

def call(url, payload, key):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), method="POST",
        headers={"OPENAPI_KEY": key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as resp:
        return json.load(resp)

def first_audio(data):
    if isinstance(data, list):
        return data[0]["audio"]
    return data["audio"]

def generate(key, name, prompt, loop, max_len):
    data = call(T2S, {"prompt": prompt, "num_sample": 1}, key)
    wav = base64.b64decode(first_audio(data))
    if loop:
        data = call(LOOP, {"source": base64.b64encode(wav).decode()}, key)
        wav = base64.b64decode(data["audio"])
    os.makedirs(OUT, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        tf.write(wav)
        tmp = tf.name
    ogg = os.path.join(OUT, f"{name}.ogg")
    cmd = ["ffmpeg", "-y", "-i", tmp]
    if not loop and max_len > 0:
        # 선행 무음 제거 후 max_len으로 컷
        cmd += ["-af", "silenceremove=start_periods=1:start_threshold=-45dB", "-t", str(max_len)]
    cmd += ["-c:a", "libvorbis", "-qscale:a", "4", ogg]
    subprocess.run(cmd, check=True, capture_output=True)
    os.unlink(tmp)
    print(f"OK {name} -> {ogg}")

def main():
    key = read_key()
    targets = sys.argv[1:] or list(SOUNDS)
    for name in targets:
        prompt, loop, max_len = SOUNDS[name]
        generate(key, name, prompt, loop, max_len)
        time.sleep(1)

if __name__ == "__main__":
    main()
