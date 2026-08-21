"""BEAT SHIFT 오디오 합성 (stdlib만). 실행: python scripts/gen_audio_beatshift.py"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "games-src", "beat-shift", "assets", "sfx")
BPMS = [96, 112, 128, 144, 160]

def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))
    print("OK", name, len(samples))

def env(i, n, a=0.005):
    t = i / n
    return t / a if t < a else max(0.0, 1.0 - (t - a) / (1.0 - a))

def kick(dur=0.12, vol=0.9):
    n = int(SR * dur); out = []; ph = 0.0
    for i in range(n):
        f = 150 - (150 - 45) * (i / n)
        ph += 2 * math.pi * f / SR
        out.append(vol * env(i, n) * math.sin(ph))
    return out

def snare(dur=0.10, vol=0.45):
    n = int(SR * dur)
    return [vol * env(i, n) * (0.7 * random.uniform(-1, 1) + 0.3 * math.sin(2 * math.pi * 190 * i / SR))
            for i in range(n)]

def hat(dur=0.03, vol=0.16):
    n = int(SR * dur)
    return [vol * env(i, n) * random.uniform(-1, 1) for i in range(n)]

def bell(freq, dur=0.5, vol=0.5):
    # 모루 벨 — 비화성 배음(금속성)
    n = int(SR * dur); out = []
    for i in range(n):
        t = i / SR
        s = (math.sin(2 * math.pi * freq * t)
             + 0.6 * math.sin(2 * math.pi * freq * 2.76 * t)
             + 0.3 * math.sin(2 * math.pi * freq * 5.40 * t))
        out.append(vol * env(i, n, 0.002) * s / 1.9)
    return out

def place(buf, t_sec, samples):
    start = int(t_sec * SR)
    for j, s in enumerate(samples):
        k = start + j
        if 0 <= k < len(buf):
            buf[k] += s

def make_loop(bpm):
    spb = 60.0 / bpm
    n = int(round(SR * spb * 4))          # 정확히 1마디
    buf = [0.0] * n
    for b in [0, 2]:
        place(buf, b * spb, kick())
    for b in [1, 3]:
        place(buf, b * spb, snare())
    for e in range(8):
        place(buf, e * 0.5 * spb, hat())
    for e in [0, 3, 4, 7]:                # 얇은 8분 베이스 펄스
        t0 = e * 0.5 * spb
        m = int(SR * min(0.22, spb * 0.45))
        for i in range(m):
            k = int(t0 * SR) + i
            if k < n:
                buf[k] += 0.12 * env(i, m, 0.01) * (1.0 if math.sin(2 * math.pi * 55 * i / SR) >= 0 else -1.0)
    return [max(-1.0, min(1.0, s)) for s in buf]

def miss_sfx():
    n = int(SR * 0.3); out = []; ph = 0.0
    for i in range(n):
        f = 160 - 100 * (i / n)
        ph += 2 * math.pi * f / SR
        out.append(env(i, n) * (0.45 * random.uniform(-1, 1) * (1 - i / n) + 0.35 * math.sin(ph)))
    return out

def whiff_sfx():
    n = int(SR * 0.12)
    return [0.15 * env(i, n, 0.3) * random.uniform(-1, 1) for i in range(n)]

def arp(freqs, step=0.09, dur=0.16, vol=0.4):
    total = int(SR * (step * (len(freqs) - 1) + dur))
    buf = [0.0] * total
    for k, f in enumerate(freqs):
        place(buf, k * step, bell(f, dur, vol))
    return [max(-1.0, min(1.0, s)) for s in buf]

random.seed(11)
for bpm in BPMS:
    save("loop_%d" % bpm, make_loop(bpm))
for i, f in enumerate([523.25, 587.33, 659.25, 783.99]):   # C5 D5 E5 G5 — PERFECT 멜로디 벨
    save("anvil_%d" % (i + 1), bell(f, 0.5, 0.55))
save("good", bell(392.0, 0.25, 0.4))
save("precue", bell(1567.98, 0.08, 0.25))
save("miss", miss_sfx())
save("whiff", whiff_sfx())
save("jingle", arp([523.25, 659.25, 783.99, 1046.5]))
save("gameover", arp([392.0, 329.63, 261.63, 196.0], 0.14, 0.3))
