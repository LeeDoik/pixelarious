"""합성 효과음을 2002년 PC의 신호 경로로 통과시킨다.

gen_audio.py가 만든 순음은 너무 깨끗하다. 그 시절 UI 소리가 그렇게 들렸던 건
소리 자체가 아니라 그것이 지나온 하드웨어 때문이다 — 11kHz 8비트 WAV,
저역이 없는 케이스 스피커, 사운드카드의 잔류 히스, 값싼 앰프의 포화.
이 스크립트는 그 경로를 순서대로 흉내낸다. (scripts/degrade_photo.py의 소리판)

  python scripts/degrade_sfx.py                 # 프리뷰 3단계 + A/B 비교본 생성
  python scripts/degrade_sfx.py --apply medium  # 고른 단계를 assets/sfx에 반영

표준 라이브러리만 쓴다(gen_audio.py와 같은 규칙 — 라이선스 청정).
click_*/key_*는 사용자가 준 실제 녹음이라 대상에서 제외한다.
"""
import argparse, math, os, random, struct, wave

SFX = os.path.join("games-src", "last-login", "assets", "sfx")
PREVIEW = os.path.join("scripts", "audio_preview")

# 합성음만. 실제 녹음(click_*/key_*)은 절대 넣지 말 것.
TARGETS = ["msg", "unlock", "error", "startup", "boot"]
AMBIENT = ["amb_fan", "amb_hum", "amb_drone"]

# 스피커에서 나오는 소리 / 방에 있는 소리를 가른다.
# UI 알림음은 케이스 스피커를 통과하니 저역이 없어야 하지만, CRT 험과 앰비언트는
# 방 자체의 소리다 — 여기에 하이패스를 걸면 55Hz 드론이 통째로 사라진다.
ROOM = {"boot", "amb_fan", "amb_hum", "amb_drone"}

PRESETS = {
    # hp/lp = 스피커 대역, decim = 실효 샘플레이트 나누기, bits = 양자화,
    # hiss = 사운드카드 잔류 잡음, drive = 앰프 포화
    # recon = DAC 재구성 필터. 이게 없으면 데시메이션 거울상이 그대로 남아
    # "옛날 PC"가 아니라 "디지털 링잉"으로 들린다.
    "light":  dict(hp=180, lp=9000, decim=2, bits=10, recon=9000, hiss=0.0015, drive=1.2),
    "medium": dict(hp=250, lp=7000, decim=2, bits=8,  recon=7500, hiss=0.0040, drive=1.6),
    "heavy":  dict(hp=350, lp=5200, decim=3, bits=6,  recon=6000, hiss=0.0100, drive=2.2),
}


def read_wav(path):
    with wave.open(path, "rb") as w:
        assert w.getsampwidth() == 2, "16비트 모노만 다룬다: " + path
        assert w.getnchannels() == 1, "16비트 모노만 다룬다: " + path
        sr = w.getframerate()
        raw = w.readframes(w.getnframes())
    return sr, [s / 32768.0 for s in struct.unpack("<%dh" % (len(raw) // 2), raw)]


def write_wav(path, sr, xs):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(b"".join(
            struct.pack("<h", max(-32767, min(32767, int(round(s * 32767))))) for s in xs))


def lowpass(xs, fc, sr):
    a = 1.0 - math.exp(-2.0 * math.pi * fc / sr)
    y, out = 0.0, []
    for x in xs:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(xs, fc, sr):
    lp = lowpass(xs, fc, sr)
    return [x - l for x, l in zip(xs, lp)]


def decimate(xs, factor):
    """샘플레이트 크러시 — 값을 계단으로 붙든다(앨리어싱이 그 시절 고역 질감)."""
    if factor <= 1:
        return list(xs)
    out, held = [], 0.0
    for i, x in enumerate(xs):
        if i % factor == 0:
            held = x
        out.append(held)
    return out


def quantize(xs, bits):
    if bits >= 16:
        return list(xs)
    steps = 2 ** (bits - 1)
    return [max(-1.0, min(1.0, round(x * steps) / steps)) for x in xs]


def add_hiss(xs, amt, rng):
    return [x + rng.uniform(-amt, amt) for x in xs]


def soft_clip(xs, drive):
    if drive <= 1.0:
        return list(xs)
    return [math.tanh(x * drive) / math.tanh(drive) for x in xs]


def fade_edges(xs, sr, ms=4.0):
    """히스를 얹으면 시작·끝이 뚝 끊겨 딸깍 소리가 난다 — 짧게 재운다."""
    n = max(1, int(sr * ms / 1000.0))
    out = list(xs)
    for i in range(min(n, len(out))):
        g = i / n
        out[i] *= g
        out[-1 - i] *= g
    return out


def match_peak(xs, target):
    peak = max((abs(x) for x in xs), default=0.0)
    if peak <= 1e-9 or target <= 1e-9:
        return xs
    g = target / peak
    return [x * g for x in xs]


def degrade(xs, sr, p, seed, room=False):
    rng = random.Random(seed)
    peak = max((abs(x) for x in xs), default=0.0)
    # 방의 소리는 스피커를 거치지 않는다 — 저역을 살려두고 포화도 덜 먹인다
    y = list(xs) if room else highpass(xs, p["hp"], sr)   # 1. 케이스 스피커엔 저역이 없다
    y = lowpass(y, p["lp"] * (1.6 if room else 1.0), sr)  # 2. 고역도 일찍 떨어진다
    y = decimate(y, p["decim"])            # 3. 11kHz/8kHz WAV
    y = quantize(y, p["bits"])             # 4. 8비트 양자화 잡음
    y = lowpass(y, p["recon"], sr)         # 5. DAC 재구성 필터
    y = soft_clip(y, 1.0 if room else p["drive"])  # 6. 값싼 앰프의 포화
    y = add_hiss(y, p["hiss"], rng)        # 7. 사운드카드 잔류 히스
    y = match_peak(y, peak)                # 원본과 같은 최대 레벨로 되돌린다
    return fade_edges(y, sr)


def rms_db(xs):
    if not xs:
        return -99.0
    m = math.sqrt(sum(x * x for x in xs) / len(xs))
    return 20 * math.log10(m) if m > 1e-9 else -99.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", choices=sorted(PRESETS), help="고른 단계를 assets/sfx에 덮어쓴다")
    ap.add_argument("--ambient", action="store_true", help="앰비언트 루프 3종도 대상에 넣는다")
    ap.add_argument("--seed", type=int, default=1102, help="히스 난수 시드(재현용)")
    args = ap.parse_args()

    names = TARGETS + (AMBIENT if args.ambient else [])
    for name in names:
        src = os.path.join(SFX, name + ".wav")
        if not os.path.exists(src):
            print("건너뜀(없음): " + name)
            continue
        sr, xs = read_wav(src)

        if args.apply:
            y = degrade(xs, sr, PRESETS[args.apply], args.seed, name in ROOM)
            write_wav(src, sr, y)
            print("%-10s ← %-6s  %.1f dB RMS" % (name, args.apply, rms_db(y)))
            continue

        gap = [0.0] * int(sr * 0.35)
        compare = list(xs)
        line = "%-10s 원본 %.1f dB" % (name, rms_db(xs))
        for level in ("light", "medium", "heavy"):
            y = degrade(xs, sr, PRESETS[level], args.seed, name in ROOM)
            write_wav(os.path.join(PREVIEW, "%s__%s.wav" % (name, level)), sr, y)
            compare += gap + y
            line += " · %s %.1f" % (level, rms_db(y))
        write_wav(os.path.join(PREVIEW, "%s__compare.wav" % name), sr, compare)
        print(line)

    if not args.apply:
        print("\n프리뷰: %s" % PREVIEW)
        print("*__compare.wav 하나만 들으면 [원본 → light → medium → heavy] 순으로 이어 들린다.")


if __name__ == "__main__":
    main()
