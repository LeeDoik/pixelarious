# -*- coding: utf-8 -*-
"""앰비언트 4·5단 — gen_audio.py의 세 겹(팬·험·드론) 위에 얹는 두 겹.

  amb_pulse.wav   4단(유서를 복원한 뒤): 심장처럼 느리게 뛰는 저음 — 40Hz가 0.55Hz로 부풀었다 가라앉는다
  amb_breath.wav  5단(정리.zip 또는 회계의 이름): 들숨 같은 노이즈 — 6초에 한 번 차올랐다 빠진다

gen_audio.py와 같은 신디사이징, 시드 고정. 6초 루프.
  python scripts/gen_audio_layers.py
"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join("games-src", "last-login", "assets", "sfx")
DUR = 6.0


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))


def pulse():
    n = int(SR * DUR); out = []
    for i in range(n):
        t = i / SR
        beat = 0.5 + 0.5 * math.sin(2 * math.pi * 0.55 * t - math.pi / 2)   # 0..1, 6초에 3.3번
        beat = beat ** 3                                                     # 뾰족하게 — 뛰는 느낌
        s = math.sin(2 * math.pi * 40 * t) * 0.7 + math.sin(2 * math.pi * 80 * t) * 0.2
        out.append(0.11 * beat * s)
    return out


def breath():
    random.seed(20021102)
    n = int(SR * DUR); out = []; acc = 0.0; lp = 0.035
    for i in range(n):
        t = i / SR
        acc += lp * (random.uniform(-1, 1) - acc)
        swell = 0.5 + 0.5 * math.sin(2 * math.pi * t / DUR - math.pi / 2)    # 한 루프에 한 번 차오른다
        swell = swell ** 2
        out.append(0.09 * swell * acc / lp * 0.05)
    return out


write("amb_pulse.wav", pulse())
write("amb_breath.wav", breath())
print("ok")
