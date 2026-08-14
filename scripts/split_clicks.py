"""마우스 클릭 녹음(여러 번 클릭)을 개별 클릭 wav들로 분할.
사용: python scripts/split_clicks.py
입력: scripts/audio_src/mouse_clicks.wav (모노/스테레오, 16bit)
출력: game/assets/sfx/click_1.wav ... click_N.wav (16bit 모노, 원본 샘플레이트, 피크 정규화)"""
import array, os, sys, wave

SRC = os.path.join("scripts", "audio_src", "mouse_clicks.wav")
OUT_DIR = os.path.join("game", "assets", "sfx")
SILENCE_MS = 60      # 이 이상 조용하면 클릭 경계
PAD_BEFORE_MS = 8
DECAY_MS = 120       # 온셋 후 최대 꼬리
MAX_SEG_MS = 350
FADE_MS = 3
PEAK_TARGET = 0.45

if not os.path.isfile(SRC):
    print("no audio_src/mouse_clicks.wav, skipping")
    sys.exit(0)

w = wave.open(SRC, "rb")
rate, ch, sw, n = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
assert sw == 2, "16bit wav만 지원"
samples = array.array("h", w.readframes(n))
w.close()
mono = samples[::ch]

win = max(1, rate // 100)  # 10ms 윈도
rms = []
for i in range(0, len(mono) - win, win):
    seg = mono[i:i + win]
    rms.append((sum(s * s for s in seg) / win) ** 0.5)
thresh = max(rms) * 0.15

# 온셋 그룹 찾기 (SILENCE_MS 이상 조용하면 경계)
groups = []
in_group = False
quiet = 0
start = 0
for idx, r in enumerate(rms):
    if r > thresh:
        if not in_group:
            in_group = True
            start = idx
        quiet = 0
        end = idx
    elif in_group:
        quiet += 1
        if quiet * 10 >= SILENCE_MS:
            groups.append((start, end))
            in_group = False
if in_group:
    groups.append((start, end))

os.makedirs(OUT_DIR, exist_ok=True)
count = 0
for gs, ge in groups:
    s = max(0, gs * win - rate * PAD_BEFORE_MS // 1000)
    e = min(len(mono), ge * win + win + rate * DECAY_MS // 1000)
    e = min(e, s + rate * MAX_SEG_MS // 1000)
    seg = mono[s:e]
    if len(seg) < rate // 100:
        continue
    peak = max(1, max(abs(v) for v in seg))
    gain = PEAK_TARGET * 32767 / peak
    fade = rate * FADE_MS // 1000
    out = array.array("h")
    for i, v in enumerate(seg):
        f = min(1.0, i / fade if fade else 1.0, (len(seg) - 1 - i) / fade if fade else 1.0)
        out.append(int(max(-32767, min(32767, v * gain * f))))
    count += 1
    ow = wave.open(os.path.join(OUT_DIR, "click_%d.wav" % count), "wb")
    ow.setnchannels(1)
    ow.setsampwidth(2)
    ow.setframerate(rate)
    ow.writeframes(out.tobytes())
    ow.close()
print("split into", count, "clicks")
