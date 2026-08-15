"""STARFALL DRIFT SFX 합성 (stdlib만). 실행: python scripts/gen_audio_starfall.py"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "games-src", "starfall-drift", "assets", "sfx")

def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))
    print("OK", name)

def env(i, n, a=0.01, r=0.3):
    t = i / n
    if t < a: return t / a
    return max(0.0, 1.0 - (t - a) / max(1e-6, r))

def square(f, t): return 1.0 if math.sin(2 * math.pi * f * t) >= 0 else -1.0

def blip(f0, f1, dur, vol=0.5, wave_fn=square):
    n = int(SR * dur)
    return [vol * env(i, n) * wave_fn(f0 + (f1 - f0) * (i / n), i / SR) for i in range(n)]

def noise(dur, vol=0.5, decay=0.9995):
    n = int(SR * dur); a = vol; out = []
    for i in range(n):
        out.append(a * env(i, n, 0.005, 0.9) * random.uniform(-1, 1)); a *= decay
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0.0 for t in tracks) for i in range(n)]

random.seed(7)
save("hop", blip(600, 950, 0.09, 0.45))
save("capture", mix(blip(523, 523, 0.07, 0.35), [0.0] * int(SR * 0.06) + blip(784, 784, 0.10, 0.35)))
save("warn", blip(180, 140, 0.12, 0.4))
save("death", mix(noise(0.5, 0.5), blip(300, 60, 0.5, 0.3)))
save("combo", mix(*[[0.0] * int(SR * 0.05 * k) + blip(660 + 110 * k, 660 + 110 * k, 0.06, 0.3) for k in range(3)]))
amb_n = int(SR * 8.0)
amb = [0.10 * math.sin(2 * math.pi * 55 * i / SR) + 0.05 * math.sin(2 * math.pi * 82.5 * i / SR + 0.5)
       + 0.02 * random.uniform(-1, 1) for i in range(amb_n)]
fade = int(SR * 0.05)
for i in range(fade):  # 루프 이음새 클릭 제거용 크로스페이드
    amb[i] = amb[i] * (i / fade) + amb[amb_n - fade + i] * (1 - i / fade)
save("ambient", amb[: amb_n - fade])
