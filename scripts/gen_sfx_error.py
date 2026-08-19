"""오류음 하나만 만든다. 사용: python scripts/gen_sfx_error.py

gen_audio.py를 다시 돌리면 안 된다 — 그 스크립트의 OUT은 옛 경로(game/assets/sfx)를
가리키고, click/key 계열은 그 뒤에 실제 녹음을 split_clicks.py로 자른 것으로 바뀌었다.
전량 재생성은 그 녹음을 신디사이즈 음으로 덮어쓴다.
"""
import math, os, struct, wave

SR = 22050
OUT = os.path.join("games-src", "last-login", "assets", "sfx")


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))


def tone(freq, dur, vol=0.5, attack=0.004, release=0.45):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        e = min(t / attack, 1.0, max(0.0, (dur - t) / (dur * release)))
        out.append(vol * e * math.sin(2 * math.pi * freq * i / SR))
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0.0 for t in tracks) for i in range(n)]


# 이 시대 오류음은 짧게 떨어지는 단3도 두 음이었다. 조금 물리게(살짝 어긋난 배음)
# 겹쳐야 맑은 알림음(unlock)과 헷갈리지 않는다.
high = mix(tone(466.16, 0.12, 0.30), tone(469.0, 0.12, 0.12))
low = mix(tone(349.23, 0.34, 0.30, release=0.6), tone(351.5, 0.34, 0.12, release=0.6))
write("error.wav", high + low)
print("ok -> %s/error.wav" % OUT)
