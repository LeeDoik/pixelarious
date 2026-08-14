"""LAST LOGIN 사운드 전량 신디사이징. 사용: python scripts/gen_audio.py"""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join("game", "assets", "sfx")

def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))

def env(i, n, a=0.01, r=0.3):
    t = i / SR
    dur = n / SR
    return min(t / a, 1.0, max(0.0, (dur - t) / (dur * r)))

def tone(freq, dur, vol=0.5):
    n = int(SR * dur)
    return [vol * env(i, n) * math.sin(2 * math.pi * freq * i / SR) for i in range(n)]

def noise(dur, vol=0.15, lp=0.02):
    n = int(SR * dur); out = []; acc = 0.0
    for _ in range(n):
        acc += lp * (random.uniform(-1, 1) - acc)   # 저역 통과 = 팬 소음 질감
        out.append(vol * acc / lp * 0.05)
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0.0 for t in tracks) for i in range(n)]

def delayed(samples, delay_s):
    return [0.0] * int(SR * delay_s) + samples

# SFX
write("msg.wav", tone(880, 0.09) + tone(1320, 0.12))          # 메신저 알림 두 음
write("unlock.wav", tone(523, 0.08) + tone(784, 0.16))
write("click.wav", tone(2000, 0.03, 0.2))
write("boot.wav", mix(tone(220, 0.8, 0.3), tone(331, 0.8, 0.2)))
# 시동음: 상승 아르페지오 3음 (G4 → C5 → E5)
write("startup.wav", mix(tone(392.0, 1.4, 0.22),
                         delayed(tone(523.25, 1.1, 0.22), 0.15),
                         delayed(tone(659.25, 0.9, 0.20), 0.30)))
# 앰비언트 루프 (act 1/2/3 겹침용)
write("amb_fan.wav", noise(6.0, 0.5))                          # 레이어 1: 팬
write("amb_hum.wav", tone(120, 6.0, 0.06) )                    # 레이어 2: 형광등 험
write("amb_drone.wav", mix(tone(55, 6.0, 0.10), tone(58, 6.0, 0.08)))  # 레이어 3: 불협 드론
print("ok")
